#!/usr/bin/env python3
"""End-to-end acceptance test for the omicstat MCP thin shell.

Starts server.py over real MCP stdio (mcp.client.stdio) and exercises every
tool against the fixture module `omicstat-selftest` (the environment
self-test).  Run it directly:

    python mcp/test_client.py

Engines:
  native     -- the environment named by OMICSTAT_NATIVE_ENV, else the real
                <suite>/.omicstat-r/native-env.json (env/native/setup_native.R),
                else a TEMPORARY development environment written by this test
                (Rscript on PATH + the library holding ggplot2, override with
                OMICSTAT_TEST_R_LIBRARY + env/native/Rprofile.omicstat).
  container  -- only when `docker image inspect <pinned image>` succeeds;
                otherwise those cases are reported as SKIP with the reason.

Python lane (ENGINEERING_PLAN 10.8 item 2): the fixture module
`omicstat-selftest-py` (scripts/run_*.py) is listed from the same registry and
run end to end -- python in omicstat-py, then the R render step in omicstat-r --
on the container engine when both pinned images exist, and on the native
engine when native-env.json has a "python" key; otherwise SKIP with the reason.

Working files land under OMICSTAT_MCP_SCRATCH (default <tmp>/omicstat-mcp-proto).
Exits 0 only when every assertion passed.  ASCII only.
"""

import asyncio
import atexit
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import uuid

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

HERE = os.path.dirname(os.path.abspath(__file__))
SUITE_ROOT = os.path.dirname(HERE)
SERVER = os.path.join(HERE, "server.py")
SCRATCH = os.path.abspath(os.environ.get(
    "OMICSTAT_MCP_SCRATCH", os.path.join(tempfile.gettempdir(), "omicstat-mcp-proto")
))
RUNS_ROOT = os.path.abspath(os.environ.get(
    "OMICSTAT_RUNS_ROOT", os.path.join(tempfile.gettempdir(), "omicstat-runs")
))

RESULTS = []
SKIPPED = []
FIXTURE_MODULE = "omicstat-selftest"
FIXTURE_ENTRY = "skills/omicstat-selftest/scripts/run_omicstat_selftest.R"
# Default-seed anchors of the self-test's synthetic fixture
# (fx_feature_table(1000, seed = 20260925); see the module's smoke test).
ANCHOR = {"n_features": 1000, "n_up": 195, "n_down": 175, "n_padj_na": 43}
# Same pattern as server._ROUTER_ROW (section-1 router rows).
ROUTER_ROW = re.compile(r"\|\s*`([a-z0-9-]+)`\s*\|\s*`(scripts/run_[A-Za-z0-9_]+\.(?:R|py))`\s*\|")
PY_FIXTURE_MODULE = "omicstat-selftest-py"
PY_FIXTURE_ENTRY = "skills/omicstat-selftest-py/scripts/run_omicstat_selftest_py.py"
# Default-seed anchors of the Python self-test fixtures (random.Random(20260925)).
PY_ANCHOR = {"n_features": 1000, "n_up": 144, "n_down": 116, "n_padj_na": 26, "n_cells": 300}
# A file / directory outside every allowed root on this platform.
OUTSIDE_FILE = r"C:\Windows\win.ini" if os.name == "nt" else "/etc/hostname"
OUTSIDE_DIR = r"C:\Windows\Temp\omicstat-escape" if os.name == "nt" else "/etc/omicstat-escape"


def ensure_dev_native_env():
    """Same resolution as test_publication.ensure_dev_native_env(); exported
    through os.environ so the stdio server child inherits it."""
    given = os.environ.get("OMICSTAT_NATIVE_ENV")
    if given and os.path.isfile(given):
        return given, "OMICSTAT_NATIVE_ENV"
    real = os.path.join(SUITE_ROOT, ".omicstat-r", "native-env.json")
    if os.path.isfile(real) and not given:
        return real, "setup_native.R environment"
    rscript = shutil.which("Rscript")
    if not rscript:
        return None, "no Rscript on PATH"
    library = os.environ.get("OMICSTAT_TEST_R_LIBRARY")
    if not library:
        probe = subprocess.run([rscript, "-e", "cat(dirname(find.package('ggplot2')))"],
                               stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=120)
        library = probe.stdout.strip()
    if not library or not os.path.isdir(library):
        return None, "no R library with ggplot2 found"
    folder = tempfile.mkdtemp(prefix="omicstat-dev-native-")
    atexit.register(shutil.rmtree, folder, True)
    path = os.path.join(folder, "native-env.json")
    with open(path, "w", encoding="utf-8") as fh:
        json.dump({"schema": "omicstat.native-env.v1", "note": "temporary test environment",
                   "rscript": rscript, "library": library,
                   "rprofile": os.path.join(SUITE_ROOT, "env", "native", "Rprofile.omicstat")}, fh)
    os.environ["OMICSTAT_NATIVE_ENV"] = path
    return path, "temporary development environment (%s, %s)" % (rscript, library)


def container_image():
    """(image, None) when the pinned image exists locally, else (image, reason)."""
    image = os.environ.get("OMICSTAT_IMAGE")
    if not image:
        with open(os.path.join(SUITE_ROOT, "env", "omicstat-env.json"), encoding="utf-8") as fh:
            cfg = json.load(fh)
        image = "%s:%s" % (cfg["image"], cfg["image_tag"])
    docker = ["wsl", "-e", "docker"] if os.name == "nt" else ["docker"]
    try:
        probe = subprocess.run(docker + ["image", "inspect", image], stdin=subprocess.DEVNULL,
                               capture_output=True, timeout=30)
    except (OSError, subprocess.TimeoutExpired) as exc:
        return image, "docker unavailable (%s)" % exc
    if probe.returncode != 0:
        return image, "docker image %s is not built on this machine" % image
    return image, None


def py_container_image():
    """(image, None) when the pinned omicstat-py image exists locally, else (image, reason)."""
    image = os.environ.get("OMICSTAT_PY_IMAGE")
    if not image:
        with open(os.path.join(SUITE_ROOT, "env", "omicstat-env.json"), encoding="utf-8") as fh:
            lane = json.load(fh)["python_lane"]
        image = "%s:%s" % (lane["image"], lane["image_tag"])
    docker = ["wsl", "-e", "docker"] if os.name == "nt" else ["docker"]
    try:
        probe = subprocess.run(docker + ["image", "inspect", image], stdin=subprocess.DEVNULL,
                               capture_output=True, timeout=30)
    except (OSError, subprocess.TimeoutExpired) as exc:
        return image, "docker unavailable (%s)" % exc
    if probe.returncode != 0:
        return image, "docker image %s is not built on this machine" % image
    return image, None


def native_python_reason(native_env):
    """None when the native environment file names a usable Python, else the reason."""
    if not native_env:
        return "no native environment file"
    try:
        with open(native_env, encoding="utf-8") as fh:
            py = json.load(fh).get("python")
    except (OSError, ValueError) as exc:
        return "native environment unreadable (%s)" % exc
    if not py or not os.path.isfile(py):
        return "native-env.json has no usable \"python\" key (bash env/py/setup_native.sh)"
    return None


def valid_contract():
    return {
        "study_design": "two-group comparison of synthetic samples (environment self-test)",
        "analysis_population": {"description": "All synthetic features of the self-test fixture"},
        "estimand": {"summary_measure": "log2 fold change", "timepoint": "single time point"},
        "exposure_or_intervention": {"name": "Treated condition"},
        "comparator": {"name": "Control condition"},
        "outcomes": [{"name": "Feature expression", "timepoint": "single time point"}],
        "covariates": [],
        "missing_data": {"strategy": "features with adjusted P = NA are reported as filtered"},
        "multiplicity": {"strategy": "Benjamini-Hochberg across features"},
        "analysis_sets": [{"name": "all features"}],
        "semantic_declarations": {
            "study_design": {"design_type": "two-group comparison"},
            "population": {"definition": "all synthetic features"},
            "estimand": {"measure": "log2 fold change", "target": "treated versus control"},
            "exposure": {"variable_or_intervention": "Treated condition"},
            "comparator": {"definition": "Control condition"},
            "outcomes": [{"identity": "Feature expression", "timing": "single time point"}],
            "missing_data": {"strategy": "filtered features reported"},
            "multiplicity": {"strategy": "Benjamini-Hochberg"},
        },
    }


def check(name, ok, detail=""):
    RESULTS.append((name, bool(ok), detail))
    print("%-6s %s%s" % ("PASS" if ok else "FAIL", name,
                         ("  -- " + str(detail)[:300]) if detail else ""),
          flush=True)
    return bool(ok)


def skip(name, reason):
    SKIPPED.append((name, reason))
    print("%-6s %s  -- %s" % ("SKIP", name, reason), flush=True)


def text_of(result):
    parts = []
    for block in result.content:
        parts.append(getattr(block, "text", ""))
    return "".join(parts)


async def call_ok(session, tool, args):
    """Call a tool that is expected to succeed."""
    res = await session.call_tool(tool, args)
    return res, text_of(res)


async def call_expect_error(session, tool, args):
    """Call a tool expected to be refused; returns (is_error, message)."""
    try:
        res = await session.call_tool(tool, args)
    except Exception as exc:                                   # noqa: BLE001
        return True, str(exc)
    return bool(res.isError), text_of(res)


def assert_manifest(label, raw, expect_feature_rows=False):
    ok = True
    ok &= check("%s: manifest is JSON" % label, raw.lstrip().startswith("{"),
                raw[:120])
    try:
        man = json.loads(raw)
    except Exception as exc:                                   # noqa: BLE001
        check("%s: manifest parses" % label, False, exc)
        return None
    ok &= check("%s: exit_code == 0" % label, man.get("exit_code") == 0,
                "exit=%s stderr=%s" % (man.get("exit_code"),
                                       man.get("stderr_tail", "")[-300:]))
    ok &= check("%s: artifacts non-empty" % label,
                bool(man.get("artifacts")) and man.get("artifact_count", 0) > 0,
                man.get("artifact_count"))
    ok &= check("%s: manifest under 8k chars" % label, len(raw) < 8000, len(raw))
    ok &= check("%s: qc_triggered field present" % label, "qc_triggered" in man)
    ok &= check("%s: engine_warnings field present (list)" % label,
                isinstance(man.get("engine_warnings"), list),
                man.get("engine_warnings"))
    ok &= check("%s: degenerate_estimates field present" % label,
                isinstance(man.get("degenerate_estimates"), list))
    if expect_feature_rows:
        rows = man.get("effect_table") or []
        ok &= check("%s: feature table detected as the primary payload" % label,
                    man.get("effect_table_schema") == "feature-table"
                    and man.get("effect_table_sources") == ["tables/feature_table.csv"],
                    "schema=%s sources=%s" % (man.get("effect_table_schema"),
                                              man.get("effect_table_sources")))
        ok &= check("%s: feature rows are non-empty and identifiable" % label,
                    bool(rows) and all(r.get("feature_id") and "log2fc" in r for r in rows),
                    rows[:1])
        ok &= check("%s: a healthy fixture has no degenerate estimates" % label,
                    man.get("degenerate_estimates") == [], man.get("degenerate_estimates"))
    # Compact envelopes omit required disk-only fields. Validate the full
    # persisted manifest and review against their actual schemas instead.
    import publication                                        # noqa: PLC0415
    try:
        full = full_manifest(man)
        errors = publication.validate_instance(full, "publication_manifest")
        check("%s: on-disk publication manifest validates" % label, not errors, errors)
        with open(os.path.join(man["outdir"], "publication", "review.json"), encoding="utf-8") as fh:
            review = json.load(fh)
        errors = publication.validate_instance(review, "publication_review")
        check("%s: on-disk publication review validates" % label, not errors, errors)
        check("%s: clean run retains human publication review" % label,
              man.get("status") in {"review_required", "needs_input"}, man.get("status"))
    except (OSError, ValueError) as exc:
        check("%s: on-disk publication documents readable" % label, False, exc)
    return man


def offline_detector_checks():
    """The engine_warnings and degenerate detectors cannot be exercised by a
    healthy run, so drive them directly on planted input."""
    sys.path.insert(0, HERE)
    import server                                              # noqa: PLC0415

    plant = os.path.join(SCRATCH, "planted_outdir", "tables")
    os.makedirs(plant, exist_ok=True)
    with open(os.path.join(plant, "et.csv"), "w", encoding="utf-8", newline="") as fh:
        fh.write("term,analysis_id,effect_type,estimate,ci_low,ci_high,p_value\n")
        fh.write("good,model1,HR,1.42,1.10,1.83,0.007\n")
        fh.write("frailty_nonconverged,joint,HR,3.10,3.10,3.10,0.9\n")   # zero-width CI
        fh.write("impossible,model2,OR,9.90,1.10,1.83,0.02\n")           # estimate outside CI
    rows, sources, kind = server._scan_effect_tables(
        os.path.join(SCRATCH, "planted_outdir"))
    check("planted 7-column table is only a module-local summary",
          kind == "module-local" and sources == ["tables/et.csv"], (kind, sources))
    check("planted table yields 3 effect rows", len(rows) == 3, len(rows))
    flagged = server._degenerate_estimates(rows)
    issues = " ".join(f["issue"] for f in flagged)
    check("degenerate scan catches the zero-width CI",
          any("zero-width" in f["issue"] for f in flagged), issues)
    check("degenerate scan catches an estimate outside its CI",
          any("outside its CI" in f["issue"] for f in flagged), issues)
    check("degenerate scan leaves the healthy row alone", len(flagged) == 2, flagged)

    # Feature-table degeneracy (padj NA everywhere; every padj < 0.05).
    ft_dir = os.path.join(SCRATCH, "planted_features")
    os.makedirs(os.path.join(ft_dir, "tables"), exist_ok=True)
    with open(os.path.join(ft_dir, "tables", "feature_table.csv"), "w", encoding="utf-8", newline="") as fh:
        fh.write("feature_id,contrast,log2fc,pvalue,padj,method,n_group1,n_group2\n")
        fh.write("G1,a,0.5,0.5,NA,m,3,3\nG2,a,0.4,0.6,NA,m,3,3\n")
        fh.write("G1,b,2.0,1e-5,0.001,m,3,3\nG2,b,-2.0,1e-4,0.01,m,3,3\n")
    _rows, ft_sources, ft_kind = server._scan_effect_tables(ft_dir)
    ft_flags = server._degenerate_features(ft_dir, ft_sources)
    check("planted feature table is detected by header", ft_kind == "feature-table", ft_kind)
    check("feature degeneracy: padj NA for every feature is flagged",
          any(f["row"].endswith("contrast a") and "padj is NA" in f["issue"] for f in ft_flags), ft_flags)
    check("feature degeneracy: all features significant is flagged",
          any(f["row"].endswith("contrast b") and f["issue"].startswith("all 2 features") for f in ft_flags), ft_flags)

    warned = server._engine_warnings(
        "[3/9] fitting\nOS_ENGINE_OUTPUT: joint frailty convergence code 4\n",
        "Warning message:\nIn coxph(): Ran out of iterations and did not converge\n")
    check("engine_warnings captures an OS_ typed code",
          any("OS_ENGINE_OUTPUT" in w for w in warned), warned)
    check("engine_warnings unwraps a bare 'Warning message:' header",
          any("did not converge" in w for w in warned)
          and not any(w.strip() == "Warning message:" for w in warned), warned)
    check("engine_warnings ignores ordinary progress lines",
          not any("[3/9] fitting" in w for w in warned), warned)


def full_manifest(man):
    with open(os.path.join(man["outdir"], "provenance", "publication_manifest.json"), encoding="utf-8") as fh:
        return json.load(fh)


def selftest_summary(man):
    with open(os.path.join(man["outdir"], "results", "selftest_summary.json"), encoding="utf-8") as fh:
        return json.load(fh)


async def run_checks(session, engine, sample):
    """One real run of the fixture module on one engine, with every manifest,
    provenance and publication assertion."""
    requested_parent = os.path.join(SCRATCH, "run_selftest_" + engine)
    call_args = {
        "module": FIXTURE_MODULE,
        "engine": engine,
        "args": {"seed": 20260925, "journal": "nature", "outdir": requested_parent},
    }
    if engine == "native":
        call_args["study_contract"] = valid_contract()
    t0 = time.time()
    _res, raw = await call_ok(session, "omicstat_run", call_args)
    print("       (%s/%s took %.1fs)" % (FIXTURE_MODULE, engine, time.time() - t0))
    label = "selftest/" + engine
    man = assert_manifest(label, raw, expect_feature_rows=True)
    if not man:
        return None
    sample.setdefault("manifest", raw)
    try:
        uuid.UUID(man.get("run_id", ""))
        uuid_ok = True
    except (ValueError, AttributeError):
        uuid_ok = False
    check("%s: UUID leaf directory" % label,
          uuid_ok and os.path.basename(man["outdir"]) == man["run_id"], man.get("outdir"))
    check("%s: requested_outdir is parent" % label,
          os.path.normcase(man.get("requested_outdir", "")) == os.path.normcase(requested_parent),
          man.get("requested_outdir"))
    check("%s: upstream_runs ends with this run (handoff.json)" % label,
          (man.get("upstream_runs") or [None])[-1] == man.get("run_id"), man.get("upstream_runs"))
    standard = [
        os.path.join(man["outdir"], "provenance", "publication_manifest.json"),
        os.path.join(man["outdir"], "publication", "review.json"),
        os.path.join(man["outdir"], "publication", "artifact_index.json"),
        os.path.join(man["outdir"], "publication", "results_outline.md"),
        os.path.join(man["outdir"], "publication", "value_map.json"),
    ]
    check("%s: five publication artifacts" % label,
          all(os.path.isfile(path) for path in standard), standard)
    check("%s: engine/all artifact views are consistent" % label,
          man.get("artifact_count") == sum(len(v) for v in man.get("artifacts", {}).values())
          and man.get("all_artifact_count") == sum(len(v) for v in man.get("all_artifacts", {}).values()),
          (man.get("artifact_count"), man.get("all_artifact_count")))
    full = full_manifest(man)
    versions = full.get("software_versions") or {}
    check("%s: structured Python/R/repository/module provenance" % label,
          bool(versions.get("python_packages"))
          and bool(versions.get("r_packages"))
          and bool(versions.get("r_session_info"))
          and bool((versions.get("repository") or {}).get("commit"))
          and isinstance((versions.get("repository") or {}).get("dirty"), bool)
          and (versions.get("module_entry_script") or {}).get("path") == FIXTURE_ENTRY
          and len((versions.get("module_entry_script") or {}).get("sha256", "")) == 64,
          versions.get("module_entry_script"))
    check("%s: the engine's R session is the one probed for provenance" % label,
          "ggplot2" in (versions.get("r_packages") or {}), sorted(versions.get("r_packages") or {})[:5])
    check("%s: random_seed is recorded from args" % label,
          full.get("random_seed") == 20260925, full.get("random_seed"))
    repo_identity = (versions.get("repository") or {}).get("worktree_identity")
    identity_paths = {item.get("path") for item in (repo_identity or {}).get("code_inventory", [])
                      if isinstance(item, dict)}
    check("%s: dirty worktree has replayable code identity" % label,
          (not (versions.get("repository") or {}).get("dirty")) or (
              isinstance(repo_identity, dict)
              and all(len(str(repo_identity.get(field, ""))) == 64 for field in (
                  "status_sha256", "diff_sha256", "untracked_sha256",
                  "code_inventory_sha256", "worktree_sha256"))
              and {
                  "mcp/server.py", "mcp/publication.py",
                  "skills/_shared/scripts/validate_effect_table_cli.R",
                  "skills/_shared/scripts/effect_table.R",
                  FIXTURE_ENTRY,
              }.issubset(identity_paths)),
          repo_identity)
    check("%s: no-candidate validator is not_applicable" % label,
          (full.get("validator") or {}).get("status") == "not_applicable",
          full.get("validator"))
    check("%s: feature table is not mistaken for a canonical effect table" % label,
          (man.get("effect_table_validation") or {}).get("ok") is True
          and (man.get("effect_table_validation") or {}).get("canonical") == [],
          man.get("effect_table_validation"))
    summary = selftest_summary(man)
    check("%s: fixture anchors (1000 features; 195 up, 175 down, 43 padj NA)" % label,
          all(summary.get(k) == v for k, v in ANCHOR.items()),
          {k: summary.get(k) for k in ANCHOR})
    check("%s: results_summary is read from results/*.json" % label,
          (full.get("results_summary") or {}).get("n_features") == ANCHOR["n_features"],
          full.get("results_summary"))
    triggered = {item.get("id") for item in man.get("qc_triggered", [])}
    check("%s: QC rules are the module's ST-xx rules" % label,
          all(str(i).startswith("ST-") for i in triggered), sorted(triggered))
    check("%s: a managed engine is not reported as unmanaged (ST-07)" % label,
          "ST-07" not in triggered and summary.get("execution_mode") == (
              "container" if engine == "container" else "native"),
          (sorted(triggered), summary.get("execution_mode")))
    check("%s: the library path does not leak (ST-08)" % label, "ST-08" not in triggered, sorted(triggered))
    check("%s: qc_triggered agrees with the module's own summary" % label,
          len(triggered) == summary.get("n_triggered"), (sorted(triggered), summary.get("n_triggered")))
    outline_path = os.path.join(man["outdir"], "publication", "results_outline.md")
    with open(outline_path, encoding="utf-8") as fh:
        outline = fh.read()
    check("%s: outline has no None or pipe-delimited labels" % label,
          "None" not in outline and "|||" not in outline, outline[:500])
    check("%s: a figure was produced" % label,
          any(a["name"] == "figures/volcano.png" for a in man["artifacts"].get("figures", [])),
          list(man["artifacts"]))
    draft = [a["name"] for a in man["artifacts"].get("draft", []) if a["name"].endswith(".md")]
    if check("%s: a draft .md is listed" % label, bool(draft), list(man["artifacts"])):
        _r, body = await call_ok(session, "omicstat_read", {
            "path": os.path.join(man["outdir"], *draft[0].split("/"))})
        check("%s: omicstat_read returns a non-empty draft" % label,
              len(body.strip()) > 300, len(body))
        check("%s: draft says it is a self-test" % label, "self-test" in body, body[:120])
    fig = [a["name"] for a in man["artifacts"].get("figures", []) if a["name"].endswith(".png")]
    if fig:
        _r, body = await call_ok(session, "omicstat_read", {
            "path": os.path.join(man["outdir"], *fig[0].split("/"))})
        check("%s: omicstat_read returns no bytes for a figure" % label,
              '"kind": "binary"' in body, body[:160])
    if engine == "native":
        check("study_contract receives its v1 discriminator",
              (full.get("request") or {}).get("study_contract", {}).get(
                  "schema_version") == "omicstat.study-contract.v1")
    else:
        image_id = (full.get("runtime") or {}).get("container_image_id") or ""
        check("container manifest records an immutable image ID",
              image_id.startswith("sha256:") and len(image_id) == 71, image_id)
        check("legacy call without study_contract still runs",
              man.get("status") == "needs_input", man.get("status"))
    return man, summary


async def module_checks(session, sample, engines):
    """Module-dependent acceptance on the fixture module omicstat-selftest."""
    _res, desc = await call_ok(session, "omicstat_describe", {"module": FIXTURE_MODULE})
    check("describe(omicstat-selftest) contains --strict", "--strict" in desc, len(desc))
    check("describe includes both SKILL.md and --help sections",
          "## SKILL.md" in desc and "## --help" in desc)

    # ---------------- refusals ----------------
    # Refusals happen before R starts; the engine only has to be available.
    usable = next(engine for engine, reason in engines if not reason)
    is_err, msg = await call_expect_error(
        session, "omicstat_run",
        {"module": FIXTURE_MODULE, "engine": usable,
         "args": {"seed": 1, "totally-made-up-flag": "x"}})
    check("unknown flag is refused", is_err, msg[:200])
    check("refusal echoes the closest known flags",
          "Closest known flags" in msg and "--" in msg, msg[:200])

    # Any path-looking value is guarded, whichever flag carries it.
    is_err, msg = await call_expect_error(
        session, "omicstat_run",
        {"module": FIXTURE_MODULE, "engine": usable, "args": {"journal": OUTSIDE_FILE}})
    check("out-of-root path value is refused", is_err, msg[:200])
    check("path refusal names the allowed roots", "allowed roots" in msg, msg[:200])

    # outdir travels inside args like every other flag
    is_err, msg = await call_expect_error(
        session, "omicstat_run",
        {"module": FIXTURE_MODULE, "engine": usable, "args": {"outdir": OUTSIDE_DIR}})
    check("out-of-root --outdir is refused", is_err, msg[:200])
    check("outdir refusal names the allowed roots", "allowed roots" in msg, msg[:200])

    # ---------------- real runs ----------------
    native_run = None
    for engine, reason in engines:
        if reason:
            skip("real run on engine %s" % engine, reason)
            continue
        result = await run_checks(session, engine, sample)
        if result and engine == "native":
            native_run = result

    if native_run is None:
        skip("native-only checks (legacy status, --strict, validate_publication, default outdir)",
             "native engine unavailable")
        return
    native_man, native_summary = native_run

    # v0 compatibility is an independently exercised native call.  It must
    # reach the legacy review state rather than be rejected as a malformed v1
    # StudyContract merely because the optional argument was omitted.
    legacy_parent = os.path.join(SCRATCH, "run_selftest_native_legacy")
    _res, legacy_raw = await call_ok(session, "omicstat_run", {
        "module": FIXTURE_MODULE, "engine": "native", "args": {"outdir": legacy_parent},
    })
    legacy_manifest = assert_manifest("selftest/native-legacy", legacy_raw)
    check("legacy native call without study_contract reaches needs_input",
          bool(legacy_manifest) and legacy_manifest.get("status") == "needs_input",
          (legacy_manifest or {}).get("status"))

    # A bool True becomes a bare switch: --strict turns the verdict into the exit code.
    _res, strict_raw = await call_ok(session, "omicstat_run", {
        "module": FIXTURE_MODULE, "engine": "native",
        "args": {"strict": True, "outdir": os.path.join(SCRATCH, "run_selftest_native_strict")},
    })
    strict_man = json.loads(strict_raw)
    expected_rc = 0 if native_summary.get("environment_ok") else 1
    check("--strict (bool True -> bare flag) exits %d for this environment's verdict" % expected_rc,
          strict_man.get("exit_code") == expected_rc
          and "--strict" in strict_man.get("command_argv", []), strict_man.get("command_argv"))
    if expected_rc:
        check("--strict failure is a typed engine warning",
              any("OS_ENV_CHECK_FAILED" in w for w in strict_man.get("engine_warnings", [])),
              strict_man.get("engine_warnings"))
        check("--strict failure is blocked for publication",
              strict_man.get("status") == "blocked", strict_man.get("status"))

    _res, reviewed_raw = await call_ok(session, "omicstat_validate_publication",
                                       {"run_id": native_man["run_id"]})
    reviewed = json.loads(reviewed_raw)
    check("validate_publication resolves run_id registry",
          reviewed.get("run_id") == native_man["run_id"]
          and reviewed.get("outdir") == native_man["outdir"], reviewed.get("run_id"))

    # ---------------- default outdir allocation ----------------
    _res, raw = await call_ok(session, "omicstat_run", {
        "module": FIXTURE_MODULE, "engine": "native", "args": {},
    })
    man = json.loads(raw)
    check("outdir is allocated under omicstat-runs when omitted",
          os.path.normcase(man.get("outdir", "")).startswith(
              os.path.normcase(os.path.join(RUNS_ROOT, FIXTURE_MODULE))),
          man.get("outdir"))


async def python_module_checks(session, py_engines, listing):
    """Python lane end to end: registry, --help contract, refusal, and a real
    run per available engine (python in omicstat-py, then the R render step)."""
    rows = {m["module"]: m for m in listing.get("modules", [])}
    check("python module is listed from the same registry with its .py entry",
          rows.get(PY_FIXTURE_MODULE, {}).get("entry") == "scripts/run_omicstat_selftest_py.py",
          rows.get(PY_FIXTURE_MODULE))
    check("R and Python modules share one registry",
          any(str(m.get("entry", "")).endswith(".R") for m in rows.values())
          and any(str(m.get("entry", "")).endswith(".py") for m in rows.values()), sorted(rows))
    usable = [e for e, reason in py_engines if not reason]
    for engine, reason in py_engines:
        if reason:
            skip("python module on engine %s" % engine, reason)
    if not usable:
        return
    _res, desc = await call_ok(session, "omicstat_describe", {"module": PY_FIXTURE_MODULE})
    check("describe(python module): --help comes from the Python entry in the R format",
          "## --help" in desc and "Usage: python run_omicstat_selftest_py.py" in desc
          and re.search(r"^  --seed <int> +default: 20260925", desc, re.M) is not None, desc[-400:])
    is_err, msg = await call_expect_error(session, "omicstat_run", {
        "module": PY_FIXTURE_MODULE, "engine": usable[0], "args": {"no-such-flag": 1}})
    check("python module: unknown flag refused against its own --help", is_err and "Closest known flags" in msg, msg[:200])
    for engine in usable:
        label = "selftest-py/" + engine
        t0 = time.time()
        _res, raw = await call_ok(session, "omicstat_run", {
            "module": PY_FIXTURE_MODULE, "engine": engine,
            "args": {"seed": 20260925, "outdir": os.path.join(SCRATCH, "run_selftest_py_" + engine)}})
        print("       (%s/%s took %.1fs)" % (PY_FIXTURE_MODULE, engine, time.time() - t0))
        man = assert_manifest(label, raw, expect_feature_rows=True)
        if not man:
            continue
        check("%s: engine command is python" % label, (man.get("command_argv") or [None])[0] == "python",
              man.get("command_argv"))
        rs = man.get("render_step") or {}
        check("%s: R render step ran in %s and rendered" % (label, "omicstat-r" if engine == "container" else "native R"),
              rs.get("status") == "rendered" and rs.get("exit_code") == 0
              and (rs.get("command_argv") or [None])[0] == "Rscript", rs)
        figs = {a["name"] for a in (man.get("artifacts") or {}).get("figures", [])}
        check("%s: both requested figures exist (volcano, umap_clusters; pdf + png)" % label,
              {"figures/volcano.png", "figures/volcano.pdf", "figures/umap_clusters.png",
               "figures/umap_clusters.pdf"} <= figs, sorted(figs))
        out = man["outdir"]
        check("%s: render step recorded in provenance (figure_render.json + render_step)" % label,
              os.path.isfile(os.path.join(out, "provenance", "figure_render.json"))
              and json.load(open(os.path.join(out, "provenance", "provenance.json"), encoding="utf-8"))
              .get("render_step", {}).get("record") == "provenance/figure_render.json")
        summary = json.load(open(os.path.join(out, "results", "selftest_summary.json"), encoding="utf-8"))
        check("%s: fixture anchors %s" % (label, PY_ANCHOR), all(summary.get(k) == v for k, v in PY_ANCHOR.items()),
              {k: summary.get(k) for k in PY_ANCHOR})
        spec = json.load(open(os.path.join(out, "figures", "volcano.figure_spec.json"), encoding="utf-8"))
        check("%s: R volcano counts agree with the Python feature table" % label,
              spec.get("counts", {}).get("up") == summary["n_up"] and spec.get("counts", {}).get("down") == summary["n_down"],
              spec.get("counts"))
        triggered = {item.get("id") for item in man.get("qc_triggered", [])}
        check("%s: QC rules are the module's PY-xx rules" % label, all(str(i).startswith("PY-") for i in triggered), sorted(triggered))
        check("%s: managed engine, verdict PASS (no blocker/error rule)" % label,
              summary.get("execution_mode") == engine and summary.get("environment_ok") is True,
              (summary.get("execution_mode"), summary.get("failed_rules")))
        check("%s: upstream_runs ends with this run (scverse handoff)" % label,
              (man.get("upstream_runs") or [None])[-1] == man.get("run_id"), man.get("upstream_runs"))
        ho = json.load(open(os.path.join(out, "objects", "handoff.json"), encoding="utf-8"))
        check("%s: handoff is scverse with AnnData + the colour registry written by the R step" % label,
              ho.get("ecosystem") == "scverse"
              and {o["name"]: o["type"] for o in ho.get("objects", [])}.get("adata") == "AnnData"
              and any(o["name"] == "colour_registry" for o in ho.get("objects", [])), ho.get("objects"))
        full = full_manifest(man)
        versions = full.get("software_versions") or {}
        pe = versions.get("python_engine") or {}
        with open(os.path.join(SUITE_ROOT, "env", "omicstat-env.json"), encoding="utf-8") as fh:
            lane = json.load(fh)["python_lane"]
        check("%s: provenance probe carries the Python environment (interpreter + package versions)" % label,
              pe.get("python") == lane["python_version"] and pe.get("packages", {}).get("scanpy") == lane["pins"]["scanpy"]
              and pe.get("packages", {}).get("scvi-tools") == lane["pins"]["scvi-tools"]
              and pe.get("packages", {}).get("torch") == lane["pins"]["torch"],
              {k: pe.get(k) for k in ("python", "engine", "py_env_version")})
        check("%s: provenance entry script is the .py entry" % label,
              (versions.get("module_entry_script") or {}).get("path") == PY_FIXTURE_ENTRY, versions.get("module_entry_script"))
        check("%s: the render session's R packages are recorded" % label, "ggplot2" in (versions.get("r_packages") or {}))
        if engine == "container":
            image_id = (full.get("runtime") or {}).get("container_image_id") or ""
            check("%s: container_image_id is the omicstat-py image; render image ID recorded" % label,
                  image_id.startswith("sha256:") and image_id == pe.get("image_id")
                  and str(pe.get("render_image_id", "")).startswith("sha256:") and pe.get("render_image_id") != image_id,
                  (image_id, pe.get("image_id"), pe.get("render_image_id")))


async def main():
    os.makedirs(SCRATCH, exist_ok=True)
    native_env, native_note = ensure_dev_native_env()
    print("native engine: %s (%s)" % (native_env, native_note))
    image, container_reason = container_image()
    engines = [("native", None if native_env else native_note),
               ("container", container_reason)]
    _py_image, py_image_reason = py_container_image()
    py_engines = [("native", native_python_reason(native_env)),
                  ("container", py_image_reason or container_reason)]
    offline_detector_checks()
    # Explicitly preserve the isolated runtime roots for the server child.
    # Some MCP client versions do not inherit a caller's complete environment
    # by default on Windows.
    params = StdioServerParameters(command=sys.executable, args=[SERVER], env=dict(os.environ))
    sample = {}

    async with stdio_client(params) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()

            # ---------------- surface ----------------
            tools = await session.list_tools()
            names = sorted(t.name for t in tools.tools)
            check("list_tools returns exactly 5 tools", len(names) == 5, names)
            check("the 5 tools are the designed ones",
                  names == ["omicstat_describe", "omicstat_list_modules",
                            "omicstat_read", "omicstat_run",
                            "omicstat_validate_publication"], names)
            run_tool = next(t for t in tools.tools if t.name == "omicstat_run")
            check("omicstat_run exposes optional study_contract",
                  "study_contract" in run_tool.inputSchema.get("properties", {})
                  and "study_contract" not in run_tool.inputSchema.get("required", []),
                  run_tool.inputSchema)

            res_list = await session.list_resources()
            tmpl = await session.list_resource_templates()
            uris = [str(r.uri) for r in res_list.resources]
            tpls = [t.uriTemplate for t in tmpl.resourceTemplates]
            check("omicstat://router resource is listed",
                  "omicstat://router" in uris, uris)
            check("skill/help resource templates are listed",
                  any("omicstat://skill/" in t for t in tpls)
                  and any("omicstat://help/" in t for t in tpls), tpls)

            router = await session.read_resource("omicstat://router")
            check("omicstat://router reads back the routing map",
                  "Routing table" in router.contents[0].text,
                  len(router.contents[0].text))

            # ---------------- list / describe ----------------
            _res, raw = await call_ok(session, "omicstat_list_modules", {})
            listing = json.loads(raw)
            # The expected count is the number of section-1 router rows.
            expected = len(ROUTER_ROW.findall(router.contents[0].text))
            check("omicstat_list_modules returns every router-table module (%d)" % expected,
                  listing.get("count") == expected and len(listing["modules"]) == expected,
                  listing.get("count"))
            check("each module row has name, summary and entry script",
                  all(m.get("module") and m.get("summary") and m.get("entry")
                      for m in listing["modules"]),
                  [m["module"] for m in listing["modules"]
                   if not (m.get("summary") and m.get("entry"))])

            registered = dict(ROUTER_ROW.findall(router.contents[0].text))
            check("listed entry scripts exactly match the router registry",
                  {m["module"]: m["entry"] for m in listing["modules"]} == registered)
            # Host acceptance can exercise help for all newly installed entries
            # through both pinned images, without requiring nested Docker.
            if os.environ.get("OMICSTAT_TEST_DESCRIBE_INSTALLED") == "1":
                with open(os.path.join(SUITE_ROOT, "docs/build/BUILD_STATUS.json"),
                          encoding="utf-8") as fh:
                    new_modules = json.load(fh)["implemented_new"]
                for module in new_modules:
                    res, desc = await call_ok(session, "omicstat_describe", {"module": module})
                    check("describe(%s) exposes registered entry, help and options" % module,
                          not res.isError
                          and "entry script: " + registered[module] in desc
                          and "## --help" in desc and "--outdir" in desc
                          and "- options.md" in desc)

            is_err, msg = await call_expect_error(
                session, "omicstat_describe", {"module": "no-such-module"})
            check("describe(unknown module) is refused with 'unknown module'",
                  is_err and "unknown module" in msg, msg[:200])

            read_bad = await session.call_tool(
                "omicstat_read", {"path": OUTSIDE_FILE})
            check("omicstat_read refuses a path outside the allowed roots",
                  "path refused" in text_of(read_bad), text_of(read_bad)[:160])

            # ---------------- module-dependent acceptance ----------------
            installed = {m.get("module") for m in listing.get("modules", [])}
            if FIXTURE_MODULE not in installed:
                skip("module-dependent acceptance",
                     "fixture module %s is not in the router table" % FIXTURE_MODULE)
            elif not native_env and container_reason:
                skip("module-dependent acceptance",
                     "no engine: native (%s); container (%s)" % (native_note, container_reason))
            else:
                await module_checks(session, sample, engines)

            # ---------------- Python lane ----------------
            if PY_FIXTURE_MODULE not in installed:
                skip("python-lane acceptance", "fixture module %s is not in the router table" % PY_FIXTURE_MODULE)
            else:
                await python_module_checks(session, py_engines, listing)

    print("\n" + "=" * 72)
    failed = [n for n, ok, _d in RESULTS if not ok]
    print("%d assertions, %d passed, %d failed, %d skipped"
          % (len(RESULTS), len(RESULTS) - len(failed), len(failed), len(SKIPPED)))
    for name in failed:
        print("  FAILED:", name)
    for name, reason in SKIPPED:
        print("  SKIPPED:", name, "--", reason)
    if sample.get("manifest"):
        path = os.path.join(SCRATCH, "sample_manifest.json")
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(sample["manifest"])
        print("sample manifest written to", path,
              "(%d chars)" % len(sample["manifest"]))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))

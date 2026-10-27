"""module_kit.py -- building blocks every Python analysis module shares.

Python counterpart of skills/_shared/scripts/module_kit.R: the --spec replay,
QC rule tables (same CSV dialect, read by mcp/publication.py scan_qc),
environment signature, provenance + resolved_spec.json, report templates from
references/reporting-templates.md, deterministic text/JSON writers and the
golden-baseline check. Standard library only. ASCII only.

Contents
  spec_argv(argv)                     expand "--spec <resolved_spec.json>" into argv
  canonical_argv(spec, args)          flag vector written to resolved_spec.json
  qc_rule(), qc_finalize(), write_qc_results()
  env_signature(), env_signature_string()
  write_provenance()                  provenance/provenance.json + resolved_spec.json
  read_templates(path), fill_template(text, values)
  write_text(lines, path), write_json(obj, path), sha256_file(path)
  golden_write(module_dir, outdir, paths), golden_check(module_dir, outdir)
  closing_line(qc)                    "N of M rules triggered; read X first"
  run_id(outdir)                      OMICSTAT_RUN_ID (MCP) or basename(outdir)
"""
import hashlib
import importlib.metadata as md
import json
import os
import platform
import re
import sys

from .args import fmt_value
from .errors import OmicstatError

OS_QC_SEVERITIES = ("blocker", "error", "warning", "info")
PROVENANCE_SCHEMA = "omicstat.provenance.v1"


# ---------------------------------------------------------------------------
# Writers (UTF-8, LF, no BOM; byte-stable)
# ---------------------------------------------------------------------------
def write_text(lines, path):
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    if isinstance(lines, str):
        lines = [lines]
    with open(path, "wb") as fh:
        fh.write(("\n".join(lines) + "\n").encode("utf-8"))
    return path


def _sort_keys(x):
    if isinstance(x, dict):
        return {k: _sort_keys(x[k]) for k in sorted(x)}
    if isinstance(x, (list, tuple)):
        return [_sort_keys(v) for v in x]
    return x


def _json_safe(x):
    if isinstance(x, float) and (x != x or x in (float("inf"), float("-inf"))):
        return None
    if isinstance(x, dict):
        return {str(k): _json_safe(v) for k, v in x.items()}
    if isinstance(x, (list, tuple)):
        return [_json_safe(v) for v in x]
    return x


def write_json(obj, path, sort_keys=True):
    """Deterministic JSON: sorted keys (default), 2-space indent, NaN/Inf -> null, LF."""
    obj = _json_safe(obj)
    text = json.dumps(_sort_keys(obj) if sort_keys else obj, indent=2, ensure_ascii=False, allow_nan=False)
    return write_text(text, path)


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


# ---------------------------------------------------------------------------
# --spec replay (ENGINEERING_PLAN 3.2 step 2) -- same semantics as os_spec_argv
# ---------------------------------------------------------------------------
def spec_argv(argv):
    """Replace "--spec <file>" by the file's argv; flags given on the command line win."""
    argv = list(argv)
    idx = [k for k, t in enumerate(argv) if t == "--spec" or t.startswith("--spec=")]
    if not idx:
        return argv
    i = idx[0]
    path = argv[i + 1] if argv[i] == "--spec" and i + 1 < len(argv) else (
        argv[i][len("--spec="):] if argv[i] != "--spec" else None)
    if not path or not os.path.isfile(path):
        raise OmicstatError("OS_INVALID_PARAMETER", "--spec expected an existing resolved_spec.json, got '%s'" % path)
    rest = argv[:i] + argv[i + (2 if argv[i] == "--spec" else 1):]
    with open(path, encoding="utf-8") as fh:
        old = [str(x) for x in (json.load(fh).get("argv") or [])]

    def flags_of(v):
        return {t.split("=", 1)[0] for t in v if t.startswith("--")}
    drop = flags_of(old) & flags_of(rest)
    keep, j = [], 0
    while j < len(old):
        tok = old[j]
        has_val = j < len(old) - 1 and not old[j + 1].startswith("--") and "=" not in tok
        if tok.split("=", 1)[0] not in drop:
            keep += [tok] + ([old[j + 1]] if has_val else [])
        j += 2 if has_val else 1
    return keep + rest


def canonical_argv(spec, args, skip=("help", "spec", "outdir")):
    """Every flag with its resolved value (switches only when on), in spec order."""
    out = []
    for f in spec.flags.values():
        if f.name in skip:
            continue
        v = args.get(f.name)
        if f.type == "bool":
            if v:
                out.append("--" + f.name)
            continue
        if v is None:
            continue
        value = fmt_value(v)
        if isinstance(v, float) and float(value) != v:
            value = format(v, ".17g")
        out += ["--" + f.name, value]
    return out


# ---------------------------------------------------------------------------
# QC rule table (dialect read by mcp/publication.py scan_qc; = module_kit.R)
# ---------------------------------------------------------------------------
def qc_rule(id, check, triggered, severity, message, action="", evidence=""):   # noqa: A002
    if severity not in OS_QC_SEVERITIES:
        raise OmicstatError("OS_INVALID_PARAMETER", "QC severity '%s' is not one of %s."
                            % (severity, ", ".join(OS_QC_SEVERITIES)))
    trig = triggered is True
    return {"id": id, "check": check, "severity": severity, "triggered": trig,
            "blocking": trig and severity == "blocker", "message": message,
            "action": action if trig else "", "evidence": evidence}


def qc_finalize(rows, read_first):
    table = sorted(rows, key=lambda r: r["id"].encode("utf-8"))
    trig = [r for r in table if r["triggered"]]
    rank = {s: k for k, s in enumerate(OS_QC_SEVERITIES)}
    worst = sorted(trig, key=lambda r: (rank[r["severity"]], r["id"].encode("utf-8")))[0]["id"] if trig else None
    return {"table": table, "n_rules": len(table), "n_triggered": len(trig),
            "blocking": any(r["blocking"] for r in trig),
            "blocking_ids": [r["id"] for r in trig if r["blocking"]],
            "failed": any(r["severity"] in ("blocker", "error") for r in trig),
            "failed_ids": [r["id"] for r in trig if r["severity"] in ("blocker", "error")],
            "worst": worst, "read_first": "qc/qc_results.csv" if trig else read_first}


def csv_quote(value):
    """R write.csv(quote = TRUE) quoting of one character cell."""
    return '"' + str(value).replace('"', '""') + '"'


def write_qc_results(qc, outdir):
    """qc/qc_results.csv, byte-identical in layout to module_kit.R os_write_qc_results."""
    cols = ["id", "check", "severity", "triggered", "blocking", "message", "action", "evidence"]
    lines = [",".join(csv_quote(c) for c in cols)]
    for r in qc["table"]:
        cells = []
        for c in cols:
            v = r[c]
            if c in ("triggered", "blocking"):
                v = "TRUE" if v else "FALSE"
            cells.append(csv_quote(v))
        lines.append(",".join(cells))
    return write_text(lines, os.path.join(outdir, "qc", "qc_results.csv"))


def run_id(outdir):
    """The run's id: OMICSTAT_RUN_ID (set per run by the MCP shell -- inside the
    container the run directory is mounted as /ws, so its basename is not the
    id), else the basename of the output directory (direct CLI runs)."""
    return os.environ.get("OMICSTAT_RUN_ID") or os.path.basename(os.path.normpath(os.path.abspath(outdir)))


def closing_line(qc):
    return "%d of %d rules triggered; read %s first" % (qc["n_triggered"], qc["n_rules"], qc["read_first"])


# ---------------------------------------------------------------------------
# Environment signature and provenance
# ---------------------------------------------------------------------------
def env_tier():
    # OMICSTAT_PY_CONTAINER, not OMICSTAT_CONTAINER: the omicstat-r image sets
    # the latter too, and a Python run there is not the Python container tier.
    if os.environ.get("OMICSTAT_PY_CONTAINER"):
        return "container"
    if os.environ.get("OMICSTAT_PY_NATIVE"):
        return "native"
    return "dev"


def env_signature():
    """tier + Python + py_env_version + platform + image (module_kit.R os_env_signature)."""
    ver = None
    for p in (os.path.join(os.environ.get("OMICSTAT_ENV_DIR", ""), "py", "py-env.json"),
              os.path.join(os.path.dirname(__file__), "..", "..", "..", "..", "env", "py", "py-env.json")):
        try:
            with open(p, encoding="utf-8") as fh:
                ver = json.load(fh)["py_env_version"]
            break
        except (OSError, KeyError, ValueError):
            continue
    return {"tier": env_tier(), "python": platform.python_version(), "py_env_version": ver,
            "platform": "%s-%s" % (sys.platform, platform.machine()),
            "image": os.environ.get("OMICSTAT_PY_IMAGE_ID") or None}


def env_signature_string(sig=None):
    sig = sig or env_signature()
    return "%s|Python %s|py_env %s|%s" % (sig["tier"], sig["python"], sig["py_env_version"], sig["platform"])


def package_versions(names=None):
    """{distribution: version} of the given distributions, or of every installed one."""
    if names is None:
        out = {}
        for d in md.distributions():
            out[re.sub(r"[-_.]+", "-", d.metadata["Name"]).lower()] = d.version
        return dict(sorted(out.items()))
    out = {}
    for n in names:
        try:
            out[n] = md.version(n)
        except md.PackageNotFoundError:
            out[n] = None
    return out


def write_provenance(outdir, module, module_version, argv, entry_script, seed, inputs=None, outputs=(),
                     upstream=None, extra=None, packages=None, seed_record=None, render_step=True):
    """provenance/provenance.json + provenance/resolved_spec.json (module_kit.R os_write_provenance).

    inputs: {name: path}; outputs: paths relative to outdir; upstream: result of
    handoff.read_handoff (or None); packages: {dist: version} (default: every
    installed distribution); render_step: record that the figures of this run
    are rendered by the R step (_shared/scripts/render_figure_request.R, in
    omicstat-r), whose own record is provenance/figure_render.json.
    """
    pdir = os.path.join(outdir, "provenance")
    os.makedirs(pdir, exist_ok=True)
    cmd = ["python", entry_script] + list(argv)
    prov = {
        "schema": PROVENANCE_SCHEMA, "module": module, "module_version": module_version,
        "language": "python",
        "command": " ".join(cmd), "command_argv": cmd,
        "environment": env_signature(), "seed": seed,
        "seed_record": seed_record,
        "inputs": {k: {"file": os.path.basename(p), "sha256": sha256_file(p)} for k, p in (inputs or {}).items()},
        "upstream_runs": list((upstream or {}).get("upstream_runs") or []),
        "upstream_module": (upstream or {}).get("module"),
        "packages": packages if packages is not None else package_versions(),
        "outputs": {f: sha256_file(os.path.join(outdir, f)) for f in outputs},
    }
    if render_step:
        prov["render_step"] = {"script": "skills/_shared/scripts/render_figure_request.R",
                               "request": "figure_data/figure_request.json",
                               "runs_in": "omicstat-r (R figure layer)",
                               "record": "provenance/figure_render.json"}
    prov.update(extra or {})
    write_json(prov, os.path.join(pdir, "provenance.json"))
    write_json({"schema": "omicstat.resolved_spec.v1", "module": module, "argv": list(argv)},
               os.path.join(pdir, "resolved_spec.json"))
    return os.path.join(pdir, "provenance.json")


# ---------------------------------------------------------------------------
# Report templates: fenced ```template <id> blocks (module_kit.R os_read_templates)
# ---------------------------------------------------------------------------
_TPL_START = re.compile(r"^```template ([A-Za-z0-9_]+)\s*$")
_SLOT = re.compile(r"\{([A-Za-z0-9_]+)\}")


def read_templates(path):
    with open(path, encoding="utf-8") as fh:
        lines = fh.read().split("\n")
    out, i = {}, 0
    while i < len(lines):
        m = _TPL_START.match(lines[i])
        if m:
            try:
                e = lines.index("```", i + 1)
            except ValueError:
                raise OmicstatError("OS_INVALID_INPUT", "template '%s' in %s is not closed." % (m.group(1), path)) from None
            out[m.group(1)] = "\n".join(lines[i + 1:e])
            i = e
        i += 1
    return out


def fill_template(text, values):
    for key in dict.fromkeys(_SLOT.findall(text)):
        v = values.get(key)
        if v is None or (isinstance(v, float) and v != v):
            raise OmicstatError("OS_TEMPLATE_SLOT_MISSING", "no value for {%s}." % key)
        text = text.replace("{%s}" % key, str(v))
    return text


# ---------------------------------------------------------------------------
# Golden baseline (lock 5) -- tests/golden_manifest.csv, same layout as R
# ---------------------------------------------------------------------------
def golden_write(module_dir, outdir, paths):
    rows = ["# env: " + env_signature_string(), "path,sha256,tier,exempt_fields"]
    tier = env_tier()
    for p in paths:
        rows.append("%s,%s,%s," % (p, sha256_file(os.path.join(outdir, p)), tier))
    return write_text(rows, os.path.join(module_dir, "tests", "golden_manifest.csv"))


def golden_check(module_dir, outdir):
    path = os.path.join(module_dir, "tests", "golden_manifest.csv")
    with open(path, encoding="utf-8") as fh:
        lines = [l for l in fh.read().split("\n") if l.strip()]
    env_line = [l for l in lines if l.startswith("# env: ")]
    rows = [l.split(",") for l in lines if not l.startswith("#")][1:]
    if not rows or not env_line:
        return {"status": "SKIP", "reason": "no golden baseline recorded yet", "problems": []}
    want, have = env_line[0][len("# env: "):], env_signature_string()
    if want != have:
        return {"status": "SKIP", "reason": "environment signature differs (golden: %s; running: %s)" % (want, have),
                "problems": []}
    bad = []
    for r in rows:
        f = os.path.join(outdir, r[0])
        got = sha256_file(f) if os.path.isfile(f) else "<missing>"
        if got != r[1]:
            bad.append(r[0])
    return {"status": "FAIL" if bad else "PASS", "reason": "", "problems": bad}

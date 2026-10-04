#!/usr/bin/env python3
"""omicstat MCP shell -- 5 generic tools over the omicstat R engines.

Architecture forked from the medstat MCP (5 synchronous tools, stdio, no
background jobs, 25-minute hard kill), but omicstat runs on its OWN R
environment (env/omicstat-env.json) and never on any medstat installation:

  engine "container" (default, the reference environment for golden
  baselines): the omicstat-r image pinned in env/omicstat-env.json, started
  through bin/omicstat-r-route.sh (Linux/macOS) or bin/omicstat-r-route.ps1
  (Windows -> WSL -> docker);
  engine "native": the isolated library created by env/native/setup_native.R
  (.omicstat-r/native-env.json), started through the same routers with
  OMICSTAT_R_NATIVE=1 so that only that library is on the search path.
  OMICSTAT_NATIVE_ENV may name a different native-env.json (keys rscript,
  library, rprofile) -- for development machines and tests; the routers
  honour the same variable, so the shell and the engine always agree.

Python lane (ENGINEERING_PLAN part 10): a module whose router entry is
scripts/run_*.py runs with `python` in the omicstat-py image (python_lane of
env/omicstat-env.json) or, natively, with the "python" interpreter of the
native-env.json; its figures are then drawn by the R render step
(skills/_shared/scripts/render_figure_request.R) in omicstat-r / the native
R. The tool surface is unchanged (still 5 tools).

The shell never interprets statistics.  It translates {flag: value} into argv,
refuses flags the module's own `--help` does not list, refuses paths outside
the allow-listed roots, runs the engine, and describes what landed on disk.

The manifest envelope additionally carries the three fields the blind-user
simulation (research/audit-0902/blind-user-simulation.md, "What the tool should
return") showed were load-bearing: `engine_warnings` (console-only OS_* /
convergence traces that no QC rule and no file records), `effect_table` (the
one payload with a real cross-module schema -- results.json has none, so it is
demoted to optional), and `degenerate_estimates` (a mechanical zero-width-CI /
estimate-outside-CI scan over those same rows).  All three are computed by the
shell from what the engine already wrote; no engine was modified.

ASCII only (house rule for Windows scripts).
NOTHING may be written to stdout: stdout is the MCP stdio protocol channel.
All logging goes to stderr.
"""

import csv
import copy
import datetime as _dt
import difflib
import hashlib
import importlib.metadata
import io
import json
import logging
import os
import platform
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import uuid
from pathlib import Path
from typing import Any, Dict, List, Optional

import yaml
from mcp.server.fastmcp import FastMCP

import publication
import package_identity

# --------------------------------------------------------------------------
# Configuration
# --------------------------------------------------------------------------

# Resolve the distributed suite first.  The former hard-coded developer
# checkout made an installed archive execute a different source tree.  An
# explicit override remains available for controlled deployments, but it must
# name a complete suite rather than a sibling workspace.
SUITE = os.path.abspath(os.environ.get("OMICSTAT_SUITE_ROOT") or str(Path(__file__).resolve().parents[1]))
WORKSPACE = os.path.abspath(os.environ.get("OMICSTAT_WORKSPACE") or SUITE)
SKILLS_DIR = os.path.join(SUITE, "skills")
ROUTER_SKILL = os.path.join(SKILLS_DIR, "omicstat", "SKILL.md")
ROUTE_PS1 = os.path.join(SUITE, "bin", "omicstat-r-route.ps1")
ROUTE_SH = os.path.join(SUITE, "bin", "omicstat-r-route.sh")
ENV_CONFIG = os.path.join(SUITE, "env", "omicstat-env.json")
# The native engine's description file (written by env/native/setup_native.R).
# OMICSTAT_NATIVE_ENV overrides the location; bin/omicstat-r-route.sh/.ps1 read
# the same variable, so availability here and execution there never diverge.
NATIVE_ENV = os.path.abspath(os.environ.get("OMICSTAT_NATIVE_ENV")
                             or os.path.join(SUITE, ".omicstat-r", "native-env.json"))
IS_WINDOWS = os.name == "nt"
RUNS_ROOT = os.path.abspath(os.environ.get(
    "OMICSTAT_RUNS_ROOT", os.path.join(tempfile.gettempdir(), "omicstat-runs")
))
RUN_REGISTRY = os.path.join(RUNS_ROOT, "_registry")
EFFECT_VALIDATOR = os.path.join(
    SKILLS_DIR, "_shared", "scripts", "validate_effect_table_cli.R"
)
# Python lane (ENGINEERING_PLAN 10.5): the R step that draws a Python run's figures.
RENDER_SCRIPT = os.path.join(SKILLS_DIR, "_shared", "scripts", "render_figure_request.R")
FIGURE_REQUEST_REL = "figure_data/figure_request.json"

# Every path-looking argument value must resolve under one of these trees.
ALLOWED_ROOTS = [
    SUITE,
    WORKSPACE,
    RUNS_ROOT,
    tempfile.gettempdir(),
]

RUN_TIMEOUT_S = 25 * 60          # hard kill; stdio idle timeout is 30 min
HELP_TIMEOUT_S = 300
MANIFEST_BUDGET = 8000           # characters
READ_LIMIT = 60000               # characters
SKILL_LIMIT = 20000              # characters

ARTIFACT_GROUPS = (
    "tables", "figures", "draft", "qc", "provenance", "publication",
    "machine", "other",
)
FIGURE_EXT = {".png", ".pdf", ".jpg", ".jpeg", ".svg", ".tif", ".tiff", ".eps"}
TEXT_EXT = {".md", ".csv", ".txt", ".json", ".yml", ".yaml", ".tsv"}

logging.basicConfig(
    level=logging.INFO,
    stream=sys.stderr,
    format="%(asctime)s omicstat-mcp %(levelname)s %(message)s",
)
log = logging.getLogger("omicstat-mcp")

_LOCK = threading.Lock()
_MODULES: "Optional[Dict[str, str]]" = None   # module -> entry script (relative)
_HELP_CACHE: Dict[str, str] = {}
_SUMMARY_CACHE: Dict[str, str] = {}

mcp = FastMCP("omicstat")


# --------------------------------------------------------------------------
# Module registry -- parsed from the router SKILL.md section 1 table so that
# there is exactly ONE contract for "which script is this module's entry".
# (Two modules ship an alias runner next to the real one -- target-trial has
# run_targettrial.R -> run_tte.R and time-dependent-exposure has
# run_tdexp.R -> run_tde.R -- so globbing run_*.R would be ambiguous.)
# --------------------------------------------------------------------------

_ROUTER_ROW = re.compile(
    r"\|\s*`([a-z0-9-]+)`\s*\|\s*`(scripts/run_[A-Za-z0-9_]+\.(?:R|py))`\s*\|"
)
# omicstat fork (M0): the suite starts with NO installed modules, so the
# section-1 table legitimately has a header row and zero data rows.  An empty
# registry is accepted only when that header row is present; a router file
# without the table at all is still refused, exactly as before.
_ROUTER_HEADER = re.compile(
    r"\|[^|\n]*\|\s*->\s*Module\s*\|\s*CLI entry script\s*\|"
)


def _modules() -> Dict[str, str]:
    global _MODULES
    with _LOCK:
        if _MODULES is None:
            with io.open(ROUTER_SKILL, encoding="utf-8") as fh:
                text = fh.read()
            rows = _ROUTER_ROW.findall(text)
            if not rows and not _ROUTER_HEADER.search(text):
                raise RuntimeError(
                    "could not parse the module table out of " + ROUTER_SKILL
                )
            _MODULES = {}
            for mod, script in rows:
                _MODULES[mod] = script
            log.info("registry: %d modules parsed from router SKILL.md", len(_MODULES))
        return _MODULES


def _entry_path(module: str) -> str:
    mods = _modules()
    if module not in mods:
        near = difflib.get_close_matches(module, list(mods), n=3, cutoff=0.0)
        raise ValueError(
            "unknown module '%s'. Closest: %s. Call omicstat_list_modules for all %d."
            % (module, ", ".join(near) or "(none installed)", len(mods))
        )
    path = os.path.join(SKILLS_DIR, module, *mods[module].split("/"))
    if not os.path.exists(path):
        raise RuntimeError("entry script missing on disk: " + path)
    return path


def _skill_path(module: str) -> str:
    _entry_path(module)   # validates the module name
    return os.path.join(SKILLS_DIR, module, "SKILL.md")


def _summary(module: str) -> str:
    """First sentence of the SKILL.md front-matter description."""
    with _LOCK:
        if module in _SUMMARY_CACHE:
            return _SUMMARY_CACHE[module]
    path = os.path.join(SKILLS_DIR, module, "SKILL.md")
    text = ""
    try:
        with io.open(path, encoding="utf-8") as fh:
            raw = fh.read()
        if raw.startswith("---"):
            end = raw.find("\n---", 3)
            if end > 0:
                front = raw[3:end]
                try:
                    meta = yaml.safe_load(front)
                    if isinstance(meta, dict):
                        text = str(meta.get("description", "") or "")
                except yaml.YAMLError as exc:
                    # Legacy docs have a plain one-line description containing
                    # an unquoted colon. Recover display text only, not metadata.
                    match = re.search(r"(?m)^description:[ \t]+([^\r\n]+)$", front)
                    if not match or match.group(1)[0] in "\"'>|[{":
                        raise
                    text = match.group(1)
                    log.warning("invalid front matter for %s; using plain description line: %s", module, exc)
    except Exception as exc:                                  # noqa: BLE001
        log.warning("summary parse failed for %s: %s", module, exc)
    text = re.sub(r"\s+", " ", text).strip()
    out, cursor = "", 0
    while cursor < len(text):
        hit = text.find(". ", cursor)
        if hit < 0:
            out = text
            break
        out = text[: hit + 1]
        if len(out) >= 40:
            break
        cursor = hit + 2
    out = (out or text)[:300].strip()
    with _LOCK:
        _SUMMARY_CACHE[module] = out
    return out


# --------------------------------------------------------------------------
# Engine invocation
# --------------------------------------------------------------------------

def _powershell() -> str:
    found = shutil.which("powershell")
    return found or r"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"


def _image_name() -> str:
    """The pinned omicstat-r image (OMICSTAT_IMAGE overrides for testing)."""
    if os.environ.get("OMICSTAT_IMAGE"):
        return os.environ["OMICSTAT_IMAGE"]
    with io.open(ENV_CONFIG, encoding="utf-8") as fh:
        cfg = json.load(fh)
    return "%s:%s" % (cfg["image"], cfg["image_tag"])


def _py_image_name() -> str:
    """The pinned omicstat-py image (OMICSTAT_PY_IMAGE overrides for testing)."""
    if os.environ.get("OMICSTAT_PY_IMAGE"):
        return os.environ["OMICSTAT_PY_IMAGE"]
    with io.open(ENV_CONFIG, encoding="utf-8") as fh:
        cfg = json.load(fh)["python_lane"]
    return "%s:%s" % (cfg["image"], cfg["image_tag"])


def _is_python_entry(script: str) -> bool:
    return script.lower().endswith(".py")


def _tool_for(script: str) -> str:
    """Engine command by entry extension: .py -> python (omicstat-py), else Rscript (omicstat-r)."""
    return "python" if _is_python_entry(script) else "Rscript"


def _native_available() -> bool:
    return os.path.isfile(NATIVE_ENV)


def _native_python() -> Optional[str]:
    """The "python" interpreter of native-env.json (env/py/setup_native.sh), if any."""
    try:
        with io.open(NATIVE_ENV, encoding="utf-8") as fh:
            value = json.load(fh).get("python")
    except (OSError, ValueError, AttributeError):
        return None
    return value if isinstance(value, str) and os.path.isfile(value) else None


def _router_cmd() -> List[str]:
    if IS_WINDOWS:
        if not os.path.exists(ROUTE_PS1):
            raise RuntimeError("router not found: " + ROUTE_PS1)
        return [_powershell(), "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", ROUTE_PS1]
    if not os.path.exists(ROUTE_SH):
        raise RuntimeError("router not found: " + ROUTE_SH)
    return ["bash", ROUTE_SH]


def _build_cmd(script: str, argv: List[str], engine: str) -> List[str]:
    if engine not in ("container", "native"):
        raise ValueError("engine must be 'container' or 'native', got " + repr(engine))
    if engine == "native" and not _native_available():
        raise RuntimeError("native omicstat environment not set up: %s is missing "
                           "(run: Rscript env/native/setup_native.R)" % NATIVE_ENV)
    tool = _tool_for(script)
    if engine == "native" and tool == "python" and _native_python() is None:
        raise RuntimeError("native omicstat Python environment not set up: %s has no usable "
                           "\"python\" key (run: bash env/py/setup_native.sh)" % NATIVE_ENV)
    return _router_cmd() + [tool, script] + argv


def _engine_env(engine: Optional[str]) -> Dict[str, str]:
    env = dict(os.environ)
    env.pop("OMICSTAT_R_NATIVE", None)
    if engine == "native":
        env["OMICSTAT_R_NATIVE"] = "1"
        # Hand the router the exact file _native_available() checked.
        env["OMICSTAT_NATIVE_ENV"] = NATIVE_ENV
    return env


def _kill_tree(proc) -> None:
    """Kill the whole process tree BY PID (never by name)."""
    try:
        if IS_WINDOWS:
            subprocess.run(["taskkill", "/F", "/T", "/PID", str(proc.pid)],
                           capture_output=True, timeout=60)
        else:
            import signal
            os.killpg(os.getpgid(proc.pid), signal.SIGKILL)
    except Exception as exc:                                  # noqa: BLE001
        log.error("tree kill failed for pid %s: %s", proc.pid, exc)


def _exec(cmd: List[str], cwd: str, timeout: int, engine: Optional[str] = None,
          extra_env: Optional[Dict[str, str]] = None):
    """Run to completion; on timeout kill the whole tree BY PID (never by name)."""
    started = _dt.datetime.now()
    env = _engine_env(engine)
    env.update(extra_env or {})
    # stdin MUST be DEVNULL. In a stdio MCP server the process's own stdin is
    # the protocol channel from the client; a child that inherits it blocks
    # forever the moment R touches its stdin connection, and could eat
    # protocol bytes. This one keyword is load-bearing.
    proc = subprocess.Popen(
        cmd, cwd=cwd, stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        env=env, start_new_session=not IS_WINDOWS,
    )
    timed_out = False
    try:
        raw_out, raw_err = proc.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        timed_out = True
        _kill_tree(proc)
        proc.kill()
        raw_out, raw_err = proc.communicate()
    dur = (_dt.datetime.now() - started).total_seconds()
    out = (raw_out or b"").decode("utf-8", "replace").replace("\r\n", "\n")
    err = (raw_err or b"").decode("utf-8", "replace").replace("\r\n", "\n")
    return proc.returncode, out, err, round(dur, 2), timed_out


def _help_text(module: str) -> str:
    """`--help` for a module, cached.  Native is preferred (it is ~10x faster
    to start) and the container is the fallback; the two were measured to emit
    byte-identical help text."""
    with _LOCK:
        if module in _HELP_CACHE:
            return _HELP_CACHE[module]
    script = _entry_path(module)
    text, problems = "", []
    for engine in ("native", "container"):
        try:
            cmd = _build_cmd(script, ["--help"], engine)
        except RuntimeError as exc:
            problems.append("%s: %s" % (engine, exc))
            continue
        rc, out, err, _dur, _to = _exec(cmd, cwd=SUITE, timeout=HELP_TIMEOUT_S, engine=engine)
        if out.strip():
            text = out
            break
        problems.append("%s: rc=%s stderr=%s" % (engine, rc, err.strip()[-300:]))
    if not text:
        raise RuntimeError(
            "could not obtain --help for %s (%s)" % (module, " | ".join(problems))
        )
    with _LOCK:
        _HELP_CACHE[module] = text
    return text


# NOTE: the design sketched the flag regex as `--[a-z0-9-]+`.  That is one
# character class too narrow for this suite: cpm-pipeline really has
# `--boot-B` and its-analysis really has `--boot-R`, and the lowercase-only
# pattern would clip them to `--boot-` and then reject the real flag as
# unknown.  Uppercase is allowed here for that reason and no other.
_FLAG_RE = re.compile(r"--([A-Za-z0-9][A-Za-z0-9-]*)")


def _flags(module: str) -> List[str]:
    return sorted(set(_FLAG_RE.findall(_help_text(module))))


# --------------------------------------------------------------------------
# Path safety
# --------------------------------------------------------------------------

_ABS_PATH = re.compile(r"^([A-Za-z]:[\\/]|\\\\|/)")
_REL_PATH = re.compile(r"^\.{0,2}[\\/]|[\\/][^\\/]+\.[A-Za-z0-9]{1,6}$")


def _looks_like_path(value: str) -> bool:
    if not value or len(value) > 4096:
        return False
    if _ABS_PATH.search(value):
        return True
    # A relative path only counts when it has a separator AND a file extension,
    # so that a label such as "mg/dL" is not mistaken for one.
    return bool(_REL_PATH.search(value))


def _under_allowed_root(path: str) -> bool:
    try:
        real = os.path.realpath(os.path.abspath(path))
    except Exception:                                          # noqa: BLE001
        return False
    for root in ALLOWED_ROOTS:
        root_abs = os.path.realpath(os.path.abspath(root))
        try:
            inside = os.path.commonpath(
                [os.path.normcase(real), os.path.normcase(root_abs)]
            ) == os.path.normcase(root_abs)
        except ValueError:
            inside = False
        if inside:
            return True
    return False


def _has_link_or_reparse(path: str) -> bool:
    """Reject every existing component that could redirect an allowed path."""
    path = os.path.abspath(path)
    drive, tail = os.path.splitdrive(path)
    current = drive + os.sep if drive else os.sep
    for part in tail.replace("/", "\\").split("\\"):
        if not part:
            continue
        current = os.path.join(current, part)
        if not os.path.lexists(current):
            continue
        try:
            st = os.lstat(current)
        except OSError:
            return True
        if os.path.islink(current) or bool(getattr(st, "st_file_attributes", 0) & 0x400):
            return True
    return False


def _guard_path(value: str, what: str, cwd: Optional[str] = None) -> None:
    if any(part == ".." for part in re.split(r"[\\/]", str(value))):
        raise ValueError("path refused: %s contains an explicit '..' component" % what)
    base = cwd or os.getcwd()
    resolved = value if os.path.isabs(value) else os.path.join(base, value)
    if not _under_allowed_root(resolved):
        raise ValueError(
            "path refused: %s = %r resolves outside the allowed roots (%s)"
            % (what, value, "; ".join(ALLOWED_ROOTS))
        )
    if _has_link_or_reparse(resolved):
        raise ValueError("path refused: %s traverses a symlink/junction/reparse point" % what)


def _allocate_run_directory(module: str, requested_outdir: Optional[str]):
    """Allocate a UUID leaf; an explicit outdir is a parent, never a run leaf."""
    run_id = str(uuid.uuid4())
    if requested_outdir is None:
        parent = os.path.join(RUNS_ROOT, module)
        requested = None
    else:
        parent = os.path.abspath(str(requested_outdir))
        requested = parent
    _guard_path(parent, "--outdir", WORKSPACE)
    os.makedirs(parent, exist_ok=True)
    outdir = os.path.join(parent, run_id)
    os.makedirs(outdir, exist_ok=False)
    if _has_link_or_reparse(outdir):
        raise ValueError("unsafe allocated run directory")
    return run_id, os.path.realpath(outdir), requested


# --------------------------------------------------------------------------
# argv assembly
# --------------------------------------------------------------------------

def _stringify(value: Any) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, float):
        return repr(value) if value != int(value) else str(int(value))
    return str(value)


def _to_argv(module: str, args: Dict[str, Any], cwd: str) -> List[str]:
    known = _flags(module)
    argv: List[str] = []
    for key, value in args.items():
        flag = str(key).lstrip("-")
        if flag not in known:
            near = difflib.get_close_matches(flag, known, n=3, cutoff=0.0)
            raise ValueError(
                "unknown flag '--%s' for module '%s'. Closest known flags: %s. "
                "The whitelist is parsed from this module's own --help; call "
                "omicstat_describe('%s') to see all %d."
                % (flag, module, ", ".join("--" + f for f in near), module, len(known))
            )
        if value is None:
            continue
        if isinstance(value, bool):
            if value:
                argv.append("--" + flag)
            continue
        if isinstance(value, (list, tuple)):
            rendered = ",".join(_stringify(v) for v in value)
        else:
            rendered = _stringify(value)
        for piece in ([rendered] + rendered.split(",") if "," in rendered else [rendered]):
            if _looks_like_path(piece):
                _guard_path(piece, "--" + flag, cwd)
        argv.extend(["--" + flag, rendered])
    return argv


# --------------------------------------------------------------------------
# Manifest
# --------------------------------------------------------------------------

def _classify(relpath: str) -> str:
    return publication.classify_artifact(relpath)


def _scan_artifacts(outdir: str):
    grouped: Dict[str, List[Dict[str, Any]]] = {g: [] for g in ARTIFACT_GROUPS}
    total = 0
    files, errors = publication.safe_walk_under(outdir)
    for rel, full in files:
        try:
            size = os.path.getsize(full)
        except OSError:
            size = -1
        grouped[_classify(rel)].append({"name": rel, "bytes": size})
        total += 1
    for error in errors:
        log.warning("artifact scan safety evidence: %s", error)
    for group in list(grouped):
        grouped[group].sort(key=lambda item: item["name"])
        if not grouped[group]:
            del grouped[group]
    return grouped, total


_TRUE = {"TRUE", "True", "true", "T", "1", "yes"}


_QC_RANK = {"critical": 0, "error": 1, "warning": 2, "info": 3}


def _scan_qc(outdir: str) -> List[Dict[str, Any]]:
    # Keep the historical list-shaped field while accepting the suite's known
    # id/code/qc_id and triggered/status QC dialects. Blocking rows come first,
    # then by severity: _fit_budget keeps only the head of this list in a
    # compact response, so a blocker must never sit behind eight warnings.
    findings = publication.scan_qc(outdir)["findings"]
    findings.sort(key=lambda h: (not h.get("blocking"), _QC_RANK.get(h.get("severity"), 9), str(h.get("id"))))
    return findings


# --- effect_table: the one payload that really is shared across modules ----
# The blind-user simulation (research/audit-0902/blind-user-simulation.md
# "What the tool should return", point 5) established that results.json has no
# cross-module schema but the effect table does, so the effect table is the
# manifest's PRIMARY payload and results_summary is demoted to optional.
# Detection is by COLUMN HEADER, not by filename: file naming is not
# predictable across modules (*_model_progression.csv, *_subgroup_detail.csv,
# ...), but _shared/docs/effect_table_schema.md fixes the columns.
_ET_REQUIRED = set(publication.CORE_EFFECT_COLUMNS)
_ET_PREFERRED = ["analysis_id", "term", "level", "stratum", "effect_type",
                 "estimate", "ci_low", "ci_high", "lower", "upper",
                 "p_value", "n_unweighted", "n_events"]
# Columns that are the numbers themselves, so they can never serve as a row's
# identity when falling back to a module-local table.
_ET_NUMERIC = {"estimate", "ci_low", "ci_high", "lower", "upper", "p_value",
               "p_adjusted", "se", "std_error", "statistic", "ci_level",
               "n_unweighted", "n_events", "value"}
_ET_LABELLIKE = 2      # leading identity columns carried on a module-local table
_ET_FALLBACK_CI = [("ci_low", "ci_high"), ("lower", "upper")]
_ET_MAX_ROWS = 20
_ET_FALLBACK_MAX_ROWS = 60

# --- feature_table: the omics per-feature result table (omicstat fork) -----
# IMPLEMENTATION_SPEC section 3 step 7 (1): the primary-payload detection
# gains one more tier for _shared/scripts/feature_table.R's schema.  Detection
# is by COLUMN HEADER exactly like the effect table; a file qualifies when it
# carries the core subset below (the full schema has 14 columns).
_FT_COLUMNS = ["feature_id", "symbol", "contrast", "base_mean", "log2fc",
               "log2fc_se", "stat", "pvalue", "padj", "method", "shrinkage",
               "n_group1", "n_group2", "filtered_reason"]
_FT_REQUIRED = {"feature_id", "log2fc", "pvalue", "padj"}
_FT_PREFERRED = ["feature_id", "symbol", "contrast", "base_mean", "log2fc",
                 "log2fc_se", "stat", "pvalue", "padj"]
_FT_TEXT = {"feature_id", "symbol", "contrast", "method", "shrinkage",
            "filtered_reason"}
_FT_SIG_ALPHA = 0.05   # "all features significant" degenerate criterion


def _short_num(text: str) -> str:
    try:
        val = float(text)
    except (TypeError, ValueError):
        return (text or "")[:60]
    # omicstat fork: a feature table can legitimately carry Inf/-Inf/NaN
    # (the degenerate log2fc case); int(inf) would raise OverflowError here.
    if val != val or val in (float("inf"), float("-inf")):
        return (text or "")[:60]
    if val == int(val) and abs(val) < 1e15:
        return str(int(val))
    return "%.4g" % val


def _read_csv_rows(path: str):
    with io.open(path, encoding="utf-8-sig", newline="") as fh:
        reader = csv.DictReader(fh)
        return list(reader.fieldnames or []), list(reader)


def _scan_effect_tables(outdir: str):
    """Return (rows, sources, schema_kind).

    Tier 1: files carrying the shared 20-column effect-table schema.
    Tier 1b (omicstat; only if tier 1 finds nothing): files carrying the
    shared feature-table core columns (feature_id, log2fc, pvalue, padj).
    Tier 2 (only if tiers 1 and 1b find nothing): a module-local estimate
    table -- an estimate column plus a CI pair plus a p-value and few enough
    rows to be effect rows rather than plot data. rcs-analysis's
    point-contrast table is the reference case for tier 2.
    """
    tier1, tier_ft, tier2 = [], [], []
    files, errors = publication.safe_walk_under(outdir)
    for error in errors:
        log.warning("effect-table scan safety evidence: %s", error)
    for rel, full in files:
            fname = os.path.basename(full)
            if not fname.lower().endswith(".csv"):
                continue
            if _classify(rel) == "qc":
                continue
            if rel.replace("\\", "/").startswith("figure_data/"):
                # Python lane: figure inputs (a volcano's copy of the feature
                # table) are never the run's payload.
                continue
            try:
                header, rows = _read_csv_rows(full)
            except Exception as exc:                           # noqa: BLE001
                log.warning("csv parse failed for %s: %s", rel, exc)
                continue
            cols = set(header)
            if _ET_REQUIRED.issubset(cols):
                tier1.append((rel, header, rows))
                continue
            if _FT_REQUIRED.issubset(cols):
                tier_ft.append((rel, header, rows))
                continue
            has_ci = any(lo in cols and hi in cols for lo, hi in _ET_FALLBACK_CI)
            if ("estimate" in cols and has_ci and "p_value" in cols
                    and 0 < len(rows) <= _ET_FALLBACK_MAX_ROWS):
                tier2.append((rel, header, rows))
    if tier1:
        chosen, kind = tier1, "shared-schema"
    elif tier_ft:
        chosen, kind = tier_ft, "feature-table"
    else:
        chosen, kind = tier2, "module-local"
    if not chosen:
        return [], [], "none"
    chosen.sort(key=lambda item: (item[0].count("/"), item[0]))
    out_rows, sources, budget = [], [], _ET_MAX_ROWS
    for rel, header, rows in chosen:
        if budget <= 0:
            break
        sources.append(rel)
        if kind == "feature-table":
            # Rows are carried in the engine's own file order (the shell never
            # re-sorts or filters by significance).
            keep = [c for c in _FT_PREFERRED if c in header]
            labels = []
            text_cols = set(_FT_TEXT)
        else:
            keep = [c for c in _ET_PREFERRED if c in header]
            # A module-local table has none of the schema's identity columns, so a
            # row would come back as five anonymous numbers. Carry its own leading
            # non-numeric columns instead (for rcs-analysis's point contrasts that
            # is `comparison` and `label`).
            labels = [c for c in header
                      if c not in keep and c.lower() not in _ET_NUMERIC][:_ET_LABELLIKE]
            keep = labels + keep
            text_cols = set(labels) | {"analysis_id", "term", "level", "stratum",
                                       "effect_type"}
        for row in rows[:budget]:
            slim = {}
            for col in keep:
                val = (row.get(col) or "").strip()
                if val in ("", "NA", "NaN"):
                    continue
                slim[col] = val[:70] if col in text_cols else _short_num(val)
            if slim:
                if len(chosen) > 1:
                    slim["_src"] = rel
                out_rows.append(slim)
        budget = _ET_MAX_ROWS - len(out_rows)
    return out_rows, sources, kind


def _as_list(value: Any) -> List[Any]:
    if value is None:
        return []
    return value if isinstance(value, list) else [value]


def _validate_effect_tables(outdir: str, engine: str) -> Dict[str, Any]:
    """Call the canonical R validator for every full-schema persisted table."""
    candidates = publication.find_effect_table_candidates(outdir)
    payload: Dict[str, Any] = {
        "schema_version": "omicstat.effect-table-validation.v1",
        "ok": not candidates["invalid_named"],
        "canonical": candidates["canonical"],
        "invalid_named": candidates["invalid_named"],
        "local": candidates["local"],
        "files": [],
        "errors": [],
    }
    if not candidates["canonical"]:
        return payload
    if not os.path.isfile(EFFECT_VALIDATOR):
        payload["ok"] = False
        payload["errors"] = ["canonical effect-table validator is missing"]
        return payload
    paths = [os.path.join(outdir, *rel.split("/")) for rel in candidates["canonical"]]
    try:
        cmd = _build_cmd(EFFECT_VALIDATOR, paths, engine)
        rc, stdout, stderr, _dur, timed_out = _exec(
            cmd, cwd=outdir, timeout=HELP_TIMEOUT_S, engine=engine
        )
        if rc != 0 or timed_out:
            raise RuntimeError(
                "validator rc=%s timed_out=%s stderr=%s"
                % (rc, timed_out, _tail(stderr, 8))
            )
        decoded = json.loads(stdout)
        files = decoded.get("files", [])
        if isinstance(files, dict):
            files = [files]
        if len(files) != len(candidates["canonical"]):
            raise RuntimeError("validator returned %d records for %d candidates" % (len(files), len(candidates["canonical"])))
        # Container validators may return /ws paths.  Bind response records by
        # requested candidate index, never by a path supplied in stdout.
        for index, item in enumerate(files):
            item["errors"] = _as_list(item.get("errors"))
            item["warnings"] = _as_list(item.get("warnings"))
            item["validator_path"] = str(item.get("path", ""))
            item["path"] = candidates["canonical"][index]
        payload["files"] = files
        payload["errors"] = _as_list(decoded.get("errors"))
        payload["ok"] = (
            not candidates["invalid_named"]
            and bool(decoded.get("ok"))
            and not payload["errors"]
        )
    except Exception as exc:                                   # noqa: BLE001
        payload["ok"] = False
        payload["errors"] = ["OS_SCHEMA_VALIDATION_FAILED: %s" % exc]
    return payload


def _degenerate_estimates(rows: List[Dict[str, Any]]) -> List[Dict[str, str]]:
    """Wrapper-level scan for estimates that cannot be real (blind-sim
    "Two wrapper-level guards worth adding"): a zero-width confidence interval,
    or a point estimate sitting outside its own interval. Catches the
    non-converged joint-frailty style result that no QC rule fires on."""
    flagged = []
    for row in rows:
        low = row.get("ci_low", row.get("lower"))
        high = row.get("ci_high", row.get("upper"))
        est = row.get("estimate")
        try:
            low_f, high_f = float(low), float(high)
        except (TypeError, ValueError):
            continue
        label = "%s / %s" % (row.get("analysis_id", "?"), row.get("term", "?"))
        if low_f == high_f:
            flagged.append({"row": label, "issue": "zero-width CI (%s)" % low})
            continue
        try:
            est_f = float(est)
        except (TypeError, ValueError):
            continue
        if not (min(low_f, high_f) <= est_f <= max(low_f, high_f)):
            flagged.append({
                "row": label,
                "issue": "estimate %s lies outside its CI (%s to %s)" % (est, low, high),
            })
    return flagged[:10]


def _float_or_none(text: Any) -> Optional[float]:
    """Parse an R-written CSV cell; NA/empty -> None, Inf/NaN kept as floats."""
    raw = ("" if text is None else str(text)).strip()
    if raw in ("", "NA"):
        return None
    try:
        return float(raw)
    except ValueError:
        return None


def _is_nonfinite(value: Optional[float]) -> bool:
    return value is not None and (value != value or value in (float("inf"), float("-inf")))


def _degenerate_features(outdir: str, sources: List[str]) -> List[Dict[str, str]]:
    """omicstat fork (IMPLEMENTATION_SPEC section 3 step 7 (2)): mechanical
    omics degeneracy criteria over the FULL feature table(s), not the 20-row
    manifest slice: padj NA for every feature, every non-NA padj below 0.05,
    or a non-finite (Inf/-Inf/NaN) log2fc.  Checked per (file, contrast)."""
    flagged: List[Dict[str, str]] = []
    for rel in sources:
        try:
            full = publication.safe_join_under(outdir, rel, require_exists=True)
            header, rows = _read_csv_rows(full)
        except Exception as exc:                               # noqa: BLE001
            log.warning("feature-table re-read failed for %s: %s", rel, exc)
            continue
        if not _FT_REQUIRED.issubset(set(header)):
            continue
        groups: Dict[str, List[Dict[str, Any]]] = {}
        for row in rows:
            groups.setdefault((row.get("contrast") or "").strip(), []).append(row)
        for contrast, members in groups.items():
            label = "%s / contrast %s" % (rel, contrast or "?")
            padj = [_float_or_none(r.get("padj")) for r in members]
            finite_padj = [p for p in padj if p is not None and p == p]
            if members and not finite_padj:
                flagged.append({"row": label,
                                "issue": "padj is NA for all %d features" % len(members)})
            elif finite_padj and all(p < _FT_SIG_ALPHA for p in finite_padj):
                flagged.append({"row": label,
                                "issue": "all %d features with non-NA padj have padj < %s"
                                         % (len(finite_padj), _FT_SIG_ALPHA)})
            nonfinite = [r.get("feature_id", "?") for r in members
                         if _is_nonfinite(_float_or_none(r.get("log2fc")))]
            if nonfinite:
                flagged.append({"row": label,
                                "issue": "log2fc is non-finite (Inf/-Inf/NaN) for %d feature(s), e.g. %s"
                                         % (len(nonfinite), ", ".join(nonfinite[:3]))})
    return flagged[:10]


def _upstream_runs(outdir: str) -> List[str]:
    """omicstat fork (ENGINEERING_PLAN section 1.3): the upstream run_id chain a
    --from-run module records in objects/handoff.json.  Accepted shape:
    {"upstream_runs": ["<run_id>", ...]} or [{"run_id": "<run_id>"}, ...].
    Absent or unreadable -> []."""
    try:
        path = publication.safe_join_under(outdir, "objects/handoff.json")
    except Exception as exc:                                   # noqa: BLE001
        log.warning("handoff.json path refused: %s", exc)
        return []
    if not os.path.isfile(path):
        return []
    try:
        with io.open(path, encoding="utf-8") as fh:
            data = json.load(fh)
    except Exception as exc:                                   # noqa: BLE001
        log.warning("handoff.json unreadable: %s", exc)
        return []
    items = data.get("upstream_runs") if isinstance(data, dict) else None
    out: List[str] = []
    for item in items if isinstance(items, list) else []:
        run = item.get("run_id") if isinstance(item, dict) else item
        if isinstance(run, str) and run.strip() and run.strip()[:128] not in out:
            out.append(run.strip()[:128])
    return out


# --- engine warnings ------------------------------------------------------
# The blind-user simulation's single highest-value recommendation: a
# non-converged engine's ONLY trace was a transient console line that no QC
# rule and no file recorded. Surface those lines next to the QC block.
_OS_CODE = re.compile(r"OS_[A-Z][A-Z0-9_]+")
_WARN_HINT = re.compile(
    r"converg|did not converge|NaN produced|Warning|numerically 0 or 1|"
    r"algorithm did not|singular|rank-deficient",
    re.IGNORECASE,
)
_BARE_WARN_HEADER = re.compile(r"^(In addition: )?Warning messages?:\s*$")


def _engine_warnings(stdout: str, stderr: str) -> List[str]:
    found: List[str] = []
    seen = set()

    def add(line: str) -> None:
        norm = re.sub(r"\s+", " ", line).strip()
        if not norm or norm in seen:
            return
        seen.add(norm)
        found.append(norm[:220])

    for stream in (stderr, stdout):
        lines = stream.split("\n")
        for idx, line in enumerate(lines):
            if not (_OS_CODE.search(line) or _WARN_HINT.search(line)):
                continue
            # "Warning message:" on its own says nothing; R puts the actual
            # warning on the following line(s).
            if _BARE_WARN_HEADER.match(line.strip()):
                taken = 0
                for nxt in lines[idx + 1:]:
                    if not nxt.strip():
                        break
                    add(nxt.strip())
                    taken += 1
                    if taken >= 3:
                        break
                continue
            add(line.strip())
    return found[:25]


def _structured_warnings(warnings: List[str]) -> List[Dict[str, str]]:
    """Machine-readable companion to the legacy console-warning strings."""
    structured = []
    for message in warnings:
        match = re.search(r"\b(OS_[A-Z0-9_]+)\b", message)
        structured.append({
            "code": match.group(1) if match else "OS_ENGINE_WARNING",
            "message": str(message),
        })
    return structured


def _scan_results(outdir: str) -> Dict[str, Any]:
    candidates: List[str] = []
    files, errors = publication.safe_walk_under(outdir)
    for error in errors:
        log.warning("results scan safety evidence: %s", error)
    for rel, full in files:
            fname = os.path.basename(full)
            if not fname.lower().endswith(".json"):
                continue
            if rel.lower().endswith("_results.json") or rel.lower().startswith("results/"):
                candidates.append(full)
    if not candidates:
        return {}
    candidates.sort(key=lambda p: (p.count(os.sep), p))
    try:
        with io.open(candidates[0], encoding="utf-8") as fh:
            data = json.load(fh)
    except Exception as exc:                                   # noqa: BLE001
        log.warning("results parse failed: %s", exc)
        return {}
    if not isinstance(data, dict):
        return {}
    out: Dict[str, Any] = {}
    for key, value in list(data.items())[:30]:
        if isinstance(value, str):
            out[key] = value[:160]
        elif isinstance(value, (int, float, bool)) or value is None:
            out[key] = value
        elif isinstance(value, list) and len(value) <= 6 and all(
            isinstance(v, (int, float, bool, str)) or v is None for v in value
        ):
            out[key] = value
        elif isinstance(value, list):
            out[key] = "<array[%d]>" % len(value)
        elif isinstance(value, dict):
            out[key] = "<object: %d keys>" % len(value)
    return out


def _tail(text: str, lines: int) -> str:
    parts = text.rstrip("\n").split("\n") if text.strip() else []
    return "\n".join(parts[-lines:])


def _dumps(obj: Any) -> str:
    return json.dumps(
        publication.json_safe(obj), ensure_ascii=True, indent=1, default=str,
        allow_nan=False,
    )


def _fit_budget(manifest: Dict[str, Any]) -> str:
    """Shrink structurally and always return one complete JSON document."""
    serialization_warnings: List[Dict[str, str]] = []
    manifest = copy.deepcopy(publication.json_safe(manifest, serialization_warnings))
    if serialization_warnings:
        existing = manifest.setdefault("serialization_warnings", [])
        existing.extend(serialization_warnings)
    text = _dumps(manifest)
    if len(text) <= MANIFEST_BUDGET:
        return text
    notes: List[str] = manifest.setdefault("notes", [])

    def shrink(label, fn):
        nonlocal text
        if len(text) <= MANIFEST_BUDGET:
            return
        fn()
        notes.append(label)
        text = _dumps(manifest)

    shrink("stderr_tail trimmed to 10 lines",
           lambda: manifest.__setitem__("stderr_tail",
                                        _tail(manifest.get("stderr_tail", ""), 10)))
    shrink("stdout_tail trimmed to 5 lines",
           lambda: manifest.__setitem__("stdout_tail",
                                        _tail(manifest.get("stdout_tail", ""), 5)))

    # New publication metadata must not evict legacy result/QC fields from the
    # compact response. The complete request, hashes and versions remain in
    # the on-disk PublicationManifest.
    def cut_heavy_publication_details():
        validation = manifest.get("effect_table_validation") or {}
        manifest["effect_table_validation"] = {
            "ok": validation.get("ok"),
            "canonical": validation.get("canonical", []),
            "invalid_named": validation.get("invalid_named", []),
            "errors": validation.get("errors", []),
        }
        manifest.pop("outputs", None)
        manifest.pop("inputs", None)
        manifest.pop("request", None)
        manifest.pop("software_versions", None)
        manifest.pop("qc", None)
        manifest.pop("engine_outputs", None)
        # These are v1 publication inventory/provenance additions. They are
        # deliberately removable before the legacy artifact/effect payload so
        # a large RCS run still has a useful MCP envelope under 8 KiB.
        # Keep the legacy shape internally consistent when the complete
        # inventory is omitted from a compact response.
        manifest["all_artifacts"] = {}
        manifest["all_artifact_count"] = 0
        manifest["total_artifact_count"] = 0
        manifest["publication_artifact_count"] = 0
        manifest["inventory_truncated"] = True
        for key in (
            "publication_review", "artifact_index",
            "results_outline", "value_map", "rules_version", "runtime",
            "validator", "finalizer", "rule_catalog_hashes",
            "literature_provenance", "structured_warnings", "serialization_warnings",
            "reviewer_decisions", "integrity_exclusions",
        ):
            manifest.pop(key, None)
    shrink("publication detail omitted from compact response; read publication_manifest",
           cut_heavy_publication_details)

    # After new publication-only detail is removed, the legacy shrink order is
    # unchanged; effect_table / engine_warnings / degenerate_estimates trim last.
    def cut_results():
        summary = manifest.get("results_summary") or {}
        manifest["results_summary"] = dict(list(summary.items())[:10])
    shrink("results_summary trimmed to 10 keys", cut_results)

    def drop_results():
        manifest["results_summary"] = {}
    shrink("results_summary dropped", drop_results)

    def cut_qc():
        qc = manifest.get("qc_triggered") or []
        manifest["qc_triggered"] = [
            {"id": h["id"], "severity": h["severity"], "blocking": bool(h.get("blocking")),
             "message": h["message"][:80]}
            for h in qc[:8]
        ]
        if len(qc) > 8:
            manifest["qc_triggered_omitted"] = len(qc) - 8
    shrink("qc_triggered trimmed to 8 rows / short messages", cut_qc)

    def cut_artifacts():
        arts = manifest.get("artifacts") or {}
        for group in list(arts):
            if len(arts[group]) > 8:
                extra = len(arts[group]) - 8
                arts[group] = arts[group][:8] + [
                    {"name": "... %d more" % extra, "bytes": 0}
                ]
    shrink("artifacts listing truncated per group", cut_artifacts)

    def cut_effect():
        rows = manifest.get("effect_table") or []
        manifest["effect_table"] = rows[:8]
    shrink("effect_table trimmed to 8 rows", cut_effect)

    def cut_warnings():
        manifest["engine_warnings"] = (manifest.get("engine_warnings") or [])[:6]
    shrink("engine_warnings trimmed to 6", cut_warnings)

    if len(text) <= MANIFEST_BUDGET:
        return text

    # The full manifest is already on disk. This bounded envelope uses only
    # fixed-size identifiers and short paths, so it cannot need raw slicing.
    compact = {
        "schema_version": manifest.get("schema_version", "omicstat.publication-manifest.v1"),
        "run_id": str(manifest.get("run_id", ""))[:64],
        "status": manifest.get("status", "review_required"),
        "module": str(manifest.get("module", ""))[:160],
        "engine": manifest.get("engine"),
        "exit_code": manifest.get("exit_code"),
        "outdir": str(manifest.get("outdir", ""))[:2048],
        "upstream_runs": manifest.get("upstream_runs", []),
        # A compact envelope still says whether the run is usable: blocking QC
        # rows and degenerate estimates are counted, never silently dropped.
        "qc_triggered_count": len(manifest.get("qc_triggered") or []),
        "qc_blocking_count": sum(1 for h in (manifest.get("qc_triggered") or []) if h.get("blocking")),
        "degenerate_estimate_count": len(manifest.get("degenerate_estimates") or []),
        "engine_warning_count": len(manifest.get("engine_warnings") or []),
        "publication_manifest": str(
            manifest.get("publication_manifest", publication.MANIFEST_REL)
        )[:512],
        "notes": ["compact response used; read the on-disk publication manifest"],
        "truncation": {"applied": True, "budget": MANIFEST_BUDGET},
    }
    text = _dumps(compact)
    if len(text) <= MANIFEST_BUDGET:
        return text
    emergency = {
        "run_id": str(manifest.get("run_id", ""))[:64],
        "status": manifest.get("status", "review_required"),
        "error": "response metadata exceeded the JSON budget; use run_id to read the manifest",
    }
    return _dumps(emergency)


def _package_version(name: str) -> str:
    try:
        return importlib.metadata.version(name)
    except importlib.metadata.PackageNotFoundError:
        return "unavailable"


def _sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def _dirty_worktree_identity(module: Optional[str]) -> Optional[Dict[str, Any]]:
    """Create a replayable identity for a dirty code tree.

    The inventory is deliberately conservative: it covers the MCP entry and
    finalizer, the selected module's entire R script directory, and all shared
    R scripts (including ``effect_table.R`` behind the validator wrapper).
    Git's binary diff covers tracked changes while the untracked-content digest
    prevents a status-only identity from accepting a changed untracked script.
    """
    try:
        def git_bytes(args: List[str]) -> bytes:
            result = subprocess.run(
                ["git"] + args, cwd=SUITE, stdin=subprocess.DEVNULL,
                capture_output=True, timeout=30, check=False,
            )
            if result.returncode != 0:
                raise RuntimeError("git identity command failed")
            return result.stdout

        status = git_bytes(["status", "--porcelain=v1", "--untracked-files=normal", "-z"])
        diff = git_bytes(["diff", "--binary", "HEAD"])
        untracked_raw = git_bytes(["ls-files", "--others", "--exclude-standard", "-z"])
        untracked = []
        for raw in untracked_raw.split(b"\0"):
            if not raw:
                continue
            rel = raw.decode("utf-8", "surrogateescape").replace("\\", "/")
            path = os.path.join(SUITE, *rel.split("/"))
            if not os.path.isfile(path) or publication._is_link_or_reparse(path):
                raise RuntimeError("untracked identity path is not a regular file")
            untracked.append({"path": rel, "sha256": publication.sha256_file(path)})
        untracked.sort(key=lambda item: item["path"])

        paths = {
            os.path.join(SUITE, "mcp", "server.py"),
            os.path.join(SUITE, "mcp", "publication.py"),
            EFFECT_VALIDATOR,
            os.path.join(SKILLS_DIR, "_shared", "scripts", "effect_table.R"),
        }
        code_ext = (".r",)
        extra_roots: List[str] = []
        if module:
            entry = _entry_path(module)
            if _is_python_entry(entry):
                # Python lane: the module's .py scripts and the shared Python layer
                # (same closure as publication._expected_code_inventory).
                code_ext = (".r", ".py")
                extra_roots.append(os.path.join(SKILLS_DIR, "_shared", "py"))
            module_scripts = os.path.dirname(entry)
            for root, dirs, files in os.walk(module_scripts):
                dirs[:] = [name for name in dirs
                           if not publication._is_link_or_reparse(os.path.join(root, name))]
                for name in files:
                    if name.lower().endswith(code_ext):
                        paths.add(os.path.join(root, name))
        for extra in extra_roots:
            for root, dirs, files in os.walk(extra):
                dirs[:] = [name for name in dirs
                           if not publication._is_link_or_reparse(os.path.join(root, name))]
                for name in files:
                    if name.lower().endswith(".py"):
                        paths.add(os.path.join(root, name))
        shared_scripts = os.path.join(SKILLS_DIR, "_shared", "scripts")
        for root, dirs, files in os.walk(shared_scripts):
            dirs[:] = [name for name in dirs
                       if not publication._is_link_or_reparse(os.path.join(root, name))]
            for name in files:
                if name.lower().endswith(".r"):
                    paths.add(os.path.join(root, name))
        inventory = []
        for path in sorted(paths):
            if not os.path.isfile(path) or publication._is_link_or_reparse(path):
                raise RuntimeError("executed-code identity path is not a regular file")
            inventory.append({
                "path": os.path.relpath(path, SUITE).replace("\\", "/"),
                "sha256": publication.sha256_file(path),
            })
        inventory_json = json.dumps(inventory, sort_keys=True, separators=(",", ":")).encode("utf-8")
        untracked_json = json.dumps(untracked, sort_keys=True, separators=(",", ":")).encode("utf-8")
        digest_input = b"\0".join((status, diff, untracked_json, inventory_json))
        return {
            "status_sha256": _sha256_bytes(status),
            "diff_sha256": _sha256_bytes(diff),
            "untracked_sha256": _sha256_bytes(untracked_json),
            "code_inventory_sha256": _sha256_bytes(inventory_json),
            "worktree_sha256": _sha256_bytes(digest_input),
            "code_inventory": inventory,
        }
    except Exception:                                           # noqa: BLE001
        return None


_PY_PROBE = (
    "import importlib.metadata as md, json, os, platform, re, sys\n"
    "pk = {re.sub(r'[-_.]+', '-', d.metadata['Name']).lower(): d.version for d in md.distributions()}\n"
    "print('__OMICSTAT_PY__' + json.dumps({'python': platform.python_version(),"
    " 'implementation': platform.python_implementation(), 'executable': sys.executable,"
    " 'platform': sys.platform + '-' + platform.machine(), 'packages': dict(sorted(pk.items())),"
    " 'threads': {v: os.environ.get(v) for v in ('OMP_NUM_THREADS', 'OPENBLAS_NUM_THREADS',"
    " 'MKL_NUM_THREADS', 'NUMBA_NUM_THREADS')}, 'pythonhashseed': os.environ.get('PYTHONHASHSEED')}))\n"
)


def _docker_image_id(docker: List[str], image: str) -> Optional[str]:
    try:
        result = subprocess.run(docker + ["image", "inspect", image, "--format", "{{.Id}}"],
                                stdin=subprocess.DEVNULL, capture_output=True, text=True,
                                timeout=10, check=False)
        candidate = result.stdout.strip()
        if result.returncode == 0 and re.fullmatch(r"sha256:[a-fA-F0-9]{64}", candidate):
            return candidate
    except Exception:                                           # noqa: BLE001
        pass
    return None


def _python_env_probe(engine: str) -> Dict[str, Any]:
    """Provenance probe of the Python lane (ENGINEERING_PLAN 10.6 item 4):
    interpreter version, importlib.metadata package versions, image ID."""
    docker = ["wsl", "-e", "docker"] if IS_WINDOWS else ["docker"]
    try:
        image = _py_image_name()
    except (OSError, ValueError, KeyError):
        image = "omicstat-py:unknown"
    try:
        with io.open(ENV_CONFIG, encoding="utf-8") as fh:
            lane = json.load(fh).get("python_lane") or {}
    except (OSError, ValueError):
        lane = {}
    cmd = (_router_cmd() + ["python", "-c", _PY_PROBE] if engine == "native" else
           docker + ["run", "--rm", "--network", "none", image, "python", "-c", _PY_PROBE])
    found: Dict[str, Any] = {}
    try:
        result = subprocess.run(cmd, stdin=subprocess.DEVNULL, env=_engine_env(engine), capture_output=True,
                                text=True, encoding="utf-8", errors="replace", timeout=120, check=False)
        for line in result.stdout.splitlines():
            if line.startswith("__OMICSTAT_PY__"):
                found = json.loads(line[len("__OMICSTAT_PY__"):])
    except Exception:                                           # noqa: BLE001
        pass
    return {
        "engine": engine,
        "python": found.get("python", "unknown"),
        "implementation": found.get("implementation"),
        "executable": found.get("executable"),
        "platform": found.get("platform"),
        "packages": found.get("packages") or {},
        "threads": found.get("threads") or {},
        "pythonhashseed": found.get("pythonhashseed"),
        "py_env_version": lane.get("py_env_version"),
        "pins": lane.get("pins") or {},
        "image": image if engine == "container" else None,
        "image_id": _docker_image_id(docker, image) if engine == "container" else None,
    }


def _software_versions(engine: str, module: Optional[str] = None) -> Dict[str, Any]:
    r_probe = (
        "cat('__OMICSTAT_R_VERSION__\\t', R.version.string, '\\n', sep=''); "
        "cat('__OMICSTAT_SESSION_BEGIN__\\n'); "
        "cat(capture.output(sessionInfo()), sep='\\n'); "
        "cat('\\n__OMICSTAT_SESSION_END__\\n'); "
        "ip <- installed.packages()[, c('Package', 'Version'), drop=FALSE]; "
        "for (i in seq_len(nrow(ip))) cat('__OMICSTAT_PACKAGE__\\t', ip[i,1], '\\t', ip[i,2], '\\n', sep='')"
    )
    docker = ["wsl", "-e", "docker"] if IS_WINDOWS else ["docker"]
    try:
        image = _image_name()
    except (OSError, ValueError, KeyError):
        image = "omicstat-r:unknown"
    probe_cmd = (_router_cmd() + ["Rscript", "-e", r_probe] if engine == "native" else
                 docker + ["run", "--rm", "--network", "none", image, "Rscript", "-e", r_probe])
    r_version = "unknown"
    r_session_lines: List[str] = []
    r_packages: Dict[str, str] = {}
    try:
        result = subprocess.run(probe_cmd, stdin=subprocess.DEVNULL, env=_engine_env(engine),
                                capture_output=True, text=True, encoding="utf-8", errors="replace",
                                timeout=60, check=False)
        in_session = False
        if result.returncode == 0:
            for line in result.stdout.splitlines():
                if line.startswith("__OMICSTAT_R_VERSION__\t"):
                    r_version = line.split("\t", 1)[1].strip() or "unknown"
                elif line == "__OMICSTAT_SESSION_BEGIN__":
                    in_session = True
                elif line == "__OMICSTAT_SESSION_END__":
                    in_session = False
                elif line.startswith("__OMICSTAT_PACKAGE__\t"):
                    parts = line.split("\t", 2)
                    if len(parts) == 3 and parts[1] and parts[2]:
                        r_packages[parts[1]] = parts[2]
                elif in_session:
                    r_session_lines.append(line)
    except Exception:                                           # noqa: BLE001
        pass
    image_id = _docker_image_id(docker, image) if engine == "container" else None
    # Python-lane module: the engine is the omicstat-py interpreter; the R
    # session probed above is the one that renders its figures.
    python_engine = None
    try:
        if module and _is_python_entry(_entry_path(module)):
            python_engine = _python_env_probe(engine)
            python_engine["render_image"] = image if engine == "container" else None
            python_engine["render_image_id"] = image_id
    except (OSError, RuntimeError, ValueError):
        python_engine = None
    repository = {"commit": None, "dirty": None, "worktree_identity": None}
    try:
        commit = subprocess.run(["git", "rev-parse", "HEAD"], cwd=SUITE,
                                stdin=subprocess.DEVNULL, capture_output=True, text=True,
                                timeout=10, check=False)
        status = subprocess.run(["git", "status", "--porcelain", "--untracked-files=normal"], cwd=SUITE,
                                stdin=subprocess.DEVNULL, capture_output=True, text=True,
                                timeout=20, check=False)
        if commit.returncode == 0 and re.fullmatch(r"[a-fA-F0-9]{40}", commit.stdout.strip()):
            repository["commit"] = commit.stdout.strip()
        if status.returncode == 0:
            repository["dirty"] = bool(status.stdout.strip())
    except Exception:                                           # noqa: BLE001
        pass
    # Release archives intentionally omit .git.  They may use only a
    # build-generated, byte-verified identity; a Git worktree never falls back
    # here, including when Git itself is broken or unavailable.
    if repository["commit"] is None and not os.path.exists(os.path.join(SUITE, ".git")):
        identity = package_identity.load_and_verify(Path(SUITE))
        if identity is not None:
            repository = {
                "commit": identity["source_commit"],
                "dirty": False,
                "worktree_identity": None,
                "package_identity": {
                    "source_tree": identity["source_tree"],
                    "inventory_sha256": identity["inventory_sha256"],
                },
            }
    if repository["dirty"] is True:
        repository["worktree_identity"] = _dirty_worktree_identity(module)
    entry_record = {"path": None, "sha256": None}
    if module:
        try:
            entry = _entry_path(module)
            entry_record = {
                "path": os.path.relpath(entry, SUITE).replace("\\", "/"),
                "sha256": publication.sha256_file(entry),
            }
        except (OSError, RuntimeError, ValueError):
            pass
    def required_hash(path: str) -> str:
        return publication.sha256_file(path)
    if python_engine is not None and engine == "container":
        image_id = python_engine.get("image_id")
    versions = {
        "python": platform.python_version(),
        "mcp": _package_version("mcp"),
        "r": r_version,
        "execution_engine": engine,
        "python_packages": {
            "mcp": _package_version("mcp"),
            "PyYAML": _package_version("PyYAML"),
            "jsonschema": _package_version("jsonschema"),
        },
        "r_session_info": "\n".join(r_session_lines).strip() or None,
        "r_packages": r_packages,
        "repository": repository,
        "module_entry_script": entry_record,
        "container_image_id": image_id,
        "container_image_warning": "image ID unavailable" if engine == "container" and image_id is None else None,
        "effect_validator_sha256": required_hash(EFFECT_VALIDATOR),
        "publication_module_rules_sha256": required_hash(os.path.join(SKILLS_DIR, "_shared", "publication", "module_rules_v1.json")),
        "publication_universal_rules_sha256": required_hash(os.path.join(SKILLS_DIR, "_shared", "publication", "universal_rules_v1.json")),
        "publication_finalizer_sha256": required_hash(os.path.join(os.path.dirname(os.path.abspath(__file__)), "publication.py")),
    }
    if python_engine is not None:
        versions["python_engine"] = python_engine
    return versions


def _persist_final_manifest(manifest: Dict[str, Any]) -> None:
    path = publication.safe_join_under(manifest["outdir"], publication.MANIFEST_REL)
    publication.write_json(path, manifest)


def _refresh_legacy_artifacts(manifest: Dict[str, Any]) -> None:
    grouped, total = _scan_artifacts(manifest["outdir"])
    # A manifest cannot truthfully index its own bytes: it is rewritten after
    # inventory refresh. Keep it explicitly out of the all_* compatibility view.
    for group in list(grouped):
        grouped[group] = [row for row in grouped[group]
                          if row.get("name") != publication.MANIFEST_REL]
        if not grouped[group]:
            del grouped[group]
    total = sum(len(rows) for rows in grouped.values())
    engine_paths = {str(item.get("path", "")) for item in manifest.get("engine_outputs", [])}
    engine_grouped: Dict[str, List[Dict[str, Any]]] = {group: [] for group in ARTIFACT_GROUPS}
    for group, rows in grouped.items():
        engine_grouped[group] = [row for row in rows if row.get("name") in engine_paths]
    engine_grouped = {group: rows for group, rows in engine_grouped.items() if rows}
    engine_count = sum(len(rows) for rows in engine_grouped.values())
    # Legacy fields are intentionally engine-only.  The v2 all_* view is the
    # complete disk inventory, including five dynamic publication artifacts.
    manifest["artifacts"] = engine_grouped
    manifest["artifact_count"] = engine_count
    manifest["engine_artifact_count"] = engine_count
    manifest["all_artifacts"] = grouped
    manifest["all_artifact_count"] = total
    manifest["total_artifact_count"] = total
    manifest["publication_artifact_count"] = max(0, total - engine_count)


def _infer_module_from_outdir(outdir: str) -> str:
    names = [os.path.basename(outdir), os.path.basename(os.path.dirname(outdir))]
    for name in names:
        for module in _modules():
            if name == module or name.startswith(module + "-"):
                return module
    return "unknown"


def _import_output_tree(source: str) -> tuple[str, str]:
    """Copy a naked output directory into a new safe UUID leaf before writes."""
    source = os.path.abspath(source)
    _guard_path(source, "outdir", WORKSPACE)
    if not os.path.isdir(source):
        raise ValueError("not an output directory: " + source)
    source_files, safety_errors = publication.safe_walk_under(source)
    if safety_errors:
        raise ValueError("outdir import refused: " + "; ".join(safety_errors[:5]))
    run_id, target, _requested = _allocate_run_directory("import", None)
    try:
        for rel, src in source_files:
            destination = publication.safe_join_under(target, rel)
            os.makedirs(os.path.dirname(destination), exist_ok=True)
            shutil.copy2(src, destination)
        return run_id, target
    except Exception:
        # target is the UUID leaf allocated immediately above, never a caller
        # directory; remove only that newly-created leaf on failed import.
        if os.path.basename(os.path.normpath(target)) == run_id:
            shutil.rmtree(target, ignore_errors=True)
        raise


def _python_render_step(entry: str, outdir: str, engine: str, rc: int, timed_out: bool,
                        elapsed: float, extra_env: Optional[Dict[str, str]] = None) -> Optional[Dict[str, Any]]:
    """Python lane (ENGINEERING_PLAN 10.5 / 10.6 item 2): draw a Python run's
    figures with the R figure layer, in omicstat-r (container) or the native R.

    None for an R module. For a Python module the record says whether the step
    ran ("rendered" / "failed" / "timed_out"), or why it did not ("skipped:
    engine failed", "skipped: no figure request"); its own provenance record is
    provenance/figure_render.json written by the step.
    """
    if not _is_python_entry(entry):
        return None
    record: Dict[str, Any] = {
        "script": os.path.relpath(RENDER_SCRIPT, SUITE).replace("\\", "/"),
        "request": FIGURE_REQUEST_REL, "engine": engine, "runs_in": "omicstat-r" if engine == "container" else "native R",
        "status": None, "exit_code": None, "duration_s": 0.0, "timed_out": False,
        "command_argv": None, "_stdout": "", "_stderr": "",
    }
    if rc != 0 or timed_out:
        record["status"] = "skipped: engine failed"
        return record
    if not os.path.isfile(os.path.join(outdir, *FIGURE_REQUEST_REL.split("/"))):
        record["status"] = "skipped: no figure request"
        return record
    argv = ["--run-dir", outdir, "--request", FIGURE_REQUEST_REL]
    cmd = _router_cmd() + ["Rscript", RENDER_SCRIPT] + argv
    remaining = max(60, int(RUN_TIMEOUT_S - elapsed))
    r_rc, r_out, r_err, r_dur, r_to = _exec(cmd, cwd=outdir, timeout=remaining, engine=engine, extra_env=extra_env)
    record.update({"status": "timed_out" if r_to else ("rendered" if r_rc == 0 else "failed"),
                   "exit_code": r_rc, "duration_s": r_dur, "timed_out": r_to,
                   "command_argv": ["Rscript", os.path.basename(RENDER_SCRIPT)] + argv,
                   "_stdout": r_out, "_stderr": r_err})
    return record


# --------------------------------------------------------------------------
# Tools
# --------------------------------------------------------------------------

@mcp.tool()
def omicstat_list_modules() -> str:
    """List every omicstat analysis module (name, one-line summary, entry script).

    Start here when you do not yet know which module covers a question. The
    routing knowledge itself lives in the omicstat://router resource; this tool
    only enumerates what is installed.
    """
    rows = []
    for module, script in _modules().items():
        rows.append({
            "module": module,
            "summary": _summary(module),
            "entry": script,
        })
    return _dumps({"count": len(rows), "modules": rows})


@mcp.tool()
def omicstat_describe(module: str) -> str:
    """Full documentation for one module: its SKILL.md, its `--help` (the
    authoritative flag contract for omicstat_run), and its references/ files.

    Read this before calling omicstat_run with flags you have not used before --
    omicstat_run rejects any flag that does not appear in this `--help` text.
    """
    skill_path = _skill_path(module)
    try:
        with io.open(skill_path, encoding="utf-8") as fh:
            skill = fh.read()
    except OSError as exc:
        skill = "(SKILL.md unreadable: %s)" % exc
    skill_note = ""
    if len(skill) > SKILL_LIMIT:
        skill = skill[:SKILL_LIMIT]
        skill_note = ("\n\n[TRUNCATED: SKILL.md is longer than %d characters; read the "
                      "rest from %s or the omicstat://skill/%s resource]"
                      % (SKILL_LIMIT, skill_path, module))

    refs_dir = os.path.join(SKILLS_DIR, module, "references")
    refs: List[str] = []
    if os.path.isdir(refs_dir):
        for root, _dirs, files in os.walk(refs_dir):
            for fname in sorted(files):
                refs.append(
                    os.path.relpath(os.path.join(root, fname), refs_dir).replace("\\", "/")
                )

    help_text = _help_text(module)
    return (
        "# omicstat module: %s\n"
        "entry script: %s\n"
        "full path: %s\n\n"
        "## SKILL.md\n\n%s%s\n\n"
        "## --help (authoritative flag contract; %d flags)\n\n```\n%s\n```\n\n"
        "## references/ (%d files)\n%s\n"
        % (
            module, _modules()[module], _entry_path(module), skill, skill_note,
            len(_flags(module)), help_text.strip(),
            len(refs), "\n".join("- " + r for r in refs) if refs else "(none)",
        )
    )


@mcp.tool()
def omicstat_run(module: str, args: Dict[str, Any], engine: str = "container",
                study_contract: Optional[Dict[str, Any]] = None) -> str:
    """Run one omicstat module and return a compact JSON manifest of what it produced.

    args: {flag-name-without-dashes: value}. A bool True becomes a bare flag,
    False is omitted, a list is joined with commas, numbers/strings pass
    through. Flags are validated against the module's own `--help`; unknown
    flags are refused with the closest matches. Path values must resolve under
    the allowed roots. If `outdir` is not given, a fresh UUID directory is
    allocated under OMICSTAT_RUNS_ROOT (default: <tmp>/omicstat-runs). If `outdir` is given,
    it is treated as a parent: the actual UUID leaf is returned in `outdir`
    and the requested parent is returned in `requested_outdir`.

    engine: "container" (default; the pinned omicstat-r image, the reference
    environment) or "native" (the isolated omicstat library made by
    env/native/setup_native.R). Neither uses any other R installation.

    Runs synchronously, hard-killed at 25 minutes. The manifest carries
    exit_code, duration_s, outdir, artifacts grouped as tables/figures/draft/
    qc/provenance/other, the triggered QC rules, `engine_warnings` (OS_* codes
    and convergence/NaN warnings that exist only on the console -- ALWAYS read
    these), `effect_table` (the shared-schema estimate rows, or the first
    feature-table rows when `effect_table_schema` is "feature-table" -- the
    primary payload), `degenerate_estimates` (zero-width CIs or estimates
    outside their own CI; for a feature table also padj all NA, every padj
    < 0.05, or a non-finite log2fc -- if this is non-empty the numbers are not
    fit to report), `upstream_runs` (the --from-run chain recorded in
    objects/handoff.json), an optional results-JSON summary, and stderr/stdout
    tails. Read individual files afterwards with omicstat_read.

    study_contract: optional StudyContract v1 object. Omitting it preserves
    legacy execution and yields publication status `needs_input`; supplying an
    invalid contract is refused before R starts.
    """
    entry = _entry_path(module)
    args = dict(args or {})

    normalized_contract, contract_errors = publication.normalize_study_contract(
        study_contract
    )
    if contract_errors:
        raise ValueError(
            "OS_CONTRACT_INVALID: StudyContract v1 failed validation: "
            + "; ".join(contract_errors[:10])
        )

    request_args = copy.deepcopy(args)
    requested_arg = args.pop("outdir", None)
    # Validate flags and path-like inputs before allocating a persistent UUID
    # directory, so rejected requests cannot leave empty run leaves behind.
    _to_argv(module, args, cwd=WORKSPACE)
    # Validate engine selection and route availability before allocating the
    # UUID leaf; _build_cmd is deterministic for an empty argv.
    _build_cmd(entry, [], engine)
    if requested_arg is not None:
        _guard_path(str(requested_arg), "--outdir", WORKSPACE)
    run_id, outdir, requested_outdir = _allocate_run_directory(
        module, None if requested_arg is None else str(requested_arg)
    )

    argv = _to_argv(module, args, cwd=outdir)
    argv.extend(["--outdir", outdir])

    cmd = _build_cmd(entry, argv, engine)
    log.info("run module=%s engine=%s outdir=%s", module, engine, outdir)
    # OMICSTAT_RUN_ID: the UUID leaf, also visible inside the container, where
    # the run directory is mounted as /ws (a module that names its run from
    # basename(outdir) would otherwise record "ws"; the Python lane reads this).
    run_env = {"OMICSTAT_RUN_ID": run_id}
    rc, out, err, dur, timed_out = _exec(cmd, cwd=outdir, timeout=RUN_TIMEOUT_S, engine=engine, extra_env=run_env)
    render = _python_render_step(entry, outdir, engine, rc, timed_out, dur, run_env)
    if render is not None:
        # One manifest per run: the render step's console joins the engine's,
        # its exit code decides when the Python step itself succeeded, and the
        # 25-minute limit covers both steps together.
        out = out + render.pop("_stdout")
        err = err + render.pop("_stderr")
        dur = round(dur + render["duration_s"], 2)
        timed_out = timed_out or render["timed_out"]
        if rc == 0:
            rc = render["exit_code"]

    grouped, total = _scan_artifacts(outdir)
    et_rows, et_sources, et_kind = _scan_effect_tables(outdir)
    effect_validation = _validate_effect_tables(outdir, engine)
    degenerate = _degenerate_estimates(et_rows)
    if et_kind == "feature-table":
        degenerate = (degenerate + _degenerate_features(outdir, et_sources))[:10]
    warnings = _engine_warnings(out, err)

    notes: List[str] = []
    notes.append("UUID run directory allocated by the shell")
    if requested_outdir:
        notes.append("args.outdir was treated as a parent directory")
    if timed_out:
        notes.append("KILLED after the %d s timeout" % RUN_TIMEOUT_S)
    if rc != 0:
        notes.append("non-zero exit: read stderr_tail, then omicstat_read the qc files")
    if render is not None and render.get("status") != "rendered":
        notes.append("Python-lane figures were not rendered (render_step.status=%s)" % render.get("status"))
    if degenerate:
        notes.append("DEGENERATE ESTIMATES FOUND -- treat these numbers as unfit to "
                     "report until the engine warnings explain them")

    manifest: Dict[str, Any] = {
        "run_id": run_id,
        "module": module,
        "engine": engine,
        "exit_code": rc,
        "duration_s": dur,
        "outdir": outdir,
        "requested_outdir": requested_outdir,
        "command": _tool_for(entry) + " " + os.path.basename(entry) + " " + " ".join(argv),
        "command_argv": [_tool_for(entry), os.path.basename(entry)] + argv,
        "artifact_count": total,
        "engine_artifact_count": total,
        "artifacts": grouped,
        "qc_triggered": _scan_qc(outdir),
        "engine_warnings": warnings,
        "structured_warnings": _structured_warnings(warnings),
        "effect_table": et_rows,
        "effect_table_sources": et_sources,
        "effect_table_schema": et_kind,
        "degenerate_estimates": degenerate,
        "upstream_runs": _upstream_runs(outdir),
        "results_summary": _scan_results(outdir),
        "stderr_tail": _tail(err, 40),
        "stdout_tail": _tail(out, 20),
        "timed_out": timed_out,
        "render_step": render,
        "request": {
            "module": module,
            "engine": engine,
            "args": request_args,
            "study_contract": normalized_contract,
        },
    }
    if notes:
        manifest["notes"] = notes
    manifest = publication.finalize_run(
        manifest,
        study_contract=normalized_contract,
        effect_validation=effect_validation,
        software_versions=_software_versions(engine, module),
        input_base=outdir,
        allowed_input_roots=ALLOWED_ROOTS,
        write_manifest=False,
    )
    _refresh_legacy_artifacts(manifest)
    publication.commit_manifest_and_registry(RUN_REGISTRY, manifest)
    return _fit_budget(manifest)


@mcp.tool()
def omicstat_validate_publication(run_id: Optional[str] = None,
                                 outdir: Optional[str] = None,
                                 reviewer_decisions: Optional[Dict[str, Any]] = None) -> str:
    """Run publication validation for an existing omicstat run.

    Provide exactly one of run_id or outdir. A run_id is resolved through the
    persistent UUID registry. An output directory without a prior publication
    manifest is still reviewable, but its module may be reported as `unknown`.
    The tool updates the five standard publication/provenance artifacts and
    returns the same compact JSON manifest envelope as omicstat_run.
    """
    if bool(run_id) == bool(outdir):
        raise ValueError("provide exactly one of run_id or outdir")
    if run_id:
        try:
            normalized_run_id = str(uuid.UUID(str(run_id)))
        except ValueError as exc:
            raise ValueError("invalid run_id UUID: %s" % run_id) from exc
        record = publication.lookup_registry(RUN_REGISTRY, normalized_run_id)
        verified_registry_digest = str(record.get("manifest_digest", ""))
        target = str(record["outdir"])
        requested_source = None
    else:
        requested_source = str(outdir)
        normalized_run_id, target = _import_output_tree(requested_source)
        verified_registry_digest = None
    _guard_path(target, "outdir", WORKSPACE)
    target = os.path.realpath(os.path.abspath(target))
    if not os.path.isdir(target):
        raise ValueError("not an output directory: " + target)

    existing = publication.read_publication_manifest(target)
    if existing:
        manifest = existing
        if run_id:
            normalized_run_id = str(existing.get("run_id") or normalized_run_id)
            if normalized_run_id != str(record.get("run_id")) or os.path.basename(os.path.normpath(target)) != normalized_run_id:
                raise ValueError("run_id mismatch among registry, UUID leaf, and manifest")
        module = str(existing.get("module") or _infer_module_from_outdir(target))
        engine = str(existing.get("engine") or "native")
        study_contract = (existing.get("request") or {}).get("study_contract")
    else:
        normalized_run_id = normalized_run_id or str(
            uuid.uuid5(uuid.NAMESPACE_URL, "omicstat:" + os.path.normcase(target))
        )
        module = _infer_module_from_outdir(target)
        engine = "native" if _native_available() else "container"
        study_contract = None
        grouped, total = _scan_artifacts(target)
        manifest = {
            "run_id": normalized_run_id,
            "module": module,
            "engine": engine,
            "exit_code": 0,
            "duration_s": 0,
            "outdir": target,
            "requested_outdir": None,
            "command": "publication validation only",
            "command_argv": [],
            "artifact_count": total,
            "engine_artifact_count": total,
            "artifacts": grouped,
            "qc_triggered": _scan_qc(target),
            "engine_warnings": [],
            "structured_warnings": [],
            "effect_table": [],
            "effect_table_sources": [],
            "effect_table_schema": "none",
            "degenerate_estimates": [],
            "upstream_runs": [],
            "results_summary": _scan_results(target),
            "stderr_tail": "",
            "stdout_tail": "",
            "timed_out": False,
            "request": {
                "module": module, "engine": engine, "args": {},
                "study_contract": None,
            },
            "notes": ["publication validation was run on an existing output directory"],
        }

    validation_engine = engine if engine in {"native", "container"} else "native"
    effect_validation = _validate_effect_tables(target, validation_engine)
    et_rows, et_sources, et_kind = _scan_effect_tables(target)
    manifest["effect_table"] = et_rows
    manifest["effect_table_sources"] = et_sources
    manifest["effect_table_schema"] = et_kind
    degenerate = _degenerate_estimates(et_rows)
    if et_kind == "feature-table":
        degenerate = (degenerate + _degenerate_features(target, et_sources))[:10]
    manifest["degenerate_estimates"] = degenerate
    manifest["upstream_runs"] = _upstream_runs(target)
    manifest["qc_triggered"] = _scan_qc(target)
    manifest["outdir"] = target
    manifest["run_id"] = normalized_run_id
    if reviewer_decisions is not None:
        if not isinstance(reviewer_decisions, dict):
            raise ValueError("reviewer_decisions must be an object keyed by rule_id")
        decisions = copy.deepcopy(reviewer_decisions)
        prior_review = publication._read_json(publication.safe_join_under(target, publication.REVIEW_REL, require_exists=True)) if existing else {}
        known_rules = {str(item.get("rule_id")) for item in prior_review.get("findings", [])}
        for rule_id, decision in decisions.items():
            if str(rule_id) not in known_rules:
                raise ValueError("reviewer decision references unknown rule: %s" % rule_id)
            if not isinstance(decision, dict) or decision.get("decision") not in {"accepted", "rejected", "pending"}:
                raise ValueError("invalid reviewer decision for %s" % rule_id)
            decision.setdefault("decided_at", _dt.datetime.now(_dt.timezone.utc).isoformat().replace("+00:00", "Z"))
        manifest["reviewer_decisions"] = decisions
    if requested_source:
        manifest["source_outdir"] = requested_source
        manifest["requested_outdir"] = requested_source
    manifest["module"] = module
    manifest = publication.finalize_run(
        manifest,
        study_contract=study_contract,
        effect_validation=effect_validation,
        software_versions=_software_versions(validation_engine, module),
        input_base=target,
        allowed_input_roots=ALLOWED_ROOTS,
        write_manifest=False,
    )
    _refresh_legacy_artifacts(manifest)
    publication.commit_manifest_and_registry(
        RUN_REGISTRY, manifest, expected_previous_digest=verified_registry_digest
    )
    return _fit_budget(manifest)


@mcp.tool()
def omicstat_read(path: str) -> str:
    """Read one artifact produced by omicstat_run.

    Text artifacts (.md .csv .txt .json .yml .yaml .tsv) come back verbatim,
    capped at 60,000 characters. Oversized JSON returns a small valid JSON
    shape summary instead of a syntactically invalid raw slice. Figures and
    other binaries return only their path and size -- image bytes are never
    returned. The path must resolve under the allowed roots.
    """
    if not _under_allowed_root(path) or _has_link_or_reparse(path):
        return _dumps({
            "error": "path refused",
            "path": path,
            "allowed_roots": ALLOWED_ROOTS,
        })
    full = os.path.abspath(path)
    if not os.path.isfile(full):
        return _dumps({"error": "not a file", "path": full})
    size = os.path.getsize(full)
    ext = os.path.splitext(full)[1].lower()
    if ext not in TEXT_EXT:
        return _dumps({
            "path": full, "bytes": size, "kind": "binary",
            "note": "content not returned; open the file directly to view it",
        })
    with io.open(full, encoding="utf-8", errors="replace") as fh:
        text = fh.read()
    if len(text) > READ_LIMIT:
        if ext == ".json":
            try:
                data = json.loads(text)
                if isinstance(data, dict):
                    shape = {
                        "type": "object", "count": len(data),
                        "keys": [str(key)[:160] for key in list(data)[:100]],
                    }
                elif isinstance(data, list):
                    shape = {"type": "array", "count": len(data)}
                else:
                    shape = {"type": type(data).__name__}
                return _dumps({
                    "path": full,
                    "bytes": size,
                    "truncated": True,
                    "character_count": len(text),
                    "summary": shape,
                    "note": "oversized JSON was summarized; read the file directly for full content",
                })
            except json.JSONDecodeError as exc:
                return _dumps({
                    "path": full,
                    "bytes": size,
                    "truncated": True,
                    "error": "oversized artifact is not valid JSON: %s" % exc,
                })
        text = (text[:READ_LIMIT]
                + "\n\n[TRUNCATED at %d of %d characters]" % (READ_LIMIT, len(text)))
    return text


# --------------------------------------------------------------------------
# Resources
# --------------------------------------------------------------------------

@mcp.resource("omicstat://router", name="omicstat router",
              description="The omicstat routing map: which omicstat module answers "
                          "which kind of bioinformatics analysis question.",
              mime_type="text/markdown")
def resource_router() -> str:
    with io.open(ROUTER_SKILL, encoding="utf-8") as fh:
        return fh.read()


@mcp.resource("omicstat://skill/{module}", name="omicstat module SKILL.md",
              description="Full SKILL.md for one omicstat module.",
              mime_type="text/markdown")
def resource_skill(module: str) -> str:
    with io.open(_skill_path(module), encoding="utf-8") as fh:
        return fh.read()


@mcp.resource("omicstat://help/{module}", name="omicstat module --help",
              description="Raw --help text for one omicstat module: the "
                          "authoritative flag contract for omicstat_run.",
              mime_type="text/plain")
def resource_help(module: str) -> str:
    return _help_text(module)


if __name__ == "__main__":
    log.info("omicstat MCP shell starting (stdio); suite=%s", SUITE)
    mcp.run()

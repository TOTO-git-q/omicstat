"""Locked default versus reported literature values (omicstat fork, coverage upgrade).

Reads the mapped parameter observations of the reviewed S0 supplement and the locked CLI defaults
(``s0_evidence/option_defaults.json``, written by import_s0_evidence.py from each module's options.md) and
counts, per module and CLI option, how many papers report the locked default and how many report something
else.  Only cleanly comparable cases are counted (the locked default is a plain number or word, the paper's
value parses to the same kind; everything else is "unparsed" and left out).  The result is context for the
owner and for the advice text: a flagged default is a prompt for owner review.  It never changes a default,
a routing or a parameter (execution_authorized stays false, S1 appendix remains the only authority).

Two safeguards keep the flags honest.  Values that a reviewer marked as the other ecosystem's ("Seurat-side value (mixed)",
"scanpy-side value (mixed)") are never pooled with the module's own ecosystem (the packs say so) and are counted separately as
n_excluded_cross_ecosystem; n_unparsed (multi-value or descriptive reports) is always shown next to n_parsed.  An owner verdict
recorded in s0_evidence/default_adjudications.json (module, option, locked default -> verdict + note) is attached as owner_verdict,
and an adjudicated flag is listed under "adjudicated" instead of "flagged" in the advise context; it stays in the full report.
A verdict only applies while the locked default it was made for is unchanged.
"""
from __future__ import annotations

import json
import re
import sqlite3
from collections import Counter
from contextlib import closing
from pathlib import Path
from typing import Any, Iterable, Mapping

OPTION_DEFAULTS_PATH = Path(__file__).with_name("s0_evidence") / "option_defaults.json"
ADJUDICATIONS_PATH = Path(__file__).with_name("s0_evidence") / "default_adjudications.json"
CROSS_ECOSYSTEM_NOTE = re.compile(r"-side value \(mixed\)", re.I)  # a reviewed value from another ecosystem, never pooled (packs)
MIN_N = 8                 # papers with a parsed value before a flag is raised
MINORITY_SHARE = 0.30     # default reported by fewer than 30 % of the parsed papers
BIMODAL_TOP = 0.65        # bimodal: the top value is below this share ...
BIMODAL_SECOND = 0.25     # ... and the runner-up reaches this share
UNINFORMATIVE = {"", "none", "null", "off", "required", "auto", "true", "false"}  # true/false only compared as words below

_NUM = re.compile(r"^[-+]?\d+(?:\.\d+)?$")
_WORD = re.compile(r"^[A-Za-z][A-Za-z0-9_.+-]*$")
_PAREN_TAIL = re.compile(r"\s+\([^)]*\)\s*$")
_LIT_NUM = re.compile(
    r"^(?:[a-z][a-z.\- ]{0,18}?\s*)?[<>≤≥=~]*\s*([-+]?\d[\d,]*(?:\.\d+)?(?:e-?\d+)?)\s*(%|k)?"
    r"(?:\s*(?:umis?|cells?|genes?|pcs?|counts?|epochs?|iterations?|dims?|dimensions?|neighbou?rs?))?\s*(?:\(.*\))?$", re.I)


def load_option_defaults(path: str | Path | None = None) -> dict[str, Any]:
    p = Path(path) if path is not None else OPTION_DEFAULTS_PATH
    try:
        raw = json.loads(p.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}
    return raw.get("modules", {}) if isinstance(raw, Mapping) else {}


def default_key(cleaned: tuple[str, Any]) -> str:
    """Stable text key of a cleaned default: 1.0 -> "1", "t-test" -> "t-test"."""
    kind, value = cleaned
    return format(value, "g") if kind == "num" else str(value)


def load_adjudications(path: str | Path | None = None) -> dict[tuple[str, str, str], dict[str, Any]]:
    """{(module, option, default_key): {verdict, note, decided}} from default_adjudications.json; {} when absent or unreadable."""
    p = Path(path) if path is not None else ADJUDICATIONS_PATH
    try:
        raw = json.loads(p.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}
    out: dict[tuple[str, str, str], dict[str, Any]] = {}
    for row in raw.get("adjudications", []) if isinstance(raw, Mapping) else []:
        if isinstance(row, Mapping) and all(isinstance(row.get(k), str) for k in ("module", "option", "locked_default", "verdict", "note")):
            out[(row["module"], row["option"], row["locked_default"])] = {k: row[k] for k in ("verdict", "note", "decided") if k in row}
    return out


def clean_default(text: Any) -> tuple[str, Any] | None:
    """('num', float) or ('word', str) for a plain locked default; None when the cell is descriptive or uninformative."""
    if not isinstance(text, str):
        return None
    t = _PAREN_TAIL.sub("", text.strip()).strip().strip("\"'").strip()
    if _NUM.match(t):
        return "num", float(t)
    if _WORD.match(t) and t.lower() not in UNINFORMATIVE:
        return "word", t.lower()
    return None


def parse_value(value: Any, kind: str) -> Any | None:
    """The paper's value as a float (kind 'num') or lower-case first word (kind 'word'); None when unparseable."""
    if not isinstance(value, str):
        return None
    t = value.strip().strip("\"'").strip()
    if not t or t.lower().startswith("not reported"):
        return None
    if kind == "num":
        m = _LIT_NUM.match(t.lower())
        if not m:
            return None
        try:
            number = float(m.group(1).replace(",", ""))
        except ValueError:
            return None
        if m.group(2) == "%":
            number /= 100.0
        elif m.group(2) == "k":
            number *= 1000.0
        return number
    word = re.split(r"[\s;,(]", t.lower().strip("\"'"), maxsplit=1)[0].strip("\"'")
    if word.startswith("variance"):       # "variance stabilizing transformation" is the long name of vst
        word = "vst"
    return word or None


def _equal(kind: str, a: Any, b: Any) -> bool:
    return abs(a - b) <= 1e-9 * max(1.0, abs(a), abs(b)) if kind == "num" else a == b


def compare(observations: Iterable[Mapping[str, Any]], option_defaults: Mapping[str, Any],
            adjudications: Mapping[tuple[str, str, str], Mapping[str, Any]] | None = None) -> dict[str, dict[str, Any]]:
    """observations: {'module', 'paper', 'options', 'value'[, 'cross_ecosystem']} (one mapped parameter row).  Returns {module: {option: stats}}."""
    seen: set[tuple[str, str, str]] = set()
    tally: dict[tuple[str, str], dict[str, Any]] = {}
    for obs in observations:
        module, options = obs["module"], obs.get("options") or []
        if len(options) != 1:
            continue  # a key that maps to several CLI options cannot be compared with one default
        option = options[0]
        info = (option_defaults.get(module) or {}).get(option)
        default = clean_default(info.get("default")) if info else None
        if default is None:
            continue
        kind, locked = default
        slot = tally.setdefault((module, option), {"kind": kind, "locked": locked, "raw_default": info.get("default"), "unparsed": 0, "excluded": 0, "values": Counter()})
        if obs.get("cross_ecosystem"):
            slot["excluded"] += 1  # before the per-paper de-duplication: it must not shadow the paper's own-ecosystem value
            continue
        if (module, option, obs["paper"]) in seen:
            continue
        seen.add((module, option, obs["paper"]))
        parsed = parse_value(obs["value"], kind)
        if parsed is None:
            slot["unparsed"] += 1
        else:
            slot["values"][parsed] += 1
    report: dict[str, dict[str, Any]] = {}
    verdicts = adjudications or {}
    for (module, option), slot in sorted(tally.items()):
        n = sum(slot["values"].values())
        at_default = sum(c for v, c in slot["values"].items() if _equal(slot["kind"], v, slot["locked"]))
        ranked = slot["values"].most_common()
        share = (at_default / n) if n else None
        flags = []
        if n >= MIN_N:
            if share < MINORITY_SHARE:
                flags.append("default_minority")
            if len(ranked) > 1 and ranked[0][1] / n < BIMODAL_TOP and ranked[1][1] / n >= BIMODAL_SECOND:
                flags.append("bimodal")
        report.setdefault(module, {})[option] = {
            "locked_default": _PAREN_TAIL.sub("", str(slot["raw_default"]).strip()).strip(), "compared_as": slot["kind"], "n_parsed": n, "n_unparsed": slot["unparsed"],
            "n_excluded_cross_ecosystem": slot["excluded"],
            "n_at_default": at_default, "default_share": None if share is None else round(share, 3),
            "top_values": [{"value": v, "n": c} for v, c in ranked[:4]], "flags": flags, "low_n": 0 < n < MIN_N,
            "owner_verdict": verdicts.get((module, option, default_key((slot["kind"], slot["locked"]))))}
    return report


def _observations(data_dir: Path, module: str | None) -> list[dict[str, Any]]:
    ref = Path(data_dir) / "reference.sqlite"
    if not ref.is_file():
        return []
    out: list[dict[str, Any]] = []
    with closing(sqlite3.connect(ref.as_uri() + "?mode=ro", uri=True, timeout=10)) as con:
        if not con.execute("SELECT 1 FROM sqlite_master WHERE name='reviewed_supplement'").fetchone():
            return []
        for modules, review in con.execute("SELECT modules_json,review_json FROM reviewed_supplement WHERE status='active' ORDER BY supplement_id"):
            usage = json.loads(review).get("usage") or {}
            if usage.get("column") != "reviewed_supplement":
                continue
            mods = json.loads(modules)
            if module is not None and module not in mods:
                continue
            for p in usage.get("parameters", []):
                if p.get("mapping_status") == "mapped":
                    out.append({"module": mods[0], "paper": usage.get("paper_id"), "options": p.get("options"), "value": p.get("value"),
                                "cross_ecosystem": bool(CROSS_ECOSYSTEM_NOTE.search(p.get("note") or ""))})
    return out


def report(data_dir: Path, module: str | None = None, option_defaults: Mapping[str, Any] | None = None,
           adjudications: Mapping[tuple[str, str, str], Mapping[str, Any]] | None = None) -> dict[str, Any]:
    result = compare(_observations(data_dir, module), option_defaults if option_defaults is not None else load_option_defaults(),
                     adjudications if adjudications is not None else load_adjudications())
    return {m: v for m, v in result.items() if module is None or m == module}


_CACHE: dict[tuple[str, int, str], dict[str, Any]] = {}


def default_context(data_dir: Path, module: str) -> dict[str, Any]:
    """Compact `default_context` for reference_advise: flagged options only, plus how many were compared.

    Cached per (reference.sqlite mtime, module): the supplement only changes at an import or curation step."""
    ref = Path(data_dir) / "reference.sqlite"
    key = (str(ref), ref.stat().st_mtime_ns if ref.is_file() else 0, module)
    if key not in _CACHE:
        if len(_CACHE) > 200:
            _CACHE.clear()
        _CACHE[key] = _build_context(data_dir, module)
    return _CACHE[key]


def _build_context(data_dir: Path, module: str) -> dict[str, Any]:
    options = report(data_dir, module).get(module, {})
    if not options:
        return {"status": "no_default_context", "module": module,
                "note": "No locked default of this module could be compared with reported S0 values (descriptive defaults, unmapped keys or no values)."}
    rows = [{"option": o, "locked_default": s["locked_default"], "default_share": s["default_share"], "n_parsed": s["n_parsed"],
             "top_reported_values": s["top_values"][:3], "flags": s["flags"], "owner_verdict": s["owner_verdict"]}
            for o, s in options.items() if s["flags"]]
    flagged = [dict((k, v) for k, v in r.items() if k != "owner_verdict") for r in rows if r["owner_verdict"] is None]
    adjudicated = [{"option": r["option"], "locked_default": r["locked_default"], "default_share": r["default_share"], "n_parsed": r["n_parsed"],
                    "flags": r["flags"], "owner_verdict": r["owner_verdict"]} for r in rows if r["owner_verdict"] is not None]
    flagged.sort(key=lambda x: (x["default_share"], x["option"]))
    adjudicated.sort(key=lambda x: (x["default_share"], x["option"]))
    context = {"status": "flagged" if flagged else "no_flag", "module": module, "options_compared": len(options),
               "options_with_enough_papers": sum(1 for s in options.values() if s["n_parsed"] >= MIN_N), "flagged": flagged[:5],
               "criteria": "flag when >= %d papers report a comparable value and fewer than %d%% use the locked default, or the top value is below %d%% with a runner-up of at least %d%%" % (MIN_N, MINORITY_SHARE * 100, BIMODAL_TOP * 100, BIMODAL_SECOND * 100),
               "caveat": "Literature values are study-specific; a minority default is not an error. The locked defaults and the S1 appendix remain the authority, and nothing here changes a parameter."}
    if adjudicated:
        context["adjudicated"] = adjudicated[:5]
        context["adjudicated_note"] = "These options were flagged but the owner has already decided them (owner_verdict); they are not open items."
    return context

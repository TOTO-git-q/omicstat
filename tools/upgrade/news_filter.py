#!/usr/bin/env python3
"""NEWS filter for an environment upgrade: which upstream changes touch the functions our modules call?

Offline.  For every package in the union of the modules' `calls_registry.json` (package_versions) it reads the
NEWS file stored in the L1 layer (`acceptance/exemplars/<module>/L1_*/<pkg>/NEWS.{txt,md}`), keeps the entries
of the window "previous release -> locked version", classifies each entry with plain regexes (deprecation /
default change / bug fix / behaviour change / other) and reports the entries that mention a registered function
or a distinctive argument name, per module.  A FILTER, not a verdict: regexes miss changes, NEWS quality varies,
and every listed entry still needs a human read.  Packages without a NEWS file in the layer (GitHub pins, CRAN
packages without NEWS) are listed so the git log between the two pinned commits can be read instead.

Window per package
    * Bioconductor package (layer directory L1_bioc*): entries with version > (x.(y-2).inf) and <= locked
      version, i.e. everything since the previous Bioconductor release line (3.22 -> 3.23 for 1.52.0 / 3.68.5 ...).
    * anything else: `--since PKG=VERSION`, otherwise the newest `--tail-blocks` entries.

    news_filter.py --repo . --out docs/upgrade/2026.10.1/affected_modules.md [--since CellChat=2.1.0]
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

sys.dont_write_bytecode = True

CLASSES = ("deprecation", "default_change", "bug_fix", "behaviour_change", "other")
_PATTERNS = (
    ("deprecation", re.compile(r"\b(?:deprecat\w*|defunct|obsolete|no longer (?:supported|available|exported)|(?:is|are|been|now|formally) removed|removal of)\b", re.I)),
    ("default_change", re.compile(r"\bdefault\b[^.\n]{0,80}\b(?:chang\w+|now|becomes?|set to|switch\w*|is)\b|\b(?:chang\w+|now|becomes?)\b[^.\n]{0,80}\bdefault\b", re.I)),
    ("bug_fix", re.compile(r"\b(?:fix(?:ed|es)?|bug(?:fix)?|corrected?|incorrect(?:ly)?|wrong(?:ly)?|regression|crash\w*|segfault|errors? (?:when|in|with))\b", re.I)),
    ("behaviour_change", re.compile(r"\b(?:now|no longer|instead|changed?|renamed|replaced|rewritten|stricter|breaking|different(?:ly)?|results? (?:may|will) differ)\b", re.I)),
)
_STOP_ARGS = {"data", "object", "value", "names", "model", "group", "genes", "method", "design", "counts", "matrix", "output", "verbose", "result", "results", "label", "labels"}
_RD_SECTION = re.compile(r"\\section\{\s*[Vv]ersion\s+([0-9][0-9.\-]*)[^}]*\}\{", re.I)
_TEXT_HEAD = re.compile(r"^(?:CHANGES?|SIGNIFICANT USER-VISIBLE CHANGES)\s+IN\s+(?:VERSION|RELEASE)?\s*(?:[A-Za-z][\w.]*\s+)?v?([0-9][0-9.\-]*[0-9])", re.I)
_MD_HEAD = re.compile(r"^#{1,3}\s*(?:[A-Za-z][\w.]*\s+)?(?:[Vv]ersion\s+)?v?([0-9]+(?:\.[0-9]+)+[0-9.\-]*)")


def vtuple(text: str) -> tuple[int, ...]:
    return tuple(int(x) for x in re.findall(r"\d+", text))


def _items_from_text(lines: list[str]) -> list[str]:
    """Bullet items (o / - / + / *) with continuation lines; blank-line paragraphs when there are no bullets."""
    items: list[str] = []
    bullet = re.compile(r"^\s{0,4}(?:[o+*-])\s+(.*)$")
    current: list[str] | None = None
    saw_bullet = any(bullet.match(l) for l in lines)
    for line in lines:
        m = bullet.match(line)
        if m:
            if current:
                items.append(" ".join(current))
            current = [m.group(1).strip()]
        elif not line.strip():
            if current and not saw_bullet:
                items.append(" ".join(current))
                current = None
        elif current is not None and (line.startswith(" ") or not saw_bullet):
            current.append(line.strip())
        elif current is None and not saw_bullet and not re.fullmatch(r"[-=\s]+", line):
            current = [line.strip()]
    if current:
        items.append(" ".join(current))
    return [i for i in items if i and not re.fullmatch(r"[A-Z ]+", i)]


def parse_news(text: str) -> list[tuple[str, list[str]]]:
    """[(version, [item text])] in file order; supports Rd \\section, 'CHANGES IN VERSION' and Markdown headings."""
    blocks: list[tuple[str, list[str]]] = []
    if "\\section{" in text and "\\item" in text:
        parts = _RD_SECTION.split(text)
        for version, body in zip(parts[1::2], parts[2::2]):
            items = [re.sub(r"\s+", " ", re.sub(r"\\(?:code|pkg|link|emph|strong|file|dQuote|sQuote|samp)\{([^}]*)\}", r"\1", i)).strip(" }\n") for i in re.split(r"\\item(?![A-Za-z])", body)[1:]]
            blocks.append((version, [i for i in items if i]))
        return blocks
    lines = text.replace("\t", " ").splitlines()
    heads = []
    for i, line in enumerate(lines):
        m = _TEXT_HEAD.match(line.strip()) or _MD_HEAD.match(line)
        if m:
            heads.append((i, m.group(1)))
    for n, (start, version) in enumerate(heads):
        end = heads[n + 1][0] if n + 1 < len(heads) else len(lines)
        blocks.append((version, _items_from_text(lines[start + 1:end])))
    return blocks


def classify(item: str) -> str:
    for name, pattern in _PATTERNS:
        if pattern.search(item):
            return name
    return "other"


def registry_terms(registry: dict) -> dict[str, dict[str, set[str]]]:
    """{package: {'functions': {...}, 'args': {...}}} from one calls_registry.json."""
    out: dict[str, dict[str, set[str]]] = defaultdict(lambda: {"functions": set(), "args": set()})
    for call in registry.get("calls", []):
        fn = str(call.get("fn", ""))
        pkg, _, name = fn.partition("::") if "::" in fn else (fn.split(".")[0], "", fn.split(".")[-1])
        if not name or pkg not in registry.get("package_versions", {}):
            continue
        out[pkg]["functions"].add(name)
        for arg in call.get("args", {}):
            if len(arg) >= 5 and arg.lower() not in _STOP_ARGS:
                out[pkg]["args"].add(arg)
    for accessor in registry.get("accessors", []):
        pkg, _, name = str(accessor).partition("::")
        if name and pkg in registry.get("package_versions", {}):
            out[pkg]["functions"].add(name)
    return out


def mentions(item: str, terms: dict[str, set[str]]) -> list[str]:
    hits = [f for f in sorted(terms["functions"]) if len(f) >= 3 and re.search(r"(?<![\w.])" + re.escape(f) + r"(?![\w])", item)]
    if not hits:   # an argument name alone is only evidence next to a function-like token or backticks
        hits = [a for a in sorted(terms["args"]) if re.search(r"(?<![\w.])" + re.escape(a) + r"(?![\w])", item) and ("(" in item or "`" in item or "=" in item)]
    return hits


def window(blocks: list[tuple[str, list[str]]], locked: str, bioc: bool, since: str | None, tail: int) -> tuple[list[tuple[str, list[str]]], str]:
    upper = vtuple(locked)
    inside = [b for b in blocks if vtuple(b[0]) <= upper] or blocks
    if since:
        low = vtuple(since)
        return [b for b in inside if vtuple(b[0]) > low], f"versions > {since} up to {locked}"
    if bioc and len(upper) >= 2 and upper[1] >= 2:
        low = (upper[0], upper[1] - 2, 10 ** 6)
        return [b for b in inside if vtuple(b[0]) > low], f"Bioconductor previous release line -> {locked} (versions > {upper[0]}.{upper[1] - 2}.x)"
    return inside[:tail], f"newest {tail} NEWS blocks up to {locked} (no release rule for this package)"


def run(repo: Path, since: dict[str, str], tail: int) -> dict:
    registries = {}
    for path in sorted(repo.glob("skills/*/scripts/calls_registry.json")):
        registries[path.parent.parent.name] = json.loads(path.read_text(encoding="utf-8"))
    packages: dict[str, dict] = {}
    for module, reg in registries.items():
        terms = registry_terms(reg)
        for pkg, version in reg.get("package_versions", {}).items():
            slot = packages.setdefault(pkg, {"locked": version, "modules": {}, "functions": set(), "args": set()})
            slot["modules"][module] = terms.get(pkg, {"functions": set(), "args": set()})
            slot["functions"] |= slot["modules"][module]["functions"]
            slot["args"] |= slot["modules"][module]["args"]
    report = {"packages": {}, "modules": defaultdict(list), "no_news": []}
    for pkg, info in sorted(packages.items()):
        found = None
        for path in sorted(repo.glob(f"acceptance/exemplars/*/L1*/{pkg}/NEWS*")):
            if path.suffix in (".txt", ".md") and path.name.startswith("NEWS"):
                found = path
                break
        if found is None:
            report["no_news"].append({"package": pkg, "locked": info["locked"], "modules": sorted(info["modules"])})
            continue
        blocks = parse_news(found.read_text(encoding="utf-8", errors="replace"))
        bioc = "L1_bioc" in found.as_posix()
        picked, rule = window(blocks, info["locked"], bioc, since.get(pkg), tail)
        counts: Counter = Counter()
        relevant = []
        for version, items in picked:
            for item in items:
                cls = classify(item)
                counts[cls] += 1
                hit = mentions(item, {"functions": info["functions"], "args": info["args"]})
                if hit:
                    relevant.append({"version": version, "class": cls, "matched": hit, "text": item[:400]})
        report["packages"][pkg] = {"locked": info["locked"], "source": found.relative_to(repo).as_posix(), "window": rule, "blocks": len(picked),
                                   "entries": sum(counts.values()), "by_class": {c: counts.get(c, 0) for c in CLASSES}, "relevant": len(relevant)}
        for module, terms in info["modules"].items():
            mine = [r for r in relevant if set(r["matched"]) & (terms["functions"] | terms["args"])]
            for r in mine:
                report["modules"][module].append({"package": pkg, **r})
    report["modules"] = dict(sorted(report["modules"].items()))
    return report


def render(report: dict, title: str) -> str:
    out = [f"# {title}", "",
           "Generated by `tools/upgrade/news_filter.py` from the NEWS files stored in the L1 layers (offline). **This is a filter, not a verdict**: "
           "regex classification misses changes, NEWS quality varies, and every entry below still needs a human read. Default values are caught mechanically "
           "by `check_default_drift` in the new image, not by this list.", "",
           "## Packages", "", "| package | locked | window | entries | deprecation | default | bug fix | behaviour | other | mention a registered function |",
           "|---|---|---|---:|---:|---:|---:|---:|---:|---:|"]
    for pkg, p in report["packages"].items():
        c = p["by_class"]
        out.append(f"| {pkg} | {p['locked']} | {p['window']} | {p['entries']} | {c['deprecation']} | {c['default_change']} | {c['bug_fix']} | {c['behaviour_change']} | {c['other']} | {p['relevant']} |")
    out += ["", "## Affected modules (entries that mention a function or distinctive argument the module registers)", ""]
    if not report["modules"]:
        out.append("None found in the available NEWS windows.")
    for module, items in report["modules"].items():
        out += [f"### {module}", ""]
        for r in items:
            out.append(f"- **{r['package']} {r['version']}** [{r['class']}] ({', '.join(r['matched'])}): {r['text']}")
        out.append("")
    out += ["## Packages without a NEWS file in the layer", "",
            "Read the git log between the two pinned commits (GitHub packages) or the CRAN/PyPI change log for these:", ""]
    out += [f"- {n['package']} {n['locked']} (modules: {', '.join(n['modules'])})" for n in report["no_news"]] or ["- none"]
    return "\n".join(out) + "\n"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[2])
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--json", type=Path, help="also write the structured report")
    ap.add_argument("--since", action="append", default=[], metavar="PKG=VERSION")
    ap.add_argument("--tail-blocks", type=int, default=6)
    ap.add_argument("--title", default="NEWS filter: locked release versus previous release")
    args = ap.parse_args()
    since = dict(s.split("=", 1) for s in args.since)
    report = run(args.repo, since, args.tail_blocks)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(render(report, args.title), encoding="utf-8", newline="\n")
    if args.json:
        args.json.write_text(json.dumps(report, ensure_ascii=False, indent=1, sort_keys=True) + "\n", encoding="utf-8", newline="\n")
    print(json.dumps({"packages_with_news": len(report["packages"]), "packages_without_news": len(report["no_news"]),
                      "modules_with_relevant_entries": len(report["modules"]), "out": str(args.out)}))
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Flag-documentation coverage (ENGINEERING_PLAN 4.3 / gate G4).

Both accepted layouts, references/reporting-templates.md (fenced template
blocks) and references/methods-template.md (slim Methods), are included through
references/*.md. Flag coverage reads their text; default checking reads only
Flag/Default tables and explicit default markers, not arbitrary template prose.

Usage: python tools/check_flag_docs.py skills/<module>
Runs `Rscript scripts/run_*.R --help` (or `python scripts/run_*.py --help`), extracts every --flag with the same
regex the MCP server uses (--[A-Za-z0-9][A-Za-z0-9-]*), and fails unless each
flag appears in SKILL.md or references/*.md. Exit 0 = 100% coverage.
"""
import pathlib, re, subprocess, sys

FLAG = re.compile(r"--[A-Za-z0-9][A-Za-z0-9-]*")


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    mod = pathlib.Path(sys.argv[1]).resolve()
    entry = sorted((mod / "scripts").glob("run_*.R")) + sorted((mod / "scripts").glob("run_*.py"))
    if len(entry) != 1:
        sys.exit(f"OS_INVALID_INPUT: expected exactly one scripts/run_*.R or run_*.py in {mod}")
    tool = sys.executable if entry[0].suffix == ".py" else "Rscript"   # Python lane: same --help convention
    out = subprocess.run([tool, str(entry[0]), "--help"], capture_output=True, text=True, stdin=subprocess.DEVNULL)
    if out.returncode != 0:
        print(f"FAIL: --help exited {out.returncode}; documentation coverage was not assessed")
        print((out.stderr or out.stdout).strip())
        sys.exit(1)
    flags = sorted(set(FLAG.findall(out.stdout)) - {"--help"})
    if not flags:
        print("FAIL: no flags discovered; documentation coverage was not assessed")
        sys.exit(1)
    docs = (mod / "SKILL.md").read_text(encoding="utf-8")
    for f in sorted((mod / "references").glob("*.md")):
        docs += f.read_text(encoding="utf-8")
    shared = mod.parent / "_shared/docs/STUDY_CONTRACT.md"
    common = shared.read_text(encoding="utf-8") if shared.exists() else ""
    missing = [f for f in flags if f not in docs and not (f in {"--study-contract", "--study-contract-sha256"} and f in common)]
    print(f"{len(flags) - len(missing)}/{len(flags)} flags documented")
    for f in missing:
        print(f"UNDOCUMENTED {f}")
    sys.exit(1 if missing else 0)


if __name__ == "__main__":
    main()

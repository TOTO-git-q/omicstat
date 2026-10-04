#!/usr/bin/env python3
"""Default-value consistency across a module's sources (CONVENTIONS.md sec 17).

Both accepted layouts, references/reporting-templates.md (fenced template
blocks) and references/methods-template.md (slim Methods), are included through
references/*.md. Flag coverage reads their text; default checking reads only
Flag/Default tables and explicit default markers, not arbitrary template prose.

Usage: python tools/check_defaults.py skills/<module> [--help-file FILE]

Collects every flag default from
  1. `Rscript scripts/run_*.R --help` / `python scripts/run_*.py --help`
     (or --help-file): lines in the
     os_help() convention  "  --<flag> <TYPE>  required|default: <value>  <text>";
  2. scripts/calls_registry.json: the top-level object "flag_defaults"
     ({"--seed": 20260925}) and every registered argument that names a
     "flag" ({"value": 0.05, "flag": "--alpha"}): its "value" is what the
     engine receives when the flag is absent. An explicit "cli_default" is
     used for optional overrides whose absence retains a lazy native default;
  3. SKILL.md and references/*.md: markdown tables whose header has a "Flag"
     and a "Default" column, and inline markers
     <!-- default --flag -->VALUE<!-- /default --> (used in Methods /
     reporting templates, where the number sits in prose; markers inside
     `code` spans or fenced blocks are examples and are ignored).
and fails when one flag has different defaults in different places, when a
source names a flag that --help does not list, or when a --help flag line does
not follow the convention. Values are compared after normalisation: backticks,
quotes and a trailing "(comment)" are dropped; off/false/absent -> off;
on/true -> on; none/-/--/n/a/null -> none; "(required)" -> required; numbers
compare numerically (20260925 == 20260925L == 2.0260925e7).
Exit 0 = consistent.
"""
import json, pathlib, re, subprocess, sys

FLAG = r"--[A-Za-z0-9][A-Za-z0-9-]*"
HELP_LINE = re.compile(r"^ +(" + FLAG + r") <([^>]*)> {2,}(required|default: (.*?))( {2,}(.*))?$")
HELP_FLAG_LINE = re.compile(r"^ +(" + FLAG + r")\b")
MARKER = re.compile(r"<!--\s*default\s+(" + FLAG + r")\s*-->(.*?)<!--\s*/default\s*-->", re.S)
NUM = re.compile(r"^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?L?$")
NONE = {"none", "-", "--", "\u2014", "\u2013", "n/a", "na", "null", ""}
OFF = {"off", "false", "absent", "no"}
ON = {"on", "true", "yes"}
IGNORE = {"--help"}


def norm(v):
    """Canonical string for a default value from any source."""
    if v is None:
        return "none"
    if isinstance(v, bool):
        return "on" if v else "off"
    if isinstance(v, (int, float)):
        return _num(str(v))
    s = str(v).strip().strip("`").strip()
    trimmed = re.sub(r"\s*\([^)]*\)\s*$", "", s)
    if trimmed:
        s = trimmed
    s = s.strip().strip("()").strip().strip("`\"'").strip()
    low = s.lower()
    if low in NONE:
        return "none"
    if low in OFF:
        return "off"
    if low in ON:
        return "on"
    if low == "required":
        return "required"
    if NUM.match(s):
        return _num(s)
    return s


def _num(s):
    x = float(s.rstrip("L"))
    if x.is_integer() and abs(x) < 1e15:
        return str(int(x))
    return repr(x)


def _key(flag):
    flag = str(flag).strip()
    return flag if flag.startswith("--") else "--" + flag


def help_defaults(text):
    """{flag: raw default} from --help text, plus nonconforming flag lines."""
    found, bad = {}, []
    for line in text.splitlines():
        m = HELP_LINE.match(line)
        if m:
            found[m.group(1)] = "required" if m.group(3) == "required" else m.group(4)
        elif HELP_FLAG_LINE.match(line):
            bad.append(line.strip())
    return found, bad


def registry_defaults(path):
    out = []  # (flag, value, where)
    if not path.exists():
        return out
    reg = json.loads(path.read_text(encoding="utf-8"))
    for flag, value in (reg.get("flag_defaults") or {}).items():
        out.append((_key(flag), value, "calls_registry.json flag_defaults"))
    for call in reg.get("calls") or []:
        for arg, entry in (call.get("args") or {}).items():
            if isinstance(entry, dict) and entry.get("flag"):
                # Optional override flags can be absent while the native call
                # retains its lazy function default (recorded in value).
                out.append((_key(entry["flag"]), entry.get("cli_default", entry.get("value")),
                            "calls_registry.json %s(%s)" % (call.get("fn", "?"), arg)))
    return out


def _cells(row):
    row = row.strip()
    if row.startswith("|"):
        row = row[1:]
    if row.endswith("|") and not row.endswith("\\|"):
        row = row[:-1]
    return [c.strip() for c in re.split(r"(?<!\\)\|", row)]


def markdown_defaults(text, where):
    """(flag, raw default, where) from Flag/Default tables and inline markers."""
    out = []
    lines = text.splitlines()
    i = 0
    while i < len(lines) - 1:
        head, sep = lines[i], lines[i + 1]
        if head.lstrip().startswith("|") and re.match(r"^\s*\|?\s*:?-{3,}", sep):
            names = [re.sub(r"[`*_]", "", c).strip().lower() for c in _cells(head)]
            j = i + 2
            if "flag" in names and "default" in names:
                fi, di = names.index("flag"), names.index("default")
                while j < len(lines) and lines[j].lstrip().startswith("|"):
                    cells = _cells(lines[j])
                    if len(cells) > max(fi, di):
                        flags = re.findall(FLAG, cells[fi])
                        if len(flags) == 1:
                            out.append((flags[0], cells[di], "%s:%d" % (where, j + 1)))
                    j += 1
            else:
                while j < len(lines) and lines[j].lstrip().startswith("|"):
                    j += 1
            i = j
            continue
        i += 1
    # Markers inside code (fenced blocks, `inline spans`) are examples, not values.
    prose = re.sub(r"```.*?```", lambda m: re.sub(r"[^\n]", " ", m.group(0)), text, flags=re.S)
    prose = re.sub(r"`[^`\n]*`", lambda m: " " * len(m.group(0)), prose)
    for m in MARKER.finditer(prose):
        line = prose.count("\n", 0, m.start()) + 1
        out.append((m.group(1), m.group(2), "%s:%d (marker)" % (where, line)))
    return out


def run_help(mod):
    # Python-lane modules (ENGINEERING_PLAN 10.4) have scripts/run_*.py; their
    # --help follows the same os_help() convention (skills/_shared/py/ospy/args.py).
    entry = sorted((mod / "scripts").glob("run_*.R")) + sorted((mod / "scripts").glob("run_*.py"))
    if len(entry) != 1:
        sys.exit("OS_INVALID_INPUT: expected exactly one scripts/run_*.R or run_*.py in %s" % mod)
    tool = sys.executable if entry[0].suffix == ".py" else "Rscript"
    out = subprocess.run([tool, str(entry[0]), "--help"], capture_output=True, text=True,
                         stdin=subprocess.DEVNULL)
    if out.returncode != 0:
        sys.exit("OS_INVALID_INPUT: %s --help exited %d: %s" % (entry[0].name, out.returncode, out.stderr.strip()[-300:]))
    return out.stdout


def check(mod, help_text):
    """Return (problems, n_help, n_compared)."""
    problems = []
    help_map, bad = help_defaults(help_text)
    for line in bad:
        problems.append("NONCONFORMING --help line (want '  --flag <TYPE>  required|default: <v>  text'): %s" % line)
    if not help_map:
        problems.append("no --help line follows the os_help() convention")
    sources = {}  # flag -> [(where, raw, norm)]
    for flag, raw in help_map.items():
        if flag not in IGNORE:
            sources.setdefault(flag, []).append(("--help", raw, norm(raw)))
    others = registry_defaults(mod / "scripts" / "calls_registry.json")
    docs = [mod / "SKILL.md"] + sorted((mod / "references").glob("*.md"))
    for d in docs:
        if d.exists():
            others += markdown_defaults(d.read_text(encoding="utf-8"), d.relative_to(mod).as_posix())
    for flag, raw, where in others:
        if flag in IGNORE:
            continue
        if flag not in help_map:
            problems.append("UNKNOWN %s: %s gives a default but --help does not list the flag" % (flag, where))
            continue
        sources.setdefault(flag, []).append((where, raw, norm(raw)))
    n_compared = 0
    for flag in sorted(sources):
        vals = sources[flag]
        if len(vals) > 1:
            n_compared += 1
        if len({v[2] for v in vals}) > 1:
            detail = "; ".join("%s=%r" % (w, r.strip() if isinstance(r, str) else r) for w, r, _ in vals)
            problems.append("MISMATCH %s: %s" % (flag, detail))
    return problems, len([f for f in help_map if f not in IGNORE]), n_compared


def main(argv):
    args = [a for a in argv if not a.startswith("--help-file")]
    help_file = None
    if "--help-file" in argv:
        k = argv.index("--help-file")
        help_file = argv[k + 1]
        args = [a for a in argv if a not in ("--help-file", help_file)]
    if len(args) != 1:
        print(__doc__)
        return 2
    mod = pathlib.Path(args[0]).resolve()
    help_text = pathlib.Path(help_file).read_text(encoding="utf-8") if help_file else run_help(mod)
    problems, n_help, n_compared = check(mod, help_text)
    for p in problems:
        print("FAIL:", p)
    print("%s: %d flag(s) in --help, %d with defaults in 2+ sources; %d problem(s)"
          % (mod.name, n_help, n_compared, len(problems)))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

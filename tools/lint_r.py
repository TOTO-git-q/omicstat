#!/usr/bin/env python3
"""Engine-hygiene lint for module R code (CONVENTIONS.md sec 18).

Usage: python tools/lint_r.py [PATH ...]
  default PATHs: skills/*/scripts/*.R and templates/module/scripts/*.R.tmpl

Rules (deliberately simple, text-based on code with comments and string
contents blanked out):
  LR01  options(... warn = <negative> ...)  -- hides every engine warning.
  LR02  suppressWarnings() around a whole stage: its argument is a { block },
        spans more than one line, or calls a stage (<x>_compute/_render/_qc/
        _report/_draft, os_engine_capture, source). A one-line coercion such
        as suppressWarnings(as.numeric(x)) is allowed.
  LR03  set.seed() whose first argument is not a variable (seed, args$seed,
        args[["seed"]]): a literal or computed seed bypasses --seed.
  LR04  sample()/sample.int()/rnorm()/runif() outside a seeded scope: the
        innermost enclosing function (or an enclosing function, or the file
        top level) must call set.seed() -- or a seeding helper defined in the
        same file, i.e. a function whose body calls set.seed() -- earlier, or
        the call must sit inside with_seed()/withr::with_seed()/os_with_seed().
Allowlist: files under a tests/ or fixtures/ directory are skipped; a single
line is exempted with a trailing comment "# lint-ok LR0x: <reason>".
Exit 0 = clean.
"""
import pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
ALLOW_DIRS = {"tests", "fixtures"}
PRAGMA = re.compile(r"#\s*lint-ok\s+((?:LR\d\d[ ,]*)+)")
ID = r"(?<![A-Za-z0-9._$@])"
RE_OPTIONS = re.compile(ID + r"options\s*\(")
RE_WARN_NEG = re.compile(r"\bwarn\s*=\s*-")
RE_SUPPRESS = re.compile(ID + r"suppressWarnings\s*\(")
RE_STAGE = re.compile(r"[A-Za-z0-9._]*_(compute|render|qc|report|draft)\s*\(|\bos_engine_capture\s*\(|\bsource\s*\(")
RE_SETSEED = re.compile(ID + r"set\.seed\s*\(")
RE_SEED_ARG = re.compile(r'^(seed\s*=\s*)?[A-Za-z.][A-Za-z0-9._]*(\$[A-Za-z.][A-Za-z0-9._]*|\[\[\s*"[^"]+"\s*\]\])*$')
RESERVED = {"NULL", "TRUE", "FALSE", "NA", "Inf", "NaN", "T", "F"}
RE_RNG = re.compile(ID + r"(sample|sample\.int|rnorm|runif)\s*\(")
RE_WITHSEED = re.compile(ID + r"(os_with_seed|with_seed)\s*\(")
RE_FUNCTION = re.compile(ID + r"(function\s*\(|\\\s*\()")
RE_FUNDEF = re.compile(ID + r"([A-Za-z.][A-Za-z0-9._]*)\s*(<-|=)\s*function\s*\(")


def mask(src):
    """Blank comments and string contents (positions and newlines preserved)."""
    out = list(src)
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        if c in "\"'":
            q = c
            i += 1
            while i < n and src[i] != q:
                if src[i] == "\\":
                    out[i] = " "
                    i += 1
                if i < n and src[i] != "\n":
                    out[i] = " "
                i += 1
            i += 1
        elif c == "#":
            while i < n and src[i] != "\n":
                out[i] = " "
                i += 1
        else:
            i += 1
    return "".join(out)


def close_of(code, open_idx):
    """Index of the bracket matching code[open_idx] (one of ( { [)."""
    pairs = {"(": ")", "{": "}", "[": "]"}
    o = code[open_idx]
    c = pairs[o]
    depth = 0
    for k in range(open_idx, len(code)):
        if code[k] == o:
            depth += 1
        elif code[k] == c:
            depth -= 1
            if depth == 0:
                return k
    return len(code) - 1


def scopes(code):
    """[(start, end)] of function bodies; the file itself is (0, len)."""
    out = [(0, len(code))]
    for m in RE_FUNCTION.finditer(code):
        p_open = m.end() - 1
        p_close = close_of(code, p_open)
        k = p_close + 1
        while k < len(code) and code[k] in " \t\r\n":
            k += 1
        if k < len(code) and code[k] == "{":
            out.append((k, close_of(code, k)))
        else:
            eol = code.find("\n", k)
            out.append((k, len(code) if eol < 0 else eol))
    return out


def innermost(sc, pos):
    inside = [s for s in sc if s[0] <= pos <= s[1]]
    return max(inside, key=lambda s: s[0])


def lint_text(src, name="<text>"):
    code = mask(src)
    lines = src.splitlines()
    problems = []

    def line_of(pos):
        return code.count("\n", 0, pos) + 1

    def add(pos, rule, msg):
        ln = line_of(pos)
        text = lines[ln - 1] if ln - 1 < len(lines) else ""
        pm = PRAGMA.search(text)
        if pm and rule in re.findall(r"LR\d\d", pm.group(1)):
            return
        problems.append("%s:%d: %s %s" % (name, ln, rule, msg))

    for m in RE_OPTIONS.finditer(code):
        body = code[m.end() - 1:close_of(code, m.end() - 1) + 1]
        if RE_WARN_NEG.search(body):
            add(m.start(), "LR01", "options(warn = <negative>) hides engine warnings; use os_engine_capture()")
    for m in RE_SUPPRESS.finditer(code):
        o = m.end() - 1
        body = code[o + 1:close_of(code, o)]
        if body.strip().startswith("{") or "\n" in body.strip() or RE_STAGE.search(body):
            add(m.start(), "LR02", "suppressWarnings() around a whole stage; wrap the stage in os_engine_capture() instead")
    sc = scopes(code)
    # Seeding helpers: functions defined in this file whose body calls set.seed()
    # (e.g. fx_rng <- function(seed) set.seed(seed, kind = ...)); calling one seeds.
    helpers = []
    for m in RE_FUNDEF.finditer(code):
        body = [s for s in sc if s[0] > m.end()]
        if body:
            b = min(body, key=lambda s: s[0])
            if RE_SETSEED.search(code[b[0]:b[1] + 1]):
                helpers.append(m.group(1))
    seeds = []
    if helpers:
        re_helper = re.compile(ID + r"(" + "|".join(re.escape(h) for h in helpers) + r")\s*\(")
        seeds += [m.start() for m in re_helper.finditer(code)]
    for m in RE_SETSEED.finditer(code):
        o = m.end() - 1
        c = close_of(code, o)
        arg = src[o + 1:c]
        depth, first = 0, ""
        for ch in arg:
            if ch in "([{":
                depth += 1
            elif ch in ")]}":
                depth -= 1
            elif ch == "," and depth == 0:
                break
            first += ch
        first = first.strip()
        if not RE_SEED_ARG.match(first) or first in RESERVED:
            add(m.start(), "LR03", "set.seed(%s): pass the parsed --seed value (a variable), not a literal or expression" % first)
        seeds.append(m.start())
    guards = [(m.end() - 1, close_of(code, m.end() - 1)) for m in RE_WITHSEED.finditer(code)]
    for m in RE_RNG.finditer(code):
        p = m.start()
        if any(a < p < b for a, b in guards):
            continue
        ok = False
        for q in seeds:
            if q < p:
                s = innermost(sc, q)
                if s[0] <= p <= s[1]:
                    ok = True
                    break
        if not ok:
            add(p, "LR04", "%s() outside a seeded scope (call set.seed(seed) first in this function)" % m.group(1))
    return problems


def default_paths():
    files = sorted(ROOT.glob("skills/*/scripts/*.R")) + sorted(ROOT.glob("templates/module/scripts/*.R.tmpl"))
    return files


def collect(paths):
    out = []
    for p in paths:
        p = pathlib.Path(p)
        if p.is_dir():
            out += sorted(list(p.rglob("*.R")) + list(p.rglob("*.R.tmpl")))
        else:
            out.append(p)
    def parts(f):
        try:
            return f.resolve().relative_to(ROOT).parts[:-1]
        except ValueError:
            return f.parts[:-1]
    return [f for f in out if not (ALLOW_DIRS & set(parts(f)))]


def main(argv):
    files = collect(argv) if argv else collect(default_paths())
    problems = []
    for f in files:
        try:
            name = f.resolve().relative_to(ROOT).as_posix()
        except ValueError:
            name = str(f)
        problems += lint_text(f.read_text(encoding="utf-8"), name)
    for p in problems:
        print("FAIL:", p)
    print("lint_r: %d file(s) scanned; %d problem(s)" % (len(files), len(problems)))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

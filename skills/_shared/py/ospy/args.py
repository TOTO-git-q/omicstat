"""args.py -- declarative command-line flags for run_*.py entry scripts.

Python counterpart of skills/_shared/scripts/args.R (CONVENTIONS.md sec 14);
same spec model, same typed errors, and a --help text in EXACTLY the R format,
so tools/check_defaults.py and the MCP flag whitelist read both lanes with one
regex. Standard library only (an entry script can answer --help before any
scientific package is imported). ASCII only.

    SPEC = os_arg_spec(
        usage="python run_x_y.py --outdir <dir> [options]",
        description="One line on what the module does.",
        flags=[
            os_flag("outdir", "path", required=True, help="output directory"),
            os_flag("seed", "int", default=20260925, help="random seed"),
            os_flag("alpha", "num", default=0.05, range=(0, 1), help="FDR level"),
            os_flag("journal", "enum", default="nature", values=["nature", "cell"], help="figure preset"),
            os_flag("strict", "bool", help="bare switch: fail on a blocker"),
            os_flag("from-run", "path", must_exist=True, help="upstream run directory")],
        exclusive=[("input", "from-run")])
    args = os_parse_args(SPEC, argv)
    if args["help"]:
        os_print_help(SPEC); return 0

Types: int, num, string, path, enum (needs values), bool (bare switch).
os_parse_args() returns an OsArgs dict: one key per flag (name without the
leading "--", dashes kept: args["from-run"]; absent optional flags carry their
default, possibly None) plus "help"; OsArgs.given lists the flags given.
Typed errors (raised as OmicstatError):
  OS_UNKNOWN_FLAG            token that is not a declared flag
  OS_MISSING_PARAMETER       required flag absent; flag without value; `requires` unmet
  OS_INVALID_PARAMETER       wrong type / not in enum / out of range / path not found
  OS_CONFLICTING_PARAMETERS  two flags of an exclusive group; a flag given twice
  OS_INVALID_ARG_SPEC        the spec itself is wrong
--help line convention (identical to args.R):
  "  --<name> <TYPE>  required|default: <value>  <help text>"
"""
import re
import sys
from decimal import Decimal

from .errors import OmicstatError

OS_ARG_TYPES = ("int", "num", "string", "path", "enum", "bool")
INT_MAX = 2147483647   # .Machine$integer.max: the R side's int range
_NAME_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9-]*$")
_INT_RE = re.compile(r"^[+-]?[0-9]+$")
_NUM_RE = re.compile(r"^[+-]?([0-9]+\.?[0-9]*|\.[0-9]+)([eE][+-]?[0-9]+)?$")
OS_HELP_LINE_RE = re.compile(r"^ +--([A-Za-z0-9][A-Za-z0-9-]*) <([^>]*)> {2,}(required|default: (.*?))( {2,}(.*))?$")


class OsFlag:
    """One declared flag (plain attributes: name, type, required, default, help, values, range, requires, must_exist)."""

    def __init__(self, **kw):
        self.__dict__.update(kw)

    def __repr__(self):
        return "OsFlag(%s)" % ", ".join("%s=%r" % kv for kv in self.__dict__.items())


def os_flag(name, type, required=False, default=None, help="", values=None, range=None,  # noqa: A002
            requires=None, must_exist=False):
    if isinstance(requires, str):
        requires = [requires]
    return OsFlag(name=name, type=type, required=bool(required), default=default, help=help,
                  values=list(values) if values is not None else None,
                  range=tuple(range) if range is not None else None,
                  requires=list(requires) if requires else None, must_exist=bool(must_exist))


def _spec_error(msg):
    return OmicstatError("OS_INVALID_ARG_SPEC", msg)


def fmt_value(x):
    """Default/range formatting of args.R .os_fmt_value (format(x, digits = 15))."""
    if x is None:
        return "none"
    if isinstance(x, bool):
        return "on" if x else "off"
    if isinstance(x, int):
        return str(x)
    if isinstance(x, float):
        s = "%.15g" % x
        if "e" in s or "E" in s:
            s = format(Decimal(s), "f")
        return s
    return str(x)


def _type_label(f):
    base = {"bool": "switch", "enum": "|".join(f.values or [])}.get(f.type, f.type)
    if f.range is not None:
        base = "%s in [%s, %s]" % (base, fmt_value(f.range[0]), fmt_value(f.range[1]))
    return base


def _invalid(f, expected, got, note=""):
    return OmicstatError("OS_INVALID_PARAMETER", "--%s: expected %s, got '%s'%s" % (f.name, expected, got, note))


def _coerce(f, raw, check_exists=True):
    import os                                                   # noqa: PLC0415
    t = f.type
    if t == "int":
        if not (_INT_RE.match(raw) and abs(int(raw)) <= INT_MAX):
            raise _invalid(f, "an integer", raw)
        v = int(raw)
    elif t == "num":
        v = float(raw) if _NUM_RE.match(raw) else float("nan")
        if v != v or v in (float("inf"), float("-inf")):
            raise _invalid(f, "a finite number", raw)
    elif t == "enum":
        if raw not in (f.values or []):
            raise _invalid(f, "one of " + "|".join(f.values or []), raw)
        v = raw
    elif t == "string":
        if not raw:
            raise _invalid(f, "a non-empty string", raw)
        v = raw
    elif t == "path":
        if not raw:
            raise _invalid(f, "a non-empty path", raw)
        if check_exists and f.must_exist and not os.path.exists(raw):
            raise _invalid(f, "an existing file or directory", raw, " (not found)")
        v = raw
    else:
        raise _invalid(f, "a declared type", t)
    if f.range is not None and (v < f.range[0] or v > f.range[1]):
        raise _invalid(f, "a value in [%s, %s]" % (fmt_value(f.range[0]), fmt_value(f.range[1])), raw)
    return v


class OsArgSpec:
    """usage, description, flags ({name: OsFlag}, in declaration order), exclusive."""

    def __init__(self, **kw):
        self.__dict__.update(kw)


def os_arg_spec(usage, flags, description=None, exclusive=()):
    flags = list(flags)
    for name in ("study-contract", "study-contract-sha256"):
        if not any(f.name == name for f in flags):
            flags.append(os_flag(name, "path" if name == "study-contract" else "string", must_exist=name == "study-contract", help="shared StudyContract byte binding; see _shared/docs/STUDY_CONTRACT.md"))
    if not any(f.name == "help" for f in flags):
        flags.append(os_flag("help", "bool", help="show this help and exit"))
    names = [f.name for f in flags]
    dup = sorted({n for n in names if names.count(n) > 1})
    if dup:
        raise _spec_error("duplicated flag(s) %s" % ", ".join(dup))
    bad = [n for n in names if not _NAME_RE.match(n)]
    if bad:
        raise _spec_error("flag names must match [A-Za-z0-9][A-Za-z0-9-]* (got %s)" % ", ".join(bad))
    for f in flags:
        if f.type not in OS_ARG_TYPES:
            raise _spec_error("--%s has type '%s' (allowed: %s)" % (f.name, f.type, ", ".join(OS_ARG_TYPES)))
        if f.type == "enum" and not f.values:
            raise _spec_error("--%s is an enum without values" % f.name)
        if f.range is not None and (f.type not in ("int", "num") or len(f.range) != 2 or f.range[0] > f.range[1]):
            raise _spec_error("--%s: range must be (lo, hi) on an int/num flag" % f.name)
        if f.required and f.default is not None:
            raise _spec_error("--%s is required and also has a default" % f.name)
        if f.type == "bool" and (f.required or f.default is not None):
            raise _spec_error("--%s is a bool switch: no default, never required" % f.name)
        if f.requires and not all(r in names for r in f.requires):
            raise _spec_error("--%s requires an undeclared flag" % f.name)
        if f.default is not None:
            if f.type == "int" and (isinstance(f.default, bool) or not isinstance(f.default, int)):
                raise _spec_error("default of --%s does not validate (an int flag needs an int default)" % f.name)
            try:
                _coerce(f, fmt_value(f.default), check_exists=False)
            except OmicstatError as exc:
                raise _spec_error("default of --%s does not validate (%s)" % (f.name, exc)) from None
        if "  " in fmt_value(f.default if f.default is not None else ""):
            raise _spec_error("default of --%s contains two consecutive spaces" % f.name)
    for g in exclusive:
        if not all(n in names for n in g):
            raise _spec_error("exclusive group names an undeclared flag (%s)" % ", ".join(g))
    return OsArgSpec(usage=usage, description=description, flags={f.name: f for f in flags},
                     exclusive=[tuple(g) for g in exclusive])


class OsArgs(dict):
    """Parsed arguments; .given = flags given on the command line, in order."""
    given = ()


def os_parse_args(spec, argv=None):
    argv = list(sys.argv[1:] if argv is None else argv)
    known = ["--" + n for n in spec.flags]
    raw, given = {}, []
    i = 0
    while i < len(argv):
        tok = argv[i]
        key = tok.split("=", 1)[0]
        inline = tok.split("=", 1)[1] if ("=" in tok and tok.startswith("--")) else None
        if key not in known:
            what = tok if tok.startswith("--") else "%s (a value without a flag)" % tok
            raise OmicstatError("OS_UNKNOWN_FLAG", "%s (known: %s)" % (what, " ".join(known)))
        name = key[2:]
        f = spec.flags[name]
        if name in given:
            raise OmicstatError("OS_CONFLICTING_PARAMETERS", "--%s given twice" % name)
        given.append(name)
        if f.type == "bool":
            if inline is not None:
                raise _invalid(f, "a bare switch without a value", inline)
            raw[name] = True
            i += 1
            continue
        if inline is not None:
            raw[name] = inline
            i += 1
            continue
        if i == len(argv) - 1 or argv[i + 1].startswith("--"):
            raise OmicstatError("OS_MISSING_PARAMETER", "--%s needs a value (<%s>)" % (name, _type_label(f)))
        raw[name] = argv[i + 1]
        i += 2
    out = OsArgs()
    out.given = tuple(given)
    if "help" in given:
        out["help"] = True
        return out
    for f in spec.flags.values():
        if f.type == "bool":
            out[f.name] = bool(raw.get(f.name))
        elif f.name in given:
            out[f.name] = _coerce(f, raw[f.name])
        elif f.required:
            raise OmicstatError("OS_MISSING_PARAMETER", "--%s is required (<%s>)" % (f.name, _type_label(f)))
        else:
            out[f.name] = f.default
    for f in spec.flags.values():
        if f.name in given and f.requires:
            miss = [r for r in f.requires if r not in given]
            if miss:
                raise OmicstatError("OS_MISSING_PARAMETER", "--%s requires %s" % (f.name, " and ".join("--" + m for m in miss)))
    for g in spec.exclusive:
        hit = [n for n in g if n in given]
        if len(hit) > 1:
            raise OmicstatError("OS_CONFLICTING_PARAMETERS", "%s are mutually exclusive (give at most one)"
                                % ", ".join("--" + h for h in hit))
    from .study_contract import bind_args
    bind_args(out)
    return out


def os_help(spec):
    """--help text as a list of lines (byte-identical layout to args.R os_help)."""
    flags = list(spec.flags.values())
    left = ["--%s <%s>" % (f.name, _type_label(f)) for f in flags]
    mid = ["required" if f.required else "default: " + ("off" if f.type == "bool" else fmt_value(f.default))
           for f in flags]
    wl, wm = max(len(x) for x in left), max(len(x) for x in mid)
    body = [("  %s  %s  %s" % (l.ljust(wl), m.ljust(wm), f.help or "")).rstrip(" ")
            for l, m, f in zip(left, mid, flags)]
    notes = ["Mutually exclusive: %s" % ", ".join("--" + n for n in g) for g in spec.exclusive]
    notes += ["--%s requires %s" % (f.name, " and ".join("--" + r for r in f.requires)) for f in flags if f.requires]
    head = ["Usage: " + spec.usage] + ([spec.description] if spec.description is not None else []) + ["Options:"]
    return head + body + notes


def os_print_help(spec, file=None):
    (file or sys.stdout).write("\n".join(os_help(spec)) + "\n")


def os_help_parse(lines):
    """Inverse of os_help(): [{name, type_label, required, default}] (default None when required)."""
    out = []
    for line in lines:
        m = OS_HELP_LINE_RE.match(line)
        if m:
            out.append({"name": m.group(1), "type_label": m.group(2), "required": m.group(3) == "required",
                        "default": None if m.group(3) == "required" else m.group(4)})
    return out


def os_check_named_values(values, required_levels, what="mapping"):
    """Named colour/label mappings must cover every level (args.R os_check_named_values)."""
    levels = []
    for x in required_levels:
        if x is not None and str(x) not in levels:
            levels.append(str(x))
    values = dict(values or {})
    covered = [bool(values.get(l)) for l in levels]
    if all(covered):
        return True
    extra = [n for n in values if n and n not in levels]
    tab = ["  [%s] %s" % ("x" if c else " ", l) for c, l in zip(covered, levels)]
    msg = ["%s must name every level; %d of %d level(s) missing:" % (what, covered.count(False), len(levels))] + tab
    if extra:
        msg.append("  (names matching no level: %s)" % ", ".join(extra))
    raise OmicstatError("OS_INVALID_PARAMETER", "\n".join(msg))

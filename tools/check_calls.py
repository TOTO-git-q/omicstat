#!/usr/bin/env python3
"""Lock 3 for Python modules (ENGINEERING_PLAN 3.3 / 10.4): call registry
consistency and default drift. Counterpart of tools/check_calls.R +
skills/_shared/scripts/calls_check.R, same calls_registry.json schema.

Usage: python tools/check_calls.py skills/<module>
Scans skills/<module>/scripts/*.py with `ast`; prints "FAIL: ..." per problem
and "N call sites scanned; X registry problems; Y default-drift problems".
Exit 0 = consistent. The default-drift half imports the registered packages,
so run it in the locked environment (omicstat-py image).

calls_registry.json (per module, scripts/calls_registry.json):
  { "module": "scanpy-cluster",
    "package_versions": {"scanpy": "1.12.4", "scvi-tools": "1.5.1"},   # distribution names
    "import_names": {"scvi-tools": "scvi"},                            # optional; see IMPORT_NAMES
    "calls": [
      {"fn": "scanpy.pp.pca",                                          # import path, dotted
       "args": {"n_comps": {"value": 50, "source": "pack_majority", "pack": "V-03",
                            "function_default": "None"}}},             # repr() of the locked default
      {"fn": "scvi.model.SCVI", "args": {...}},                        # a class = its constructor
      {"fn": "scvi.model.SCVI.train", "args": {...}},                  # a method, see receivers below
      {"fn": "scvi.model.SCANVI.from_scvi_model", "returns": "scvi.model.SCANVI", "args": {...}}],
    "accessors": ["anndata.AnnData.write_h5ad"] }                      # pure accessors, exempt from C2

Checks (numbering as in calls_check.R, plus two that Python needs):
  C1 every call site of a registered function names EVERY registered argument
     as a keyword -- even when the value equals the function default
     (except signature-checked required inputs declared in positional_inputs,
     needed by singledispatch APIs; scientific options remain keywords);
  C2 any call into a package listed in package_versions that is neither
     registered nor an accessor fails;
  C3 every registered function is called at least once;
  C4 a method call whose name matches a registered method but whose receiver
     cannot be resolved (bind the receiver with `x = pkg.Class(...)` or with a
     registered call that declares "returns");
  C5 a registered call site that passes **kwargs (explicitness cannot be
     verified).
  D1 (default drift) for every argument carrying "function_default",
     repr(inspect.signature(fn).parameters[arg].default) in the LOCKED
     environment must equal it ("<required>" for a parameter without a
     default, "<absent>" for a name that is not a parameter, e.g. one passed
     through **kwargs); D0 the package / attribute cannot be imported.
Name resolution: `import pkg as a`, `from pkg.sub import name as b`, attribute
chains (a.pp.pca), aliases (f = a.pp.pca) and instance receivers
(model = scvi.model.SCVI(...); model.train(...)) are followed; scopes are not
distinguished (one binding table per file, source order). ASCII only.
"""
import ast
import importlib
import inspect
import json
import pathlib
import re
import sys

IMPORT_NAMES = {"scvi-tools": "scvi", "scikit-learn": "sklearn", "umap-learn": "umap", "scikit-misc": "skmisc",
                "python-igraph": "igraph", "pytorch-lightning": "pytorch_lightning"}


def import_name(dist, reg):
    return (reg.get("import_names") or {}).get(dist) or IMPORT_NAMES.get(dist) or dist.replace("-", "_")


def _is_class_path(q):
    last = q.rsplit(".", 1)[-1]
    return bool(last) and last[0].isupper()


def _method_names(reg):
    """Registered methods: 'pkg.mod.Class.method' -> method name."""
    out = {}
    for c in reg.get("calls") or []:
        parts = c["fn"].split(".")
        if len(parts) >= 2 and _is_class_path(".".join(parts[:-1])) and not _is_class_path(c["fn"]):
            out.setdefault(parts[-1], []).append(c["fn"])
    return out


class _Scanner(ast.NodeVisitor):
    def __init__(self, fname, tracked, returns, methods):
        self.fname, self.tracked, self.returns, self.methods = fname, tracked, returns, methods
        self.alias = {}      # name -> qualified module/attr path
        self.inst = {}       # variable -> class path (instance) or qualified alias
        self.sites = []      # dicts: file, line, q, kws, starstar, unresolved_method
        self.n_calls = 0

    # --- imports
    def visit_Import(self, node):
        for a in node.names:
            if a.asname:
                self.alias[a.asname] = a.name
            else:
                top = a.name.split(".")[0]
                self.alias[top] = top
        self.generic_visit(node)

    def visit_ImportFrom(self, node):
        if node.module and node.level == 0:
            for a in node.names:
                if a.name != "*":
                    self.alias[a.asname or a.name] = node.module + "." + a.name
        self.generic_visit(node)

    # --- resolution
    def resolve(self, expr):
        if isinstance(expr, ast.Name):
            if expr.id in self.inst:
                return self.inst[expr.id]
            return self.alias.get(expr.id)
        if isinstance(expr, ast.Attribute):
            base = self.resolve(expr.value)
            return None if base is None else base + "." + expr.attr
        return None

    def _bind(self, targets, value):
        q = None
        if isinstance(value, ast.Call):
            fq = self.resolve(value.func)
            if fq in self.returns:
                q = self.returns[fq]
            elif fq is not None and _is_class_path(fq):
                q = fq
        elif isinstance(value, (ast.Name, ast.Attribute)):
            q = self.resolve(value)
        for t in targets:
            if isinstance(t, ast.Name):
                if q is None:
                    self.inst.pop(t.id, None)
                    self.alias.pop(t.id, None)
                else:
                    self.inst[t.id] = q

    def visit_Assign(self, node):
        self.generic_visit(node)       # calls on the right-hand side first (source order)
        self._bind(node.targets, node.value)

    def visit_AnnAssign(self, node):
        self.generic_visit(node)
        if node.value is not None:
            self._bind([node.target], node.value)

    def visit_Call(self, node):
        self.n_calls += 1
        q = self.resolve(node.func)
        kws = [k.arg for k in node.keywords if k.arg is not None]
        starstar = any(k.arg is None for k in node.keywords)
        if q is not None and q.split(".")[0] in self.tracked:
            self.sites.append({"file": self.fname, "line": node.lineno, "q": q, "kws": kws, "starstar": starstar, "n_positional": len(node.args), "star_args": any(isinstance(a, ast.Starred) for a in node.args)})
        elif q is None and isinstance(node.func, ast.Attribute) and node.func.attr in self.methods:
            self.sites.append({"file": self.fname, "line": node.lineno, "q": None, "kws": kws, "starstar": starstar,
                               "unresolved_method": node.func.attr})
        self.generic_visit(node)


def scan(scripts, reg):
    tracked = {import_name(d, reg) for d in (reg.get("package_versions") or {})}
    returns = {c["fn"]: c["returns"] for c in reg.get("calls") or [] if c.get("returns")}
    methods = _method_names(reg)
    sites, n = [], 0
    for s in scripts:
        p = pathlib.Path(s)
        tree = ast.parse(p.read_text(encoding="utf-8"), filename=str(p))
        sc = _Scanner(p.name, tracked, returns, methods)
        sc.visit(tree)
        sites += sc.sites
        n += sc.n_calls
    return sites, n


def check_calls(scripts, registry):
    reg = json.loads(pathlib.Path(registry).read_text(encoding="utf-8")) if isinstance(registry, (str, pathlib.Path)) else registry
    sites, n_sites = scan(scripts, reg)
    problems = []
    reg_fns = {c["fn"]: c for c in reg.get("calls") or []}
    accessors = set(reg.get("accessors") or [])
    for fn, c in reg_fns.items():
        hits = [s for s in sites if s["q"] == fn]
        if not hits:
            problems.append("C3 registered function %s is never called" % fn)
            continue
        need = list((c.get("args") or {}).keys())
        for h in hits:
            positional = c.get("positional_inputs", [])
            if positional:
                if any(a not in need or c["args"][a].get("function_default") != "<required>" for a in positional):
                    problems.append("C1 %s invalid positional_inputs: only signature-checked required inputs are allowed" % fn)
                    positional = []
                if h.get("star_args") or h.get("n_positional", 0) != len(positional):
                    problems.append("C1 %s:%d %s must supply exactly its registered positional inputs" % (h["file"], h["line"], fn))
            miss = [a for a in need if a not in h["kws"] and a not in positional[:h.get("n_positional", 0)]]
            if miss:
                problems.append("C1 %s:%d %s does not name registered argument(s): %s" % (h["file"], h["line"], fn, ", ".join(miss)))
            if h["starstar"]:
                problems.append("C5 %s:%d %s passes **kwargs; registered arguments must be literal keywords" % (h["file"], h["line"], fn))
    for s in sites:
        if s["q"] is None:
            problems.append("C4 %s:%d cannot resolve the receiver of .%s() (registered as %s); bind it to a registered "
                            "class or a call with \"returns\"" % (s["file"], s["line"], s["unresolved_method"],
                                                                   ", ".join(_method_names(reg)[s["unresolved_method"]])))
        elif s["q"] not in reg_fns and s["q"] not in accessors:
            problems.append("C2 %s:%d unregistered call %s" % (s["file"], s["line"], s["q"]))
    return {"ok": not problems, "problems": problems, "n_sites": n_sites}


def resolve_object(q):
    """Import the longest importable module prefix of q, then getattr the rest."""
    parts = q.split(".")
    for k in range(len(parts), 0, -1):
        try:
            obj = importlib.import_module(".".join(parts[:k]))
        except ImportError:
            continue
        for attr in parts[k:]:
            obj = getattr(obj, attr)
        return obj
    raise ImportError("no importable prefix of %s" % q)


def locked_default(obj, arg):
    target = obj.__init__ if inspect.isclass(obj) else obj
    sig = inspect.signature(target)
    p = sig.parameters.get(arg)
    if p is None or p.kind in (inspect.Parameter.VAR_KEYWORD, inspect.Parameter.VAR_POSITIONAL):
        return "<absent>"
    return "<required>" if p.default is inspect.Parameter.empty else repr(p.default)


def check_default_drift(registry):
    reg = json.loads(pathlib.Path(registry).read_text(encoding="utf-8")) if isinstance(registry, (str, pathlib.Path)) else registry
    problems = []
    for c in reg.get("calls") or []:
        wants = {a: e.get("function_default") for a, e in (c.get("args") or {}).items()
                 if isinstance(e, dict) and e.get("function_default") is not None}
        try:
            obj = resolve_object(c["fn"])
        except (ImportError, AttributeError) as exc:
            problems.append("D0 %s cannot be imported (%s)" % (c["fn"], exc))
            continue
        positional = c.get("positional_inputs", [])
        if positional:
            sig = inspect.signature(obj)
            names = [p.name for p in sig.parameters.values() if p.kind in (p.POSITIONAL_ONLY, p.POSITIONAL_OR_KEYWORD)]
            if positional != names[:len(positional)]:
                problems.append("D1 %s positional_inputs differ from installed signature" % c["fn"])
        for a, want in wants.items():
            try:
                got = locked_default(obj, a)
            except (TypeError, ValueError) as exc:
                problems.append("D0 %s has no inspectable signature (%s)" % (c["fn"], exc))
                break
            if got != want:
                problems.append("D1 %s(%s): locked default is %s, PACK D recorded %s" % (c["fn"], a, got, want))
    return {"ok": not problems, "problems": problems}


def main(argv):
    if len(argv) != 1:
        print("usage: python tools/check_calls.py skills/<module>")
        return 2
    mod = pathlib.Path(argv[0]).resolve()
    reg = mod / "scripts" / "calls_registry.json"
    if not reg.is_file():
        print("FAIL: %s has no scripts/calls_registry.json" % mod.name)
        return 1
    scripts = sorted((mod / "scripts").glob("*.py"))
    cc, dd = check_calls(scripts, reg), check_default_drift(reg)
    for p in cc["problems"] + dd["problems"]:
        print("FAIL:", p)
    print("%d call sites scanned; %d registry problems; %d default-drift problems"
          % (cc["n_sites"], len(cc["problems"]), len(dd["problems"])))
    return 0 if cc["ok"] and dd["ok"] else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

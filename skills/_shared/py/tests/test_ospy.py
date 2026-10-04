#!/usr/bin/env python3
"""Unit tests of skills/_shared/py/ospy (the Python lane's shared layer).

Usage: python skills/_shared/py/tests/test_ospy.py
Standard library only; the numpy/torch/scvi parts of seed.set_seed are
exercised when those packages are importable (omicstat-py image) and reported
as SKIP otherwise. Cross-lane byte parity with the R side (help text, feature
table, QC table, handoff) is tested from R in
skills/_shared/tests/test_render_figure_request.R. Exit 0 = all passed.
ASCII only.
"""
import io
import json
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile
import warnings
from contextlib import redirect_stderr

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

from ospy import args as A                                    # noqa: E402
from ospy import engine_run, feature_table as FT, figure_request as FR, handoff as H  # noqa: E402
from ospy import module_kit as K, seed as S                   # noqa: E402
from ospy.errors import OmicstatError, os_error               # noqa: E402

FAILS, SKIPS = [], []


def check(cond, msg):
    print(("PASS: " if cond else "FAIL: ") + msg)
    if not cond:
        FAILS.append(msg)


def raises(code, fn, *a, **k):
    try:
        fn(*a, **k)
    except OmicstatError as exc:
        return exc.code == code, str(exc)
    except Exception as exc:                                  # noqa: BLE001
        return False, "%s: %s" % (type(exc).__name__, exc)
    return False, "no error"


TMP = pathlib.Path(tempfile.mkdtemp(prefix="ospy-test-"))

# ---------------------------------------------------------------- args
SPEC = A.os_arg_spec(
    usage="python run_x_y.py --outdir <dir> [options]",
    description="Test module.",
    flags=[A.os_flag("outdir", "path", required=True, help="output directory"),
           A.os_flag("seed", "int", default=20260925, help="random seed"),
           A.os_flag("alpha", "num", default=0.05, range=(0, 1), help="FDR level"),
           A.os_flag("journal", "enum", default="nature", values=["nature", "cell"], help="figure preset"),
           A.os_flag("strict", "bool", help="bare switch"),
           A.os_flag("label", "string", help="free label"),
           A.os_flag("input", "path", must_exist=True, help="input file"),
           A.os_flag("from-run", "path", must_exist=True, help="upstream run"),
           A.os_flag("layer", "string", requires="from-run", help="layer of the upstream object")],
    exclusive=[("input", "from-run")])
want_help = [
    "Usage: python run_x_y.py --outdir <dir> [options]",
    "Test module.",
    "Options:",
    "  --outdir <path>          required           output directory",
    "  --seed <int>             default: 20260925  random seed",
    "  --alpha <num in [0, 1]>  default: 0.05      FDR level",
    "  --journal <nature|cell>  default: nature    figure preset",
    "  --strict <switch>        default: off       bare switch",
    "  --label <string>         default: none      free label",
    "  --input <path>           default: none      input file",
    "  --from-run <path>        default: none      upstream run",
    "  --layer <string>         default: none      layer of the upstream object",
    "  --help <switch>          default: off       show this help and exit",
    "Mutually exclusive: --input, --from-run",
    "--layer requires --from-run",
]
got_help = A.os_help(SPEC)
check(got_help == want_help, "os_help layout == args.R layout" + ("" if got_help == want_help else "\n" + "\n".join(got_help)))
parsed = A.os_help_parse(got_help)
check([p["name"] for p in parsed] == list(SPEC.flags) and parsed[0]["required"] and parsed[1]["default"] == "20260925",
      "os_help_parse inverts os_help")
a = A.os_parse_args(SPEC, ["--outdir", str(TMP), "--alpha=0.1", "--strict"])
check(a["alpha"] == 0.1 and a["strict"] is True and a["seed"] == 20260925 and a["journal"] == "nature"
      and a["label"] is None and a.given == ("outdir", "alpha", "strict") and a["help"] is False, "parse: values and defaults")
check(A.os_parse_args(SPEC, ["--help", "--seed", "x"])["help"] is True, "--help short-circuits validation")
cases = [
    ("OS_UNKNOWN_FLAG", ["--outdir", "o", "--nope", "1"]),
    ("OS_UNKNOWN_FLAG", ["stray"]),
    ("OS_MISSING_PARAMETER", ["--seed", "1"]),
    ("OS_MISSING_PARAMETER", ["--outdir"]),
    ("OS_MISSING_PARAMETER", ["--outdir", "o", "--layer", "X"]),
    ("OS_INVALID_PARAMETER", ["--outdir", "o", "--seed", "1.5"]),
    ("OS_INVALID_PARAMETER", ["--outdir", "o", "--seed", "3000000000"]),
    ("OS_INVALID_PARAMETER", ["--outdir", "o", "--alpha", "2"]),
    ("OS_INVALID_PARAMETER", ["--outdir", "o", "--alpha", "inf"]),
    ("OS_INVALID_PARAMETER", ["--outdir", "o", "--journal", "lancet"]),
    ("OS_INVALID_PARAMETER", ["--outdir", "o", "--input", str(TMP / "absent.csv")]),
    ("OS_INVALID_PARAMETER", ["--outdir", "o", "--strict=yes"]),
    ("OS_CONFLICTING_PARAMETERS", ["--outdir", "o", "--seed", "1", "--seed", "2"]),
    ("OS_CONFLICTING_PARAMETERS", ["--outdir", "o", "--input", str(TMP), "--from-run", str(TMP)]),
]
for code, argv in cases:
    ok, msg = raises(code, A.os_parse_args, SPEC, argv)
    check(ok, "%s for %s (%s)" % (code, argv, msg))
ok, msg = raises("OS_INVALID_PARAMETER", A.os_parse_args, SPEC, ["--outdir", "o", "--alpha", "x"])
check(ok and "expected a finite number, got 'x'" in msg, "error text says expected ..., got '...'")
for bad in ([A.os_flag("a", "int", default=1.5)], [A.os_flag("a", "enum")], [A.os_flag("a", "bool", default=True)],
            [A.os_flag("a", "int", required=True, default=1)], [A.os_flag("a b", "int")],
            [A.os_flag("a", "string", default="x  y")], [A.os_flag("a", "num", range=(2, 1))]):
    ok, msg = raises("OS_INVALID_ARG_SPEC", A.os_arg_spec, "u", bad)
    check(ok, "OS_INVALID_ARG_SPEC: %s" % msg)
check(A.fmt_value(1e-8) == "0.00000001" and A.fmt_value(1e20) == "100000000000000000000" and A.fmt_value(1.0) == "1"
      and A.fmt_value(1 / 3) == "0.333333333333333" and A.fmt_value(None) == "none" and A.fmt_value(False) == "off",
      "fmt_value follows R format(x, digits = 15, scientific = FALSE)")
ok, msg = raises("OS_INVALID_PARAMETER", A.os_check_named_values, {"a": "#000000"}, ["a", "b"], "colours")
check(ok and "[x] a" in msg and "[ ] b" in msg, "os_check_named_values checklist")

# ---------------------------------------------------------------- spec replay / canonical argv
spec_file = TMP / "resolved_spec.json"
spec_file.write_text(json.dumps({"argv": ["--seed", "7", "--journal", "cell", "--strict"]}), encoding="utf-8")
check(K.spec_argv(["--spec", str(spec_file), "--seed", "9"]) == ["--journal", "cell", "--strict", "--seed", "9"],
      "spec_argv: command line wins over the replayed argv")
check(K.spec_argv(["--outdir", "o"]) == ["--outdir", "o"], "spec_argv: no --spec is a no-op")
ok, _m = raises("OS_INVALID_PARAMETER", K.spec_argv, ["--spec", str(TMP / "nope.json")])
check(ok, "spec_argv: missing file is OS_INVALID_PARAMETER")
check(K.canonical_argv(SPEC, a) == ["--seed", "20260925", "--alpha", "0.1", "--journal", "nature", "--strict"],
      "canonical_argv: resolved flags in spec order, switches only when on")

# ---------------------------------------------------------------- QC table
qc = K.qc_finalize([K.qc_rule("XX-02", "b", True, "warning", "m2", action="do"),
                    K.qc_rule("XX-01", "a", False, "blocker", "m1", action="never shown"),
                    K.qc_rule("XX-03", "c", True, "error", 'has "quote"')], read_first="draft/x.md")
check(qc["n_rules"] == 3 and qc["n_triggered"] == 2 and qc["worst"] == "XX-03" and qc["failed"]
      and not qc["blocking"] and qc["read_first"] == "qc/qc_results.csv", "qc_finalize summary")
K.write_qc_results(qc, str(TMP / "run"))
body = (TMP / "run" / "qc" / "qc_results.csv").read_bytes()
check(body.startswith(b'"id","check","severity","triggered","blocking","message","action","evidence"\n"XX-01","a","blocker","FALSE","FALSE","m1","",""\n')
      and b'"has ""quote"""' in body and b"\r" not in body, "qc_results.csv dialect (quoted, TRUE/FALSE, LF)")
check(K.closing_line(qc) == "2 of 3 rules triggered; read qc/qc_results.csv first", "closing line")
ok, _m = raises("OS_INVALID_PARAMETER", K.qc_rule, "X", "c", True, "fatal", "m")
check(ok, "unknown QC severity is refused")

# ---------------------------------------------------------------- run id
os.environ.pop("OMICSTAT_RUN_ID", None)
check(K.run_id(str(TMP / "abc-123") + os.sep) == "abc-123", "run_id: basename of the output directory")
os.environ["OMICSTAT_RUN_ID"] = "uuid-from-mcp"
check(K.run_id("/ws") == "uuid-from-mcp", "run_id: OMICSTAT_RUN_ID wins (container outdir is /ws)")
os.environ.pop("OMICSTAT_RUN_ID", None)

# ---------------------------------------------------------------- templates
tpl = TMP / "reporting-templates.md"
tpl.write_text("x\n```template methods\nRan {tool} v{version}.\n```\n", encoding="utf-8")
t = K.read_templates(str(tpl))
check(K.fill_template(t["methods"], {"tool": "scanpy", "version": "1.12.4"}) == "Ran scanpy v1.12.4.", "template fill")
ok, _m = raises("OS_TEMPLATE_SLOT_MISSING", K.fill_template, t["methods"], {"tool": "x"})
check(ok, "missing template slot is typed")

# ---------------------------------------------------------------- engine_run
elog = engine_run.EngineLog(str(TMP / "run"))
err = io.StringIO()
with redirect_stderr(err):
    def stage_fn():
        warnings.warn("first thing", UserWarning)
        warnings.warn("first thing", UserWarning)          # repeats are kept ("always")
        import logging
        logging.getLogger("scanpy").warning("a scanpy message")
        return 42
    r = elog.capture("compute", stage_fn)
check(r == 42 and elog.counts()["warning"] == 2 and elog.counts()["message"] >= 1, "warnings and messages recorded")
check("OS_ENGINE_WARNING: [compute] UserWarning: first thing" in err.getvalue(), "warning echoed as OS_ENGINE_WARNING")
try:
    with redirect_stderr(io.StringIO()):
        elog.capture("render", lambda: (_ for _ in ()).throw(ValueError("boom")))
    check(False, "an error propagates")
except ValueError as exc:
    check(str(exc) == "boom", "an error propagates unchanged")
csv_text = (TMP / "run" / "qc" / "engine_warnings.csv").read_text(encoding="utf-8")
check(csv_text.startswith('"stage","type","message"\n') and '"render","error","ValueError: boom"' in csv_text,
      "engine_warnings.csv records the error and is flushed")
e2 = engine_run.EngineLog(str(TMP / "run2"))
e2.capture("compute", lambda: 1)
check((TMP / "run2" / "qc" / "engine_warnings.csv").read_text(encoding="utf-8") == '"stage","type","message"\n',
      "no conditions -> header only")

# ---------------------------------------------------------------- feature table
rows = [{"feature_id": "ENSG00000000003.14", "contrast": "b", "log2fc": 1.5, "pvalue": 0.001, "padj": 0.01,
         "method": "m", "n_group1": 3, "n_group2": 3},
        {"feature_id": "G2", "contrast": "a", "log2fc": -2.0, "pvalue": 0.5, "padj": None, "method": "m",
         "n_group1": 3, "n_group2": 3, "filtered_reason": "low_count"},
        {"feature_id": "G1", "contrast": "a", "log2fc": 1e-12, "pvalue": 0.02, "padj": 0.04, "method": "m",
         "n_group1": 3, "n_group2": 3, "symbol": 'S"1'},
        {"feature_id": "G3", "contrast": "a", "log2fc": float("inf"), "pvalue": 0.5, "padj": 0.9, "method": "m",
         "n_group1": 3, "n_group2": 3}]
ft = FT.as_feature_table(rows)
check([r["feature_id"] for r in ft] == ["G1", "G3", "G2", "ENSG00000000003"], "canonical order; Ensembl version stripped")
v = FT.validate_feature_table(ft)
check(v["ok"] and any("non-finite" in w for w in v["warnings"]), "validation: ok with a non-finite warning")
bad = FT.validate_feature_table([dict(ft[0], pvalue=1.5), ft[1]])
check(not bad["ok"] and any("pvalue outside" in e for e in bad["errors"]), "pvalue outside [0, 1] is an error")
dup = FT.validate_feature_table([ft[0], ft[0]])
check(not dup["ok"], "duplicated feature within a contrast is an error")
with warnings.catch_warnings():
    warnings.simplefilter("ignore")
    FT.write_feature_table(ft, str(TMP / "ft.csv"))
    FT.write_feature_table(FT.as_feature_table(rows), str(TMP / "ft2.csv"))
b = (TMP / "ft.csv").read_bytes()
check(b == (TMP / "ft2.csv").read_bytes(), "feature table bytes are reproducible")
check(b.split(b"\n")[1] == b'"G1","S""1","a","NA","      1e-12","NA","NA","       0.02","       0.04","m","",3,3,NA'
      and b'"        Inf"' in b and b',"NA",' in b, "R write.csv dialect of formatC(digits = 10, 'g') cells")
check(FT.format_g10(123456.789012345) == " 123456.789" and FT.format_g10(1e-300) == "     1e-300"
      and FT.format_g10(5.682149994e-07) == "5.682149994e-07" and FT.format_g10(None) == "NA", "format_g10 (formatC width 11)")
ok, _m = raises("OS_SCHEMA_INVALID", FT.write_feature_table, [{"feature_id": "x"}], str(TMP / "bad.csv"))
check(ok, "writing an invalid table is OS_SCHEMA_INVALID")

# ---------------------------------------------------------------- handoff
up = TMP / "up"
(up / "objects").mkdir(parents=True)
(up / "objects" / "adata.h5ad").write_bytes(b"h5ad bytes")
(up / "tables").mkdir()
shutil.copy(TMP / "ft.csv", up / "tables" / "feature_table.csv")
H.write_handoff(str(up), "run-1", "scanpy-qc", "0.1.0",
                {"adata": {"path": str(up / "objects" / "adata.h5ad"), "type": "AnnData"},
                 "feature_table": {"path": str(up / "tables" / "feature_table.csv"), "type": "feature_table"}},
                contract_hash="abc", ecosystem="scverse", state={"z": 1, "a": "x"}, upstream_runs=["run-0"])
doc = json.loads((up / "objects" / "handoff.json").read_text(encoding="utf-8"))
check(doc["upstream_runs"] == ["run-0", "run-1"] and doc["ecosystem"] == "scverse" and list(doc["state"]) == ["a", "z"]
      and [o["name"] for o in doc["objects"]] == ["adata", "feature_table"] and doc["objects"][0]["path"] == "objects/adata.h5ad",
      "write_handoff document")
hr = H.read_handoff(str(up), expect={"adata": "AnnData"}, front_end_ecosystem="scverse", contract_hash="abc")
check(hr["objects"]["adata"]["type"] == "AnnData" and hr["upstream_runs"][-1] == "run-1", "read_handoff verifies and describes")
ok, _m = raises("OS_ECOSYSTEM_MIXED", H.read_handoff, str(up), front_end_ecosystem="seurat")
check(ok, "front-end ecosystem mixing is refused")
ok, _m = raises("OS_CONTRACT_MISMATCH", H.read_handoff, str(up), contract_hash="other")
check(ok, "contract mismatch is refused")
ok, _m = raises("OS_HANDOFF_MISMATCH", H.read_handoff, str(up), expect={"adata": "Seurat"})
check(ok, "type mismatch is refused")
ok, _m = raises("OS_HANDOFF_MISMATCH", H.read_handoff, str(up), expect={"absent": "AnnData"})
check(ok, "missing object is refused")
ok, _m = raises("OS_HANDOFF_MISSING", H.read_handoff, str(TMP))
check(ok, "no handoff.json is OS_HANDOFF_MISSING")
ok, _m = raises("OS_INVALID_PARAMETER", H.write_handoff, str(up), "r", "m", "v",
                {"x": {"path": str(TMP / "ft.csv"), "type": "feature_table"}})
check(ok, "an object outside the run directory is refused")
ok, _m = raises("OS_INVALID_PARAMETER", H.write_handoff, str(up), "r", "m", "v",
                {"x": {"path": str(up / "tables" / "feature_table.csv"), "type": "AnnData"}})
check(ok, "AnnData must be an .h5ad file")
ok, _m = raises("OS_INVALID_PARAMETER", H.write_handoff, str(up), "r", "m", "v", {}, ecosystem="python")
check(ok, "unknown ecosystem is refused")
bc = TMP / "bc"
(bc / "objects").mkdir(parents=True)
(bc / "objects" / "m.csv").write_text("x\n", encoding="utf-8")
H.write_handoff(str(bc), "run-bc", "sva-batch", "1", {"matrix": {"path": str(bc / "objects" / "m.csv"), "type": "batch_corrected_matrix"}})
ok, _m = raises("OS_BATCH_CORRECTED_INPUT", H.read_handoff, str(bc), expect={"matrix": "count_matrix"})
check(ok, "batch-corrected matrix requested as counts is OS_BATCH_CORRECTED_INPUT")
(up / "objects" / "adata.h5ad").write_bytes(b"changed")
ok, _m = raises("OS_HANDOFF_MISMATCH", H.read_handoff, str(up))
check(ok, "a changed object file fails the sha256 check")

# ---------------------------------------------------------------- figure request
run = TMP / "figrun"
req = FR.FigureRequest(str(run), module="m", module_version="0.1.0", journal="nature")
req.add("emb", "os_embedding",
        data={"emb": FR.frame({"cell": ["c1", "c2"], "x": [0.1, 1 / 3], "y": [1, 2], "cluster": ["b", "a"]},
                              types={"cluster": "factor"}, levels={"cluster": ["b", "a"]})},
        args={"group_col": "cluster", "reduction": "UMAP"})
req.add("vec", "os_ridge", data={"values": FR.vector([1.5, None]), "groups": FR.vector(["g1", "g2"])},
        args={"feature": "GENE"}, width=89, formats=("png",))
req.add("mat", "os_heatmap", data={"mat": FR.matrix([[1, 2], [3, float("nan")]], ["r1", "r2"], ["s1", "s2"])},
        args={"value_title": "z"})
path = req.write()
rq = json.loads(pathlib.Path(path).read_text(encoding="utf-8"))
check(rq["schema"] == "omicstat.figure-request.v1" and [f["id"] for f in rq["figures"]] == ["emb", "vec", "mat"],
      "figure_request.json written")
emb_csv = (run / "figure_data" / "emb__emb.csv").read_text(encoding="utf-8")
check(emb_csv == '"cell","x","y","cluster"\n"c1",0.10000000000000001,1,"b"\n"c2",0.33333333333333331,2,"a"\n',
      "frame CSV: quoted characters, 17-digit numbers, integers plain")
check(rq["figures"][0]["data"]["emb"]["columns"][3] == {"name": "cluster", "type": "factor", "levels": ["b", "a"]},
      "factor levels travel in the request")
check((run / "figure_data" / "vec__values.csv").read_text(encoding="utf-8") == '"value"\n1.5\nNA\n', "vector CSV with NA")
check((run / "figure_data" / "mat__mat.csv").read_text(encoding="utf-8") == '"row_id","s1","s2"\n"r1",1,2\n"r2",3,NA\n',
      "matrix CSV with row ids")
check(FR.validate_request(str(run)) == [], "validate_request: files and sha256 agree")
(run / "figure_data" / "vec__values.csv").write_text('"value"\n9\n9\n', encoding="utf-8")
check(any("sha256" in p for p in FR.validate_request(str(run))), "validate_request catches a changed data file")
for bad_call in (lambda: req.add("emb", "os_embedding", data={}),
                 lambda: req.add("x", "ggplot", data={}),
                 lambda: req.add("y", "os_volcano", data={}, out_stem="../escape"),
                 lambda: req.add("z", "os_volcano", data={"ft": [1]}),
                 lambda: FR.frame({"a": [1, 2], "b": [1]}),
                 lambda: FR.frame({"a": ["x"]}, types={"a": "factor"}, levels={"a": ["y"]})):
    ok, msg = raises("OS_INVALID_PARAMETER", bad_call)
    check(ok, "figure request refuses: %s" % msg)

# ---------------------------------------------------------------- seed
rec = S.set_seed(123)
check(rec["seed"] == 123 and rec["python_random"] is True, "set_seed record")
import random                                                   # noqa: E402
S.set_seed(5)
r1 = random.random()
S.set_seed(5)
check(random.random() == r1, "set_seed makes random reproducible")
if rec.get("torch_manual_seed") is True:
    check(rec["torch_deterministic_algorithms"] is True and rec["torch_num_threads"] == 1, "torch deterministic, 1 thread")
else:
    SKIPS.append("torch parts of set_seed (torch not installed)")
if rec.get("scvi_settings_seed") == 123:
    check(True, "scvi.settings.seed set")
else:
    SKIPS.append("scvi parts of set_seed (scvi-tools not installed)")
try:
    S.set_seed("1")
    check(False, "a non-int seed is refused")
except TypeError:
    check(True, "a non-int seed is refused")

# ---------------------------------------------------------------- run_entry exit codes
prog = ("import sys; sys.path.insert(0, %r)\nfrom ospy.errors import run_entry, os_error\n"
        "def main(argv):\n    if argv[0] == 'typed': raise os_error('OS_INVALID_INPUT', 'bad input')\n"
        "    if argv[0] == 'crash': raise RuntimeError('boom')\n    return 0\nrun_entry(main)\n") % str(HERE.parent)
res = {k: subprocess.run([sys.executable, "-c", prog, k], capture_output=True, text=True) for k in ("typed", "crash", "ok")}
check(res["typed"].returncode == 1 and res["typed"].stderr.strip() == "OS_INVALID_INPUT: bad input", "typed error -> exit 1, message only")
check(res["crash"].returncode == 1 and "Traceback" in res["crash"].stderr and "RuntimeError: boom" in res["crash"].stderr,
      "untyped error -> exit 1 with traceback")
check(res["ok"].returncode == 0, "normal return -> exit 0")
check(str(os_error("OS_X", "y")) == "OS_X: y", "os_error message format")

# Native JSON/Boolean CLI conversion rejects malformed structured options.
from ospy import native_options as N
converted = N.resolve({'bool': 'none', 'obj': '{"lr":0.002}', 'keys': '["batch"]', 'groups': '["0","1"]'},
                      {'bool': 'boolean', 'obj': 'object', 'keys': 'list', 'groups': 'groups'})
check(converted == {'bool': None, 'obj': {'lr': 0.002}, 'keys': ['batch'], 'groups': ['0', '1']},
      'native options retain actual Boolean and structured JSON values')
for kind, value in [('object', '[]'), ('list', '{}'), ('list', '[1]'), ('groups', '[]'), ('object', '{bad}')]:
    try:
        N.resolve({'x': value}, {'x': kind})
        check(False, 'invalid native option must raise typed error')
    except OmicstatError as exc:
        check('OS_INVALID_PARAMETER' in str(exc), 'invalid native option raises OS_INVALID_PARAMETER')

shutil.rmtree(TMP, ignore_errors=True)
for s in SKIPS:
    print("SKIP:", s)
print("== ospy: %s (%d skipped)" % ("ALL PASSED" if not FAILS else "%d FAILED" % len(FAILS), len(SKIPS)))
sys.exit(1 if FAILS else 0)

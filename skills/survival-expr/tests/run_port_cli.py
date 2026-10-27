"""Real R CLI/replay/refusal evidence runner. No engine double or alternate method.

Requires a new empty output path and the locked OmicStat R environment. A missing
Rscript exits127 before making that directory. Inputs are invented seed9182 only.
"""
from __future__ import annotations
import argparse
import csv
import hashlib
import json
import pathlib
import shutil
import subprocess
import sys

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[2]
ENTRY = ROOT / "skills/survival-expr/scripts/run_survival_expr.R"
sys.path.insert(0, str(HERE))
from prepare_port_fixture import extend_generated_fixture
from port_oracle import aalen_johansen


def replace(argv, key, value):
    argv = list(argv)
    if key in argv:
        i = argv.index(key)
        if value is None: del argv[i:i+2]
        else: argv[i+1] = str(value)
    elif value is not None:
        argv.extend([key, str(value)])
    return argv


def scenarios():
    legacy = json.loads((HERE / "acceptance.json").read_text())["canonical"]["argv"]
    # Explicit, fixed test times avoid unverified extrapolation on any branch.
    legacy = replace(legacy, "--risk-times", "0,50,100")
    nonph = legacy + ["--survival-extension", "nonph", "--dataset-name", "Project-generated seed9182 contract",
                     "--nonph-primary", "cox", "--nonph-transforms", "km,rank,identity,log", "--nonph-magnitude", ".2"]
    piecewise = replace(nonph, "--nonph-primary", "piecewise") + ["--piecewise-cuts", "50,100", "--piecewise-gene", "SIM_SIGNAL",
                    "--piecewise-fit", "source-native", "--piecewise-adjust", "holm", "--piecewise-family-size", "3"]
    competing = replace(legacy, "--clinical", "{fixtures}/competing.csv")
    competing = replace(competing, "--covariates", "none")
    competing += ["--survival-extension", "competing-risks", "--dataset-name", "Project-generated seed9182 contract",
                  "--competing-status-col", "cause", "--event-of-interest", "1", "--cif-estimator", "aalen-johansen", "--cif-interval", "none"]
    return {"legacy": legacy, "nonph": nonph, "piecewise": piecewise, "competing": competing}


def refusal_cases():
    s = scenarios(); n, p, c = s["nonph"], s["piecewise"], s["competing"]
    cases = [
        ("port-inactive", s["legacy"] + ["--dataset-name", "Invented"], "OS_INVALID_PARAMETER"),
        ("port-no-dataset", replace(n, "--dataset-name", None), "OS_MISSING_PARAMETER"),
        ("port-no-magnitude", replace(n, "--nonph-magnitude", None), "OS_MISSING_PARAMETER"),
        ("port-automatic-selection", replace(n, "--nonph-primary", "automatic"), "OS_INVALID_PARAMETER"),
        ("port-duplicate-transforms", replace(n, "--nonph-transforms", "km,km"), "OS_INVALID_PARAMETER"),
        ("port-primary-transform-absent", replace(n, "--nonph-transforms", "rank,identity"), "OS_INVALID_PARAMETER"),
        ("port-piecewise-inactive", n + ["--piecewise-cuts", "50,100"], "OS_INVALID_PARAMETER"),
        ("port-piecewise-no-policy", replace(p, "--piecewise-fit", None), "OS_MISSING_PARAMETER"),
        ("port-cuts-unsorted", replace(p, "--piecewise-cuts", "100,50"), "OS_INVALID_PARAMETER"),
        ("port-cuts-duplicate", replace(p, "--piecewise-cuts", "50,50"), "OS_INVALID_PARAMETER"),
        ("port-cuts-zero", replace(p, "--piecewise-cuts", "0,100"), "OS_INVALID_PARAMETER"),
        ("port-cuts-budget", replace(p, "--piecewise-cuts", ",".join(map(str, range(1, 12)))), "OS_INVALID_PARAMETER"),
        ("port-period-family", replace(p, "--piecewise-family-size", "2"), "OS_INVALID_PARAMETER"),
        ("port-gene-outside-prespecified", replace(p, "--piecewise-gene", "SIM2"), "OS_INVALID_PARAMETER"),
        ("port-no-status", replace(c, "--competing-status-col", None), "OS_MISSING_PARAMETER"),
        ("port-status-alias", replace(c, "--competing-status-col", "event"), "OS_INVALID_DESIGN"),
        ("port-status-mismatch", replace(c, "--clinical", "{fixtures}/competing-mismatch.csv"), "OS_INVALID_DESIGN"),
        ("port-status-gap", replace(c, "--clinical", "{fixtures}/competing-gap.csv"), "OS_INVALID_INPUT"),
        ("port-status-fraction", replace(c, "--clinical", "{fixtures}/competing-fractional.csv"), "OS_INVALID_INPUT"),
        ("port-status-missing", replace(c, "--clinical", "{fixtures}/competing-missing.csv"), "OS_INVALID_INPUT"),
        ("port-cause-budget", replace(c, "--clinical", "{fixtures}/competing-too-many-causes.csv"), "OS_RESOURCE_LIMIT"),
        ("port-forbidden-km", replace(c, "--cif-estimator", "one_minus_km"), "OS_INVALID_PARAMETER"),
        ("port-unavailable-ci", replace(c, "--cif-interval", "wald"), "OS_INVALID_PARAMETER"),
        ("port-unavailable-adjusted-cif", replace(c, "--covariates", "covar1"), "OS_INVALID_PARAMETER"),
        ("port-cif-optimized-cut", replace(c, "--cutoff", "optimal") + ["--exploratory", "--min-group-fraction", ".2"], "OS_INVALID_PARAMETER"),
        ("port-foreign-branch", c + ["--nonph-primary", "cox"], "OS_INVALID_PARAMETER"),
        ("port-risk-extrapolation", replace(c, "--risk-times", "0,1000000"), "OS_INVALID_PARAMETER"),
    ]
    return cases


def table_bytes(run):
    return {p.relative_to(run / "tables").as_posix(): p.read_bytes() for p in sorted((run / "tables").glob("*.csv"))}


def check_aggregate_cif(fixtures, run):
    with (fixtures / "competing.csv").open(newline="") as stream: rows = list(csv.DictReader(stream))
    with (fixtures / "expression.csv").open(newline="") as stream:
        reader = csv.reader(stream); header = next(reader); signal = next(reader)
    values = {unit: float(x) for unit, x in zip(header[1:], signal[1:])}
    ordered = sorted(values.values()); cut = (ordered[79] + ordered[80]) / 2
    with (run / "tables/cif_timepoints.csv").open(newline="") as stream: observed = list(csv.DictReader(stream))
    errors = []
    for row in observed:
        selected = [v for v in rows if (values[v["unit"]] <= cut) == (row["group"] == "low")]
        expected = aalen_johansen([float(v["time"]) for v in selected], [int(v["cause"]) for v in selected],
                                  [float(row["time"])], int(row["code"]))[0]
        errors.append(abs(float(row["cif"]) - float(expected)))
    if not errors or max(errors) > 1e-12:
        raise AssertionError("native exported AJ table disagrees with independent invented risk-set arithmetic")
    return max(errors)


def run(output):
    rscript = shutil.which("Rscript")
    if not rscript:
        print("BLOCKED: Rscript is absent; native R4.6.1/survival3.8-9, CLI, replay, refusals and figures were not run", file=sys.stderr)
        return 127
    output = pathlib.Path(output).resolve()
    if output.exists(): raise ValueError("use a new evidence directory; prior failures must remain intact")
    # Validate runtime and copied source checks before making a run directory.
    probe = subprocess.run([rscript, str(HERE / "run_port_smoke.R")], cwd=ROOT, text=True, capture_output=True)
    print(probe.stdout, end=""); print(probe.stderr, end="", file=sys.stderr)
    if probe.returncode: return probe.returncode
    output.mkdir(parents=True); (output / "native-source-parity.log").write_text(probe.stdout + probe.stderr)
    fixtures = output / "fixtures"
    def execute(label, argv, expect=0, code=None):
        result = subprocess.run(argv, cwd=ROOT, text=True, capture_output=True)
        (output / (label + ".log")).write_text(result.stdout + result.stderr)
        if (code is None and result.returncode != expect) or (code is not None and (result.returncode == 0 or code not in result.stdout + result.stderr)):
            raise RuntimeError(f"{label} failed its exact expectation; see retained log")
        return result
    execute("prepare", [sys.executable, str(HERE / "prepare_acceptance.py"), str(fixtures)])
    extend_generated_fixture(fixtures)
    execute("inherited-smoke", [rscript, str(HERE / "run_smoke_test.R")])
    def args(values, target): return [v.replace("{fixtures}", str(fixtures)).replace("{outdir}", str(target)) for v in values]
    tables = {}
    for name, argv in scenarios().items():
        target = output / name
        execute(name, [rscript, str(ENTRY), *args(argv, target)])
        before = table_bytes(target)
        if not before: raise AssertionError("canonical run emitted no tables")
        replay = output / (name + "-replay")
        execute(name + "-replay", [rscript, str(ENTRY), "--spec", str(target / "provenance/resolved_spec.json"), "--outdir", str(replay)])
        if before != table_bytes(replay): raise AssertionError(name + " replay changed numerical CSV bytes")
        specs = list((target / "figures").glob("*.figure_spec.json"))
        if not specs: raise AssertionError(name + " produced no figure specs")
        for path in specs:
            spec = json.loads(path.read_text())
            if name != "legacy" and "Project-generated seed9182 contract" not in spec["caption"]:
                raise AssertionError("every extension figure must carry its actual invented dataset label")
        tables[name] = {k: hashlib.sha256(v).hexdigest() for k, v in before.items()}
    for name in ("nonph", "piecewise"):
        for key, value in table_bytes(output / "legacy").items():
            if table_bytes(output / name).get(key) != value:
                raise AssertionError("optional diagnostics altered original scientific table: " + key)
    # Execute every old refusal and every new branch refusal without relaxing codes.
    with (HERE / "refusals.csv").open(newline="") as stream: old = list(csv.DictReader(stream))
    for row in old:
        execute("refusal-" + row["case"], [rscript, str(ENTRY), *args(json.loads(row["argv"]), output / ("refused-" + row["case"]))], code=row["expected_code"])
    error = check_aggregate_cif(fixtures, output / "competing")
    report = {"schema": "omicstat.survival-port-native-contract.v1", "native_executed": True,
              "copied_source_native_same_input_checks_passed": True,
              "same_input_legacy_tables_unchanged": True, "resolved_replays_exact_csv_bytes": True,
              "cif_independent_max_error": error, "refusal_count": len(old), "tables": tables,
              "real_owner_anchor_passed": False, "owner_visual_review": None,
              "historical_clinical_rows_acquired": False, "synthetic_contract_only": True}
    (output / "RESULT.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2)); return 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser(); parser.add_argument("--out", required=True)
    raise SystemExit(run(parser.parse_args().out))

"""Actual native entry/replay/refusal/figure contract, not a Python numerical substitute."""
import argparse
import csv
import hashlib
import json
import os
import pathlib
import shutil
import subprocess
import sys

from prepare_distribution_fixture import prepare

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[2]
ENTRY = HERE.parent / "scripts/run_omicstat_groupcompare.R"


def base_argv(fixtures):
    return ["--input", str(fixtures / "distribution.csv"), "--response-col", "value", "--group-col", "group", "--unit-col", "ID",
            "--group-order", "A,B", "--design", "independent", "--technical-policy", "reject", "--pairwise-test", "none",
            "--omnibus", "none", "--rank-method", "not-applicable", "--adjust", "none", "--family-size", "1", "--ci-level", ".95",
            "--display", "interval", "--journal", "nature", "--study-contract", str(fixtures / "contract.json"),
            "--analysis-mode", "distribution-effects", "--reference-group", "A", "--quantile-grid", ".1,.5,.9",
            "--min-cell-n", "10", "--outcome-unit", "synthetic measurement units", "--inference", "none",
            "--dataset-name", "SYNTHETIC source contract only", "--development-mode", "--seed", "104729"]


def changed(argv, flag, value):
    argv = list(argv)
    if flag in argv:
        i = argv.index(flag)
        argv[i:i + 2] = [] if value is None else [flag, str(value)]
    elif value is not None:
        argv += [flag, str(value)]
    return argv


def run(evidence):
    rscript = shutil.which("Rscript")
    if rscript is None:
        raise RuntimeError("OS_DEPENDENCY_MISSING: Rscript is unavailable; native CLI and figures were not executed")
    version = subprocess.run([rscript, "-e", 'cat(as.character(getRversion()))'], capture_output=True, text=True, check=True)
    if version.stdout.strip() != "4.6.1":
        raise RuntimeError("OS_ENV_R_VERSION: exact independent R4.6.1 lineage required")
    out = pathlib.Path(evidence)
    if out.is_symlink() or (out.exists() and (not out.is_dir() or any(out.iterdir()))):
        raise FileExistsError("fresh empty evidence directory required; earlier failed runs cannot be reused")
    out.mkdir(parents=True, exist_ok=True)
    fixtures = out / "fixtures"; prepare(fixtures)
    records = []

    def invoke(label, argv, expected=None):
        destination = out / label
        cmd = [rscript, str(ENTRY)] + argv + ["--outdir", str(destination)]
        log = out / (label + ".log")
        with log.open("w") as stream:
            p = subprocess.run(cmd, stdout=stream, stderr=subprocess.STDOUT)
        body = log.read_text()
        passed = p.returncode == 0 if expected is None else p.returncode != 0 and expected in body
        records.append({"label": label, "command": cmd, "returncode": p.returncode, "expected_code": expected,
                        "passed": passed, "log_sha256": hashlib.sha256(log.read_bytes()).hexdigest()})
        (out / "COMMANDS.json").write_text(json.dumps(records, indent=2) + "\n")
        if not passed:
            raise RuntimeError("Native case failed; preserve evidence: " + label)
        return destination

    base = base_argv(fixtures)
    canonical = invoke("canonical", base)
    replay = invoke("replay", ["--spec", str(canonical / "provenance/resolved_spec.json")])
    for name in ["distribution_metrics.csv", "effect_table.csv", "distribution_guardrails.csv"]:
        if (canonical / "tables" / name).read_bytes() != (replay / "tables" / name).read_bytes():
            raise AssertionError("exact replay table drift: " + name)
    boot = changed(changed(changed(base, "--inference", "iid_stratified_bootstrap"), "--bootstrap-replicates", 200), "--min-success-fraction", .95)
    bootstrap = invoke("bootstrap", boot)
    reordered = invoke("reordered", changed(boot, "--input", fixtures / "reordered.csv"))
    if (bootstrap / "tables/distribution_metrics.csv").read_bytes() != (reordered / "tables/distribution_metrics.csv").read_bytes():
        raise AssertionError("seeded bootstrap changed under row permutation")
    for label in ["small", "empty", "wholly_suppressed", "constant"]:
        invoke(label, changed(boot if label == "constant" else base, "--input", fixtures / (label + ".csv")))
    cases = list(csv.DictReader((HERE / "distribution_refusals.csv").read_text().splitlines()))
    for row in cases:
        argv = [x.replace("{fixtures}", str(fixtures)) for x in json.loads(row["argv"])]
        invoke("refusal_" + row["case"], argv, row["expected_code"])
    # Scope is genuine render/replay contract using invented measurements only.
    # These files must never populate an owner-review dataset receipt/contact sheet.
    figure_specs = sorted((bootstrap / "figures").glob("*.figure_spec.json"))
    if not figure_specs:
        figure_specs = sorted((bootstrap / "figures").glob("*.spec.json"))
    if not figure_specs:
        raise AssertionError("native source branch produced no figure specs")
    sys.path.insert(0, str(ROOT / "tools"))
    from acceptance.figures import inspect_figures
    figures = inspect_figures(bootstrap)
    if not figures or any(not row["lint"]["ok"] for row in figures):
        raise AssertionError("actual native PNG/spec hashes or plot lint failed")
    for row in figures:
        spec = json.loads((bootstrap / row["spec"]).read_text())
        if "Dataset: SYNTHETIC source contract only" not in spec["caption"]:
            raise AssertionError("per-figure synthetic dataset label absent")
    suppressed = out / "wholly_suppressed"
    statuses = list(csv.DictReader((suppressed / "tables/distribution_figure_status.csv").read_text().splitlines()))
    if not statuses or any(row["state"] != "withheld_no_released_effect" for row in statuses) or list((suppressed / "figures").glob("*.png")):
        raise AssertionError("wholly suppressed source must retain status rows without invented figures")
    for p in [*(bootstrap / "tables").glob("*.csv"), *figure_specs]:
        if "synthetic_" in p.read_text():
            raise AssertionError("row identifier leaked into aggregate/figure source: " + str(p))
    result = {"R": version.stdout.strip(), "native_commands": records, "synthetic_contract_only": True,
              "owner_review_completed": False, "figure_inspection": figures, "figure_specs": [str(x.relative_to(out)) for x in figure_specs]}
    (out / "NATIVE_CLI.json").write_text(json.dumps(result, indent=2) + "\n")
    return result


if __name__ == "__main__":
    ap = argparse.ArgumentParser(); ap.add_argument("--outdir", required=True)
    args = ap.parse_args()
    run(args.outdir)

"""Genuine R4.6.1 entry, serialized chain, replay, refusals and figures."""
import argparse
import csv
import hashlib
import json
import pathlib
import shutil
import subprocess
import sys

from prepare_longitudinal_fixture import prepare

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[2]
ENTRY = HERE.parent / "scripts/run_emmeans_contrast.R"
LMM = ROOT / "skills/lme4-lmm/scripts/run_lme4_lmm.R"


def changed(argv, flag, value):
    result = list(argv)
    if flag in result:
        i = result.index(flag)
        result[i:i + 2] = [] if value is None else [flag, str(value)]
    elif value is not None:
        result.extend([flag, str(value)])
    return result


def base_argv(fixtures, upstream):
    return ["--from-run", str(upstream), "--factor", "grp", "--by", "visit", "--longitudinal",
            "--time-levels", "visit1,visit2,visit3", "--dataset-name", "SYNTHETIC LONG-balanced-cells contract only",
            "--weights", "equal", "--df-method", "kenward-roger", "--adjust", "holm", "--ci-level", ".95",
            "--study-contract", str(fixtures / "contract.json"), "--development-mode", "--seed", "151"]


def run(destination):
    rscript = shutil.which("Rscript")
    if not rscript:
        raise RuntimeError("OS_DEPENDENCY_MISSING: Rscript absent; no native or figure pass")
    version = subprocess.run([rscript, "-e", "cat(as.character(getRversion()))"], capture_output=True, text=True, check=True)
    if version.stdout.strip() != "4.6.1":
        raise RuntimeError("OS_ENV_R_VERSION: exact independent OmicStat R4.6.1 required")
    out = pathlib.Path(destination)
    if out.is_symlink() or (out.exists() and (not out.is_dir() or any(out.iterdir()))):
        raise FileExistsError("fresh empty evidence required; failed directories must remain intact")
    out.mkdir(parents=True, exist_ok=True)
    fixtures = out / "fixtures"
    prepare(fixtures, rscript)
    records = []

    def invoke(label, argv, entry=ENTRY, expected=None):
        target = out / label
        command = [rscript, str(entry), *argv, "--outdir", str(target)]
        log = out / (label + ".log")
        with log.open("w") as stream:
            result = subprocess.run(command, stdout=stream, stderr=subprocess.STDOUT)
        body = log.read_text()
        passed = result.returncode == 0 if expected is None else result.returncode != 0 and expected + ":" in body
        records.append({"label": label, "command": command, "returncode": result.returncode,
                        "expected_code": expected, "passed": passed, "log_sha256": hashlib.sha256(log.read_bytes()).hexdigest()})
        (out / "COMMANDS.json").write_text(json.dumps(records, indent=2) + "\n")
        if not passed:
            raise RuntimeError("Native case failed; preserve original log: " + label)
        return target

    upstream = invoke("upstream", ["--input", str(fixtures / "longitudinal.csv"), "--response", "y", "--subject", "id",
        "--formula", "y ~ grp * visit + (1 | id)", "--estimation", "REML", "--singular-tolerance", ".0001",
        "--ci-level", ".95", "--study-contract", str(fixtures / "contract.json"), "--development-mode", "--seed", "151"], LMM)
    base = base_argv(fixtures, upstream)
    canonical = invoke("canonical", base)
    replay = invoke("replay", ["--spec", str(canonical / "provenance/resolved_spec.json")])
    table_names = [p.name for p in (canonical / "tables").glob("*.csv")]
    if not {"joint_tests_native.csv", "interaction_tests.csv", "contrasts_unadjusted.csv", "contrasts_adjusted.csv",
            "longitudinal_emm_draw_data.csv"}.issubset(table_names):
        raise AssertionError("new longitudinal tables absent")
    for name in table_names:
        if (canonical / "tables" / name).read_bytes() != (replay / "tables" / name).read_bytes():
            raise AssertionError("same-input replay table drift: " + name)
    sat = invoke("satterthwaite", changed(base, "--df-method", "satterthwaite"))
    # No upstream refit or method substitution for the second explicit df method.
    for row in csv.DictReader((HERE / "longitudinal_refusals.csv").read_text().splitlines()):
        argv = [x.replace("{fixtures}", str(fixtures)).replace("{upstream}", str(upstream)) for x in json.loads(row["argv"])]
        invoke("refusal_" + row["case"], argv, expected=row["expected_code"])
    sys.path.insert(0, str(ROOT / "tools"))
    from acceptance.figures import inspect_figures
    figure_records = {}
    for label, location in [("kenward_roger", canonical), ("satterthwaite", sat)]:
        figures = inspect_figures(location)
        if len(figures) < 2 or any(not item["lint"]["ok"] for item in figures):
            raise AssertionError("actual longitudinal PNG/spec inspection failed")
        for item in figures:
            spec = json.loads((location / item["spec"]).read_text())
            if "Dataset: SYNTHETIC LONG-balanced-cells contract only" not in spec["caption"]:
                raise AssertionError("every new figure must name its synthetic dataset")
        figure_records[label] = figures
    result = {"R": version.stdout.strip(), "commands": records, "figure_inspection": figure_records,
              "replayed_tables": sorted(table_names), "synthetic_contract_only": True, "owner_review_passed": False}
    (out / "NATIVE_CLI.json").write_text(json.dumps(result, indent=2) + "\n")
    return result


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--outdir", required=True)
    run(ap.parse_args().outdir)

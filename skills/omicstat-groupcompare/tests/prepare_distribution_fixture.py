"""Locally invented contracts only; never an owner-review or real-data receipt."""
import csv
import hashlib
import io
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "mcp"))
from study_contract import build_contract, contract_bytes


def csv_bytes(rows):
    stream = io.StringIO(newline="")
    writer = csv.writer(stream, lineterminator="\n")
    writer.writerows(rows)
    return stream.getvalue().encode()


def payloads():
    rows = [[f"synthetic_{i:04d}", "A" if i <= 200 else "B", i if i <= 200 else i - 198]
            for i in range(1, 401)]
    header = ["ID", "group", "value"]
    contract = build_contract(
        design="Synthetic independent biological-unit distribution contract",
        biological_unit="One invented independent ID, technical repeats do not increase n",
        population="400 invented units, 200 per fixed group A and B",
        comparison={"target": "B minus A", "measure": "mean, standardized mean and fixed-grid quantile differences",
                    "exposure": "B", "comparator": "A"},
        outcomes=[{"name": "Invented endpoint", "timepoint": "One fixed endpoint"}],
        covariates=[], missing_data="Refuse missing data; retain source small-cell suppression",
        multiplicity="No hypothesis tests; pointwise 95% bootstrap only when explicitly selected; no simultaneous coverage",
        analysis_sets=["Prespecified independent synthetic groups A and B"],
        schema_path=ROOT / "skills/_shared/schemas/study_contract.v1.schema.json")
    overlap = [r[:] for r in rows]; overlap[200][0] = rows[0][0]
    missing = [r[:] for r in rows]; missing[0][2] = ""
    unknown = [r[:] for r in rows]; unknown[0][1] = "undeclared"
    constant = [[r[0], r[1], 1 if r[1] == "A" else 2] for r in rows]
    return {
        "distribution.csv": csv_bytes([header] + rows),
        "reordered.csv": csv_bytes([header] + list(reversed(rows))),
        "small.csv": csv_bytes([header] + rows[:9] + rows[200:]),
        "empty.csv": csv_bytes([header] + rows[:200]),
        "wholly_suppressed.csv": csv_bytes([header] + rows[:5] + rows[200:205]),
        "overlap.csv": csv_bytes([header] + overlap),
        "missing.csv": csv_bytes([header] + missing),
        "unknown_group.csv": csv_bytes([header] + unknown),
        "constant.csv": csv_bytes([header] + constant),
        "contract.json": contract_bytes(contract),
    }


def prepare(destination):
    out = pathlib.Path(destination)
    if out.is_symlink() or (out.exists() and (not out.is_dir() or any(out.iterdir()))):
        raise FileExistsError("fresh empty synthetic fixture required; preserve existing evidence")
    out.mkdir(parents=True, exist_ok=True)
    data = payloads()
    for name, value in data.items():
        (out / name).write_bytes(value)
    manifest = {"schema": "omicstat.synthetic-source-fixture.v1", "real_owner_data": False,
                "data_origin": "Deterministic invented source contracts only; no biological or clinical rows",
                "files": {name: {"bytes": len(value), "sha256": hashlib.sha256(value).hexdigest()}
                          for name, value in data.items()}}
    (out / "SOURCE.json").write_text(json.dumps(manifest, indent=2) + "\n")
    return manifest


if __name__ == "__main__":
    prepare(sys.argv[1])

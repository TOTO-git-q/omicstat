"""Extend only the explicitly project-generated canonical fixture, never real rows."""
from __future__ import annotations
import csv
import json
import pathlib


def extend_generated_fixture(directory):
    directory = pathlib.Path(directory)
    provenance = json.loads((directory / "SYNTHETIC_INPUT_PROVENANCE.json").read_text())
    if (provenance.get("schema") != "omicstat.synthetic-fixture.v1"
            or provenance.get("measured_people") is not False
            or provenance.get("uses_package_datasets") is not False
            or provenance.get("seed") != 9182
            or provenance.get("n_units") != 160):
        raise ValueError("only the declared project-generated seed9182 fixture is eligible")
    with (directory / "clinical.csv").open(newline="") as stream:
        reader = csv.DictReader(stream); fields = list(reader.fieldnames); rows = list(reader)
    if len(rows) != 160 or any(not row["unit"].startswith("synthetic_") for row in rows):
        raise ValueError("invented independent-unit contract differs")
    # Fixed software mutation, not a biological competing-event model or calibration.
    for i, row in enumerate(rows):
        row["cause"] = "1" if row["event"] == "1" else "2" if i % 2 == 0 else "0"
    if {row["cause"] for row in rows} != {"0", "1", "2"}:
        raise ValueError("invented fixture must cover censoring and two event types")
    fields.append("cause")
    def write(name, values):
        with (directory / name).open("w", newline="") as stream:
            writer = csv.DictWriter(stream, fieldnames=fields); writer.writeheader(); writer.writerows(values)
    write("competing.csv", rows)
    bad = [dict(row) for row in rows]; bad[0]["cause"] = "2" if rows[0]["event"] == "1" else "1"
    write("competing-mismatch.csv", bad)
    bad = [dict(row) for row in rows]
    for row in bad:
        if row["cause"] == "2": row["cause"] = "3"
    write("competing-gap.csv", bad)
    bad = [dict(row) for row in rows]; bad[0]["cause"] = "1.5"; write("competing-fractional.csv", bad)
    bad = [dict(row) for row in rows]; bad[0]["cause"] = "NA"; write("competing-missing.csv", bad)
    bad = [dict(row) for row in rows]; censored = [row for row in bad if row["event"] == "0"]
    if len(censored) < 20: raise ValueError("invented cause-budget refusal needs20 originally censored units")
    for i, row in enumerate(censored): row["cause"] = str(2 + i % 20)
    write("competing-too-many-causes.csv", bad)
    marker = {"schema": "omicstat.synthetic-port-fixture.v1", "source_seed": 9182,
              "n_units": 160, "measured_people": False, "uses_package_datasets": False,
              "cause_rule": "Original event stays cause1; original censored even zero-based row index becomes invented cause2; remaining rows stay censored",
              "binary_event_unchanged": True, "analysis_times": [0, 50, 100],
              "piecewise_cuts": [50, 100], "purpose": "software boundary only; not real owner evidence"}
    (directory / "PORT_INPUT_PROVENANCE.json").write_text(json.dumps(marker, indent=2) + "\n")
    return marker


if __name__ == "__main__":
    import sys
    extend_generated_fixture(sys.argv[1])

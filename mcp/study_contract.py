"""Build the user's declarations; no design or scientific choices are inferred."""
import json
from pathlib import Path

from jsonschema import Draft202012Validator


def build_contract(*, design, biological_unit, population, comparison, outcomes,
                   covariates, missing_data, multiplicity, analysis_sets, schema_path):
    """Return a schema-valid contract with matching descriptive/semantic fields."""
    required = {"target", "measure", "exposure", "comparator"}
    if not isinstance(comparison, dict) or set(comparison) != required:
        raise ValueError("comparison requires exactly target, measure, exposure, comparator")
    if not isinstance(biological_unit, str) or not biological_unit.strip():
        raise ValueError("biological_unit must name the independent experimental unit")
    if not isinstance(population, str) or not population.strip():
        raise ValueError("population must describe included/excluded samples")
    # Check raw fields before interpolation; None must never become meaningful text.
    strings = [design, missing_data, multiplicity, *comparison.values()]
    if any(not isinstance(x, str) or not x.strip() for x in strings):
        raise ValueError("declarations must be nonempty strings")
    if not isinstance(outcomes, list) or any(
        not isinstance(x, dict) or set(x) != {"name", "timepoint"} for x in outcomes
    ):
        raise ValueError("outcomes require name and timepoint")
    definition = {"definition": population, "biological_unit": biological_unit}
    contract = {
        "schema_version": "omicstat.study-contract.v1",
        "study_design": design,
        "analysis_population": definition,
        "estimand": {"target": comparison["target"], "measure": comparison["measure"]},
        "exposure_or_intervention": comparison["exposure"],
        "comparator": comparison["comparator"],
        "outcomes": outcomes,
        "covariates": covariates,
        "missing_data": missing_data,
        "multiplicity": multiplicity,
        "analysis_sets": analysis_sets,
        "semantic_declarations": {
            "study_design": {"design_type": design},
            "population": {"definition": population + "; biological unit: " + biological_unit},
            "estimand": {"measure": comparison["measure"], "target": comparison["target"]},
            "exposure": {"variable_or_intervention": comparison["exposure"]},
            "comparator": {"definition": comparison["comparator"]},
            "outcomes": [{"identity": x["name"], "timing": x["timepoint"]} for x in outcomes],
            "missing_data": {"strategy": missing_data},
            "multiplicity": {"strategy": multiplicity},
        },
    }
    schema = json.loads(Path(schema_path).read_text(encoding="utf-8"))
    Draft202012Validator(schema).validate(contract)
    return contract


def contract_bytes(contract):
    """UTF-8, sorted keys, compact separators, no newline; arrays retain user order."""
    return json.dumps(contract, sort_keys=True, separators=(",", ":"),
                      ensure_ascii=False, allow_nan=False).encode("utf-8")

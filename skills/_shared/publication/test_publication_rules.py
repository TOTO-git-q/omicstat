#!/usr/bin/env python3
"""Read-only validation for the data-only publication rule registry."""

from __future__ import annotations

import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent
UNIVERSAL = ROOT / "universal_rules_v1.json"
MODULES = ROOT / "module_rules_v1.json"
# Each module is added here at its S5 install step together with its
# module_rules_v1.json record.  The set is read from the router's section 1
# table (skills/omicstat/SKILL.md), the suite's ONE module registry: every
# installed module needs exactly one publication record.
def _router_modules() -> set[str]:
    import re
    router = Path(__file__).resolve().parents[2] / "omicstat" / "SKILL.md"
    text = router.read_text(encoding="utf-8")
    sec = text.split("## 1. Routing table", 1)[1].split("\n## ", 1)[0]
    return set(re.findall(r"^\|[^|]*\|\s*`([a-z0-9-]+)`\s*\|", sec, flags=re.M))


EXPECTED_MODULES: set[str] = _router_modules()
EXPECTED_CATEGORIES = {
    "universal_hard", "design_conditional", "advisory", "journal_specific"
}
EXPECTED_SEVERITIES = {"hard_error", "major", "minor", "info"}


def load_json(path: Path) -> dict:
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def fail(message: str) -> None:
    raise AssertionError(message)


def assert_rule(rule: dict, source: str, categories: set[str], severities: set[str]) -> str:
    rule_id = rule.get("rule_id")
    if not isinstance(rule_id, str) or not rule_id:
        fail(f"{source}: missing rule_id")
    if rule.get("category") not in categories:
        fail(f"{source}/{rule_id}: invalid category {rule.get('category')!r}")
    if rule.get("severity") not in severities:
        fail(f"{source}/{rule_id}: invalid severity {rule.get('severity')!r}")
    return rule_id


def main() -> int:
    universal = load_json(UNIVERSAL)
    modules_doc = load_json(MODULES)
    for name, document, schema in (
        (UNIVERSAL.name, universal, "omicstat.publication_rules"),
        (MODULES.name, modules_doc, "omicstat.module_publication_rules"),
    ):
        if document.get("schema") != schema:
            fail(f"{name}: unexpected schema")
        expected_version = "1.1.0" if name == UNIVERSAL.name else "1.0.0"
        if document.get("version") != expected_version:
            fail(f"{name}: unexpected version")
        if set(document.get("rule_categories", [])) != EXPECTED_CATEGORIES:
            fail(f"{name}: category registry drift")
        if set(document.get("severities", [])) != EXPECTED_SEVERITIES:
            fail(f"{name}: severity registry drift")

    seen_ids: set[str] = set()
    for rule in universal.get("rules", []):
        rule_id = assert_rule(rule, UNIVERSAL.name, EXPECTED_CATEGORIES, EXPECTED_SEVERITIES)
        if rule_id in seen_ids:
            fail(f"duplicate rule_id: {rule_id}")
        seen_ids.add(rule_id)

    records = modules_doc.get("modules")
    if not isinstance(records, list):
        fail("module_rules_v1.json: modules must be a list")
    actual_modules = {record.get("module") for record in records}
    if actual_modules != EXPECTED_MODULES or len(records) != len(EXPECTED_MODULES):
        missing = sorted(EXPECTED_MODULES - actual_modules)
        extra = sorted(actual_modules - EXPECTED_MODULES)
        fail(f"module set mismatch; missing={missing}, extra={extra}")

    required_fields = {
        "reporting_guidelines", "effect_table_policy", "artifact_aliases",
        "artifact_expectations", "required_diagnostics", "narrative_points",
        "causal_language",
    }
    for record in records:
        module = record["module"]
        rule_id = assert_rule(record, module, EXPECTED_CATEGORIES, EXPECTED_SEVERITIES)
        if rule_id in seen_ids:
            fail(f"duplicate rule_id: {rule_id}")
        seen_ids.add(rule_id)
        missing = required_fields - set(record)
        if missing:
            fail(f"{module}: missing required fields {sorted(missing)}")
        if not isinstance(record["effect_table_policy"], dict):
            fail(f"{module}: effect_table_policy must be an object")
        if not isinstance(record["artifact_aliases"], dict):
            fail(f"{module}: artifact_aliases must be an object")
        if not isinstance(record["causal_language"], dict):
            fail(f"{module}: causal_language must be an object")
        for field in (
            "reporting_guidelines", "artifact_expectations", "required_diagnostics",
            "narrative_points",
        ):
            if not isinstance(record[field], list) or not record[field]:
                fail(f"{module}: {field} must be a non-empty list")

    print(f"publication rules valid: {len(records)} modules, {len(seen_ids)} unique rule IDs")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AssertionError, OSError, json.JSONDecodeError) as error:
        print(f"publication rules invalid: {error}", file=sys.stderr)
        raise SystemExit(1)

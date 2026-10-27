"""Preserve all original mathematical anchors and add real native port contracts.

This runner does not acquire the clinical MedStat mgus2 case. That original case
stays explicitly blocked in ORIGINAL_ANCHOR_STATUS.json, not marked reproduced.
"""
import json
import pathlib
import sys
from anchors import audit
from run_port_cli import run as run_port


def main(output, canonical, fixtures):
    output = pathlib.Path(output)
    values = audit(fixtures, canonical)
    target = output.parent / "survival-port-native-contract"
    code = run_port(target)
    if code:
        print("Original anchor values computed; native port anchor lane failed or is blocked. No combined pass file written.", file=sys.stderr)
        return code
    result = json.loads((target / "RESULT.json").read_text())
    if not result["native_executed"] or not result["synthetic_contract_only"]:
        raise ValueError("native software-contract provenance differs")
    values.update(port_aj_max_error=result["cif_independent_max_error"],
                  port_legacy_table_invariance=int(result["same_input_legacy_tables_unchanged"]),
                  port_replay_csv_invariance=int(result["resolved_replays_exact_csv_bytes"]),
                  port_copied_source_same_input=int(result["copied_source_native_same_input_checks_passed"]))
    output.write_text(json.dumps(values, indent=2) + "\n")
    print("Original10 mathematical diagnostics and4 native port contracts; real clinical anchor/owner evidence remain blocked.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(*sys.argv[1:4]))

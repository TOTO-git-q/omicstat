"""Preserve printed glmnet coefficient anchors; require real new native contracts."""
import csv
import json
import pathlib
import sys
from run_workup_cli import run


def main(output,canonical):
    output=pathlib.Path(output);canonical=pathlib.Path(canonical)
    with (canonical/'tables/coefficients.csv').open(newline='') as f:rows={r['gene']:r for r in csv.DictReader(f)}
    values={f'cox_example_v{i}':float(rows[f'V{i}']['coefficient']) for i in range(1,9)}
    target=output.parent/'cpm-workup-native-contract'
    code=run(target)
    if code:
        print('Native workup blocked or failed; no combined anchor pass file written',file=sys.stderr)
        return code
    result=json.loads((target/'RESULT.json').read_text())
    if result['state']!='passed_software_contracts_only' or not result['native_executed'] or not result['synthetic_contract_only']:
        raise ValueError('unexpected native contract provenance')
    values.update(workup_source_contracts=1,workup_legacy_table_invariance=int(result['original_tables_unchanged']),
        workup_replay_invariance=int(result['numerical_replay_exact']),workup_frozen_external_object=int(result['external_prediction_object_unchanged']))
    output.write_text(json.dumps(values,indent=2)+'\n')
    print('Original eight printed coefficient anchors and four native software contracts; real owner/environment closure still separately required')
    return 0


if __name__=='__main__':raise SystemExit(main(*sys.argv[1:3]))

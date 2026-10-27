"""Fail closed until an independently reviewed exact OmicStat pROC closure is bound."""
import json,pathlib,sys
r=pathlib.Path(__file__).resolve().parents[3]
d=json.loads((r/'docs/build/P0-13-proc-roc/DEPENDENCY_REQUIREMENTS.json').read_text())
c=json.loads((r/'skills/proc-roc/scripts/calls_registry.json').read_text())
if d['state']!='verified_independent_native_closure' or not c.get('native_defaults_verified'):
 print('OS_DEPENDENCY_MISSING: exact independent pROC closure and actual installed formals unresolved; no installation attempted.',file=sys.stderr)
 raise SystemExit(1)
raise SystemExit('OS_INVALID_PARAMETER: changing a status flag does not bind a closure; reviewed actual validator required')

"""This gate fails closed until a separately reviewed actual closure is bound."""
import json,pathlib,sys
r=pathlib.Path(__file__).resolve().parents[3]
d=json.loads((r/'docs/build/P0-13-agreement/DEPENDENCY_REQUIREMENTS.json').read_text())
c=json.loads((r/'skills/omicstat-agreement/scripts/calls_registry.json').read_text())
if d['state']!='verified_independent_native_closure' or not c.get('native_defaults_verified'):
 print('OS_DEPENDENCY_MISSING: exact independent vcd/irr/epiR closure and installed formals unresolved; no installation or substitute estimator attempted.',file=sys.stderr)
 raise SystemExit(1)
raise SystemExit('OS_INVALID_PARAMETER: changing a status flag cannot authorize a native closure; reviewed validator revision required')

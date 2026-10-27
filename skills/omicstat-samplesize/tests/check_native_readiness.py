"""Fail closed until actual independent dependency and default bindings exist."""
import json,pathlib,sys
root=pathlib.Path(__file__).resolve().parents[3]
d=json.loads((root/'docs/build/P0-13-samplesize/DEPENDENCY_REQUIREMENTS.json').read_text())
c=json.loads((root/'skills/omicstat-samplesize/scripts/calls_registry.json').read_text())
if d['state']!='verified_independent_native_closure' or not c.get('native_defaults_verified'):
 print('OS_DEPENDENCY_MISSING: exact independent OmicStat pwr/gsDesign closure and native formals are unresolved; no installation attempted.',file=sys.stderr)
 raise SystemExit(1)
raise SystemExit('OS_INVALID_PARAMETER: a verified closure requires a separately reviewed validator revision; a status-string edit cannot authorize it')

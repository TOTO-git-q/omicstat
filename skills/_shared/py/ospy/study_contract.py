"""Read actual contract bytes, validate them, and bind an engine process context."""
import hashlib,importlib.util,json,pathlib,re,sys
from .errors import OmicstatError
_CONTEXT=None
ROOT=pathlib.Path(__file__).resolve().parents[4]
def _json(text):
 def reject(x):raise ValueError('non-finite JSON: '+x)
 def unique(pairs):
  out={}
  for k,v in pairs:
   if k in out:raise ValueError('duplicate JSON key: '+k)
   out[k]=v
  return out
 return json.loads(text,parse_constant=reject,object_pairs_hook=unique)
def read_study_contract(path,upstream=None,expected_sha256=None):
 p=pathlib.Path(path)
 try:
  if p.is_symlink() or not p.is_file():raise ValueError('contract must be a regular non-symlink file')
  if p.stat().st_size>1024**2:raise ValueError('contract exceeds 1 MiB')
  raw=p.read_bytes();contract=_json(raw.decode('utf-8'));digest=hashlib.sha256(raw).hexdigest()
  if not isinstance(contract,dict):raise ValueError('contract must be an object')
  # Schema validation is the host/MCP job (mcp/requirements.txt pins jsonschema).
  # Engine images need not ship it: a missing import only warns, the byte hash
  # binding and the semantic rules below still apply and nothing is refused.
  try:from jsonschema import Draft202012Validator
  except ImportError:
   Draft202012Validator=None
   sys.stderr.write('warning: jsonschema is not installed in this image; StudyContract JSON-schema validation is left to the host/MCP, byte binding and semantic checks still ran.\n')
  errors=[]
  if Draft202012Validator is not None:
   schema=json.loads((ROOT/'skills/_shared/schemas/study_contract.v1.schema.json').read_text())
   errors=[e.message for e in Draft202012Validator(schema).iter_errors(contract)]
  # Reuse publication's semantic rules without accepting normalization as a new hash.
  mcp_path=str(ROOT/'mcp');sys.path.insert(0,mcp_path)
  try:
   spec=importlib.util.spec_from_file_location('_omicstat_contract_semantics',ROOT/'mcp/publication.py');pub=importlib.util.module_from_spec(spec);spec.loader.exec_module(pub)
  finally:sys.path.remove(mcp_path)
  normalized,semantic=pub.normalize_study_contract(contract);errors+=semantic
  if errors:raise ValueError('; '.join(errors[:10]))
 except OmicstatError:raise
 except (OSError,ValueError,UnicodeError) as exc:raise OmicstatError('OS_CONTRACT_INVALID',str(exc)) from exc
 for value in [expected_sha256,(upstream or {}).get('contract_hash')]:
  if value is not None and (not isinstance(value,str) or not re.fullmatch('[0-9a-f]{64}',value) or value!=digest):raise OmicstatError('OS_CONTRACT_MISMATCH','contract bytes differ from declared/upstream hash')
 return {'path':str(p.resolve()),'sha256':digest,'study_contract':contract}
def bind_args(args):
 global _CONTEXT
 _CONTEXT=None
 path=args.get('study-contract');expected=args.get('study-contract-sha256')
 if expected and not path:raise OmicstatError('OS_MISSING_PARAMETER','--study-contract-sha256 requires --study-contract; a supplied hash is not evidence')
 if not path:return None
 upstream=None
 if args.get('from-run'):
  handoff=pathlib.Path(args['from-run'])/'objects/handoff.json'
  try:upstream=_json(handoff.read_text())
  except (OSError,ValueError) as exc:raise OmicstatError('OS_HANDOFF_MISSING','cannot bind the declared upstream handoff') from exc
 _CONTEXT=read_study_contract(path,upstream,expected);return _CONTEXT

def bound_hash(explicit=None):
 if _CONTEXT is None:return explicit
 # Detect a contract modified after parse/before handoff emission.
 actual=read_study_contract(_CONTEXT['path'],expected_sha256=_CONTEXT['sha256'])['sha256']
 if explicit is not None and explicit!=actual:raise OmicstatError('OS_CONTRACT_MISMATCH','engine supplied a contract hash different from validated bytes')
 return actual

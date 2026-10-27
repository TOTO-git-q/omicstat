"""Acceptance mechanics. No golden, lock or signature writer is present."""
import csv,datetime,hashlib,json,math,pathlib,re,subprocess
STAGES=('static','anchors','replay','refusals','chain','figures','golden','seal','regression')
REQUIRED=('static','anchors','replay','refusals','chain','figures')
HEADINGS=('When to use / when not','Input requirements','Run','What gets produced','Reading the results','When a QC rule fires','Known limitations','Reference files')
def now():return datetime.datetime.now(datetime.timezone.utc).isoformat()
def invalid_constant(value):raise ValueError('Non-finite JSON constant: '+value)
def load(p):return json.loads(pathlib.Path(p).read_text(),parse_constant=invalid_constant)
def sha(p):
 h=hashlib.sha256()
 with pathlib.Path(p).open('rb') as f:
  while b:=f.read(1024*1024):h.update(b)
 return h.hexdigest()
def dump(p,x):
 p=pathlib.Path(p);p.parent.mkdir(parents=True,exist_ok=True);tmp=p.with_name(p.name+'.tmp');tmp.write_text(json.dumps(x,indent=2,ensure_ascii=False,allow_nan=False)+'\n');tmp.replace(p)
def contained(root,path):
 root=pathlib.Path(root).resolve();p=(root/path).resolve()
 if not p.is_relative_to(root):raise ValueError('path escapes permitted root: '+str(path))
 return p
def safe_rel(path):
 p=pathlib.PurePosixPath(path)
 if p.is_absolute() or '..' in p.parts or '\\' in path:raise ValueError('unsafe relative path')
 return str(p)
def finite_numeric(x):return isinstance(x,(int,float)) and not isinstance(x,bool) and math.isfinite(x)
def anchor_result(definition,obtained):
 expected=definition['expected'];tol=definition['tolerance']
 if not finite_numeric(tol) or tol<0:raise ValueError('anchor tolerance must be finite and nonnegative')
 kind=definition.get('tolerance_kind','relative_floor_one')
 if kind not in ('absolute','relative_floor_one'):raise ValueError('unknown anchor tolerance kind')
 if finite_numeric(expected):passed=finite_numeric(obtained) and abs(obtained-expected)<=tol*(1 if kind=='absolute' else max(1,abs(expected)))
 else:passed=type(obtained)==type(expected) and obtained==expected and tol==0
 return {**definition,'obtained':obtained,'pass':bool(passed),'tolerance_rule':('absolute_error <= tolerance' if kind=='absolute' else 'absolute_error <= tolerance * max(1,abs(expected))')+'; exact for nonnumbers'}
def replay_inventory(root):
 root=pathlib.Path(root);out={}
 for pattern in ('tables/*.csv','figures/*.png','figures/*.figure_spec.json'):
  for p in sorted(root.glob(pattern)):
   if p.is_symlink() or not p.resolve().is_relative_to(root.resolve()):raise ValueError('replay artifact escapes run root')
   out[p.relative_to(root).as_posix()]=sha(p)
 return out
def compare_runs(first,second):
 a,b=replay_inventory(first),replay_inventory(second);keys=sorted(set(a)|set(b));diff=[k for k in keys if a.get(k)!=b.get(k)]
 return {'identical_files':[k for k in keys if k not in diff],'differing_files':diff,'first':a,'second':b,'ok':bool(keys) and not diff}
def read_refusals(path):
 with pathlib.Path(path).open(newline='') as f:
  reader=csv.DictReader(f)
  if reader.fieldnames!=['case','argv','expected_code','stage']:raise ValueError('refusals.csv columns must be case,argv,expected_code,stage')
  rows=list(reader)
 names=set()
 for r in rows:
  if not re.fullmatch('[A-Za-z0-9_.-]+',r['case']) or r['case'] in names:raise ValueError('refusal case must be unique/safe')
  names.add(r['case']);r['argv']=json.loads(r['argv'])
  if not isinstance(r['argv'],list) or not all(isinstance(a,str) for a in r['argv']):raise ValueError('refusal argv must be a JSON string array, never shell text')
  if not re.fullmatch('OS_[A-Z][A-Z0-9_]+',r['expected_code']) or not r['stage']:raise ValueError('explicit refusal code/stage required')
 return rows
def refusal_result(row,run):
 codes=sorted(set(re.findall(r'\bOS_[A-Z][A-Z0-9_]+\b',run.get('stderr',''))))
 return {**row,'observed_code':row['expected_code'] if row['expected_code'] in codes else None,'observed_codes':codes,'returncode':run.get('returncode'),'pass':run.get('returncode') not in (None,0) and not run.get('timed_out') and row['expected_code'] in codes}
def verdict(record,full=False):
 required=list(REQUIRED)+(['regression'] if full else [])
 bad=[s for s in required if record['stages'].get(s,{}).get('status') not in ('pass','not_applicable')]
 # Owner freeze is unconditional here. A forged visual_review cannot promote it.
 return ('fail' if bad else 'needs_visual'),bad
def protected(root):return {str(p.relative_to(root)):sha(p) for p in (root/'skills').rglob('*') if p.is_file() and (p.name=='module_lock.json' or 'golden' in p.name or 'golden' in p.parts)}

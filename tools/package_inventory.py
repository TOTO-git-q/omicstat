"""Validate package prefixes against locked or attested observed inventories.
Planned candidate package lists never prove installation. Candidate inventories
cannot authorize an accepted module or change the production environment.
"""
import csv,hashlib,json,pathlib,re

def packages(root, *, candidate=False):
 root=pathlib.Path(root);paths=[root/'env/pkg_lock.csv',root/'env/py/py_installed.csv']
 if candidate:
  for path in sorted((root/'env/candidates').glob('*/observed_packages.csv')):
   proof=json.loads(path.with_suffix('.provenance.json').read_text())
   if (proof.get('schema')!='omicstat.observed-candidate-packages.v1' or
       proof.get('inventory')!=path.name or proof.get('purpose')!='candidate_prefix_validation_only' or
       not re.fullmatch('sha256:[0-9a-f]{64}',proof.get('observed_image_id','')) or
       not re.fullmatch('[0-9a-f]{40}',proof.get('source_commit','')) or
       not proof.get('repository') or not proof.get('source_path') or
       hashlib.sha256(path.read_bytes()).hexdigest()!=proof.get('sha256')):
    raise ValueError('invalid observed candidate package inventory: '+str(path))
   paths.append(path)
 out={'omicstat':'omicstat'}
 for path in paths:
  if path.exists():
   for row in csv.DictReader(path.read_text().splitlines()):
    name=row.get('Package') or row.get('package') or row.get('name') or ''
    if name:out[name.lower().replace('-','')]=name
 return out


def declared(root, module):
 """Package names declared by the lock of the candidate/lane image a module's
 acceptance request names (sources.lock.json rows and manifest new_packages).
 A declaration only licenses the module-name prefix; installation and native
 numerical acceptance are still proven by the acceptance run in that image."""
 root=pathlib.Path(root);names={}
 for path in sorted((root/'acceptance/requests').glob('*.json')):
  try:request=json.loads(path.read_text())
  except ValueError:continue
  if module not in (request.get('modules') or []):continue
  rels=[request.get('image_candidate'),request.get('render_image_candidate'),(request.get('module_image_candidates') or {}).get(module)]
  for rel in rels:
   if not isinstance(rel,str) or not re.fullmatch('env/(py/|lanes/)?(candidates/)?[^/]+(/[^/]+)?',rel):continue
   folder=root/rel
   if not folder.is_dir():continue
   rows=[]
   for file,key in (('sources.lock.json','sources'),('manifest.json','new_packages')):
    if (folder/file).is_file():
     try:data=json.loads((folder/file).read_text())
     except ValueError:continue
     rows+=data.get(key,[]) if isinstance(data,dict) else []
   for row in rows:
    name=row.get('package') if isinstance(row,dict) else row
    if isinstance(name,str) and name:names[name.lower().replace('-','')]=name
 return names

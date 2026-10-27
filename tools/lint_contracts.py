#!/usr/bin/env python3
"""Schema and source-contract gate. Never edits modules, seals, or goldens.

Legacy calls registries are accepted only at their recorded baseline SHA256;
new or modified registries must satisfy the strict schema, without relaxation.
"""
from __future__ import annotations
import argparse, ast, csv, hashlib, json, pathlib, re, sys
ROOT = pathlib.Path(__file__).resolve().parents[1]
SCHEMAS = ROOT / 'skills/_shared/schemas'

def load(path):
    return json.loads(path.read_text(encoding='utf-8'))

def validate(instance, schema, path='$'):
    """Small fail-closed validator for the schema keywords used by this family.

    Full Draft202012Validator is used when available; these local schemas do
    not require external resolution, network I/O, or a new runtime dependency.
    """
    try:
        from jsonschema import Draft202012Validator
    except ImportError:
        pass
    else:
        return [f'{path}/{"/".join(map(str,e.absolute_path))}: {e.message}' for e in Draft202012Validator(schema).iter_errors(instance)]
    errors=[]
    for key in ('allOf','anyOf','oneOf'):
        if key in schema:
            checks=[validate(instance,x,path) for x in schema[key]]
            good=sum(not x for x in checks)
            if (key=='allOf' and good!=len(checks)) or (key=='anyOf' and not good) or (key=='oneOf' and good!=1):errors.append(f'{path}: {key} constraint failed')
    kind=schema.get('type')
    kinds={'object':dict,'array':list,'string':str,'integer':int,'number':(int,float),'boolean':bool,'null':type(None)}
    if kind and (not isinstance(instance,kinds[kind]) or kind in ('integer','number') and isinstance(instance,bool)):
        return [f'{path}: expected {kind}']
    if 'enum' in schema and instance not in schema['enum']: errors.append(f'{path}: not in enum')
    if 'const' in schema and instance != schema['const']: errors.append(f'{path}: incorrect constant')
    if isinstance(instance,str):
        if len(instance)<schema.get('minLength',0):errors.append(f'{path}: empty string')
        if 'pattern' in schema and re.search(schema['pattern'],instance) is None:errors.append(f'{path}: pattern mismatch')
    if isinstance(instance,(int,float)) and 'minimum' in schema and instance<schema['minimum']:errors.append(f'{path}: below minimum')
    if isinstance(instance,dict):
        for k in schema.get('required',[]):
            if k not in instance:errors.append(f'{path}: missing {k}')
        props=schema.get('properties',{})
        for k,v in instance.items():
            if k in props:errors.extend(validate(v,props[k],f'{path}/{k}'))
            elif isinstance(schema.get('additionalProperties'),dict):errors.extend(validate(v,schema['additionalProperties'],f'{path}/{k}'))
            elif schema.get('additionalProperties') is False:errors.append(f'{path}: unexpected {k}')
    if isinstance(instance,list):
        if schema.get('uniqueItems') and len({json.dumps(v,sort_keys=True) for v in instance})!=len(instance):errors.append(f'{path}: duplicate items')
        for i,v in enumerate(instance):errors.extend(validate(v,schema.get('items',{}),f'{path}/{i}'))
    return errors

def handoff_literals(src, suffix):
    """Only object descriptors (path + type), never e.g. ggplot arrow(type=)."""
    if suffix=='.py':
        try: tree=ast.parse(src)
        except SyntaxError:return []
        out=[]
        for node in ast.walk(tree):
            if isinstance(node,ast.Dict):
                keys={k.value:v for k,v in zip(node.keys,node.values) if isinstance(k,ast.Constant) and isinstance(k.value,str)}
                if 'path' in keys:
                    def returned_strings(value):
                        if isinstance(value,ast.Constant) and isinstance(value.value,str): return [value.value]
                        if isinstance(value,ast.IfExp): return returned_strings(value.body)+returned_strings(value.orelse)
                        return []
                    out.extend((node.lineno,value) for value in returned_strings(keys.get('type')))
            elif isinstance(node,ast.Call) and isinstance(node.func,ast.Name) and node.func.id=='dict':
                keys={k.arg:k.value for k in node.keywords if k.arg is not None}
                if 'path' in keys and isinstance(keys.get('type'),ast.Constant) and isinstance(keys['type'].value,str):out.append((node.lineno,keys['type'].value))
        return out
    # Balance R list(...) boundaries, ignoring parentheses in strings/comments.
    from lint_r import mask, close_of
    code=mask(src); out=[]
    for m in re.finditer(r'\blist\s*\(',code):
        end=close_of(code,m.end()-1); body=src[m.end():end]
        # A descriptor is a leaf list with path= and a literal type=.
        if re.search(r'\bpath\s*=',body) and not re.search(r'\blist\s*\(',mask(body)):
            for t in re.finditer(r'\btype\s*=',mask(body)):
                value=body[t.end():].lstrip()
                if value.startswith('if'):
                    conditional=mask(value);opening=conditional.find('(')
                    if opening<0:continue
                    ending=close_of(conditional,opening);value=value[ending+1:].lstrip()
                    pattern=r"^[\"']([^\"']+)[\"']|\belse\s+[\"']([^\"']+)[\"']"
                    choices=[a or b for a,b in re.findall(pattern,value.split(',')[0])]
                else:
                    hit=re.match(r"^[\"']([^\"']+)[\"']",value);choices=[hit.group(1)] if hit else []
                out.extend((src.count('\n',0,m.end()+t.start())+1,x) for x in choices)
    return out

def lint(root=ROOT, selected=None):
    sd=root/'skills/_shared/schemas'; problems=[]; stats={'modules':0,'calls_registries':0,'legacy_registries':0,'source_files':0}
    types={x['id'] for x in load(sd/'handoff_types.v1.json')['types']}
    ed=load(sd/'error_codes.v1.json'); codes={x['code']:x for x in ed['codes']}; symbols=set(ed.get('non_diagnostic_symbols',[]))
    legacy=load(sd/'legacy_contracts.v1.json')['calls_registries']
    from package_inventory import packages as package_names, declared as declared_packages
    packages=package_names(root);candidate_packages=package_names(root,candidate=True)
    for p in sorted((root/'skills').glob('*/module.json')):
        if selected and p.parent.name not in selected:continue
        d=load(p);stats['modules']+=1
        problems.extend(f'{p.relative_to(root)}: {e}' for e in validate(d,load(sd/'module.v1.schema.json')))
        if d.get('name')!=p.parent.name:problems.append(f'{p}: module name differs from directory')
        prefix=d.get('name','').split('-')[0]
        if prefix not in (candidate_packages if d.get('status')=='candidate' else packages) and prefix not in declared_packages(root,d.get('name')) and d.get('name') not in {x['module'] for x in legacy.values()}:problems.append(f'{p}: module prefix is not an installed package, a package declared by the lock its request names, or omicstat')
        for t in d.get('handoff',{}).get('inputs',[])+d.get('handoff',{}).get('outputs',[]):
            if t not in types:problems.append(f'{p}: unknown handoff type {t}')
    for p in sorted((root/'skills').glob('*/scripts/calls_registry.json')):
        if selected and p.parent.parent.name not in selected:continue
        rel=str(p.relative_to(root));d=load(p);stats['calls_registries']+=1
        old=legacy.get(rel)
        if old and hashlib.sha256(p.read_bytes()).hexdigest()==old['sha256']:
            stats['legacy_registries']+=1
            if d.get('module')!=p.parent.parent.name:problems.append(f'{rel}: legacy module mismatch')
        else:problems.extend(f'{rel}: {e}' for e in validate(d,load(sd/'calls_registry.v1.schema.json')))
    for top in ['skills','tools','mcp','env','reference_service']:
        for p in sorted((root/top).rglob('*')):
            if p.suffix not in ('.R','.py') or '__pycache__' in p.parts:continue
            if selected and top=='skills' and p.relative_to(root).parts[1] not in set(selected)|{'_shared'}:continue
            src=p.read_text(encoding='utf-8');rel=str(p.relative_to(root));stats['source_files']+=1
            for code in sorted(set(re.findall(r'\bOS_[A-Z][A-Z_0-9]*\b',src))):
                if code not in codes and code not in symbols:problems.append(f'{rel}: unregistered diagnostic/symbol {code}')
                elif code in codes and 'alias_of' in codes[code]:
                    sites=codes[code].get('legacy_sites',[])
                    if not any(s['path']==rel and s['sha256']==hashlib.sha256(p.read_bytes()).hexdigest() for s in sites):problems.append(f'{rel}: new use of alias {code}; use {codes[code]["alias_of"]}')
            if top=='skills':
                for line,t in handoff_literals(src,p.suffix):
                    if t not in types:problems.append(f'{rel}:{line}: unregistered handoff type {t}')
    ref=root/'env/refdata_registry.json'
    if ref.exists():
        from refdata import metadata
        registry=load(ref)
        problems.extend('refdata: '+e for e in validate(registry,load(sd/'refdata.v2.schema.json')))
        problems.extend('refdata: '+e for e in metadata(registry,root))
    return problems,stats

def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('modules',nargs='*');ap.add_argument('--root',type=pathlib.Path,default=ROOT);ap.add_argument('--json',action='store_true');ap.add_argument('--check',action='store_true');a=ap.parse_args()
    try: problems,stats=lint(a.root,a.modules)
    except (OSError,ValueError,KeyError) as e:problems,stats=[str(e)],{}
    if a.json:print(json.dumps({'ok':not problems,'counts':stats,'problems':problems},indent=2))
    else:
        for p in problems:print(p)
        print(('FAIL' if problems else 'PASS')+': contracts '+json.dumps(stats,sort_keys=True))
    return int(bool(problems))
if __name__=='__main__':raise SystemExit(main())

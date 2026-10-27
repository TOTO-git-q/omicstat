#!/usr/bin/env python3
"""Generate registry views from module.json; --check is read-only and fails on drift."""
from __future__ import annotations
import argparse,ast,collections,hashlib,json,pathlib,re,sys
from lint_contracts import ROOT,validate,load
BEGIN='<!-- registry:begin -->';END='<!-- registry:end -->'
HEADINGS=['When to use / when not','Input requirements','Run','What gets produced','Reading the results','When a QC rule fires','Known limitations','Reference files']
def dump(x):return json.dumps(x,ensure_ascii=False,indent=2)+'\n'
def dump_reference(x):return json.dumps(x,ensure_ascii=False,indent=1)+'\n'
def replace_block(text,body,begin=BEGIN,end=END,bootstrap=False):
    if begin in text:
        if text.count(begin)!=1 or text.count(end)!=1:raise ValueError('registry markers must occur exactly once')
        return text.split(begin)[0]+begin+'\n'+body.rstrip()+'\n'+end+text.split(end,1)[1]
    if not bootstrap:raise ValueError('missing generated-block markers')
    rows=list(re.finditer(r'^\|.*\|\s*$',text,re.M))
    if not rows:raise ValueError('no table to adopt')
    first=rows[0].start();last=rows[-1].end()
    return text[:first]+begin+'\n'+body.rstrip()+'\n'+end+text[last:]

def generated(root=ROOT):
    modules=[load(p) for p in (root/'skills').glob('*/module.json')];modules.sort(key=lambda m:(m['routing']['order'],m['name']))
    if not modules:raise ValueError('no module.json records')
    names=[m['name'] for m in modules]
    if len(set(names))!=len(names):raise ValueError('duplicate module name')
    orders=[m['routing']['order'] for m in modules]
    if len(set(orders))!=len(orders):raise ValueError('routing.order collision')
    out={};schema=load(root/'skills/_shared/schemas/module.v1.schema.json')
    for m in modules:
        errors=validate(m,schema)
        if errors:raise ValueError(f'{m["name"]}: {errors}')
        if not (root/'skills'/m['name']/m['entry']).is_file():raise ValueError(f'missing entry for {m["name"]}')
    routed=[m for m in modules if m['status']=='accepted']
    route='| The question sounds like... | -> Module | CLI entry script |\n|---|---|---|\n'+'\n'.join(f'| {m["routing"]["question"]} | `{m["name"]}` | `{m["entry"]}` |' for m in routed)+'\n'
    path='skills/omicstat/SKILL.md';text=(root/path).read_text() if (root/path).exists() else '# omicstat router\n\n## 1. Routing table\n'+BEGIN+'\n'+END+'\n\n## 2. Disambiguation\n';before,section=text.split('## 1.',1);part,after=section.split('\n## 2.',1)
    out[path]=before+'## 1.'+replace_block(part,route,bootstrap=True)+'\n## 2.'+after
    q=load(root/'tools/qc_prefixes.json');q['planned']={m['name']:m['qc_prefix'] for m in modules};out['tools/qc_prefixes.json']=dump(q)
    pub=load(root/'skills/_shared/publication/module_rules_v1.json') if (root/'skills/_shared/publication/module_rules_v1.json').exists() else {'schema':'omicstat.module_publication_rules','version':'1.0.0','modules':[]};existing={m['module']:m for m in pub['modules']}
    records=[]
    for m in routed:
        override=m['publication'].get('legacy_override')
        if override is not None:
            if existing.get(m['name'])!=override:raise ValueError(f'{m["name"]}: owner-protected publication override drift')
            records.append(override)
        else:records.append({'module':m['name'],'rule_id':'PUB-M-'+m['name'].upper()+'-001','category':m['publication']['rule_category'],'severity':'hard_error','reporting_guidelines':m['publication'].get('reporting_guidelines',[]),'effect_table_policy':m['publication'].get('effect_table_policy',{}),'artifact_expectations':m['publication'].get('artifact_expectations',[]),'required_diagnostics':m['publication'].get('required_diagnostics',[]),'narrative_points':m['publication'].get('narrative_points',[]),'causal_language':m['publication'].get('causal_language',{})})
    by_module={x['module']:x for x in records}
    records=[by_module.pop(x['module']) for x in pub['modules'] if x['module'] in by_module]+list(by_module.values())
    # Preserve exact bytes of grandfathered manual overrides.
    if records==pub['modules'] and (root/'skills/_shared/publication/module_rules_v1.json').exists():out['skills/_shared/publication/module_rules_v1.json']=(root/'skills/_shared/publication/module_rules_v1.json').read_text()
    else:pub['modules']=records;out['skills/_shared/publication/module_rules_v1.json']=dump(pub)
    candidate_rows=[m for m in modules if m['status']=='candidate']
    if (root/'SUITE.md').is_file():
        if candidate_rows:
            template=(root/'templates/candidate_suite.md.tmpl').read_text()
            body=template.replace('{{rows}}','\n'.join('| `'+m['name']+'` | '+m['domain']+' | '+m['routing']['question']+' | candidate |' for m in candidate_rows))
        else:body='## 标准化候选模块（自动生成）\n\n当前没有 candidate 模块。已接受模块及入口见路由表。'
        path='SUITE.md';out[path]=replace_block((root/path).read_text(),body,'<!-- candidates:begin -->','<!-- candidates:end -->')
    if (root/'reference_service/app/registry.py').is_file():
        refs=sorted((m for m in routed if m.get('reference',{}).get('enabled')),key=lambda m:(m['reference'].get('order',m['routing']['order']),m['name']))
        path='reference_service/app/method_map.json'
        methods=load(root/path) if (root/path).is_file() else {'schema':'omicstat.method-map.v1'}
        methods.update(source_path='skills/*/module.json; skills/omicstat/SKILL.md section 1',source_sha256=hashlib.sha256(out['skills/omicstat/SKILL.md'].encode()).hexdigest(),order_rule='Accepted reference-enabled module.json records in reference.order; historical targets retain their order. Deployment must reconcile the stored method-map cursor.')
        methods['modules']=[{'module':m['name'],'entry_script':m['entry'],'entry_status':'implemented_routed'} for m in refs]
        out[path]=dump_reference(methods)
        path='reference_service/app/schemas/literature_request.v1.json'
        if (root/path).is_file():
            schema=load(root/path);schema['properties']['module']['enum']=[m['name'] for m in refs]+['unmapped'];out[path]=dump_reference(schema)
        path='reference_service/app/discovery_profiles.json'
        if (root/path).is_file():
            profiles=load(root/path);existing={p['module']:p for p in profiles['profiles']}
            profiles['profiles']=[m['reference'].get('discovery_profile') or existing[m['name']] for m in refs]
            out[path]=dump_reference(profiles)
    counts={'schema':'omicstat.registry-counts.v1','total':len(modules),'routed':len(routed),'by_lane':dict(sorted(collections.Counter(m['lane'] for m in modules).items())),'by_domain':dict(sorted(collections.Counter(m['domain'] for m in modules).items())),'by_status':dict(sorted(collections.Counter(m['status'] for m in modules).items())),'legacy_implemented_new':sum(bool(m.get('migration',{}).get('implemented_new')) for m in modules)}
    out['tools/registry_counts.json']=dump(counts)
    # Scaffold-only test roots may omit the MCP server.
    if (root/'mcp/server.py').is_file():
        # Derive the public MCP inventory without importing the server or engines.
        names=[]
        for node in ast.parse((root/'mcp/server.py').read_text()).body:
            if not isinstance(node,(ast.FunctionDef,ast.AsyncFunctionDef)):continue
            for decorator in node.decorator_list:
                if isinstance(decorator,ast.Call) and ast.unparse(decorator.func)=='mcp.tool':
                    names.append(next((ast.literal_eval(k.value) for k in decorator.keywords if k.arg=='name'),node.name))
        if not names or len(set(names))!=len(names):raise ValueError('empty or duplicate MCP tool inventory')
        out['mcp/tools_manifest.json']=dump({'schema':'omicstat.mcp-tools.v1','tools':names})
    for m in modules:
        folder=root/'skills'/m['name']
        sk=folder/'SKILL.md';text=sk.read_text() if sk.exists() else f'---\nname: {m["name"]}\ndescription: {m["routing"]["question"]}\n---\n'
        out[str(sk.relative_to(root))]=text
        if 'preserve_sealed_documentation' in m.get('status_notes',[]):continue
        pp=folder/'references/parameters.md';text=pp.read_text() if pp.exists() else '# Parameters\n\n'+BEGIN+'\n'+END+'\n'
        body='| Flag | Default | Source |\n|---|---|---|\n'+'\n'.join('| '+str(p.get('flag','')).replace('|','\\|')+' | '+json.dumps(p.get('default'),ensure_ascii=False).replace('|','\\|')+' | '+str(p.get('source','user_required')).replace('|','\\|')+' |' for p in m.get('inputs',[]))
        if BEGIN not in text:text+='\n'+BEGIN+'\n'+END+'\n'
        out[str(pp.relative_to(root))]=replace_block(text,body)
        text=out[str(sk.relative_to(root))]
        for heading in HEADINGS:
            if '## '+heading not in text:text+='\n## '+heading+'\n'
        out[str(sk.relative_to(root))]=text
        anchors=folder/m['anchors'];pack=root/'acceptance/exemplars'/m['name']/'PACK.md'
        if anchors.exists() and pack.exists():
            a=load(anchors);a=a.get('anchors',[]) if isinstance(a,dict) else a
            body='| ID | Metric | Expected | Tolerance | Source | Scope | How |\n|---|---|---|---|---|---|---|\n'+'\n'.join('| '+' | '.join(str(x.get(k,'')) for k in ['id','metric','expected','tolerance','source','scope','how'])+' |' for x in a)
            s=pack.read_text();b='<!-- anchors:begin -->';e='<!-- anchors:end -->'
            if b not in s:s+='\n## C. Machine-readable anchors\n'+b+'\n'+e+'\n'
            out[str(pack.relative_to(root))]=replace_block(s,body,b,e)
    return out,counts

def sync(root=ROOT,check=False):
    out,counts=generated(root);drift=[]
    for rel,text in out.items():
        p=root/rel
        if not p.exists() or p.read_text()!=text:
            drift.append(rel)
            if not check:p.parent.mkdir(parents=True,exist_ok=True);p.write_text(text,encoding='utf-8',newline='\n')
    return drift,counts
if __name__=='__main__':
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--check',action='store_true');ap.add_argument('--root',type=pathlib.Path,default=ROOT);a=ap.parse_args()
    try:d,c=sync(a.root,a.check)
    except (ValueError,KeyError,OSError) as e:print(f'FAIL: {e}',file=sys.stderr);raise SystemExit(1)
    print(('FAIL' if a.check and d else 'PASS')+f': registry {c["total"]} modules; '+(', '.join(d) if d else 'no drift'))
    raise SystemExit(int(a.check and bool(d)))

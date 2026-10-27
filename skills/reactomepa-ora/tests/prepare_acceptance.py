import pathlib,subprocess,sys,json,hashlib,csv,shutil
root=pathlib.Path(__file__).resolve().parents[3];out=pathlib.Path(sys.argv[1]);out.mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(root/'mcp'));from study_contract import build_contract,contract_bytes
c=build_contract(design='Software validation of explicit-universe Reactome ORA using fifteen upstream author example Entrez IDs',biological_unit='Gene in a declared assay-eligible background; no expression sample inference in this fixture',population='Human annotation snapshot; examples do not constitute biological replication',comparison={'target':'Pathway over-representation','measure':'One-sided hypergeometric P and BH adjusted P','exposure':'Prespecified selected Entrez genes','comparator':'Explicit annotated eligible universe'},outcomes=[{'name':'Pathway overlap','timepoint':'Frozen annotation snapshot'}],covariates=[],missing_data='Reject malformed IDs and explicitly report annotation loss',multiplicity='BH across all nonzero-overlap size-eligible tested Reactome pathways',analysis_sets=['Explicit selected list and declared background'],schema_path=root/'skills/_shared/schemas/study_contract.v1.schema.json');(out/'contract.json').write_bytes(contract_bytes(c))
shutil.copyfile(root/'env/refdata_registry.json',out/'registry.json')
subprocess.run(['Rscript',str(pathlib.Path(__file__).with_name('make_inputs.R')),str(out)],check=True)
def wr(name,ids):
 with (out/name).open('w') as f:w=csv.writer(f);w.writerow(['gene_id']);w.writerows([[x] for x in ids])
q=[r['gene_id'] for r in csv.DictReader((out/'selected.csv').open())];u=[r['gene_id'] for r in csv.DictReader((out/'universe.csv').open())]
wr('duplicate.csv',q+[q[0]]);wr('bad-id.csv',['001']+q[1:]);wr('not-subset.csv',q+['999999999']);wr('same.csv',u)
p=json.loads((out/'provenance.json').read_text());p['sha256']='0'*64;(out/'bad-sha.json').write_text(json.dumps(p));p=json.loads((out/'provenance.json').read_text());p['species']='Mus musculus';(out/'wrong-species.json').write_text(json.dumps(p));p=json.loads((out/'provenance.json').read_text());del p['licence'];(out/'no-licence.json').write_text(json.dumps(p))
e=json.loads((out/'registry.json').read_text());next(x for x in e['entries'] if x['id']=='reactome_gene_sets')['consumers']=[];(out/'wrong-consumer.json').write_text(json.dumps(e))

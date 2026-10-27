import pathlib,subprocess,sys,json,shutil
root=pathlib.Path(__file__).resolve().parents[3];out=pathlib.Path(sys.argv[1]);out.mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(root/'mcp'))
from study_contract import build_contract,contract_bytes
c=build_contract(design='Synthetic published CoxExample numerical fixture with fixed supplied ten-fold split; potential external validation uses frozen coefficients',biological_unit='One independent simulated subject per matrix column',population='1000 subjects in upstream glmnet CoxExample simulation, not real gene-expression patients',comparison={'target':'Prespecified thirty-feature penalized Cox risk score','measure':'Frozen linear predictor and IPCW AUC','exposure':'Continuous simulated feature vector','comparator':'Lower predicted risk'},outcomes=[{'name':'Simulated event','timepoint':'Right-censored simulation follow-up'}],covariates=[],missing_data='Reject missing events, identities and selected feature values',multiplicity='Prediction development only; no post-selection coefficient p-values; training AUC labelled apparent',analysis_sets=['Published training simulation','Independent simulated validation fixture with frozen coefficients'],schema_path=root/'skills/_shared/schemas/study_contract.v1.schema.json')
(out/'contract.json').write_bytes(contract_bytes(c))
subprocess.run(['Rscript',str(pathlib.Path(__file__).with_name('make_inputs.R')),str(out)],check=True)
cfg=json.loads(pathlib.Path(__file__).with_name('acceptance.json').read_text())['chain']['upstream']
a=[v.replace('{fixtures}',str(out)).replace('{outdir}',str(out/'upstream')) for v in cfg['argv']]
subprocess.run(['Rscript',str(root/'skills/limma-array'/cfg['script']),*a],check=True)
for kind in ['batch','display','wrong-type','tampered']:
 dest=out/kind;shutil.copytree(out/'upstream',dest);p=dest/'objects/handoff.json';h=json.loads(p.read_text())
 if kind=='batch':h['state']['batch_corrected_lineage']=True
 if kind=='display':h['state']['display_only']=True
 if kind=='wrong-type':
  for o in h['objects']:
   if o['type']=='expression_matrix':o['type']='count_matrix'
 if kind=='tampered':h['objects'][0]['sha256']='0'*64
 p.write_text(json.dumps(h)+'\n')

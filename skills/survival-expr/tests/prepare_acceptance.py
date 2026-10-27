import pathlib,subprocess,sys,json,shutil
root=pathlib.Path(__file__).resolve().parents[3];out=pathlib.Path(sys.argv[1]);out.mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(root/'mcp'))
from study_contract import build_contract,contract_bytes
c=build_contract(design='Entirely synthetic expression-survival software validation; no measured people or package datasets',biological_unit='One independently generated artificial unit per expression column',population='160 synthetic units generated with seed9182; no observed patient data',comparison={'target':'Continuous SIM_SIGNAL effect adjusted for two artificial covariates','measure':'Hazard ratio per synthetic unit','exposure':'Randomly generated continuous SIM_SIGNAL','comparator':'One synthetic unit lower'},outcomes=[{'name':'Simulated event','timepoint':'Independently generated event and censoring times in arbitrary units'}],covariates=['covar1','covar2'],missing_data='No exclusions in generated canonical fixture; the module refuses missing input',multiplicity='One prespecified synthetic signal Cox model; one displayed median KM diagnostic; PH diagnostics not selection',analysis_sets=['All160 artificial units retained'],schema_path=root/'skills/_shared/schemas/study_contract.v1.schema.json')
(out/'contract.json').write_bytes(contract_bytes(c))
subprocess.run(['Rscript',str(pathlib.Path(__file__).with_name('make_inputs.R')),str(out)],check=True)
cfg=json.loads(pathlib.Path(__file__).with_name('acceptance.json').read_text())['chain']['upstream']
a=[v.replace('{fixtures}',str(out)).replace('{outdir}',str(out/'upstream')) for v in cfg['argv']]
subprocess.run(['Rscript',str(root/'skills/limma-array'/cfg['script']),*a],check=True)
from prepare_port_fixture import extend_generated_fixture
extend_generated_fixture(out)
for kind in ['batch','display','candidate','wrong-type','tampered']:
 dest=out/kind;shutil.copytree(out/'upstream',dest);p=dest/'objects/handoff.json';h=json.loads(p.read_text())
 if kind=='batch':h['state']['batch_corrected_lineage']=True
 if kind=='display':h['state']['display_only']=True
 if kind=='candidate':h['state']['candidate']=True
 if kind=='wrong-type':
  for o in h['objects']:
   if o['type']=='expression_matrix':o['type']='count_matrix'
 if kind=='tampered':h['objects'][0]['sha256']='0'*64
 p.write_text(json.dumps(h)+'\n')

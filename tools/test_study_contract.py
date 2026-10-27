import copy,hashlib,json,pathlib,shutil,subprocess,sys,tempfile,unittest
ROOT=pathlib.Path(__file__).resolve().parents[1];sys.path[:0]=[str(ROOT/'mcp'),str(ROOT/'skills/_shared/py')]
from study_contract import build_contract,contract_bytes
from ospy.study_contract import read_study_contract,bind_args,bound_hash
from ospy import args as A,handoff as H
from ospy.errors import OmicstatError
FIELDS=dict(design='paired dose experiment',biological_unit='donor',population='All assayed donors',comparison=dict(target='population ED50',measure='concentration ng/mL',exposure='concentration',comparator='lower asymptote'),outcomes=[dict(name='assay response',timepoint='24 h')],covariates=[],missing_data='Refuse missing analysis data',multiplicity='One prespecified ED50',analysis_sets=['All complete donors'])
class EngineContractTests(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.root=pathlib.Path(self.tmp.name);self.path=self.root/'contract.json'
  self.contract=build_contract(**FIELDS,schema_path=ROOT/'skills/_shared/schemas/study_contract.v1.schema.json');self.raw=contract_bytes(self.contract);self.path.write_bytes(self.raw);self.digest=hashlib.sha256(self.raw).hexdigest();bind_args({})
 def tearDown(self):bind_args({});self.tmp.cleanup()
 def test_exact_bytes_schema_and_invalid_inputs(self):
  self.assertEqual(read_study_contract(self.path)['sha256'],self.digest)
  for field,value in [('study_design',''),('outcomes',[]),('analysis_sets',[]),('covariates',['']),('schema_version','wrong'),('semantic_declarations',{})]:
   x=copy.deepcopy(self.contract);x[field]=value;self.path.write_text(json.dumps(x))
   with self.subTest(field=field),self.assertRaises(OmicstatError):read_study_contract(self.path)
 def test_duplicate_nonfinite_and_symlink_refused(self):
  for raw in ['{"x":NaN}','{"x":1,"x":2}','[]']:
   self.path.write_text(raw)
   with self.assertRaises(OmicstatError):read_study_contract(self.path)
  link=self.root/'link.json';link.symlink_to(self.path)
  with self.assertRaises(OmicstatError):read_study_contract(link)
 def test_hash_only_and_mismatch_and_mutation(self):
  with self.assertRaisesRegex(OmicstatError,'OS_MISSING_PARAMETER'):bind_args({'study-contract-sha256':self.digest})
  with self.assertRaisesRegex(OmicstatError,'OS_CONTRACT_MISMATCH'):read_study_contract(self.path,{'contract_hash':'0'*64})
  bind_args({'study-contract':str(self.path)});self.assertEqual(bound_hash(),self.digest)
  self.path.write_bytes(self.raw+b'\n')
  with self.assertRaisesRegex(OmicstatError,'OS_CONTRACT_MISMATCH'):bound_hash()
 def test_real_python_handoff_binding_and_reset(self):
  spec=A.os_arg_spec('test',[A.os_flag('outdir','path')]);A.os_parse_args(spec,['--study-contract',str(self.path)])
  out=self.root/'run';(out/'objects').mkdir(parents=True);data=out/'objects/x.csv';data.write_text('x\n1\n')
  H.write_handoff(out,'test','synthetic-test','0.1',{'x':{'path':data,'type':'feature_table'}})
  self.assertEqual(json.loads((out/'objects/handoff.json').read_text())['contract_hash'],self.digest)
  A.os_parse_args(spec,[]);self.assertIsNone(bound_hash())
 @unittest.skipUnless(shutil.which('Rscript'),'actual Rscript required')
 def test_real_r_helper_hash_refusal_handoff_and_help_parity(self):
  script=self.root/'probe.R';result=self.root/'result.json'
  script.write_text('''a <- commandArgs(TRUE)
source(file.path(a[1], "skills/_shared/scripts/args.R"))
source(file.path(a[1], "skills/_shared/scripts/module_kit.R"))
source(file.path(a[1], "skills/_shared/scripts/handoff.R"))
spec <- os_arg_spec("test", list(os_flag("outdir", "path")))
v <- os_parse_args(spec, c("--study-contract", a[2]))
r <- os_study_contract_read(a[2]);stopifnot(identical(r$sha256,a[4]))
err <- tryCatch({os_study_contract_read(a[2],upstream=list(contract_hash=paste(rep("0",64),collapse="")));""}, error=conditionMessage)
stopifnot(grepl("OS_CONTRACT_MISMATCH",err,fixed=TRUE))
run <- file.path(dirname(a[3]),"r-run");dir.create(file.path(run,"objects"),recursive=TRUE)
f <- file.path(run,"objects/x.csv");writeLines(c("x","1"),f)
write_handoff(run,"probe","synthetic-test","0.1",list(x=list(path=f,type="feature_table")))
h <- jsonlite::fromJSON(file.path(run,"objects/handoff.json"));stopifnot(identical(h$contract_hash,a[4]))
os_parse_args(spec,character());stopifnot(is.null(os_study_contract_bound_hash()))
jsonlite::write_json(os_help(spec),a[3],auto_unbox=FALSE)
''')
  p=subprocess.run(['Rscript',str(script),str(ROOT),str(self.path),str(result),self.digest],capture_output=True,text=True)
  self.assertEqual(p.returncode,0,p.stdout+p.stderr);spec=A.os_arg_spec('test',[A.os_flag('outdir','path')]);self.assertEqual(json.loads(result.read_text()),A.os_help(spec))
if __name__=='__main__':unittest.main()

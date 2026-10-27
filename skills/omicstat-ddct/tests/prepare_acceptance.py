import pathlib,json,csv,copy,sys,shutil
root=pathlib.Path(__file__).resolve().parents[3];out=pathlib.Path(sys.argv[1]);out.mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(root/'mcp'))
from study_contract import build_contract,contract_bytes
contract=build_contract(design='Livak Table 1 technical-repeat normalization demonstration; descriptive only',biological_unit='One tissue RNA preparation per tissue; each gene has six technical wells',population='Published Table 1 brain and kidney RNA preparations',comparison={'target':'c-myc Kidney relative to Brain','measure':'2^(-delta-delta-Ct) normalized relative quantity','exposure':'Kidney','comparator':'Brain'},outcomes=[{'name':'Ct cycles for c-myc and GAPDH','timepoint':'Published Table 1 qPCR assay'}],covariates=[],missing_data='Refuse undetermined, missing, nonpositive or over-limit Ct; no imputation',multiplicity='One descriptive comparison; no inferential p-values or biological confidence intervals',analysis_sets=['All 24 source PCR well records'],schema_path=root/'skills/_shared/schemas/study_contract.v1.schema.json')
(out/'contract.json').write_bytes(contract_bytes(contract))
assay={'schema':'omicstat.qpcr-assay.v1','target_genes':['c-myc'],'reference_gene':'GAPDH','equal_efficiency_confirmed':True,'near_two_amplification_confirmed':True,'reference_stability_confirmed':True,'source':'Livak and Schmittgen2001 DOI10.1006/meth.2001.1262, sections1.2-1.4; Table1 normalization example','basis':'Published demonstration assumes equal near-two amplification and GAPDH normalization. This fixture declaration is not a new measured efficiency experiment or biological reference-stability validation.'}
(out/'assay.json').write_text(json.dumps(assay,indent=2)+'\n')
bad=copy.deepcopy(assay);bad['equal_efficiency_confirmed']=False;(out/'invalid-assay.json').write_text(json.dumps(bad)+'\n')
shutil.copy2(pathlib.Path(__file__).with_name('livak_table1.csv'),out/'livak.csv')
with (out/'livak.csv').open() as f:reader=csv.DictReader(f);fields=reader.fieldnames;rows=list(reader)
def save(name,rows):
 with (out/name).open('w') as f:w=csv.DictWriter(f,fieldnames=fields);w.writeheader();w.writerows(rows)
for name,col,value in [('undetermined.csv','ct','Undetermined'),('overlimit.csv','ct','41'),('zero.csv','ct','0'),('blank-unit.csv','unit','')]:
 x=copy.deepcopy(rows);x[0][col]=value;save(name,x)
save('duplicate.csv',rows+[rows[0]])
save('missing-ref.csv',[x for x in rows if not (x['group']=='Kidney' and x['gene']=='GAPDH')])

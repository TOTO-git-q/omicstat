"""Reproduce the exact source fixture RNG order; no golden/lock writes."""
import copy,csv,json,pathlib,subprocess,sys
root=pathlib.Path(__file__).resolve().parents[2];module=sys.argv[1];out=pathlib.Path(sys.argv[2]).resolve();out.mkdir(parents=True,exist_ok=True)
def run(args):subprocess.run(args,cwd=root,check=True)
run([sys.executable,str(root/'tests/candidate-models/prepare_contract.py'),str(out)])
run(['Rscript','tests/candidate-models/'+('make_scope_inputs.R' if module in ('drc-calibrate','nlme-dose') else 'make_experimental_inputs.R'),str(out)])
def edit(source,dest,fn):
 with (out/source).open() as f:r=csv.DictReader(f);fields=r.fieldnames;rows=list(r)
 fn(rows)
 with (out/dest).open('w') as f:w=csv.DictWriter(f,fieldnames=fields);w.writeheader();w.writerows(rows)
def setcell(col,value):return lambda rows:rows[0].__setitem__(col,value)
def allcell(col,value):return lambda rows:[x.__setitem__(col,value) for x in rows]
if module in ('drc-calibrate','nlme-dose'):
 edit('plate.csv','cal-duplicate-well.csv',lambda r:r[1].__setitem__('well',r[0]['well']))
 edit('repeated.csv','nl-duplicate.csv',lambda r:r.append(copy.deepcopy(r[0])))
 edit('repeated.csv','nl-zero.csv',setcell('dose','0'))
 edit('repeated.csv','nl-one-subject.csv',allcell('subject','one'))
else:
 for name,fn in [('duplicate-unit',lambda r:r[1].__setitem__('biological_id',r[0]['biological_id'])),('missing-unit',setcell('biological_id',' ')),('negative-dose',setcell('dose','-1')),('bad-response',setcell('OD','bad'))]:edit('elisa_curated.csv','drc-'+name+'.csv',fn)
 for name,fn in [('missing-response',setcell('Reaction','NA')),('blank-subject',setcell('Subject',' ')),('one-subject',allcell('Subject','one'))]:edit('sleepstudy.csv','lmm-'+name+'.csv',fn)
 edit('samples.csv','pd-duplicate-biology.csv',lambda r:r[1].__setitem__('biological_id',r[0]['biological_id']))
 edit('samples.csv','pd-missing-condition.csv',setcell('condition',''))
 def complete_zero(rows):
  # The refusal concerns upstream's zero-to-NA rewrite ONLY for complete data.
  for row in rows:
   for key in list(row)[1:]:
    if row[key] in ('NA',''):row[key]='22'
  rows[0][list(rows[0])[1]]='0'
 edit('proteins.csv','pd-zero.csv',complete_zero)
 for name,fn in [('duplicate-feature',lambda r:r.append(copy.deepcopy(r[0]))),('ambiguous-peptide',lambda r:[x.__setitem__('PeptideModifiedSequence',x['PeptideModifiedSequence'].split('_',1)[1]) for x in r]),('invalid-charge',setcell('PrecursorCharge','1.5')),('heavy-label',setcell('IsotopeLabelType','H')),('one-biorep',allcell('BioReplicate','one')),('negative-intensity',setcell('Intensity','-1'))]:edit('msstats_long.csv','ms-'+name+'.csv',fn)
 if module=='emmeans-contrast':
  args=json.loads((root/'tests/candidate-models/canonical_commands.json').read_text())['lme4-lmm']
  args=[a.replace('{fixtures}',str(out)).replace('{outdir}',str(out/'upstream')) for a in args]
  run(['Rscript','skills/lme4-lmm/scripts/run_lme4_lmm.R',*args])

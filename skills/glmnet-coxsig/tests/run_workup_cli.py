"""Actual R CLI/replay/refusal runner; real missing dependencies fail, never skip.

Official CoxExample is an upstream simulated software fixture, not real biological
owner evidence. An independent validation cohort is invented by a fixed R seed.
"""
from __future__ import annotations
import argparse
import csv
import hashlib
import json
import pathlib
import shutil
import subprocess
import sys

HERE=pathlib.Path(__file__).resolve().parent
ROOT=HERE.parents[2]
ENTRY=ROOT/'skills/glmnet-coxsig/scripts/run_glmnet_coxsig.R'


def replace(argv,key,value):
    argv=list(argv)
    if key in argv:
        i=argv.index(key)
        if value is None: del argv[i:i+2]
        else: argv[i+1]=str(value)
    elif value is not None: argv.extend([key,str(value)])
    return argv


def scenarios():
    legacy=json.loads((HERE/'acceptance.json').read_text())['canonical']['argv']
    training=legacy+['--prediction-workup','cpm','--dataset-name','Official glmnet CoxExample simulation, not biological owner evidence',
        '--planning-source','Invented prior assumptions for wrapper contract only', '--planning-parameters','30',
        '--planning-cs-r2','.1','--planning-shrinkage','.9','--planning-rate','.1','--planning-horizon','2','--planning-mean-followup','10',
        '--bootstrap-B','200','--bootstrap-seed','19021','--bootstrap-fit-policy','penalized-pipeline',
        '--baseline-estimator','frozen-offset-breslow','--calibration-horizon','2','--calibration-min-bin','20','--calibration-max-bins','5',
        '--calibration-slope-fit','source-native']
    external=list(legacy)
    for key in ('folds','standardize','nlambda','lambda-min-ratio','selection','lambda','cv-measure','cv-grouped','max-iter','thresh','cox-ties','cutoff','cutpoint'):
        external=replace(external,'--'+key,None)
    for key,value in (('--mode','validate'),('--from-run','{external}/upstream'),('--clinical','{external}/clinical.csv'),('--risk-times','0,1,2'),('--signature-run','{training}')):
        external=replace(external,key,value)
    external+=['--prediction-workup','cpm','--dataset-name','Project-invented independent seed19022 contract cohort']
    return {'legacy':legacy,'training':training,'external':external}


def refusal_cases():
    s=scenarios();t=s['training'];e=s['external']
    rows=[('workup-inactive',s['legacy']+['--dataset-name','invented'],'OS_INVALID_PARAMETER'),
      ('workup-no-dataset',replace(t,'--dataset-name',None),'OS_MISSING_PARAMETER'),
      ('workup-no-prior-source',replace(t,'--planning-source',None),'OS_MISSING_PARAMETER'),
      ('workup-no-budget',replace(t,'--bootstrap-B',None),'OS_MISSING_PARAMETER'),
      ('workup-no-policy',replace(t,'--bootstrap-fit-policy',None),'OS_MISSING_PARAMETER'),
      ('workup-shrinkage-one',replace(t,'--planning-shrinkage','1'),'OS_INVALID_PARAMETER'),
      ('workup-r2-above-shrinkage',replace(t,'--planning-cs-r2','.95'),'OS_INVALID_PARAMETER'),
      ('workup-nonpositive-rate',replace(t,'--planning-rate','0'),'OS_INVALID_PARAMETER'),
      ('workup-horizon-disagrees',replace(t,'--planning-horizon','3'),'OS_INVALID_PARAMETER'),
      ('workup-bootstrap-below-floor',replace(t,'--bootstrap-B','199'),'OS_INVALID_PARAMETER'),
      ('workup-bootstrap-budget',replace(t,'--bootstrap-B','2001'),'OS_RESOURCE_LIMIT'),
      ('workup-bin-small',replace(t,'--calibration-min-bin','9'),'OS_INVALID_PARAMETER'),
      ('workup-too-many-bins',replace(t,'--calibration-max-bins','11'),'OS_INVALID_PARAMETER'),
      ('workup-no-model-substitution',replace(t,'--bootstrap-fit-policy','unpenalized-rms'),'OS_INVALID_PARAMETER'),
      ('workup-no-baseline-recalibration',replace(t,'--baseline-estimator','refit'),'OS_INVALID_PARAMETER'),
      ('workup-candidate-parameter-count',replace(t,'--planning-parameters','1'),'OS_INVALID_PARAMETER'),
      ('workup-horizon-outside-support',replace(replace(t,'--planning-horizon','1000000'),'--calibration-horizon','1000000'),'OS_INVALID_PARAMETER'),
      ('workup-external-replan',e+['--planning-source','changed'],'OS_CONFLICTING_PARAMETERS'),
      ('workup-external-move-horizon',e+['--calibration-horizon','3'],'OS_CONFLICTING_PARAMETERS'),
      ('workup-external-rebin',e+['--calibration-min-bin','10'],'OS_CONFLICTING_PARAMETERS'),
      ('workup-external-no-baseline',replace(e,'--signature-run','{legacy}'),'OS_HANDOFF_MISMATCH')]
    return rows


def table_bytes(run):
    return {p.name:p.read_bytes() for p in sorted((run/'tables').glob('*.csv'))}


def run(output):
    rscript=shutil.which('Rscript')
    if not rscript:
        print('BLOCKED: Rscript absent; actual R4.6.1 workup/CLI/replay/refusal/figure tests not executed',file=sys.stderr)
        return 127
    output=pathlib.Path(output).resolve()
    if output.exists(): raise ValueError('new evidence directory required; do not overwrite previous attempts')
    output.mkdir(parents=True)
    state={'schema':'omicstat.cpm-workup-native-contract.v1','state':'running','native_executed':False,'owner_visual_review':None,'real_owner_anchor_passed':False,'synthetic_contract_only':True,'checks':[]}
    def checkpoint(): (output/'CHECKPOINT.json').write_text(json.dumps(state,indent=2)+'\n')
    def execute(label,argv,code=None):
        result=subprocess.run(argv,cwd=ROOT,text=True,capture_output=True)
        log=result.stdout+result.stderr;(output/(label+'.log')).write_text(log)
        ok=result.returncode==0 if code is None else result.returncode!=0 and code in log
        state['checks'].append({'name':label,'argv':argv,'exit':result.returncode,'expected_code':code,'passed':ok,'log_sha256':hashlib.sha256(log.encode()).hexdigest()})
        checkpoint()
        if not ok: raise RuntimeError(label+' failed; original log retained')
    checkpoint()
    try:
        execute('native-source-contracts',[rscript,str(HERE/'test_cpm_port.R'),str(ROOT)])
        state['native_executed']=True;checkpoint()
        fixtures=output/'fixtures';external=output/'external-fixture'
        execute('prepare-original',[sys.executable,str(HERE/'prepare_acceptance.py'),str(fixtures)])
        execute('inherited-smoke',[rscript,str(HERE/'run_smoke_test.R')])
        substitutions={'{fixtures}':str(fixtures),'{external}':str(external),'{training}':str(output/'training'),'{legacy}':str(output/'legacy')}
        def args(argv,target):
            values=[]
            for v in argv:
                for key,value in substitutions.items():v=v.replace(key,value)
                values.append(v.replace('{outdir}',str(target)))
            return values
        tables={}
        for name,argv in scenarios().items():
            if name=='external':
                execute('make-invented-validation',[rscript,str(HERE/'make_workup_external.R'),str(external),str(output/'training')])
                cfg=json.loads((HERE/'acceptance.json').read_text())['chain']['upstream']
                producer=[v.replace('{fixtures}',str(external)).replace('{outdir}',str(external/'upstream')) for v in cfg['argv']]
                producer=replace(producer,'--preprocessing','Project-invented independent seed19022 software validation cohort')
                execute('actual-validation-producer',[rscript,str(ROOT/'skills/limma-array'/cfg['script']),*producer])
            target=output/name
            execute(name,[rscript,str(ENTRY),*args(argv,target)])
            before=table_bytes(target)
            if not before:raise AssertionError('no numeric tables')
            replay=output/(name+'-replay')
            execute(name+'-replay',[rscript,str(ENTRY),'--spec',str(target/'provenance/resolved_spec.json'),'--outdir',str(replay)])
            if before!=table_bytes(replay):raise AssertionError(name+' numerical replay bytes changed')
            if name!='legacy':
                specs=list((target/'figures').glob('*.figure_spec.json'))
                if not specs:raise AssertionError('no actual figure specs')
                for path in specs:
                    figure=json.loads(path.read_text())
                    if 'Dataset:' not in figure['caption']:raise AssertionError('dataset label absent')
                with (target/'tables/calibration_performance.csv').open(newline='') as f:perf=list(csv.DictReader(f))
                if len(perf)!=1 or perf[0]['prediction_model_refitted'].upper()!='FALSE':raise AssertionError('external diagnostic refitted prediction model')
            tables[name]={k:hashlib.sha256(v).hexdigest() for k,v in before.items()}
        for name,value in table_bytes(output/'legacy').items():
            if table_bytes(output/'training').get(name)!=value:raise AssertionError('optional workup altered original scientific table '+name)
        train_object=(output/'training/objects/model.rds').read_bytes()
        if train_object!=(output/'external/objects/model.rds').read_bytes():raise AssertionError('external validation changed frozen signature bytes')
        with (HERE/'refusals.csv').open(newline='') as f:cases=list(csv.DictReader(f))
        for row in cases:
            execute('refusal-'+row['case'],[rscript,str(ENTRY),*args(json.loads(row['argv']),output/('refused-'+row['case']))],code=row['expected_code'])
        state.update(state='passed_software_contracts_only',tables=tables,refusal_count=len(cases),numerical_replay_exact=True,original_tables_unchanged=True,external_prediction_object_unchanged=True,exact_new_dependency_closure_verified=False)
        checkpoint();(output/'RESULT.json').write_text(json.dumps(state,indent=2)+'\n');print(json.dumps(state));return 0
    except Exception as error:
        state.update(state='failed',error=str(error));checkpoint();raise


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--out',required=True);raise SystemExit(run(p.parse_args().out))

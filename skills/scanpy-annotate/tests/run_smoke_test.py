#!/usr/bin/env python3
"""Locked synthetic display replay, guardrails and generated computed golden."""
import sys,json,tempfile,os,subprocess
from pathlib import Path
MODULE=Path(__file__).resolve().parent.parent
ROOT=MODULE.parent.parent
sys.path.insert(0,str(ROOT/'tools'));sys.path.insert(0,str(ROOT/'skills/_shared/py'));sys.path.insert(0,str(ROOT/'skills/_shared/py/tests'))
from check_calls import check_calls,check_default_drift
from seal_python import require_locked_environment
from ospy import handoff as H,sc_module as S,figure_request as F
from sc_smoke_support import run,common,cluster_args,load,snapshot_tables,compare_snapshots,golden,negative_chain_tests

def main():
    reg=MODULE/'scripts/calls_registry.json'
    assert check_calls(list((MODULE/'scripts').glob('*.py')),reg)['ok']
    for tool in ('check_defaults.py','check_flag_docs.py'):subprocess.run([sys.executable,str(ROOT/'tools'/tool),str(MODULE)],check=True)
    try:require_locked_environment()
    except RuntimeError:
        if os.environ.get('OMICSTAT_REQUIRE_LOCKED')=='1':raise
        print('SKIP: numerical display smoke requires pinned Python image');return 0
    assert check_default_drift(reg)['ok']
    import numpy as np,pandas as pd,anndata as ad,scanpy as sc
    from scipy.spatial.distance import cdist
    from scipy import sparse
    from sklearn.cluster import DBSCAN
    from ospy.display import largest_island_medians
    base=Path(os.environ.get('OMICSTAT_TEST_TMP','/tmp'));base.mkdir(parents=True,exist_ok=True)
    work=Path(tempfile.mkdtemp(prefix=MODULE.name+'_',dir=base));print('Acceptance workspace:',work,flush=True)
    rng=np.random.default_rng(20260925);labels=np.repeat(['A','B'],40)
    counts=rng.poisson(2,(80,40)).astype('float32');counts[:40,:3]+=20;counts[40:,3:6]+=20
    raw=ad.AnnData(sparse.csr_matrix(counts),obs=pd.DataFrame({'sample':np.tile(['s1','s2'],40),'batch':np.tile(['s1','s2'],40),'truth':labels},index=['c%d'%i for i in range(80)]),var=pd.DataFrame(index=['g%d'%i for i in range(40)]))
    raw.obsm['X_known']=np.c_[np.repeat([0,10],40)+rng.normal(0,.2,80),rng.normal(0,.2,80)].astype('float32')
    raw_path=work/'raw.h5ad';raw.write_h5ad(raw_path)
    source=work/'upstream';run('scanpy-cluster',common(raw_path,source)+['--n-hvg',20,'--n-pcs',5,'--n-neighbors',8,'--resolution',.5,'--use-rep','X_known'])
    before=load(source);before.obs['manual_cluster']=pd.Categorical(labels)
    before.write_h5ad(source/'objects/adata.h5ad')
    # Rebuild fixture handoff through the real helper after adding the declared evidence column.
    h=json.loads((source/'objects/handoff.json').read_text())
    H.write_handoff(str(source),'fixture', 'scanpy-cluster','1.1.0',{'adata':{'path':str(source/'objects/adata.h5ad'),'type':'AnnData'}},ecosystem='scverse',state=h['state'])
    panel=work/'panel.json';panel.write_text(json.dumps({'A':{'genes':['g0','g1','g2'],'lineage':'L1','order':0},'B':{'genes':['g3','g4','g5'],'lineage':'L2','order':1}}))
    mapping=work/'map.json';mapping.write_text(json.dumps({'A':'A','B':'B'}))
    annotate=common(source,work/'annotated',True,'counts')+['--cluster-col','manual_cluster','--marker-panel',panel,'--label-map',mapping,'--unresolved-label','Unresolved','--expression-layer','logcounts']
    if MODULE.name=='scanpy-annotate':
        args=list(annotate);args[args.index('--outdir')+1]=work/'anchor'
        run(MODULE.name,args);output=work/'anchor';current=load(output)
        np.testing.assert_array_equal(current.obs.celltype.astype(str),labels)
        table=pd.read_csv(output/'tables/cluster_annotation.csv')
        for i,cl in enumerate(['A','B']):
            np.testing.assert_allclose(table.loc[table.cluster==cl,'score:'+cl],before.layers['logcounts'][labels==cl,i*3:i*3+3].toarray().astype('float64').mean(),atol=1e-12,rtol=1e-12)
        unmapped=common(source,work/'unresolved',True,'counts')+['--cluster-col','manual_cluster','--marker-panel',panel,'--unresolved-label','Unresolved','--expression-layer','logcounts']
        run(MODULE.name,unmapped);assert (load(work/'unresolved').obs.celltype=='Unresolved').all()
        capped=list(args);capped[capped.index('--outdir')+1]=work/'capped';capped+=['--display-max-per-group',5,'--label-placement','largest-island','--label-island-eps',1,'--label-island-min-samples',2]
        run(MODULE.name,capped);capdata=load(work/'capped');assert capdata.n_obs==current.n_obs
        assert (output/'tables/cluster_annotation.csv').read_bytes()==(work/'capped/tables/cluster_annotation.csv').read_bytes()
        req=json.loads((work/'capped/figure_data/figure_request.json').read_text());assert req['figures'][0]['data']['emb']['n_rows']==10
        assert 'label_xy' in req['figures'][0]['data']
    else:
        run('scanpy-annotate',annotate);source=work/'annotated';before=load(source)
        if MODULE.name=='scanpy-purity':
            args=common(source,work/'anchor',True,'counts')+['--label-col','celltype','--graph-key','neighbors','--purity-threshold',.6,'--embedding-neighbors',5,'--embedding-purity-threshold',.6,'--island-eps',100,'--island-min-samples',2,'--island-min-size',3]
            run(MODULE.name,args);output=work/'anchor';current=load(output)
            table=pd.read_csv(output/'tables/purity.csv');graph=before.obsp['connectivities'].toarray();np.fill_diagonal(graph,0)
            expected=np.array([(labels[np.flatnonzero(row)]==labels[i]).mean() if np.any(row) else 0 for i,row in enumerate(graph)])
            np.testing.assert_allclose(table.purity,expected,atol=1e-12,rtol=1e-12)
            dist=cdist(before.obsm['X_umap'],before.obsm['X_umap']);np.fill_diagonal(dist,np.inf)
            expected=(labels[np.argsort(dist,axis=1,kind='stable')[:,:5]]==labels[:,None]).mean(1)
            np.testing.assert_allclose(table.embedding_purity,expected,atol=1e-12,rtol=1e-12)
            assert current.n_obs==before.n_obs and H.read_handoff(str(output))['state']['display_only'] is True
            marker=common(output,work/'refused_marker',True,'counts')+['--cluster-col','manual_cluster','--expression-layer','logcounts','--purpose','cluster-description']
            run('scanpy-markers',marker,error='OS_DISPLAY_ONLY_INPUT')
            cells = work/'marker_selection.csv'; pd.DataFrame({'cell':before.obs_names[:20]}).to_csv(cells,index=False)
            selected = common(source,work/'refused_selected_marker',True,'counts') + ['--cell-list',cells,'--cluster-col','manual_cluster','--expression-layer','logcounts','--purpose','cluster-description']
            run('scanpy-markers',selected,error='OS_DISPLAY_ONLY_INPUT')
            direct=common(output/'objects/adata.h5ad',work/'refused_direct',False,'counts')+['--cluster-col','manual_cluster','--expression-layer','logcounts','--purpose','cluster-description']
            run('scanpy-markers',direct,error='OS_DISPLAY_ONLY_INPUT')
        else:
            refids=work/'ref.csv';pd.DataFrame({'cell':before.obs_names[::2]}).to_csv(refids,index=False)
            ref=work/'reference';run('scanpy-cluster',common(source,ref,True,'counts')+['--cell-list',refids,'--n-hvg',20,'--n-pcs',5,'--n-neighbors',8,'--resolution',.5,'--use-rep','X_known'])
            queryids=work/'query.csv';pd.DataFrame({'cell':before.obs_names[1::2]}).to_csv(queryids,index=False)
            args=common(source,work/'anchor',True,'counts')+['--reference-run',ref,'--query-run',source,'--cell-list',queryids,'--label-col','celltype','--neighbors-key','neighbors','--n-neighbors',8]
            run(MODULE.name,args);output=work/'anchor';current=load(output);reference=load(ref)
            replay_query=before[before.obs_names[1::2]].copy();replay_ref=reference.copy()
            for dataset in (replay_ref,replay_query):dataset.obsm['X_known']=np.ascontiguousarray(dataset.obsm['X_known'],dtype=np.float32)
            replay_ref.obsm['X_umap']=np.ascontiguousarray(replay_ref.obsm['X_umap'],dtype=np.float32)
            fixed=replay_ref.obsm['X_umap'].copy()
            sc.tl.ingest(replay_query,replay_ref,obs=None,embedding_method='umap',neighbors_key='neighbors',k=8,random_state=20260925)
            np.testing.assert_array_equal(current.obsm['X_umap'],replay_query.obsm['X_umap']);np.testing.assert_array_equal(fixed,replay_ref.obsm['X_umap'])
            stored=pd.read_csv(output/'tables/reference_coordinates.csv');np.testing.assert_allclose(stored[['x','y']],fixed,atol=1e-12,rtol=1e-12)
            distances=cdist(current.obsm['X_known'],reference.obsm['X_known']);neighbors=np.argsort(distances,axis=1)[:,:8]
            fractions=(reference.obs.celltype.astype(str).to_numpy()[neighbors]==current.obs.celltype.astype(str).to_numpy()[:,None]).mean(1)
            np.testing.assert_array_equal(pd.read_csv(output/'tables/projected_cells.csv').same_label_reference_fraction,fractions)
    assert F.validate_request(str(output))==[]
    replay=work/'replay';run(MODULE.name,['--spec',output/'provenance/resolved_spec.json','--outdir',replay])
    sa,sb=work/'snapshot_a',work/'snapshot_b';snapshot_tables(output,sa);snapshot_tables(replay,sb);compare_snapshots(sa,sb)
    golden(MODULE,output,sa,os.environ.get('OMICSTAT_WRITE_GOLDEN')=='1')
    print('PASS: numerical oracle, display guardrails, deterministic replay and computed golden');return 0
if __name__=='__main__':raise SystemExit(main())

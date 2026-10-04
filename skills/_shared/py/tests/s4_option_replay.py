"""Closed S3 repairs: independent native replay of default and alternate bindings."""
import json
from pathlib import Path
import numpy as np
import pandas as pd
import scanpy as sc
from sc_smoke_support import load, run, SEED, ATOL, RTOL
from ospy.seed import set_seed
from ospy.sc_module import canonical_pca, canonical_clusters


def summary(module, out):
    return json.loads((out / 'results' / (module.replace('-', '_') + '_results.json')).read_text())


def options_for(options, names, prefix=''):
    # The test uses recorded native values, independently calls the API and
    # compares its outputs. CLI-to-native conversion is checked below as well.
    return {name: options[(prefix + '-' if prefix else '') + name.replace('_', '-')]
            for name in names.split()}


def graph_umap(replay, observed, p, o, rep, key=None):
    sc.pp.neighbors(replay, n_neighbors=p['n-neighbors'], n_pcs=p.get('n-pcs'), use_rep=rep,
                    random_state=SEED, key_added=key,
                    **options_for(o, 'method metric metric_kwds transformer', 'neighbors'))
    suffix = key + '_' if key else ''
    for slot in ('connectivities', 'distances'):
        np.testing.assert_allclose(replay.obsp[suffix+slot].toarray(), observed.obsp[suffix+slot].toarray(), atol=ATOL, rtol=RTOL)
    sc.tl.umap(replay, min_dist=p['min-dist'], random_state=SEED, neighbors_key=key,
               **options_for(o, 'spread maxiter alpha gamma negative_sample_rate init_pos a b', 'umap'))
    np.testing.assert_allclose(replay.obsm['X_umap'], observed.obsm['X_umap'], atol=ATOL, rtol=RTOL)


def cluster(source, out):
    previous, observed = load(source), load(out)
    s=summary('scanpy-cluster',out); p,o=s['parameters'],s['native_options']
    set_seed(SEED)
    replay=previous.copy(); replay.X=replay.layers['counts'].copy()
    sc.pp.normalize_total(replay, target_sum=p['target-sum'], key_added='omicstat_size_factor',
                           **options_for(o,'exclude_highly_expressed max_fraction','normalize'))
    sc.pp.log1p(replay, base=o['log1p-base'])
    sc.pp.highly_variable_genes(replay, n_top_genes=p['n-hvg'], batch_key=p['hvg-batch-col'],
                                **options_for(o,'flavor span n_bins','hvg'))
    np.testing.assert_array_equal(replay.var['highly_variable'],observed.var['highly_variable'])
    work=replay[:,replay.var['highly_variable']].copy()
    if p['scale']=='on': sc.pp.scale(work, zero_center=o['scale-zero-center'], max_value=p['scale-max'])
    sc.pp.pca(work, n_comps=p['n-pcs'], random_state=SEED, use_highly_variable=False,
              **options_for(o,'svd_solver zero_center dtype','pca'))
    scores, _=canonical_pca(work.obsm['X_pca'],work.varm['PCs'])
    np.testing.assert_allclose(scores,observed.obsm['X_pca'],atol=ATOL,rtol=RTOL)
    replay.obsm['X_pca']=scores
    graph_umap(replay,observed,p,o,'X_pca')
    partition=o['leiden-partition-type']
    if partition:
        import leidenalg
        partition=getattr(leidenalg,partition.rsplit('.',1)[-1])
    sc.tl.leiden(replay,resolution=p['resolution'],random_state=SEED,directed=False,
                  flavor=p['leiden-flavor'],partition_type=partition,
                  n_iterations=o['leiden-n-iterations'],use_weights=o['leiden-use-weights'])
    labels,_=canonical_clusters(replay.obs['leiden'])
    np.testing.assert_array_equal(labels.astype(str),observed.obs[p['cluster-col']].astype(str))


def markers(source, out):
    replay=load(source); s=summary('scanpy-markers',out); p,o=s['parameters'],s['native_options']
    replay.obs[p['cluster-col']]=pd.Categorical(replay.obs[p['cluster-col']].astype(str), categories=sorted(replay.obs[p['cluster-col']].astype(str).unique()))
    sc.tl.rank_genes_groups(replay,groupby=p['cluster-col'],use_raw=False,method=p['test'],pts=True,
                             layer=p['expression-layer'],key_added='direct',
                             **options_for(o,'reference groups mask_var rankby_abs corr_method tie_correct n_genes'))
    native=sc.get.rank_genes_groups_df(replay,group=None,key='direct')
    csv=pd.read_csv(out/'tables/rank_genes_groups_native.csv',dtype={'group':str,'names':str})
    assert list(csv.columns)==list(native.columns)
    for column in native:
        if pd.api.types.is_numeric_dtype(native[column]): np.testing.assert_allclose(csv[column],native[column],atol=1e-12,rtol=1e-10,equal_nan=True)
        else: assert csv[column].astype(str).tolist()==native[column].astype(str).tolist()
    saved=load(out).uns['omicstat_markers']
    for key in ('names','scores','logfoldchanges','pvals','pvals_adj'):
        for group in saved[key].dtype.names:
            if key=='names': np.testing.assert_array_equal(saved[key][group],replay.uns['direct'][key][group])
            else: np.testing.assert_allclose(saved[key][group],replay.uns['direct'][key][group],atol=1e-12,rtol=1e-10,equal_nan=True)


def qc(out):
    observed=load(out); s=summary('scanpy-qc',out); p,o=s['parameters'],s['native_options']
    # All QC cutoffs in the scoring fixture retain the already verified anchor.
    replay=observed.copy(); replay.X=replay.layers['counts'].copy()
    for key in ('scrublet','doublet_score','predicted_doublet'):
        if key in replay.uns: del replay.uns[key]
        if key in replay.obs: del replay.obs[key]
    set_seed(SEED)
    sc.pp.scrublet(replay,batch_key=p['sample-col'],expected_doublet_rate=p['expected-doublet-rate'],
                   n_prin_comps=p['scrublet-pcs'],threshold=p['doublet-threshold'],verbose=False,random_state=SEED,
                   **options_for(o,'sim_doublet_ratio stdev_doublet_rate synthetic_doublet_umi_subsampling knn_dist_metric normalize_variance log_transform mean_center use_approx_neighbors n_neighbors'))
    np.testing.assert_allclose(observed.obs['doublet_score'],replay.obs['doublet_score'],atol=ATOL,rtol=RTOL)
    np.testing.assert_array_equal(observed.obs['predicted_doublet'],replay.obs['predicted_doublet'])


def vi(source,out):
    import scvi
    replay,observed=load(source),load(out)
    s=summary('scvi-integrate',out); p,o=s['parameters'],s['native_options']
    set_seed(SEED)
    scvi.model.SCVI.setup_anndata(replay,layer='counts',batch_key=p['batch-col'],
                                  **options_for(o,'size_factor_key categorical_covariate_keys continuous_covariate_keys'))
    model=scvi.model.SCVI(replay,n_latent=p['n-latent'],
                          **options_for(o,'n_hidden n_layers dropout_rate dispersion gene_likelihood use_observed_lib_size latent_distribution'))
    model.train(max_epochs=p['max-epochs'],accelerator='cpu',devices=1,batch_size=p['batch-size'],
                 deterministic=True,enable_progress_bar=False,enable_checkpointing=False,logger=None,
                 check_val_every_n_epoch=1,num_sanity_val_steps=0,
                 **options_for(o,'train_size validation_size shuffle_set_split early_stopping plan_kwargs datasplitter_kwargs'))
    replay.obsm['X_scVI']=model.get_latent_representation(replay,batch_size=p['batch-size'])
    np.testing.assert_allclose(replay.obsm['X_scVI'],observed.obsm['X_scVI'],atol=ATOL,rtol=RTOL)
    graph_umap(replay,observed,p,o,'X_scVI','scvi_neighbors')


def va(source,out):
    import scvi
    replay,observed=load(source),load(out)
    s=summary('scanvi-annotate',out); p,o=s['parameters'],s['native_options']
    features=(source/'objects/scvi_model/omicstat_features.txt').read_text().splitlines()
    replay=replay[:,features].copy()
    set_seed(SEED)
    base=scvi.model.SCVI.load(str(source/'objects/scvi_model'),adata=replay,accelerator='cpu',device='auto')
    model=scvi.model.SCANVI.from_scvi_model(base,unlabeled_category=p['unlabeled-category'],labels_key=p['labels-col'],adata=replay)
    model.train(max_epochs=p['max-epochs'],n_samples_per_label=p['samples-per-label'],check_val_every_n_epoch=1,
                 batch_size=p['batch-size'],accelerator='cpu',devices=1,deterministic=True,
                 enable_progress_bar=False,enable_checkpointing=False,logger=False,num_sanity_val_steps=0,
                 **options_for(o,'train_size validation_size shuffle_set_split adversarial_classifier plan_kwargs datasplitter_kwargs'))
    soft=model.predict(replay,soft=True,batch_size=p['batch-size'],use_posterior_mean=o['use-posterior-mean'])
    hard=model.predict(replay,soft=False,batch_size=p['batch-size'],use_posterior_mean=o['use-posterior-mean'])
    csv=pd.read_csv(out/'tables/label_probabilities.csv')
    assert list(csv.columns[1:])==list(soft.columns)
    np.testing.assert_allclose(csv.iloc[:,1:],soft,atol=ATOL,rtol=RTOL)
    np.testing.assert_array_equal(np.asarray(hard).astype(str),observed.obs[p['prediction-col']].astype(str))


def verify(module, source, args, work):
    def alternate(name, values):
        new=list(args); out=work/name; new[new.index('--outdir')+1]=out
        for key,value in values.items():
            key='--'+key
            if key in new: new[new.index(key)+1]=value
            else: new.extend([key,value])
        run(module,new); return out
    if module=='scanpy-qc':
        qc(work/'doublet_score')
        out=alternate('scrublet_options',{'doublet-mode':'score','expected-doublet-rate':0.06,'doublet-threshold':0.2,'scrublet-pcs':10,
            'sim-doublet-ratio':1.5,'stdev-doublet-rate':0.03,'synthetic-doublet-umi-subsampling':0.9,'knn-dist-metric':'manhattan',
            'normalize-variance':'off','log-transform':'on','mean-center':'off','use-approx-neighbors':'off','n-neighbors':15})
        qc(out)
        filtered=alternate('doublet_filter',{'doublet-mode':'filter','expected-doublet-rate':0.06,'doublet-threshold':0.2,'scrublet-pcs':10})
        scored=load(work/'doublet_score')
        expected=scored.obs_names[~scored.obs['predicted_doublet'].to_numpy()]
        assert load(filtered).obs_names.equals(expected)
        pd.testing.assert_frame_equal(pd.read_csv(filtered/'tables/cell_qc.csv').drop(columns='retained'),
                                      pd.read_csv(work/'doublet_score/tables/cell_qc.csv').drop(columns='retained'))
    elif module=='scanpy-cluster':
        cluster(source,work/'anchor')
        cluster(source,alternate('scaled',{'scale':'on'}))
        cluster(source,alternate('native_options',{'normalize-exclude-highly-expressed':'on','normalize-max-fraction':0.1,
            'log1p-base':2,'hvg-flavor':'cell_ranger','hvg-span':0.4,'hvg-n-bins':25,'scale':'on','scale-zero-center':'off',
            'pca-zero-center':'off','pca-svd-solver':'randomized','pca-dtype':'float64','neighbors-method':'gauss',
            'neighbors-metric':'minkowski','neighbors-metric-kwds':'{"p":1}','neighbors-transformer':'sklearn',
            'leiden-n-iterations':2,'leiden-use-weights':'off','leiden-flavor':'leidenalg','leiden-partition-type':'RBConfigurationVertexPartition',
            'umap-spread':1.2,'umap-maxiter':80,'umap-alpha':0.8,'umap-gamma':1.1,'umap-negative-sample-rate':4,
            'umap-init-pos':'random','umap-a':1.5,'umap-b':0.9}))
    elif module=='scanpy-markers':
        markers(source,work/'anchor')
        data=load(source); groups=sorted(data.obs['cluster'].astype(str).unique())
        # Add a Boolean mask to a verified alternative producer, through its engine output.
        # For mask_var, use the native highly_variable column already in the source.
        out=alternate('named_reference',{'test':'wilcoxon','reference':groups[0],'groups':json.dumps(groups[1:]),
            'mask-var':'highly_variable','rankby-abs':'on','corr-method':'bonferroni','tie-correct':'on','n-genes':25})
        markers(source,out)
    elif module=='scvi-integrate':
        vi(source,work/'anchor')
        # Native covariates already present in the small upstream fixture.
        vi(source,alternate('tutorial_structure',{'n-layers':2,'gene-likelihood':'nb','n-hidden':64,'dropout-rate':0.2,
            'dispersion':'gene-batch','use-observed-lib-size':'off','latent-distribution':'ln',
            'categorical-covariate-keys':'["sample"]','continuous-covariate-keys':'["omicstat_size_factor"]',
            'size-factor-key':'omicstat_size_factor','train-size':0.8,'validation-size':0.2,'shuffle-set-split':'off',
            'early-stopping':'on','plan-kwargs':'{"lr":0.002}','datasplitter-kwargs':'{"drop_last":false}',
            'neighbors-metric':'cosine','neighbors-transformer':'sklearn','neighbors-metric-kwds':'{}',
            'umap-spread':1.2,'umap-init-pos':'random','umap-maxiter':80,'umap-alpha':0.8,'umap-gamma':1.1,
            'umap-negative-sample-rate':4,'umap-a':1.5,'umap-b':0.9}))
    elif module=='scanvi-annotate':
        va(source,work/'anchor')
        va(source,alternate('native_split_predict',{'train-size':0.8,'validation-size':0.2,'shuffle-set-split':'off',
            'adversarial-classifier':'off','plan-kwargs':'{"lr":0.002}','datasplitter-kwargs':'{"drop_last":false}',
            'use-posterior-mean':'off'}))
    # Actual JSON values, not just serialized CLI text, are present in both records.
    for output in work.iterdir():
        if not (output/'results'/ (module.replace('-','_')+'_results.json')).exists(): continue
        s=summary(module,output)
        method=(output/'draft/methods_results.md').read_text()
        prov=json.loads((output/'provenance/provenance.json').read_text())
        if module == 'scanpy-markers':
            for key in ('reference', 'groups', 'mask_var', 'rankby_abs', 'corr_method', 'tie_correct', 'n_genes'):
                value = s['requested_n_genes'] if key == 'n_genes' else s[key]
                assert value == s['native_options'][key.replace('_', '-')], key
                for section in (method.split('## Methods\n', 1)[1].split('## Results', 1)[0],
                                method.split('## Results\n', 1)[1].split('## Resolved parameters', 1)[0]):
                    assert f'{key}={value}' in section, (key, section)
            assert 'BH adjustment' not in method and 'versus the remaining cells' not in method
        assert '## Native arguments' in method
        assert s['native_options'] == prov['analysis_summary']['native_options']
    print('PASS: S4 native default/alternative option parity, graph/labels, native CSV ordering and actual Methods/provenance values')

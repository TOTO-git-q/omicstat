"""Project a query with scanpy ingest while preserving every reference coordinate."""
from ospy import sc_module as S
from ospy.display import read_run, read_cells
from ospy.errors import OmicstatError
MODULE_VERSION = '1.0.0'


def validate(a):
    if a['query-run']:
        if a['input'] or (a['from-run'] and a['from-run'] != a['query-run']):
            raise OmicstatError('OS_CONFLICTING_PARAMETERS', 'query-run is the query input; do not supply a different input/from-run.')
        a['from-run'] = a['query-run']
    elif not (a['from-run'] and a['cell-list']):
        raise OmicstatError('OS_MISSING_PARAMETER', 'supply --query-run or --from-run query pool plus --cell-list.')


def compute(adata, a, upstream):
    import numpy as np
    import pandas as pd
    import scanpy as sc
    from sklearn.neighbors import NearestNeighbors
    reference, handoff = read_run(a['reference-run'])
    S.require_columns(reference.obs, [a['label-col']]); S.require_columns(adata.obs, [a['label-col']])
    if not reference.var_names.equals(adata.var_names):
        raise OmicstatError('OS_HANDOFF_MISMATCH', 'reference/query genes and ordering must match.')
    if set(reference.obs_names) & set(adata.obs_names):
        raise OmicstatError('OS_CELL_MISMATCH', 'query must exclude cells already in the fixed reference.')
    for key in ('species', 'annotation'):
        if handoff['state'].get(key) not in (None, a[key]):
            raise OmicstatError('OS_HANDOFF_MISMATCH', 'reference metadata differs: ' + key)
    if a['neighbors-key'] not in reference.uns:
        raise OmicstatError('OS_MISSING_REDUCTION', 'reference neighbor graph is absent.')
    params = reference.uns[a['neighbors-key']]['params']
    rep = params.get('use_rep')
    if rep not in reference.obsm or rep not in adata.obsm:
        raise OmicstatError('OS_MISSING_REDUCTION', 'reference graph must explicitly declare a shared obsm representation via use_rep; query and reference must both contain it.')
    if reference.obsm[rep].shape[1] != adata.obsm[rep].shape[1] or not np.isfinite(reference.obsm[rep]).all() or not np.isfinite(adata.obsm[rep]).all():
        raise OmicstatError('OS_INVALID_INPUT', 'reference/query representations must have matching dimensions and finite values.')
    if 'X_umap' not in reference.obsm:
        raise OmicstatError('OS_MISSING_REDUCTION', 'reference UMAP is absent.')
    if a['n-neighbors'] > reference.n_obs:
        raise OmicstatError('OS_INVALID_PARAMETER', 'n-neighbors exceeds reference cell count.')
    fixed = np.asarray(reference.obsm['X_umap']).copy()
    reference.obsm['X_umap'] = np.ascontiguousarray(fixed, dtype=np.float32)
    reference.obsm[rep] = np.ascontiguousarray(reference.obsm[rep], dtype=np.float32)
    adata.obsm[rep] = np.ascontiguousarray(adata.obsm[rep], dtype=np.float32)
    if not np.array_equal(fixed, reference.obsm['X_umap']):
        raise OmicstatError('OS_RESULT_INCONSISTENT', 'float32 conversion would change reference coordinates; rebuild reference in float32 first.')
    sc.tl.ingest(adata=adata, adata_ref=reference, obs=None, embedding_method='umap', labeling_method='knn', neighbors_key=a['neighbors-key'], inplace=True,
                 k=a['n-neighbors'], queue_size=a['queue-size'], epsilon=a['epsilon'], random_state=a['seed'])
    if not np.array_equal(fixed, reference.obsm['X_umap']):
        raise OmicstatError('OS_RESULT_INCONSISTENT', 'ingest changed fixed reference coordinates.')
    nn = NearestNeighbors(n_neighbors=a['n-neighbors'], radius=1.0, algorithm='auto', leaf_size=30, metric=params['metric'], p=2, metric_params=params.get('metric_kwds'), n_jobs=1)
    nn.fit(X=reference.obsm[rep], y=None)
    indices = nn.kneighbors(X=adata.obsm[rep], n_neighbors=a['n-neighbors'], return_distance=False)
    fraction = (reference.obs[a['label-col']].astype(str).to_numpy()[indices] == adata.obs[a['label-col']].astype(str).to_numpy()[:, None]).mean(axis=1)
    projected = S.embedding_frame(adata, a['label-col']); projected['same_label_reference_fraction'] = fraction
    fixed_table = S.embedding_frame(reference, a['label-col'])
    combined = pd.concat([fixed_table.assign(origin='reference'), projected.assign(origin='query')], ignore_index=True)
    if isinstance(reference.obs[a['label-col']].dtype, pd.CategoricalDtype):
        categories = reference.obs[a['label-col']].cat.categories.tolist()
        categories += [label for label in pd.unique(combined[a['label-col']]) if label not in categories]
        combined[a['label-col']] = pd.Categorical(combined[a['label-col']], categories=categories).remove_unused_categories()

    return {'adata': adata, 'tables': {'projected_cells': projected, 'reference_coordinates': fixed_table, 'cell_metadata': combined},
            'colour_registry': None,
            'summary': {'n_reference': reference.n_obs, 'n_projected': adata.n_obs, 'reference_max_abs_diff': float(np.abs(fixed - reference.obsm['X_umap']).max()), 'use_rep': rep},
            'state': {'display_only': True, 'display_curation': 'fixed-reference ingest', 'reference_run': a['reference-run']}}

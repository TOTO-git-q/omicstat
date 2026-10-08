"""Explicit neighbour purity and island flags; never silently subset cells."""
from ospy import sc_module as S
from ospy.errors import OmicstatError
MODULE_VERSION = '1.0.0'


def validate(a):
    if not a['from-run']:
        raise OmicstatError('OS_MISSING_PARAMETER', 'scanpy-purity requires --from-run.')
    if not (a['graph-key'] or a['use-rep']):
        raise OmicstatError('OS_MISSING_PARAMETER', 'supply --graph-key or --use-rep.')
    if a['use-rep'] and a['n-neighbors'] is None:
        raise OmicstatError('OS_MISSING_PARAMETER', 'representation purity requires --n-neighbors.')


def compute(adata, a, upstream):
    import numpy as np
    import pandas as pd
    from scipy import sparse
    from sklearn.neighbors import NearestNeighbors
    from sklearn.cluster import DBSCAN
    S.require_columns(adata.obs, [a['label-col']])
    labels = adata.obs[a['label-col']].astype(str).to_numpy()
    if a['graph-key']:
        key = a['graph-key']
        graph_key = adata.uns.get(key, {}).get('connectivities_key', key)
        if graph_key not in adata.obsp:
            raise OmicstatError('OS_MISSING_REDUCTION', 'chosen graph is absent.')
        graph = sparse.csr_matrix(adata.obsp[graph_key], copy=True)
        graph.setdiag(0); graph.eliminate_zeros()
        purity = np.array([(labels[graph.indices[graph.indptr[i]:graph.indptr[i+1]]] == labels[i]).mean() if graph.indptr[i+1] > graph.indptr[i] else 0.0 for i in range(adata.n_obs)])
    else:
        if a['use-rep'] not in adata.obsm:
            raise OmicstatError('OS_MISSING_REDUCTION', 'chosen representation is absent.')
        if a['n-neighbors'] >= adata.n_obs:
            raise OmicstatError('OS_INVALID_PARAMETER', 'n-neighbors must be smaller than cell count.')
        nn = NearestNeighbors(n_neighbors=a['n-neighbors'] + 1, radius=1.0, algorithm='auto', leaf_size=30, metric=a['metric'], p=2, metric_params=None, n_jobs=1)
        nn.fit(X=adata.obsm[a['use-rep']], y=None)
        indices = nn.kneighbors(X=adata.obsm[a['use-rep']], n_neighbors=a['n-neighbors'] + 1, return_distance=False)
        indices = np.array([row[row != i][:a['n-neighbors']] for i, row in enumerate(indices)])
        purity = (labels[indices] == labels[:, None]).mean(axis=1)
    emb = S.embedding_frame(adata, a['label-col'])
    if a['embedding-neighbors'] >= adata.n_obs:
        raise OmicstatError('OS_INVALID_PARAMETER', 'embedding-neighbors must be smaller than cell count.')
    un = NearestNeighbors(n_neighbors=a['embedding-neighbors'] + 1, radius=1.0, algorithm='auto', leaf_size=30, metric='euclidean', p=2, metric_params=None, n_jobs=1)
    un.fit(X=emb[['x', 'y']].to_numpy(), y=None)
    indices = un.kneighbors(X=emb[['x', 'y']].to_numpy(), n_neighbors=a['embedding-neighbors'] + 1, return_distance=False)
    indices = np.array([row[row != i][:a['embedding-neighbors']] for i, row in enumerate(indices)])
    umap_purity = (labels[indices] == labels[:, None]).mean(axis=1)
    passing = (purity >= a['purity-threshold']) & (umap_purity >= a['embedding-purity-threshold'])
    if a['exclude-label']:
        passing &= labels != a['exclude-label']
    islands = np.full(adata.n_obs, -1, dtype=int)
    if passing.any():
        db = DBSCAN(eps=a['island-eps'], min_samples=a['island-min-samples'], metric='euclidean', metric_params=None, algorithm='auto', leaf_size=30, p=None, n_jobs=1)
        islands[passing] = db.fit_predict(X=emb.loc[passing, ['x', 'y']].to_numpy(), y=None, sample_weight=None)
    sizes = pd.Series(islands[passing & (islands >= 0)]).value_counts()
    island_size = np.array([sizes.get(i, 0) if i >= 0 else 0 for i in islands])
    isolated = (islands < 0) | (island_size < a['island-min-size'])
    retained = passing & ~isolated
    table = pd.DataFrame({'cell': adata.obs_names, 'label': labels, 'purity': purity, 'embedding_purity': umap_purity,
                          'low_purity': ~passing, 'island': islands, 'island_size': island_size, 'isolated': isolated, 'retained': retained})
    adata.obs['display_retained'] = retained
    return {'adata': adata, 'tables': {'purity': table, 'retained_cells': pd.DataFrame({'cell': adata.obs_names[retained]}), 'cell_metadata': emb},
            'summary': {'n_removed': int((~retained).sum()), 'n_denominator': adata.n_obs, 'n_retained': int(retained.sum()), 'subset_performed': False},
            'state': {'display_only': True, 'display_curation': 'neighbour purity flags; explicit cell-list required for rerun'}}

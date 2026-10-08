"""Shared-layer embedding of the computed result, with explicit labels."""
from ospy import figure_request as F

def report(res, a):
    group = 'celltype' if 'cluster_annotation' in res['tables'] else a['label-col']
    return [('umap_celltypes', 'os_embedding', {'emb': F.frame(res['tables']['cell_metadata'])},
             {'group_col': group, 'family': 'celltype', 'reduction': 'UMAP', 'label': True})]

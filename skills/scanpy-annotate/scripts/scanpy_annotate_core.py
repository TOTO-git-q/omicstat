"""Panel evidence and explicit descriptive naming; no automatic validation claim."""
import json
from pathlib import Path
from ospy import sc_module as S, user_genesets as U
from ospy.display import category_palette, unassigned_colour
from ospy.errors import OmicstatError
MODULE_VERSION = '1.0.0'


def validate(a):
    if not a['from-run']:
        raise OmicstatError('OS_MISSING_PARAMETER', 'scanpy-annotate requires --from-run.')


def compute(adata, a, upstream):
    import numpy as np
    import pandas as pd
    import scanpy as sc
    S.require_columns(adata.obs, [a['cluster-col']])
    panel = json.loads(Path(a['marker-panel']).read_text())
    if not isinstance(panel, dict) or not panel:
        raise OmicstatError('OS_INVALID_INPUT', 'marker-panel must map types to genes, lineage and order.')
    for name, entry in panel.items():
        if not isinstance(entry, dict) or not isinstance(entry.get('genes'), list) or not entry.get('genes') or not entry.get('lineage') or not isinstance(entry.get('order'), int):
            raise OmicstatError('OS_INVALID_INPUT', 'each panel type requires genes, lineage and integer order.')
    order = sorted(panel, key=lambda name: (panel[name]['order'], name))
    # A panel declared through the user-supplied provenance contract (for
    # example PanglaoDB-derived markers) is hashed, checked and recorded.
    record = None
    if U.given(a, feature=True):
        if not U.given(a):
            raise OmicstatError('OS_CONFLICTING_PARAMETERS', '--feature-id-type applies only to a marker panel declared with --gene-sets-provenance or --gene-sets-source/--gene-sets-version/--gene-sets-id-type.')
        sets = {name: [str(g) for g in panel[name]['genes']] for name in order}
        record = U.check(U.resolve(a['marker-panel'], a, sets, 'marker-panel file'), sets, a['feature-id-type'],
                         adata.var_names, 'the AnnData features', '--feature-id-type', analysis_species=a.get('species'))
    label_map = json.loads(Path(a['label-map']).read_text()) if a['label-map'] else {}
    clusters = adata.obs[a['cluster-col']].astype(str)
    if not isinstance(label_map, dict) or set(label_map) - set(clusters) or set(label_map.values()) - set(panel) - {a['unresolved-label']}:
        raise OmicstatError('OS_INVALID_INPUT', 'label-map must map observed clusters to panel names or unresolved-label.')
    S.layer(adata, a['expression-layer'])
    aggregate = sc.get.aggregate(adata=adata, by=a['cluster-col'], func='mean', axis='obs', mask=None, dof=1,
                                 layer=None if a['expression-layer'] == 'X' else a['expression-layer'], obsm=None, varm=None)
    aggregate_rows = {str(value): i for i, value in enumerate(aggregate.obs[a['cluster-col']])}
    rows = []
    for cluster in sorted(clusters.unique()):
        mask = clusters.to_numpy() == cluster
        means = np.asarray(aggregate.layers['mean'][aggregate_rows[cluster]]).ravel()
        row = {'cluster': cluster, 'n': int(mask.sum())}
        for name in order:
            genes = [g for g in panel[name]['genes'] if g in adata.var_names]
            row['score:' + name] = float(means[adata.var_names.get_indexer(genes)].mean()) if genes else np.nan
            row['observed_genes:' + name] = ','.join(genes)
        markers = adata.uns.get('omicstat_markers', {}).get('names')
        row['top_markers'] = ','.join(map(str, markers[cluster][:a['top-n']])) if markers is not None and cluster in markers.dtype.names else ','.join(adata.var_names[np.argsort(-means, kind='stable')[:a['top-n']]])
        name = label_map.get(cluster, a['unresolved-label'])
        row.update(assigned_name=name, status='unresolved' if name == a['unresolved-label'] else 'user_descriptive', lineage=panel[name]['lineage'] if name in panel else a['unresolved-label'])
        rows.append(row)
    table = pd.DataFrame(rows)
    names = table.set_index('cluster').assigned_name.to_dict()
    lineages = table.set_index('cluster').lineage.to_dict()
    adata.obs['celltype'] = pd.Categorical(clusters.map(names), categories=order + ([a['unresolved-label']] if a['unresolved-label'] not in panel else []))
    adata.obs['lineage'] = clusters.map(lineages).to_numpy()
    palette = category_palette()
    colours = {}
    for i, name in enumerate(order):
        if 'colour' in panel[name]:
            colours[name] = panel[name]['colour']
        elif i < len(palette):
            colours[name] = palette[i]
        else:
            raise OmicstatError('OS_TOO_MANY_CATEGORIES', 'supply every colour when the marker panel exceeds the shared palette.')
    colours.setdefault(a['unresolved-label'], unassigned_colour())
    registry = {'schema': 'omicstat.colour-registry.v1', 'families': {'celltype': colours}}
    result = {'adata': adata, 'tables': {'cluster_annotation': table, 'cell_metadata': S.embedding_frame(adata, 'celltype')},
              'colour_registry': registry,
              'summary': {'n_clusters': len(table), 'n_unresolved': int(table.loc[table.status == 'unresolved', 'n'].sum()), 'annotation': 'descriptive user naming; panel scores are mean log expression'},
              'state': {'celltype_col': 'celltype', 'lineage_col': 'lineage', 'annotation_descriptive': True}}
    if record is not None:
        result['user_gene_sets'] = record
        result['methods_extra'] = U.methods_sentence(record)
        result['summary']['user_gene_sets'] = record
        result['state']['marker_panel'] = {'origin': U.ORIGIN, 'source': record['source'], 'version_or_release': record['version_or_release'],
                                           'id_type': record['id_type'], 'sha256': record['sha256']}
    return result

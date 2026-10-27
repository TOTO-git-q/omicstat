"""Deterministic invented matrices, with no external datasets or participants."""
import json
import math
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'py'))
from ospy.figure_request import FigureRequest, frame, matrix
out = Path(sys.argv[1]); out.mkdir(parents=True, exist_ok=True)
journal = sys.argv[2] if len(sys.argv) > 2 else 'nature'
rows = ['invented_feature_' + str(i) for i in range(1, 5)]
cols = ['invented_sample_' + str(i) for i in range(1, 7)]
values = [[0, 1, 2, 6, 9, 10], [2, 3, 9, 8, 12, 14], [8, 5, 4, 3, 1, 4], [5, 7, 8, 11, 6, 15]]
r = FigureRequest(str(out), 'synthetic-matrix-semantics', '0.0.0', journal=journal)
ann = {'sample_id': cols[::-1], 'condition': ['treated'] * 3 + ['reference'] * 3,
       'time': ['late', 'late', 'early', 'late', 'late', 'early']}
r.add('column_zscore', 'os_heatmap', {'mat': matrix(values, rows, cols), 'col_annot': frame(ann, row_id='sample_id')},
      args=dict(value_title='Within-gene z-score', normalization='col_zscore', row_entity='aggregate', col_entity='gene',
                matrix_kind='expression', quantity='column z-score', unit='dimensionless', clip=1.5), width='double', height_mm=100)
dids = ['invented_object_' + str(i) for i in range(1, 5)]
dm = [[0, 2, 8, 9], [2, 0, 4, 7], [8, 4, 0, 3], [9, 7, 3, 0]]
da = {'object_id': dids[::-1], 'group': ['beta', 'beta', 'alpha', 'alpha']}
r.add('direct_distance', 'os_heatmap', {'mat': matrix(dm, dids, dids), 'col_annot': frame(da, row_id='object_id')},
      args=dict(value_title='Supplied distance', matrix_kind='distance', row_entity='object', col_entity='object',
                quantity='supplied distance', unit='unknown', display_mask_gt=7), width='double', height_mm=100)
state_values = [[0, 1.5, 1.5001, None], [0.1, 0.2, float('inf'), 0.3], [0.4, 0.5, 0.6, 0.7]]
sr = rows[:3]; sc = cols[:4]
cells = []
for j, col in enumerate(sc):
    for i, row in enumerate(sr):
        v = state_values[i][j]
        state = 'missing' if v is None else 'infinite' if v == float('inf') else 'true_zero' if v == 0 else 'observed'
        cells.append(dict(row_id=row, col_id=col, value=v, state=state, test_metric='adjusted_p', threshold=0.05, fit_id='invented_fit'))
for index, state in ((1, 'reference'), (2, 'nonsignificant'), (4, 'failed'), (5, 'not_credible')):
    cells[index]['state'] = state
cells[5]['test_metric'] = 'posterior_probability'; cells[5]['threshold'] = 0.95
r.add('cell_states', 'os_heatmap', {'mat': matrix(state_values, sr, sc), 'cell_metadata': frame(cells[::-1])},
      args=dict(value_title='Supplied effect', scale_type='sequential', cluster_rows=False, cluster_cols=False,
                row_entity='feature', col_entity='contrast', quantity='effect', unit='log2 ratio', display_mask_gt=1.5), width='double', height_mm=100)
cd = {'sample': cols, 'condition': ['reference'] * 3 + ['treated'] * 3}
ft = {'feature_id': rows, 'padj': [0.03, 0.01, 0.02, 0.2], 'log2fc': [1, 2, -2, 0]}
for operation in ('zscore_then_mean', 'mean_then_zscore'):
    r.add(operation, 'os_top_heatmap', {'mat': matrix(values, rows, cols), 'ft': frame(ft), 'coldata': frame(cd)},
          args=dict(group_col='condition', n=3, col_unit='condition_average', aggregation_order=operation), width='double', height_mm=100)
r.write()
source_cells = [dict(c, value=('positive_infinity' if isinstance(c['value'], float) and math.isinf(c['value']) else c['value'])) for c in cells]
(out / 'SOURCE.json').write_text(json.dumps({'source': 'manually invented deterministic matrices; no real biological or clinical records',
    'matrix': {'rows': rows, 'columns': cols, 'values': values}, 'distance': dm, 'cell_states': source_cells}, indent=2, allow_nan=False) + '\n')

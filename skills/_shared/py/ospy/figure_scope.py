"""Bound aggregate sampling scope for figure captions; no selection or fitting."""
import hashlib
import json
import math
import re
from pathlib import Path

from .errors import OmicstatError

SOURCE_REL = 'provenance/resource_sampling.json'
SCHEMA = 'omicstat.figure-sampling-scope.v1'
MAX_EMBEDDING_PAGES = 8


def _invalid(message):
    raise OmicstatError('OS_INVALID_INPUT', 'figure sampling scope: ' + message)


def _count(value, name, minimum=0):
    if type(value) is not int or not minimum <= value <= 9007199254740991:
        _invalid(name + ' must be an exact nonnegative integer')
    return value


def scope_from_record(record, current_observations):
    """Check the real selection record and expose counts, never per-cell rows."""
    if not isinstance(record, dict) or record.get('schema') != 'omicstat.resource-sampling.v1':
        _invalid('unsupported selection record')
    before = _count(record.get('observations_before'), 'observations_before', 1)
    after = _count(record.get('observations_after'), 'observations_after', 1)
    units_before = _count(record.get('biological_units_before'), 'biological_units_before', 1)
    units_after = _count(record.get('biological_units_after'), 'biological_units_after', 1)
    if after > before or units_after != units_before or after != _count(current_observations, 'current cells', 1):
        _invalid('retained cells or preserved biological-unit count disagrees')
    if type(record.get('applied')) is not bool or record['applied'] != (after < before):
        _invalid('applied selection claim differs from retained counts')
    rows = record.get('by_unit')
    if not isinstance(rows, list) or len(rows) != units_before:
        _invalid('by-unit count disagrees')
    ids = []
    total_before = total_after = 0
    for row in rows:
        if not isinstance(row, dict) or not isinstance(row.get('unit_id'), str) or not row['unit_id']:
            _invalid('biological-unit ID is absent')
        ids.append(row['unit_id'])
        n = _count(row.get('observations_before'), 'unit cells before', 1)
        k = _count(row.get('observations_after'), 'unit cells after', 1)
        if k > n:
            _invalid('unit cells increased during selection')
        total_before += n
        total_after += k
    if len(set(ids)) != len(ids) or (total_before, total_after) != (before, after):
        _invalid('duplicate units or inconsistent cell totals')
    groups = record.get('by_group')
    declared = record.get('groups_provided')
    if type(declared) is not bool or not isinstance(groups, list) or bool(groups) != declared:
        _invalid('declared grouping and per-group counts disagree')
    clean_groups = []
    for row in groups:
        if not isinstance(row, dict) or not isinstance(row.get('group'), str) or not row['group']:
            _invalid('group label is absent')
        clean = {'group': row['group']}
        for key in ('observations_before', 'observations_after', 'biological_units_before', 'biological_units_after'):
            clean[key] = _count(row.get(key), 'group ' + key)
        if (clean['observations_before'] < 1 or clean['biological_units_before'] < 1
                or clean['observations_after'] > clean['observations_before']
                or clean['biological_units_after'] > clean['biological_units_before']
                or clean['biological_units_before'] > units_before
                or clean['biological_units_after'] > units_after
                or clean['biological_units_before'] > clean['observations_before']
                or clean['biological_units_after'] > clean['observations_after']):
            _invalid('group retained counts disagree')
        clean_groups.append(clean)
    if declared and (len({x['group'] for x in clean_groups}) != len(clean_groups)
            or sum(x['observations_before'] for x in clean_groups) != before
            or sum(x['observations_after'] for x in clean_groups) != after):
        _invalid('duplicate groups or inconsistent group cell totals')
    scope = {'schema': SCHEMA, 'observation_unit': 'cells', 'analysis_sampling': record['applied'],
             'display_only': False, 'observations_before': before, 'observations_after': after,
             'biological_units_before': units_before, 'biological_units_after': units_after,
             'groups_provided': declared, 'by_group': clean_groups}
    for key in ['original_id_sha256', 'selected_id_sha256']:
        if not isinstance(record.get(key), str) or not re.fullmatch('[0-9a-f]{64}', record[key]):
            _invalid('selection ID digest is absent or malformed')
        scope[key] = record[key]
    scope['caption'] = sampling_caption(scope)
    return scope


def sampling_caption(scope):
    n, k = scope['observations_before'], scope['observations_after']
    un, uk = scope['biological_units_before'], scope['biological_units_after']
    text = f'Analysis subsampling: {k:,} of {n:,} input cells and {uk:,} of {un:,} biological units retained. '
    text += ('This changes the analyzed observations, not only their display; cells are not biological replicates.'
             if scope['analysis_sampling'] else
             'No input cells were removed by this sampling step; cells are not biological replicates.')
    groups = scope['by_group']
    if scope['groups_provided']:
        labels = [f"{r['group']}: {r['biological_units_after']:,} of {r['biological_units_before']:,} biological units, "
                  f"{r['observations_after']:,} of {r['observations_before']:,} cells" for r in groups[:6]]
        text += ' Declared groups: ' + '; '.join(labels) + '.'
        if len(groups) > 6:
            text += f' {len(groups) - 6} further groups are listed in the source sampling record and figure metadata.'
    else:
        text += ' No condition/group column was declared; no per-group replication is inferred.'
    return text


def _id_digest(ids):
    return hashlib.sha256(b''.join(str(len(x.encode('utf-8'))).encode('ascii') + b':' + x.encode('utf-8') for x in ids)).hexdigest()


def check_embedding_scope(scope, frame, selected_ids=None):
    ids = frame.get('data', {}).get('cell')
    if (not isinstance(ids, list) or not ids or any(not isinstance(x, str) or not x for x in ids)
            or len(set(ids)) != len(ids) or frame.get('n') != len(ids)
            or len(ids) > scope['observations_after']):
        _invalid('display cell IDs/count do not identify unique retained cells')
    if len(ids) == scope['observations_after'] and _id_digest(ids) != scope['selected_id_sha256']:
        _invalid('display cell order/IDs differ from the complete selected analysis')
    if selected_ids is not None and not set(ids).issubset(selected_ids):
        _invalid('display includes cells outside the retained analysis')


def bound_sampling_scope(record, current_observations, run_dir, selected_ids=None):
    scope = scope_from_record(record, current_observations)
    if selected_ids is not None:
        selected_ids = list(selected_ids)
        check_embedding_scope(scope, {'data': {'cell': selected_ids}, 'n': len(selected_ids)})
        if len(selected_ids) != current_observations:
            _invalid('current analysis cell IDs are incomplete')
    root = Path(run_dir).resolve()
    path = root / SOURCE_REL
    if (not path.is_file() or path.is_symlink() or path.parent.is_symlink()
            or not path.resolve().is_relative_to(root)):
        _invalid('source selection record missing or unsafe')
    raw = path.read_bytes()
    try:
        actual = json.loads(raw)
    except (ValueError, UnicodeError) as exc:
        _invalid('source selection record is invalid JSON: ' + str(exc))
    if actual != record:
        _invalid('source selection record differs from the computed record')
    scope['source'] = {'path': SOURCE_REL, 'sha256': hashlib.sha256(raw).hexdigest()}
    return scope


def embedding_pages(fig_id, builder, data, args, palette_capacity):
    """Partition category foregrounds, retaining the same full coordinate data.

    Only high-cardinality embedding displays change. Cells/labels are never
    merged, resampled, reclustered or fitted. Grey context repeats across pages
    and is not another cluster or an additive independent-cell denominator.
    """
    if builder != 'os_embedding':
        return [(fig_id, builder, data, args)]
    capacity = _count(palette_capacity, 'categorical palette capacity', 1)
    frame = data.get('emb')
    if not isinstance(frame, dict) or frame.get('kind') != 'data.frame':
        _invalid('embedding page data must be a frame')
    column = args.get('group_col')
    values = frame.get('data', {}).get(column)
    if values is None:
        _invalid('embedding group column missing')
    missing_label = args.get('missing_label', 'Missing metadata')
    if not isinstance(missing_label, str) or not missing_label:
        _invalid('missing-category label must be nonempty')
    missing = [x is None or x == '' or (isinstance(x, float) and math.isnan(x)) for x in values]
    observed = {str(x) for x, absent in zip(values, missing) if not absent}
    if any(missing) and missing_label in observed:
        _invalid('missing-category label collides with an observed category')
    descriptor = next((x for x in frame.get('columns', []) if x['name'] == column), {})
    levels = ([str(x) for x in descriptor['levels'] if str(x) in observed]
              if descriptor.get('type') == 'factor' else sorted(observed))
    if set(levels) != observed or len(levels) != len(set(levels)):
        _invalid('embedding category levels disagree with observed values')
    if any(missing):
        levels.append(missing_label)
    if len(levels) <= capacity:
        return [(fig_id, builder, data, args)]
    total = (len(levels) + capacity - 1) // capacity
    if total > MAX_EMBEDDING_PAGES:
        raise OmicstatError('OS_TOO_MANY_CATEGORIES',
            f'{len(levels)} categories require {total} directly labelled pages at {capacity} categories/page; '
            f'the display bound is {MAX_EMBEDDING_PAGES} pages. No cells or categories were merged or dropped. '
            'Retain the analysis and request an explicit scientifically justified display subset; '
            'a 2000-category stress input is not an owner-review figure.')
    pages = []
    for index in range(total):
        page_args = dict(args, page_groups=levels[index * capacity:(index + 1) * capacity],
                         page_index=index + 1, page_count=total)
        pages.append((fig_id + '_page%03d' % (index + 1), 'os_embedding_page', data, page_args))
    return pages

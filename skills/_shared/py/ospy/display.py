"""Display curation helpers. None changes an analysis table or embedding."""
import json
import re
from pathlib import Path
from .errors import OmicstatError
from . import figure_request as F


def read_cells(path):
    import csv
    import pandas as pd
    lines = Path(path).read_text().splitlines()
    header = next(csv.reader(lines[:1]), [])
    cells = pd.read_csv(path, dtype=str, keep_default_na=False)['cell'].tolist() if 'cell' in header else [x.strip() for x in lines if x.strip()]
    if not cells or any(not x.strip() for x in cells) or len(set(cells)) != len(cells):
        raise OmicstatError('OS_INVALID_INPUT', 'cell-list must contain nonempty unique cell IDs.')
    return cells


def read_registry(path):
    try:
        registry = json.loads(Path(path).read_text())
        families = registry['families']
        if not isinstance(families, dict) or any(not isinstance(v, dict) for v in families.values()):
            raise ValueError('families must contain colour maps')
        if any(not re.fullmatch(r'#[0-9a-fA-F]{6}', colour) for family in families.values() for colour in family.values()):
            raise ValueError('colours must be six-digit hex strings')
    except (KeyError, ValueError, TypeError) as exc:
        raise OmicstatError('OS_INVALID_INPUT', 'invalid colour registry: %s' % exc) from exc
    return registry


def category_palette():
    """Read authoritative figure tokens; no second palette in the Python lane."""
    source = Path(__file__).resolve().parents[2] / 'scripts/fig_style.R'
    body = source.read_text().split('OS_PAL_CATEGORY <- c(', 1)[1].split(')', 1)[0]
    return re.findall(r'#[0-9a-fA-F]{6}', body)


def unassigned_colour():
    source = Path(__file__).resolve().parents[2] / 'scripts/fig_style.R'
    match = re.search(r'col_na\s*=\s*"(#[0-9a-fA-F]{6})"', source.read_text())
    if match is None:
        raise OmicstatError('OS_INVALID_INPUT', 'authoritative unassigned colour token is missing.')
    return match.group(1)


def largest_island_medians(embedding, group_col, *, eps, min_samples):
    import numpy as np
    import pandas as pd
    from sklearn.cluster import DBSCAN
    rows = []
    for group, frame in embedding.groupby(group_col, observed=True, sort=True):
        model = DBSCAN(eps=eps, min_samples=min_samples, metric='euclidean', metric_params=None,
                       algorithm='auto', leaf_size=30, p=None, n_jobs=1)
        islands = model.fit_predict(X=frame[['x', 'y']].to_numpy(), y=None, sample_weight=None)
        sizes = pd.Series(islands[islands >= 0]).value_counts()
        # No density-supported island: all-cell median, explicitly recorded.
        island = min(sizes.index, key=lambda i: (-sizes[i], i)) if len(sizes) else None
        selected = frame if island is None else frame.iloc[np.flatnonzero(islands == island)]
        rows.append({'group': str(group), 'x': float(selected.x.median()), 'y': float(selected.y.median()),
                     'label_island_n': len(selected), 'label_fallback': island is None})
    return pd.DataFrame(rows)


def embedding_data(data, kwargs, a):
    import pandas as pd
    import numpy as np
    data, kwargs = dict(data), dict(kwargs)
    original = data['emb']
    emb = pd.DataFrame(original['data'])
    group = kwargs['group_col']
    if a.get('label-placement') == 'largest-island' and kwargs.get('label', True):
        lab = largest_island_medians(emb, group, eps=a['label-island-eps'], min_samples=a['label-island-min-samples'])
        data['label_xy'] = F.frame(lab)
        kwargs.update(label_island_eps=a['label-island-eps'], label_island_min_samples=a['label-island-min-samples'])
    # Opt-in rendering only; the default request carries no label_style argument.
    if a.get('label-style') == 'halo' and kwargs.get('label', True):
        kwargs['label_style'] = 'halo'
    cap = a.get('display-max-per-group')
    if cap is not None:
        rng = np.random.default_rng(a['seed'])
        selected = sorted(i for _, frame in emb.groupby(group, observed=True, sort=True)
                          for i in rng.permutation(frame.index)[:cap])
        kwargs.update(display_max_per_group=cap, display_n_input=len(emb))
        emb = emb.loc[selected].copy()
        types = {c['name']: c['type'] for c in original['columns']}
        levels = {c['name']: c['levels'] for c in original['columns'] if 'levels' in c}
        data['emb'] = F.frame(emb, types=types, levels=levels)
    return data, kwargs


def read_run(run):
    from . import handoff as H
    import anndata as ad
    handoff = H.read_handoff(run, front_end_ecosystem='scverse')
    objects = [o for o in handoff['objects'].values() if o['type'] == 'AnnData']
    if len(objects) != 1:
        raise OmicstatError('OS_HANDOFF_MISMATCH', 'run must contain exactly one AnnData object.')
    return ad.read_h5ad(objects[0]['path']), handoff

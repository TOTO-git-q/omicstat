"""Shared acceptance implementation, with independent package replays.

Static tests run without scverse. Numerical tests require exact image pins and
local registered anchors; no missing dependency is counted as a numeric pass.
Set OMICSTAT_REQUIRE_LOCKED=1 to make every skip a failure. Outputs can be kept
with OMICSTAT_TEST_TMP for the separate R figure-render acceptance.
"""
from __future__ import annotations
import hashlib
import importlib.util
import json
import os
import re
import runpy
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
SUITE = HERE.parents[3]
sys.path.insert(0, str(HERE.parent))
sys.path.insert(0, str(SUITE / 'tools'))
from ospy import module_kit as K, handoff as H, feature_table as FT
from ospy.seed import set_seed
from check_calls import check_calls, check_default_drift
from seal_python import require_locked_environment
from sc_anchor import make_pbmc, make_synthetic, SEED

MODULES = ('scanpy-qc', 'scanpy-cluster', 'scanpy-markers', 'scvi-integrate', 'scanvi-annotate')
# Fixed acceptance policy declared before execution, never adjusted to pass.
ATOL = 1e-6
RTOL = 1e-6
TOLERANCE_TABLES = {
    'cell_metadata': ['x', 'y'], 'pca': ['^PC[0-9]+$'],
    'latent_coordinates': ['^latent_[0-9]+$'], 'embedding_comparison': ['x', 'y'],
    'batch_mixing': ['same_batch_weight_fraction', 'normalized_batch_entropy'],
    'training_history': ['value'], 'annotations': ['max_probability'],
    'label_probabilities': ['!cell'],
}


def entry(module):
    return SUITE / 'skills' / module / 'scripts' / ('run_' + module.replace('-', '_') + '.py')


def run(module, args, *, error=None, env=None):
    environment = dict(os.environ, PYTHONHASHSEED='0', OMP_NUM_THREADS='1', OPENBLAS_NUM_THREADS='1', MKL_NUM_THREADS='1', NUMBA_NUM_THREADS='1')
    environment.update(env or {})
    process = subprocess.run([sys.executable, str(entry(module)), *map(str, args)], capture_output=True,
                             text=True, stdin=subprocess.DEVNULL, env=environment, timeout=1500)
    if error is None:
        assert process.returncode == 0, '%s failed:\n%s\n%s' % (module, process.stdout, process.stderr)
        assert re.search(r'\d+ of \d+ rules triggered; read .+ first\s*$', process.stdout), process.stdout
    else:
        assert process.returncode != 0 and error in process.stderr, (error, process.returncode, process.stderr)
        assert 'Traceback' not in process.stderr, process.stderr
    return process


def load(run_dir):
    import anndata as ad
    return ad.read_h5ad(run_dir / 'objects/adata.h5ad')


def common(source, outdir, is_run=False, layer='X'):
    return ['--from-run' if is_run else '--input', source, '--outdir', outdir,
            '--species', 'human', '--annotation', 'anchor-provided-identifiers',
            '--sample-col', 'sample', '--counts-layer', layer, '--seed', SEED]


def qc_args(source, outdir, min_genes=1):
    return common(source, outdir) + ['--mito-prefix', 'MT-', '--min-genes', min_genes, '--max-genes', 1000000,
            '--min-counts', 1, '--max-counts', 1e12, '--max-mito-percent', 100, '--min-cells', 1, '--doublet-mode', 'skip']


def cluster_args(source, outdir, is_run=True, n_hvg=600):
    return common(source, outdir, is_run, 'counts' if is_run else 'X') + [
        '--n-hvg', n_hvg, '--n-pcs', 10, '--n-neighbors', 10, '--resolution', 0.5]


def vi_args(source, outdir):
    return common(source, outdir, True, 'counts') + ['--batch-col', 'batch', '--cluster-col', 'cluster',
            '--max-epochs', 2, '--n-neighbors', 10, '--n-latent', 5, '--batch-size', 32]


def va_args(source, outdir):
    return common(source, outdir, True, 'counts') + ['--labels-col', 'observed_label', '--unlabeled-category', 'unlabeled',
            '--cluster-col', 'cluster', '--max-epochs', 2, '--batch-size', 32, '--min-confidence', 0.6]


def prepare(module, work):
    if module.startswith(('scvi-', 'scanvi-')):
        raw = make_synthetic(SUITE, work / 'synthetic.h5ad')
        cluster = work / 'upstream_cluster'
        run('scanpy-cluster', cluster_args(raw, cluster, False, 80))
        if module == 'scvi-integrate':
            return cluster, vi_args(cluster, work / 'anchor')
        vi = work / 'upstream_scvi'
        run('scvi-integrate', vi_args(cluster, vi))
        return vi, va_args(vi, work / 'anchor')
    raw = make_pbmc(SUITE, work / 'pbmc3k.h5ad')
    if module == 'scanpy-qc':
        return raw, qc_args(raw, work / 'anchor')
    qc = work / 'upstream_qc'
    run('scanpy-qc', qc_args(raw, qc))
    if module == 'scanpy-cluster':
        return qc, cluster_args(qc, work / 'anchor')
    cluster = work / 'upstream_cluster'
    run('scanpy-cluster', cluster_args(qc, cluster))
    return cluster, common(cluster, work / 'anchor', True, 'counts') + ['--cluster-col', 'cluster',
            '--expression-layer', 'logcounts', '--purpose', 'cluster-description']


def check_output(module, output):
    import numpy as np
    import pandas as pd
    data = load(output)
    handoff = H.read_handoff(str(output), front_end_ecosystem='scverse')
    assert handoff['module'] == module and handoff['state']['front_end_ecosystem'] == 'scverse'
    assert handoff['state'].get('batch_corrected_lineage') is False
    summary = json.loads((output / 'results' / (module.replace('-', '_') + '_results.json')).read_text())
    assert summary['n_cells'] == data.n_obs and summary['n_genes'] == data.n_vars
    assert (output / 'draft/methods_results.md').is_file()
    assert '{n_cells}' not in (output / 'draft/methods_results.md').read_text()
    assert not list(output.rglob('Rplots.pdf'))
    request = json.loads((output / 'figure_data/figure_request.json').read_text())
    assert request['schema'] == 'omicstat.figure-request.v1' and request['figures']
    for figure in request['figures']:
        for value in figure['data'].values():
            path = output / value['path']
            assert path.resolve().is_relative_to(output.resolve())
            assert K.sha256_file(path) == value['sha256']
    if module == 'scanpy-markers':
        table = pd.read_csv(output / 'tables/feature_table.csv')
        assert FT.validate_feature_table(FT.as_feature_table(table))['ok']
        assert summary['inference'] == 'descriptive_cluster_markers'
    if module == 'scanvi-annotate':
        labels = pd.read_csv(output / 'tables/annotations.csv')
        assert labels['cell'].astype(str).tolist() == data.obs_names.astype(str).tolist()
        assert np.isfinite(labels['max_probability']).all()
    return data


def independent_replay(module, source, output):
    """Compare with direct package use, not a second call to engine.compute."""
    import numpy as np
    import pandas as pd
    import scanpy as sc
    import anndata as ad
    from scipy import sparse
    current = load(output)
    previous = load(source) if Path(source).is_dir() else ad.read_h5ad(source)
    set_seed(SEED)
    if module == 'scanpy-qc':
        raw = previous.X
        counts = np.asarray(raw.sum(axis=1)).ravel()
        genes = np.asarray((raw > 0).sum(axis=1)).ravel()
        audit = pd.read_csv(output / 'tables/cell_qc.csv')
        np.testing.assert_array_equal(audit['total_counts'], counts)
        np.testing.assert_array_equal(audit['n_genes_by_counts'], genes)
        keep = (counts >= 1) & (genes >= 1)
        np.testing.assert_array_equal(audit['retained'], keep)
        assert current.obs_names.equals(previous.obs_names[keep])
    elif module == 'scanpy-cluster':
        # Replay the documented Scanpy normalization, HVG and PCA workflow.
        replay = previous.copy()
        replay.X = previous.layers.get('counts', previous.X).copy()
        summary = json.loads((output / 'results/scanpy_cluster_results.json').read_text())
        params = summary['parameters']
        sc.pp.normalize_total(replay, target_sum=params['target-sum'])
        sc.pp.log1p(replay)
        sc.pp.highly_variable_genes(replay, n_top_genes=params['n-hvg'], flavor='seurat')
        np.testing.assert_array_equal(replay.var['highly_variable'], current.var['highly_variable'])
        work = replay[:, replay.var['highly_variable']].copy()
        if params['scale'] == 'on':
            sc.pp.scale(work, zero_center=True, max_value=params['scale-max'])
        sc.pp.pca(work, n_comps=params['n-pcs'], svd_solver=None, random_state=SEED,
                  use_highly_variable=False)
        # Sign-invariant reconstruction (not raw coordinate sign assumptions).
        from ospy.sc_module import canonical_pca
        scores, _ = canonical_pca(work.obsm['X_pca'], work.varm['PCs'])
        np.testing.assert_allclose(scores, current.obsm['X_pca'], atol=ATOL, rtol=RTOL)
        sc.pp.neighbors(current, n_neighbors=params['n-neighbors'], n_pcs=params['n-pcs'],
                        use_rep='X_pca', random_state=SEED, key_added='replay_neighbors')
        sc.tl.leiden(current, resolution=params['resolution'], random_state=SEED, flavor='igraph',
                     directed=False, n_iterations=-1, key_added='replay_labels', neighbors_key='replay_neighbors')
        from sklearn.metrics import adjusted_rand_score
        assert adjusted_rand_score(current.obs[params['cluster-col']], current.obs['replay_labels']) == 1
    elif module == 'scanpy-markers':
        replay = previous.copy()
        sc.tl.rank_genes_groups(replay, groupby='cluster', use_raw=False, groups='all', reference='rest',
                               method='t-test', corr_method='benjamini-hochberg', layer='logcounts',
                               n_genes=replay.n_vars, key_added='direct_replay', pts=True)
        result = replay.uns['direct_replay']
        table = pd.read_csv(output / 'tables/marker_details.csv', dtype={'cluster': str})
        for group in result['names'].dtype.names:
            observed = table[table['cluster'] == group].set_index('feature_id')
            expected = pd.DataFrame({k: result[k][group] for k in ('names', 'scores', 'pvals', 'pvals_adj', 'logfoldchanges')}).set_index('names')
            observed = observed.loc[expected.index]
            for left, right in [('stat', 'scores'), ('pvalue', 'pvals'), ('padj', 'pvals_adj'), ('log2fc', 'logfoldchanges')]:
                np.testing.assert_allclose(observed[left], expected[right], atol=1e-12, rtol=1e-10, equal_nan=True)
    elif module == 'scvi-integrate':
        import scvi
        model = scvi.model.SCVI.load(str(output / 'objects/scvi_model'), adata=current, accelerator='cpu', device='auto')
        latent = model.get_latent_representation(adata=current, give_mean=True, batch_size=32)
        np.testing.assert_allclose(latent, current.obsm['X_scVI'], atol=ATOL, rtol=RTOL)
        np.testing.assert_array_equal(current.obs['cluster'], previous.obs['cluster'])
        delta = current.layers['counts'] - previous.layers['counts']
        assert (delta.nnz == 0) if sparse.issparse(delta) else np.array_equal(delta, np.zeros(delta.shape))
    elif module == 'scanvi-annotate':
        import scvi
        model = scvi.model.SCANVI.load(str(output / 'objects/scanvi_model'), adata=current, accelerator='cpu', device='auto')
        labels = model.predict(adata=current, soft=False, batch_size=32, use_posterior_mean=True)
        np.testing.assert_array_equal(np.asarray(labels).astype(str), current.obs['scanvi_label'].astype(str))
        np.testing.assert_array_equal(current.obs['observed_label'], previous.obs['observed_label'])


def snapshot_tables(output, destination):
    """Split exact IDs/tables and tolerance-tier coordinates; no object/pickle golden."""
    import numpy as np
    import pandas as pd
    destination.mkdir(parents=True, exist_ok=True)
    arrays, numerical = {}, {}
    for path in sorted((output / 'tables').glob('*.csv')):
        patterns = TOLERANCE_TABLES.get(path.stem, [])
        if not patterns:
            (destination / path.name).write_bytes(path.read_bytes())
            continue
        frame = pd.read_csv(path, dtype=str, keep_default_na=False)
        columns = [c for c in frame if any((p.startswith('!') and c != p[1:]) or re.fullmatch(p, c) for p in patterns)]
        for column in columns:
            key = '%s__%s' % (path.stem, column)
            arrays[key] = pd.to_numeric(frame[column].replace({'NA': np.nan, '': np.nan}), errors='raise').to_numpy(float)
        numerical[path.name] = columns
        frame.drop(columns=columns).to_csv(destination / path.name, index=False, lineterminator='\n')
    np.savez_compressed(destination / 'numeric.npz', **arrays)
    K.write_json({'atol': ATOL, 'rtol': RTOL, 'tables': numerical}, str(destination / 'tolerance_policy.json'))


def compare_snapshots(left, right):
    import numpy as np
    assert {p.name for p in left.glob('*.csv')} == {p.name for p in right.glob('*.csv')}
    for path in left.glob('*.csv'):
        assert path.read_bytes() == (right / path.name).read_bytes(), 'exact table mismatch: ' + path.name
    assert (left / 'tolerance_policy.json').read_bytes() == (right / 'tolerance_policy.json').read_bytes()
    with np.load(left / 'numeric.npz', allow_pickle=False) as a, np.load(right / 'numeric.npz', allow_pickle=False) as b:
        assert set(a.files) == set(b.files)
        for key in a.files:
            np.testing.assert_allclose(a[key], b[key], atol=ATOL, rtol=RTOL, equal_nan=True, err_msg=key)


def golden(module_dir, output, snapshot, writing):
    target = module_dir / 'tests/golden'
    signature = K.env_signature_string()
    if writing:
        require_locked_environment()
        if target.exists():
            shutil.rmtree(target)
        shutil.copytree(snapshot, target)
        record = {'numerical_smoke_passed': True, 'environment_signature': signature,
                  'seed': SEED, 'atol': ATOL, 'rtol': RTOL,
                  'exemptions': ['wall-clock provenance', 'HDF5 serialization', 'torch checkpoint serialization',
                                 'PDF creation timestamps', 'absolute paths'],
                  'figures': 'Python requests tested; R render and visual review remain separate gates'}
        K.write_json(record, str(target / 'acceptance.json'))
        # Hash only computed snapshot artifacts. The numeric.npz is compared by
        # values, never by ZIP timestamps; hashes bind the stored baseline itself.
        paths = [str(p.relative_to(module_dir)) for p in sorted(target.iterdir()) if p.is_file()]
        K.golden_write(str(module_dir), str(module_dir), paths)
        print('PASS: generated golden from the executed pinned-container replay')
    elif not target.is_dir():
        if os.environ.get('OMICSTAT_REQUIRE_LOCKED') == '1':
            raise RuntimeError('OS_GOLDEN_PENDING: run generate_golden.sh first')
        print('SKIP: no generated golden baseline; numerical replay was checked but not sealed')
        return
    assert json.loads((target / 'acceptance.json').read_text())['environment_signature'] == signature
    # Verify hashes of the baseline files, then compare current computed values.
    verdict = K.golden_check(str(module_dir), str(module_dir))
    assert verdict['status'] == 'PASS', verdict
    compare_snapshots(target, snapshot)
    print('PASS: exact-table and tolerance-tier golden comparisons')


def negative_chain_tests(module, args, source, work):
    if not Path(source).is_dir():
        return
    for key, value, code in [('ecosystem', 'seurat', 'OS_ECOSYSTEM_MIXED'),
                              ('lineage', True, 'OS_BATCH_CORRECTED_INPUT'), ('hash', '0'*64, 'OS_HANDOFF_MISMATCH')]:
        copied = work / ('bad_' + key)
        shutil.copytree(source, copied)
        path = copied / 'objects/handoff.json'
        doc = json.loads(path.read_text())
        if key == 'ecosystem': doc['ecosystem'] = value
        elif key == 'lineage': doc['state']['batch_corrected_lineage'] = value
        else: doc['objects'][0]['sha256'] = value
        path.write_text(json.dumps(doc))
        bad = list(args)
        bad[bad.index('--from-run') + 1] = copied
        bad[bad.index('--outdir') + 1] = work / ('refused_' + key)
        run(module, bad, error=code)
    if module == 'scanvi-annotate':
        copied = work / 'bad_model_hash'
        shutil.copytree(source, copied)
        doc = json.loads((copied / 'objects/handoff.json').read_text())
        model_file = next(obj for obj in doc['objects'] if obj['type'] == 'scvi_model_file')
        path = copied / model_file['path']
        path.write_bytes(path.read_bytes() + b'\n')
        bad = list(args)
        bad[bad.index('--from-run') + 1] = copied
        bad[bad.index('--outdir') + 1] = work / 'refused_model_hash'
        run(module, bad, error='OS_HANDOFF_MISMATCH')
        print('PASS: tampered upstream model-file hash refusal')
    print('PASS: ecosystem, corrected lineage and tampered-hash refusals')


def main(module_dir):
    module_dir = Path(module_dir).resolve()
    module = module_dir.name
    assert module in MODULES
    registry = module_dir / 'scripts/calls_registry.json'
    checked = check_calls(sorted((module_dir / 'scripts').glob('*.py')), registry)
    assert checked['ok'], checked
    for tool in ('check_defaults.py', 'check_flag_docs.py'):
        subprocess.run([sys.executable, str(SUITE / 'tools' / tool), str(module_dir)], check=True)
    process = subprocess.run([sys.executable, str(entry(module)), '--bogus'], capture_output=True, text=True)
    assert process.returncode == 1 and 'OS_UNKNOWN_FLAG' in process.stderr
    print('PASS: static calls, defaults, flags, package-independent help and typed argument errors')
    missing = [p for p in ('scanpy', 'anndata', 'scvi') if importlib.util.find_spec(p) is None]
    try:
        require_locked_environment()
    except RuntimeError as exc:
        if os.environ.get('OMICSTAT_REQUIRE_LOCKED') == '1':
            raise
        print('SKIP: numerical anchor / model / golden tests require locked image; ' + str(exc))
        return 0
    assert not missing, missing
    reg = json.loads(registry.read_text())
    assert reg.get('default_capture_status') == 'captured_locked_container', 'capture locked API formals before acceptance'
    drift = check_default_drift(registry)
    assert drift['ok'], drift
    base = Path(os.environ.get('OMICSTAT_TEST_TMP', tempfile.gettempdir()))
    base.mkdir(parents=True, exist_ok=True)
    work = Path(tempfile.mkdtemp(prefix=module + '_', dir=base))
    print('Acceptance workspace:', work, flush=True)
    source, args = prepare(module, work)
    output = work / 'anchor'
    run(module, args, env={'OMICSTAT_RUN_ID': 'acceptance-' + module})
    data = check_output(module, output)
    assert H.read_handoff(str(output))['run_id'] == 'acceptance-' + module
    independent_replay(module, source, output)
    print('PASS: anchor invariants and independent official-package replay')
    replay = work / 'replay'
    run(module, ['--spec', output / 'provenance/resolved_spec.json', '--outdir', replay],
        env={'OMICSTAT_RUN_ID': 'acceptance-' + module})
    check_output(module, replay)
    snap_a, snap_b = work / 'snapshot_a', work / 'snapshot_b'
    snapshot_tables(output, snap_a)
    snapshot_tables(replay, snap_b)
    compare_snapshots(snap_a, snap_b)
    print('PASS: --spec determinism; exact identities/tables and fixed coordinate tolerances')
    negative_chain_tests(module, args, source, work)
    if module == 'scanpy-qc':
        import numpy as np
        import pandas as pd
        observed = pd.read_csv(output / 'tables/cell_qc.csv')
        cutoff = int(np.quantile(observed['n_genes_by_counts'], 0.5))
        alternate = work / 'stricter_qc'
        run(module, qc_args(source, alternate, cutoff))
        assert load(alternate).n_obs < data.n_obs
        score = list(args)
        score[score.index('--outdir')+1] = work / 'doublet_score'
        score[score.index('--doublet-mode')+1] = 'score'
        score += ['--expected-doublet-rate', 0.06, '--doublet-threshold', 0.2, '--scrublet-pcs', 10]
        run(module, score)
        scored = pd.read_csv(work / 'doublet_score/tables/cell_qc.csv')
        assert scored['doublet_score'].notna().any()
    if module == 'scanpy-cluster':
        alternate = list(args)
        alternate[alternate.index('--n-pcs')+1] = 5
        alternate[alternate.index('--outdir')+1] = work / 'different_pcs'
        run(module, alternate)
        assert load(work / 'different_pcs').obsm['X_pca'].shape[1] == 5
    if module == 'scanpy-markers':
        invalid = list(args)
        invalid[invalid.index('--purpose')+1] = 'condition-inference'
        invalid[invalid.index('--outdir')+1] = work / 'invalid_inference'
        run(module, invalid, error='OS_PSEUDOREPLICATION')
        alternate = list(args) + ['--test', 'wilcoxon']
        alternate[alternate.index('--outdir')+1] = work / 'wilcoxon'
        run(module, alternate)
        assert (output/'tables/feature_table.csv').read_bytes() != (work/'wilcoxon/tables/feature_table.csv').read_bytes()
    if module == 'scvi-integrate':
        alternate = list(args)
        alternate[alternate.index('--n-latent')+1] = 3
        alternate[alternate.index('--outdir')+1] = work / 'different_latent'
        run(module, alternate)
        assert load(work / 'different_latent').obsm['X_scVI'].shape[1] == 3
    if module == 'scanvi-annotate':
        alternate = list(args)
        alternate[alternate.index('--min-confidence')+1] = 1
        alternate[alternate.index('--outdir')+1] = work / 'different_display'
        run(module, alternate)
        import pandas as pd
        prior = pd.read_csv(output/'tables/annotations.csv')
        after = pd.read_csv(work/'different_display/tables/annotations.csv')
        assert prior['predicted_label'].equals(after['predicted_label'])
        assert after['below_display_threshold'].all()
    print('PASS: numerical flag effectiveness and scientific refusal path')
    from s4_option_replay import verify
    verify(module, source, args, work)
    golden(module_dir, output, snap_a, os.environ.get('OMICSTAT_WRITE_GOLDEN') == '1')
    print('PASS: %s pinned numerical smoke; R rendering/visual review must run separately' % module)
    return 0

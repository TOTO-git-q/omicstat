"""Pure-Python contract tests. These do not claim scverse estimator acceptance."""
from __future__ import annotations
import hashlib
import json
import os
import runpy
import sys
from pathlib import Path
from types import SimpleNamespace
import numpy as np
import pandas as pd
import pytest
from scipy import sparse

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
sys.path.insert(0, str(HERE.parent))
sys.path.insert(0, str(ROOT / 'tools'))
from ospy import sc_module as S, handoff as H, figure_request as F, module_kit as K
from ospy.errors import OmicstatError
from seal_python import require_locked_environment


@pytest.mark.parametrize('value', [np.array([[0, 1], [3, 4]]), sparse.csr_matrix([[0, 1], [3, 4]]), np.zeros((2, 2))])
def test_integer_counts(value):
    S.validate_counts(value)


@pytest.mark.parametrize('value', [np.array([[0, -1]]), np.array([[1, 0.1]]), np.array([[np.inf]]), np.array([[np.nan]]), np.array([['x']])])
def test_refuse_invalid_counts(value):
    with pytest.raises(OmicstatError, match='OS_INVALID_INPUT'):
        S.validate_counts(value)


def test_clusters_and_pca_are_canonical():
    labels, mapping = S.canonical_clusters(['b', 'a', 'b', 'a', 'c'])
    assert mapping == {'a': '0', 'b': '1', 'c': '2'}
    assert list(labels) == ['1', '0', '1', '0', '2']
    scores = np.array([[1., 2.], [3., 4.]])
    loading = np.array([[-0.9, 0.2], [0.1, -0.8], [0.2, 0.1]])
    canonical, weights = S.canonical_pca(scores, loading)
    np.testing.assert_allclose(scores @ loading.T, canonical @ weights.T)
    for j in range(weights.shape[1]):
        assert weights[np.argmax(np.abs(weights[:, j])), j] >= 0


def test_layer_is_not_guessed():
    obj = SimpleNamespace(X=np.array([[1, 0]]), layers={'counts': np.array([[1, 2]])})
    np.testing.assert_array_equal(S.layer(obj, 'counts', counts=True), [[1, 2]])
    with pytest.raises(OmicstatError, match='OS_MISSING_LAYER'):
        S.layer(obj, 'normalized')


@pytest.mark.parametrize('column', ['absent', 'empty', 'missing'])
def test_missing_metadata(column):
    data = pd.DataFrame({'empty': [''], 'missing': [None]})
    with pytest.raises(OmicstatError):
        S.require_columns(data, [column])


def test_batch_diagnostic_does_not_invent_neighbors():
    graph = sparse.csr_matrix([[2., 1., 1.], [1., 2., 0.], [0., 0., 1.]])
    answer = S.batch_mixing(graph, ['A', 'A', 'B'])
    assert answer.loc[0, 'same_batch_weight_fraction'] == .5
    assert answer.loc[0, 'normalized_batch_entropy'] == 1
    assert answer.loc[1, 'same_batch_weight_fraction'] == 1
    assert np.isnan(answer.loc[2, 'same_batch_weight_fraction'])


def test_embedding_does_not_recompute_missing_reduction():
    obj = SimpleNamespace(n_obs=2, obs_names=pd.Index(['a', 'b']),
                          obs=pd.DataFrame({'cluster': ['0', '1']}), obsm={})
    with pytest.raises(OmicstatError, match='OS_MISSING_REDUCTION'):
        S.embedding_frame(obj, 'cluster')
    obj.obsm['X_umap'] = np.array([[1, 2], [3, 4]])
    frame = S.embedding_frame(obj, 'cluster')
    assert frame['cell'].tolist() == ['a', 'b']
    np.testing.assert_array_equal(frame[['x', 'y']], obj.obsm['X_umap'])


def make_handoff(tmp_path, monkeypatch=None):
    root = tmp_path / 'ws'
    root.mkdir()
    obj = root / 'counts.csv'
    obj.write_text('feature_id,sample\ngene,1\n')
    if monkeypatch:
        monkeypatch.setenv('OMICSTAT_RUN_ID', 'actual-mcp-uuid')
    H.write_handoff(str(root), 'ws', 'scanpy-qc', '1.0.0',
                    {'counts': {'path': str(obj), 'type': 'count_matrix'}},
                    ecosystem='scverse', state={'front_end_ecosystem': 'scverse'})
    return root


def test_run_id_uses_mcp_uuid(tmp_path, monkeypatch):
    root = make_handoff(tmp_path, monkeypatch)
    result = H.read_handoff(str(root))
    assert result['run_id'] == 'actual-mcp-uuid'
    assert result['upstream_runs'] == ['actual-mcp-uuid']


@pytest.mark.parametrize('value', ['../escape', 'bad/id', ' ', 'x'*129])
def test_invalid_run_id_refused(monkeypatch, value):
    monkeypatch.setenv('OMICSTAT_RUN_ID', value)
    with pytest.raises(OmicstatError):
        H.os_run_id('/ws')


def test_corrected_lineage_not_laundered(tmp_path):
    root = make_handoff(tmp_path)
    path = root / 'objects/handoff.json'
    doc = json.loads(path.read_text())
    doc['state']['batch_corrected_lineage'] = True
    path.write_text(json.dumps(doc))
    with pytest.raises(OmicstatError, match='OS_BATCH_CORRECTED_INPUT'):
        H.read_handoff(str(root), expect={'counts': 'count_matrix'})
    upstream = H.read_handoff(str(root))
    with pytest.raises(OmicstatError, match='OS_BATCH_CORRECTED_INPUT'):
        H.assert_uncorrected(upstream, 'counts')


def test_neutral_backend_does_not_reset_ecosystem(tmp_path):
    root = make_handoff(tmp_path)
    path = root / 'objects/handoff.json'
    doc = json.loads(path.read_text())
    doc['ecosystem'] = 'neutral'
    doc['state']['front_end_ecosystem'] = 'seurat'
    path.write_text(json.dumps(doc))
    with pytest.raises(OmicstatError, match='OS_ECOSYSTEM_MIXED'):
        H.read_handoff(str(root), front_end_ecosystem='scverse')


def test_duplicate_object_name_refused(tmp_path):
    root = make_handoff(tmp_path)
    path = root / 'objects/handoff.json'
    doc = json.loads(path.read_text())
    doc['objects'].append(doc['objects'][0].copy())
    path.write_text(json.dumps(doc))
    with pytest.raises(OmicstatError, match='duplicate'):
        H.read_handoff(str(root))


def test_symlink_escape_refused(tmp_path):
    root = make_handoff(tmp_path)
    outside = tmp_path / 'outside.csv'
    outside.write_text('private\n')
    link = root / 'escape.csv'
    try:
        link.symlink_to(outside)
    except OSError:
        pytest.skip('filesystem does not support symlinks')
    path = root / 'objects/handoff.json'
    doc = json.loads(path.read_text())
    doc['objects'][0].update(path='escape.csv', sha256=hashlib.sha256(outside.read_bytes()).hexdigest())
    path.write_text(json.dumps(doc))
    with pytest.raises(OmicstatError, match='OS_HANDOFF_MISMATCH'):
        H.read_handoff(str(root))


def test_contract_mismatch_refused(tmp_path):
    root = make_handoff(tmp_path)
    path = root / 'objects/handoff.json'
    doc = json.loads(path.read_text())
    doc['contract_hash'] = 'original'
    path.write_text(json.dumps(doc))
    with pytest.raises(OmicstatError, match='OS_CONTRACT_MISMATCH'):
        H.read_handoff(str(root), contract_hash='different')


def test_figure_caption_context_and_data_hashes(tmp_path):
    request = F.FigureRequest(str(tmp_path), 'scanpy-qc', '1.0.0')
    request.add('a', 'os_embedding', data={'emb': F.frame([{'cell': 'a', 'x': 1., 'y': 2., 'cluster': '0'}])},
                caption_context='One cell; QC thresholds were declared.')
    request.write()
    content = json.loads((tmp_path / F.REQUEST_REL).read_text())
    assert content['figures'][0]['caption_context'].startswith('One cell')
    descriptor = content['figures'][0]['data']['emb']
    assert K.sha256_file(tmp_path / descriptor['path']) == descriptor['sha256']
    with pytest.raises(OmicstatError, match='caption_context'):
        request.add('b', 'os_embedding', data={}, caption_context=2)


def test_seal_refuses_unpinned_interpreter(monkeypatch):
    monkeypatch.delenv('OMICSTAT_PY_CONTAINER', raising=False)
    with pytest.raises(RuntimeError, match='OS_ENVIRONMENT_MISMATCH'):
        require_locked_environment()


@pytest.mark.parametrize('module', ['scanpy-qc', 'scanpy-cluster', 'scanpy-markers', 'scvi-integrate', 'scanvi-annotate'])
def test_layout_and_registry_have_no_fake_seal(module):
    folder = ROOT / 'skills' / module
    for relative in ['SKILL.md', 'scripts/calls_registry.json', 'tests/run_smoke_test.py', 'tests/generate_golden.sh',
                     'tests/fixtures/make_anchor.py', 'references/reporting-templates.md', 'references/parameters.md']:
        assert (folder / relative).is_file()
    registry = json.loads((folder / 'scripts/calls_registry.json').read_text())
    assert registry['default_capture_status'] in ('pending_locked_container', 'captured_locked_container')
    if registry['default_capture_status'] == 'pending_locked_container':
        assert not (folder / 'module_lock.json').exists()
        assert all('function_default' not in arg for call in registry['calls'] for arg in call['args'].values())

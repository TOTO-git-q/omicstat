#!/usr/bin/env python3
"""Adapter contract tests using isolated test doubles, never real data claims."""
import contextlib
import hashlib
import importlib.util
import io
import json
import pathlib
import sys
import tarfile
import tempfile
import types
import unittest
from unittest.mock import patch
from lint_contracts import validate

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'skills/_shared/py/tests'))
import sc_anchor


def load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class FakeData:
    """Tiny in-memory stand-in; not a biological fixture or Scanpy calculation."""
    def __init__(self, n=2700):
        self.n_obs, self.n_vars, self.obs = n, 1000, {}
    def __getitem__(self, item):
        return FakeData(min(item[0].stop, self.n_obs))
    def copy(self):
        return self
    def write_h5ad(self, filename, **kwargs):
        pathlib.Path(filename).write_text('SYNTHETIC TEST DOUBLE; cells=%s\n' % self.n_obs)


class AnchorAdapterTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.tmp.name)
        self.source = self.root / 'acceptance/data/pbmc3k_filtered_gene_bc_matrices.tar.gz'
        self.source.parent.mkdir(parents=True)
        with tarfile.open(self.source, 'w:gz') as archive:
            content = b'SYNTHETIC MATRIX TEST DOUBLE\n'
            info = tarfile.TarInfo('filtered/matrix.mtx')
            info.size = len(content)
            archive.addfile(info, io.BytesIO(content))
        self.digest = hashlib.sha256(self.source.read_bytes()).hexdigest()
        self.fake = types.SimpleNamespace(read_10x_mtx=lambda **kwargs: FakeData())

    def tearDown(self):
        self.tmp.cleanup()

    @contextlib.contextmanager
    def doubles(self):
        with patch.dict(sys.modules, {'scanpy': self.fake}), patch.object(sc_anchor, 'PBMC_SHA256', self.digest):
            yield

    def test_legacy_smoke_budget_is_unchanged(self):
        with self.doubles():
            path = sc_anchor.make_pbmc(self.root, self.root / 'smoke.h5ad')
        result = json.loads(path.with_name(path.name + '.source.json').read_text())
        self.assertEqual(result['n_cells'], 600)
        self.assertEqual(result['fixture_rule'], 'first 600 cells in supplied order; all genes')

    def test_owner_adapter_requests_all_supplied_cells(self):
        adapter = load_module('owner_pbmc_unit', ROOT / 'skills/scanpy-cluster/tests/prepare_acceptance.py')
        with self.doubles():
            result = adapter.prepare(self.root / 'out', self.root)
        self.assertEqual(result['preparation']['n_cells'], 2700)
        self.assertEqual(result['preparation']['biological_samples'], 1)
        self.assertFalse(result['preparation']['independent_condition_inference'])
        self.assertIn('no acceptance subsampling', result['preparation']['rule'])
        self.assertEqual(result['source_files'], [{'key': 'archive', 'sha256': self.digest}])
        output = self.root / 'out' / result['prepared_inputs'][0]['path']
        self.assertEqual(result['prepared_inputs'][0]['sha256'], hashlib.sha256(output.read_bytes()).hexdigest())

    def test_owner_adapter_preserves_existing_outputs(self):
        adapter = load_module('owner_pbmc_unit', ROOT / 'skills/scanpy-cluster/tests/prepare_acceptance.py')
        with self.doubles():
            adapter.prepare(self.root / 'out', self.root)
            with self.assertRaises(FileExistsError):
                adapter.prepare(self.root / 'out', self.root)

    def test_unregistered_archive_bytes_refuse_before_native_read(self):
        with patch.dict(sys.modules, {'scanpy': self.fake}):
            with self.assertRaisesRegex(RuntimeError, 'SHA256 mismatch'):
                sc_anchor.make_pbmc(self.root, self.root / 'wrong.h5ad', max_cells=None)
        self.assertFalse((self.root / 'wrong.h5ad').exists())

    def test_budget_value_guard(self):
        for bad in [True, 0, -1, '600', 1.5]:
            with self.subTest(value=bad), self.assertRaises(ValueError):
                sc_anchor.make_pbmc(self.root, self.root / 'invalid.h5ad', max_cells=bad)

    def test_canonical_and_anchor_schemas_are_valid(self):
        for module in ['deseq2-wald', 'scanpy-cluster']:
            for name, schema in [('acceptance', 'fixture'), ('anchors', 'anchors')]:
                value = json.loads((ROOT / 'skills' / module / 'tests' / (name + '.json')).read_text())
                definition = json.loads((ROOT / 'acceptance/schemas' / (schema + '.v1.schema.json')).read_text())
                with self.subTest(module=module, contract=name):
                    self.assertEqual(validate(value, definition), [])

    def test_anchor_exception_cannot_be_written_as_success(self):
        adapter = load_module('pbmc_anchor_unit', ROOT / 'skills/scanpy-cluster/tests/anchors.py')
        def fail(*args):
            raise AssertionError('intentional direct-package mismatch')
        with patch.dict(sys.modules, {'sc_smoke_support': types.SimpleNamespace(independent_replay=fail)}):
            with self.assertRaises(AssertionError):
                adapter.check(self.root / 'source', self.root / 'run', self.root / 'obtained.json')
        self.assertFalse((self.root / 'obtained.json').exists())

    def test_replay_only_anchors_never_invent_printed_counts(self):
        definitions = json.loads((ROOT / 'skills/scanpy-cluster/tests/anchors.json').read_text())
        self.assertEqual({x['id'] for x in definitions}, {'hvg_exact', 'pca_fixed_tolerance', 'cluster_ari_one'})
        self.assertTrue(all(x['how'] == 'replay' and x['expected'] is True for x in definitions))


if __name__ == '__main__':
    unittest.main()

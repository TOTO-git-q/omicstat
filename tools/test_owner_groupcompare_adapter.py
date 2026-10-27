"""Owner receipt contracts with labelled synthetic doubles; no real rows copied."""
import hashlib
import importlib.util
import json
import pathlib
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch
from acceptance.owner_data import dataset
from lint_contracts import validate

ROOT = pathlib.Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'skills/omicstat-groupcompare/tests/prepare_acceptance.py'
SPEC = importlib.util.spec_from_file_location('owner_sleep_adapter_unit', SCRIPT)
ADAPTER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ADAPTER)
SYNTHETIC = b'SYNTHETIC RECEIPT CONTRACT DOUBLE ONLY\n'
SOURCE_SHA = 'c45604d3160d61f40535c8773b1762e120e47b824d95521950ea54ca17516fd9'
CONTRACT_SHA = '8ad040e702a9fa98057c2883291bdaa8089dc38e37fcdf5d7b0b3c5fefd033bb'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


class SleepOwnerAdapter(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.tmp.name)
        schema = 'skills/_shared/schemas/study_contract.v1.schema.json'
        (self.root / schema).parent.mkdir(parents=True)
        shutil.copyfile(ROOT / schema, self.root / schema)
        self.out = self.root / 'fixtures'
        self.registered = {'sources': [{'key': 'sleep_csv', 'sha256': hashlib.sha256(SYNTHETIC).hexdigest()}]}

    def tearDown(self):
        self.tmp.cleanup()

    def writer(self, argv, *, check):
        self.assertTrue(check)
        self.assertEqual(argv, ['Rscript', str(self.root / 'skills/omicstat-groupcompare/tests/make_inputs.R'), str(self.out)])
        (self.out / 'sleep.csv').write_bytes(SYNTHETIC)
        (self.out / 'comparisons.csv').write_text('SYNTHETIC COMPARISON CONTRACT DOUBLE ONLY\n')
        return subprocess.CompletedProcess(argv, 0)

    def prepare(self, writer=None):
        with patch.object(ADAPTER, 'dataset', return_value=(self.registered, 'unit-only')), \
             patch.object(ADAPTER.subprocess, 'run', side_effect=writer or self.writer):
            return ADAPTER.prepare(self.out, self.root)

    def test_fresh_receipt_binds_all_canonical_inputs(self):
        self.out.mkdir()  # Real Pipeline creates an empty fixtures directory.
        result = self.prepare()
        self.assertEqual(result['dataset_id'], 'r-sleep')
        self.assertEqual(result['source_files'], self.registered['sources'])
        self.assertEqual({x['path'] for x in result['prepared_inputs']}, {'sleep.csv', 'comparisons.csv', 'contract.json'})
        for row in result['prepared_inputs']:
            self.assertEqual(row['sha256'], sha(self.out / row['path']))
            self.assertEqual(row['bytes'], (self.out / row['path']).stat().st_size)
        # This is real contract serialization, compared to the existing native
        # executor receipt. The data writer above remains a synthetic double.
        self.assertEqual(sha(self.out / 'contract.json'), CONTRACT_SHA)
        self.assertFalse(result['preparation']['independent_group_inference'])
        self.assertEqual(result, json.loads((self.out / 'owner_dataset.json').read_text()))

    def test_existing_evidence_is_not_overwritten(self):
        self.prepare()
        before = {p.name: p.read_bytes() for p in self.out.iterdir()}
        with self.assertRaises(FileExistsError):
            self.prepare()
        self.assertEqual(before, {p.name: p.read_bytes() for p in self.out.iterdir()})

    def test_wrong_native_data_hash_produces_no_receipt(self):
        self.registered['sources'][0]['sha256'] = '0' * 64
        with self.assertRaisesRegex(ValueError, 'serialization SHA256 mismatch'):
            self.prepare()
        self.assertFalse((self.out / 'owner_dataset.json').exists())

    def test_missing_or_failed_R_never_produces_receipt(self):
        for error in [FileNotFoundError('unit-only missing Rscript'), subprocess.CalledProcessError(1, ['Rscript'])]:
            with self.subTest(error=type(error).__name__):
                if self.out.exists():
                    shutil.rmtree(self.out)
                def fail(*args, **kwargs):
                    raise error
                with self.assertRaises(type(error)):
                    self.prepare(fail)
                self.assertFalse((self.out / 'owner_dataset.json').exists())
                self.assertEqual(sha(self.out / 'contract.json'), CONTRACT_SHA)

    def test_missing_comparison_cannot_issue_receipt(self):
        def incomplete(*args, **kwargs):
            self.writer(*args, **kwargs)
            (self.out / 'comparisons.csv').unlink()
        with self.assertRaisesRegex(ValueError, 'missing or unsafe'):
            self.prepare(incomplete)
        self.assertFalse((self.out / 'owner_dataset.json').exists())

    def test_registration_drift_is_rejected_before_native_execution(self):
        with patch.object(ADAPTER, 'dataset', side_effect=ValueError('official source drift')), \
                patch.object(ADAPTER.subprocess, 'run') as run:
            with self.assertRaisesRegex(ValueError, 'official source drift'):
                ADAPTER.prepare(self.out, self.root)
        run.assert_not_called()
        self.assertFalse(self.out.exists())

    def test_checked_in_official_registration_uses_existing_exact_head_proof(self):
        registered, _ = dataset(ROOT, 'omicstat-groupcompare', 'r-sleep')
        self.assertEqual(registered['label'], 'datasets::sleep (10 paired subjects)')
        self.assertEqual(registered['sources'][0]['sha256'], SOURCE_SHA)
        provenance = registered['registration']['hash_provenance']
        report = json.loads((ROOT / provenance['local_report']).read_text())
        self.assertEqual(report['requested_source_head'], '1a1d406dd8d7cba9a4685c47df3220be2fc76309')
        self.assertEqual(report['requested_source_head'], provenance['requested_source_head'])
        self.assertEqual(report['image'], provenance['image'])
        self.assertIsNone(registered['registration']['owner_visual_approval'])
        # The exact published source fixture hash is present in the external
        # report. It is not inferred from published statistics or generated here.
        self.assertIn(SOURCE_SHA, json.dumps(report['artifact_hashes']))
        fixture = json.loads((ROOT / 'skills/omicstat-groupcompare/tests/acceptance.json').read_text())
        self.assertEqual(fixture['owner_review'], {'dataset_id': 'r-sleep', 'receipt': 'owner_dataset.json'})
        for name, schema in [('acceptance', 'fixture'), ('anchors', 'anchors')]:
            value = json.loads((ROOT / 'skills/omicstat-groupcompare/tests' / (name + '.json')).read_text())
            definition = json.loads((ROOT / 'acceptance/schemas' / (schema + '.v1.schema.json')).read_text())
            self.assertEqual(validate(value, definition), [])
        anchors = json.loads((ROOT / 'skills/omicstat-groupcompare/tests/anchors.json').read_text())
        self.assertEqual(len(anchors), 16)
        ported = anchors[6:]
        self.assertTrue(all(x['how'] == 'replay' and 'Synthetic' in x['scope'] for x in ported))
        self.assertTrue(all('obtained' not in x and 'pass' not in x for x in ported))
        anchors = anchors[:6]  # Exact original official sleep anchors remain unchanged.
        self.assertTrue(all(x['how'] == 'printed' for x in anchors))
        self.assertEqual([x['expected'] for x in anchors], [-4.062, 9, .003, -1.58, -2.293, -.867])
        self.assertEqual([x['tolerance'] for x in anchors], [.0005, 0, .0005, .0005, .0005, .0005])
        self.assertIn('dataset_id', fixture['owner_review'])


if __name__ == '__main__':
    unittest.main()

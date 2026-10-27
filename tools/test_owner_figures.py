#!/usr/bin/env python3
"""Synthetic unit tests of real-data lineage gates; no biological acceptance.

The miniature registry and successful invocation below are test doubles in a
temporary directory. They are never committed as official dataset evidence.
Actual official-data rendering still requires the locked executor and cache.
"""
import copy
import json
import pathlib
import tempfile
import unittest
from PIL import Image

from acceptance.common import dump, load, sha, replay_inventory
from acceptance.figures import contact_sheet, inspect_figures
from acceptance.owner_data import REGISTRY, bind_run, dataset, source_hashes, input_snapshot, verify_run
from accept_module import source_fingerprint


class OwnerFigureTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.base = pathlib.Path(self.temp.name)
        self.root = self.base / 'repo'
        self.out = self.base / 'evidence'
        self.fixtures = self.out / 'fixtures'
        self.run = self.out / 'runs/canonical'
        self.module = 'unit-fixture'
        self.folder = self.root / 'skills' / self.module
        for path in [self.folder / 'scripts', self.folder / 'tests', self.fixtures,
                     self.run / 'tables', self.run / 'figures', self.out / 'logs',
                     self.root / 'acceptance/data']:
            path.mkdir(parents=True)
        self.fixture = {'canonical': {'argv': ['--input', '{fixtures}/counts.csv', '--outdir', '{outdir}']},
                        'prepare': [{'script': 'tests/prepare.py', 'argv': []}],
                        'owner_review': {'dataset_id': 'unit-test', 'receipt': 'receipt.json'}}
        dump(self.folder / 'module.json', {'entry': 'scripts/run.py'})
        dump(self.folder / 'tests/acceptance.json', self.fixture)
        (self.folder / 'scripts/run.py').write_text('# synthetic unit-test execution double\n')
        (self.folder / 'tests/prepare.py').write_text('# synthetic unit-test preparation double\n')
        registration = self.root / 'acceptance/data/REGISTRATION.txt'
        registration.write_text('Synthetic unit-test registry only; not official evidence.\n')
        self.registry = {'schema': 'omicstat.owner-review-datasets.v1',
                         'registration_files_sha256': {'acceptance/data/REGISTRATION.txt': sha(registration)},
                         'datasets': [{'id': 'unit-test', 'label': 'SYNTHETIC UNIT TEST fixture',
                                       'kind': 'registered_real', 'modules': [self.module],
                                       'sources': [{'key': 'raw', 'sha256': 'a' * 64}]}]}
        dump(self.root / REGISTRY, self.registry)
        data = self.fixtures / 'counts.csv'
        data.write_text('value\n1\n2\n3\n')
        self.receipt = {'schema': 'omicstat.owner-dataset-receipt.v1', 'dataset_id': 'unit-test',
                        'kind': 'registered_real', 'source_files': [{'key': 'raw', 'sha256': 'a' * 64}],
                        'prepared_inputs': [{'path': 'counts.csv', 'sha256': sha(data), 'bytes': data.stat().st_size}]}
        dump(self.fixtures / 'receipt.json', self.receipt)
        (self.run / 'tables/result.csv').write_text('value\n1\n2\n3\n')
        image = self.run / 'figures/test.png'
        Image.new('RGB', (120, 80), 'white').save(image)
        dump(image.with_suffix('.figure_spec.json'), {
            'schema': 'omicstat.figure-spec.v1', 'caption': 'Synthetic unit-test image, not owner data',
            'width_mm': 89, 'height_mm': 60, 'png_dpi': 600, 'lint': [],
            'files': {'png': {'sha256': sha(image)}}})
        self.records = inspect_figures(self.run)
        self.argv = ['--input', str(data), '--outdir', str(self.run)]
        self.command = ['python3', str(self.folder / 'scripts/run.py')] + self.argv
        self.execution = {'schema': 'omicstat.canonical-execution.v1', 'command': self.command,
                          'runner_argv': self.command, 'returncode': 0, 'timed_out': False,
                          'log': 'logs/canonical-unit-double.log',
                          'source_scripts_sha256': source_hashes(self.root, self.module, self.fixture),
                          'input_snapshot': input_snapshot(self.fixtures, self.fixture),
                          'artifacts_sha256': replay_inventory(self.run)}
        log = self.out / self.execution['log']
        log.write_text('ARGV ' + repr(self.command) + '\nRETURN 0\nSTDOUT\nUNIT TEST DOUBLE ONLY\nSTDERR\n')
        self.execution['log_sha256'] = sha(log)
        dump(self.out / 'canonical_execution.json', self.execution)
        self.proof = self.out / 'owner_run_evidence.json'
        self.context = dict(root=self.root, module=self.module, fixtures=self.fixtures,
                            fixture=self.fixture, evidence_path=self.proof,
                            execution_root=self.out, expected_command=self.command)

    def tearDown(self):
        self.temp.cleanup()

    def bind(self):
        return bind_run(self.root, self.module, self.fixtures, self.run, self.records,
                        self.fixture, self.argv, {'counts.csv': str(self.fixtures / 'counts.csv')},
                        self.proof, execution_root=self.out, expected_command=self.command)

    def verify(self):
        return verify_run(run=self.run, records=self.records, **self.context)

    def test_lineage_double_binds_all_artifacts_and_labels_every_tile(self):
        before = sha(self.run / 'tables/result.csv')
        evidence = self.bind()
        self.assertEqual(self.verify()['id'], 'unit-test')
        sheet = contact_sheet(self.run, self.records, self.out / 'unit-sheet.png', owner_context=self.context)
        self.assertTrue(sheet['dataset_label_on_each_tile'])
        self.assertEqual(sheet['figure_datasets'], {'figures/test.png': 'unit-test'})
        self.assertLessEqual(sheet['bytes'], 2 * 1024 * 1024)
        self.assertEqual(sha(self.run / 'tables/result.csv'), before)
        self.assertIsNone(evidence['visual_review'])
        self.assertFalse(evidence['scientific_anchor_results_certified'])
        self.assertIsNone(sheet['visual_review'])

    def test_missing_real_evidence_is_never_an_owner_sheet(self):
        with self.assertRaisesRegex(ValueError, 'registered real-data'):
            contact_sheet(self.run, self.records, self.out / 'owner.png')
        self.assertFalse((self.out / 'owner.png').exists())

    def test_explicit_contract_sheet_stays_ineligible(self):
        result = contact_sheet(self.run, self.records, self.out / 'contract.png', purpose='contract')
        self.assertFalse(result['owner_review_eligible'])
        self.assertIsNone(result['dataset'])
        self.assertEqual(result['figure_datasets'], {})

    def test_real_repository_registry_has_reviewed_hash_bindings(self):
        root = pathlib.Path(__file__).resolve().parents[1]
        for module, name in [('deseq2-wald', 'pasilla'), ('scanpy-cluster', 'pbmc3k'),
                             ('edger-qlf', 'gse60450'), ('limma-voom', 'gse63310'), ('scater-qc', 'zeisel')]:
            with self.subTest(dataset=name):
                self.assertEqual(dataset(root, module, name)[0]['id'], name)

    def test_official_registration_drift_refused(self):
        (self.root / 'acceptance/data/REGISTRATION.txt').write_text('changed')
        with self.assertRaisesRegex(ValueError, 'registration changed'):
            self.bind()

    def test_synthetic_or_wrong_module_registry_refused(self):
        for field, value in [('kind', 'synthetic'), ('modules', ['another-module'])]:
            changed = copy.deepcopy(self.registry)
            changed['datasets'][0][field] = value
            dump(self.root / REGISTRY, changed)
            with self.subTest(field=field), self.assertRaises(ValueError):
                self.bind()

    def test_unknown_and_duplicate_dataset_refused(self):
        for identifier in ['unknown', 'unit-test']:
            if identifier == 'unit-test':
                self.registry['datasets'].append(copy.deepcopy(self.registry['datasets'][0]))
                dump(self.root / REGISTRY, self.registry)
            with self.subTest(identifier=identifier), self.assertRaises(ValueError):
                dataset(self.root, self.module, identifier)

    def test_source_sha_and_duplicate_keys_refused(self):
        for entries in [[{'key': 'raw', 'sha256': 'b' * 64}], self.receipt['source_files'] * 2]:
            self.receipt['source_files'] = entries
            dump(self.fixtures / 'receipt.json', self.receipt)
            with self.assertRaisesRegex(ValueError, 'registered real source'):
                self.bind()

    def test_duplicate_prepared_input_refused(self):
        self.receipt['prepared_inputs'] *= 2
        dump(self.fixtures / 'receipt.json', self.receipt)
        with self.assertRaisesRegex(ValueError, 'unique prepared'):
            self.bind()

    def test_unconsumed_input_refused(self):
        self.argv[1] = 'unrelated.csv'
        with self.assertRaisesRegex(ValueError, 'not bound'):
            self.bind()

    def test_modified_input_before_binding_refused(self):
        (self.fixtures / 'counts.csv').write_text('changed')
        with self.assertRaisesRegex(ValueError, 'canonical input changed'):
            self.bind()

    def test_input_receipt_table_spec_and_script_drift_each_refused(self):
        self.bind()
        for path in [self.fixtures / 'counts.csv', self.fixtures / 'receipt.json',
                     self.run / 'tables/result.csv', self.run / 'figures/test.figure_spec.json',
                     self.folder / 'scripts/run.py']:
            original = path.read_bytes()
            path.write_bytes(original + b'\n')
            with self.subTest(path=path.name), self.assertRaises(ValueError):
                self.verify()
            path.write_bytes(original)

    def test_missing_and_failed_canonical_execution_refused(self):
        path = self.out / 'canonical_execution.json'
        path.unlink()
        with self.assertRaises(ValueError):
            self.bind()
        self.execution['returncode'] = 1
        dump(path, self.execution)
        with self.assertRaisesRegex(ValueError, 'successful bound'):
            self.bind()

    def test_execution_argv_and_log_drift_refused(self):
        self.bind()
        self.execution['command'] = ['python3', 'other.py']
        dump(self.out / 'canonical_execution.json', self.execution)
        with self.assertRaisesRegex(ValueError, 'successful bound'):
            self.verify()

    def test_canonical_log_drift_refused(self):
        self.bind()
        (self.out / self.execution['log']).write_text('RETURN 1\n')
        with self.assertRaisesRegex(ValueError, 'log changed'):
            self.verify()

    def test_empty_tables_and_omitted_figures_refused(self):
        table = self.run / 'tables/result.csv'
        table.unlink()
        with self.assertRaisesRegex(ValueError, 'artifacts changed'):
            self.bind()
        table.write_text('value\n1\n')
        self.records = []
        with self.assertRaises(ValueError):
            self.bind()

    def test_forged_lint_result_refused(self):
        record = self.records[0]
        spec = self.run / record['spec']
        data = load(spec)
        data['lint'] = [{'severity': 'blocker'}]
        dump(spec, data)
        with self.assertRaises(ValueError):
            self.bind()

    def test_rewritten_input_and_receipt_cannot_rebind_an_old_execution(self):
        data = self.fixtures / 'counts.csv'
        data.write_text('different input after actual invocation\n')
        self.receipt['prepared_inputs'][0].update(sha256=sha(data), bytes=data.stat().st_size)
        dump(self.fixtures / 'receipt.json', self.receipt)
        with self.assertRaisesRegex(ValueError, 'bytes supplied'):
            self.bind()

    def test_rewritten_outputs_cannot_be_attested_as_old_execution(self):
        (self.run / 'tables/result.csv').write_text('changed after invocation\n')
        with self.assertRaisesRegex(ValueError, 'artifacts changed'):
            self.bind()

    def test_missing_per_figure_dataset_refused(self):
        evidence = self.bind()
        evidence['figure_datasets'] = {}
        dump(self.proof, evidence)
        with self.assertRaisesRegex(ValueError, 'each owner figure'):
            self.verify()

    def test_contract_sheet_path_escape_and_symlink_refused(self):
        for path in ['../outside.png', '/tmp/outside.png']:
            with self.subTest(path=path), self.assertRaises(ValueError):
                contact_sheet(self.run, [{'path': path}], self.out / 'unsafe.png', purpose='contract')
        target = self.run / 'figures/test.png'
        link = self.run / 'figures/link.png'
        link.symlink_to(target)
        with self.assertRaises(ValueError):
            contact_sheet(self.run, [{'path': 'figures/link.png'}], self.out / 'unsafe.png', purpose='contract')

    def test_prepared_input_symlink_refused(self):
        target = self.fixtures / 'counts.csv'
        original = self.base / 'original.csv'
        target.rename(original)
        target.symlink_to(original)
        with self.assertRaisesRegex(ValueError, 'missing/unsafe'):
            self.bind()

    def test_registry_is_in_resume_fingerprint(self):
        before = source_fingerprint(self.root, self.module, None, None)
        self.registry['datasets'][0]['label'] = 'Changed unit-test label'
        dump(self.root / REGISTRY, self.registry)
        self.assertNotEqual(before, source_fingerprint(self.root, self.module, None, None))

    def test_sheet_inventory_and_size_caps(self):
        with self.assertRaisesRegex(ValueError, '128'):
            contact_sheet(self.run, self.records * 129, self.out / 'large.png', purpose='contract')
        with self.assertRaisesRegex(ValueError, 'exceeds'):
            contact_sheet(self.run, self.records, self.out / 'small.png', max_bytes=1, purpose='contract')


if __name__ == '__main__':
    unittest.main()

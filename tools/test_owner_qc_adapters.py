"""QC adapter contracts with test doubles; never a biological/native pass."""
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import types
import unittest
from unittest.mock import patch

from lint_contracts import validate
import test_owner_anchor_adapters as anchor_contracts
from test_owner_anchor_adapters import load_module

ROOT = Path(__file__).resolve().parents[1]
MODULES = ('seurat-qc', 'scanpy-qc', 'scater-qc')


class QCCanonicalContracts(unittest.TestCase):
    def test_all_three_canonical_and_anchor_schemas(self):
        for module in MODULES:
            for name, schema in [('acceptance', 'fixture'), ('anchors', 'anchors')]:
                value = json.loads((ROOT/'skills'/module/'tests'/(name+'.json')).read_text())
                definition = json.loads((ROOT/'acceptance/schemas'/(schema+'.v1.schema.json')).read_text())
                with self.subTest(module=module, schema=schema):
                    self.assertEqual(validate(value, definition), [])

    def test_every_prepared_input_is_an_explicit_canonical_argument(self):
        inputs = {'seurat-qc':['pbmc3k_counts.rds'], 'scanpy-qc':['pbmc3k.h5ad'], 'scater-qc':['zeisel.rds','mt.txt']}
        for module in MODULES:
            q = json.loads((ROOT/'skills'/module/'tests/acceptance.json').read_text())
            self.assertEqual(q['figure_policy'], 'required')
            self.assertEqual(q['owner_review']['receipt'], 'owner_dataset.json')
            for file in inputs[module]:
                self.assertIn('{fixtures}/'+file, q['canonical']['argv'])
            self.assertTrue((ROOT/'skills'/module/q['prepare'][0]['script']).is_file())
            self.assertTrue((ROOT/'skills'/module/q['anchor_runner']['script']).is_file())

    def test_each_module_uses_only_its_registered_dataset(self):
        registry = json.loads((ROOT/'acceptance/data/owner_review_datasets.json').read_text())
        expected = {'seurat-qc':'pbmc3k','scanpy-qc':'pbmc3k','scater-qc':'zeisel'}
        for module, dataset in expected.items():
            q = json.loads((ROOT/'skills'/module/'tests/acceptance.json').read_text())
            self.assertEqual(q['owner_review']['dataset_id'], dataset)
            row, = [d for d in registry['datasets'] if d['id']==dataset]
            self.assertIn(module, row['modules'])
            self.assertEqual(row['kind'], 'registered_real')

    def test_existing_distinct_threshold_recipes_are_not_conflated(self):
        def args(module):
            a=json.loads((ROOT/'skills'/module/'tests/acceptance.json').read_text())['canonical']['argv']
            return dict(zip(a[::2], a[1::2]))
        seurat, scanpy, scater = (args(m) for m in MODULES)
        self.assertEqual({k:seurat[k] for k in ['--min-features','--max-features','--max-mito','--min-cells']},
                         {'--min-features':'200','--max-features':'2500','--max-mito':'5','--min-cells':'3'})
        self.assertEqual({k:scanpy[k] for k in ['--min-genes','--max-genes','--max-mito-percent','--min-cells','--doublet-mode']},
                         {'--min-genes':'1','--max-genes':'1000000','--max-mito-percent':'100','--min-cells':'1','--doublet-mode':'skip'})
        self.assertEqual(scater['--qc-mode'], 'mad')
        self.assertEqual(scater['--nmads'], '3')

    def test_retained_reference_and_registration_bytes_are_bound(self):
        registry = json.loads((ROOT/'acceptance/data/owner_review_datasets.json').read_text())
        for path, digest in registry['registration_files_sha256'].items():
            self.assertEqual(hashlib.sha256((ROOT/path).read_bytes()).hexdigest(), digest)
        helper = (ROOT/'skills/_shared/scripts/owner_qc_fixture.R').read_text()
        self.assertIn('registration source changed', helper)
        self.assertIn('registered input SHA256 differs', helper)
        self.assertIn('fresh canonical fixture required', helper)

    def test_printed_values_are_retained_not_replaced_by_engine_outputs(self):
        seurat = {x['id']:x for x in json.loads((ROOT/'skills/seurat-qc/tests/anchors.json').read_text())}
        self.assertEqual(seurat['input_cells']['expected'], 2700)
        self.assertEqual(seurat['created_genes']['expected'], 13714)
        self.assertEqual(seurat['first_cell_mito_percent']['tolerance'], 5e-8)
        scanpy = json.loads((ROOT/'skills/scanpy-qc/tests/anchors.json').read_text())
        self.assertTrue(all(x['how']=='replay' and x['expected'] is True and x['tolerance']==0 for x in scanpy))
        scater = {x['id']:x for x in json.loads((ROOT/'skills/scater-qc/tests/anchors.json').read_text())}
        self.assertEqual(scater['input_genes']['expected'], 20006)
        self.assertEqual(scater['input_cells']['expected'], 3005)
        self.assertTrue(all(x['tolerance']==0 for x in scater.values()))

    def test_qc_anchor_failure_never_becomes_boolean_success(self):
        adapter=load_module('owner_qc_anchor_test',ROOT/'skills/scanpy-qc/tests/anchors.py')
        with tempfile.TemporaryDirectory() as d:
            output=Path(d)/'obtained.json'
            def fail(*args):raise AssertionError('intentional direct QC mismatch')
            with patch.dict(sys.modules, {'sc_smoke_support':types.SimpleNamespace(independent_replay=fail)}):
                with self.assertRaises(AssertionError):adapter.check('source','run',output)
            self.assertFalse(output.exists())

    def test_qc_anchor_preserves_prior_output(self):
        adapter=load_module('owner_qc_anchor_test',ROOT/'skills/scanpy-qc/tests/anchors.py')
        with tempfile.TemporaryDirectory() as d:
            output=Path(d)/'obtained.json';output.write_text('prior')
            with self.assertRaises(FileExistsError):adapter.check('source','run',output)
            self.assertEqual(output.read_text(),'prior')

    def test_scanpy_qc_preparation_uses_all_cells_with_test_double_only(self):
        # Reuse isolated synthetic archive/double helpers, without collecting the
        # imported class's unrelated tests as part of this test count.
        harness=anchor_contracts.AnchorAdapterTests('test_legacy_smoke_budget_is_unchanged');harness.setUp()
        try:
            adapter=load_module('owner_qc_prepare_test',ROOT/'skills/scanpy-qc/tests/prepare_acceptance.py')
            with harness.doubles():result=adapter.prepare(harness.root/'qc',harness.root)
            self.assertEqual(result['preparation']['n_cells'],2700)
            self.assertIn('no acceptance subsampling',result['preparation']['rule'])
            self.assertFalse(result['preparation']['independent_condition_inference'])
            with self.assertRaises(FileExistsError):adapter.prepare(harness.root/'qc',harness.root)
        finally:harness.tearDown()

    def test_request_keeps_native_and_owner_stages_explicit(self):
        from accept_module import checked_request
        from exec_runner import request_for_branch
        path, declared = request_for_branch(ROOT, 'dot/P0-5-round3-qc-canonical')
        checked_request(ROOT, path)
        q=json.loads((ROOT/'acceptance/requests/P0-5-round3-qc-canonical.json').read_text())
        self.assertEqual(q, declared)
        self.assertEqual(q['modules'],list(MODULES))
        self.assertFalse(q['write_golden'])
        self.assertIsNone(q['owner_visual_review'])
        for stage in ('static','anchors','replay','figures','regression'):
            self.assertIn(stage,q['stages'])

    def test_qc_python_check_uses_python_even_with_R_candidate(self):
        from exec_runner import check_image
        config=json.loads((ROOT/'env/py/py-env.json').read_text())
        expected=config['image']+':'+config['image_tag']
        for candidate in (None, 'env/candidates/test-only'):
            plan={'default':candidate,'renderer':None}
            built={} if candidate is None else {candidate:{'image':{'tag':'omicstat-r:test-only'}}}
            self.assertEqual(check_image(ROOT,['python3','tools/test_owner_qc_adapters.py'],{'modules':[]},plan,built),expected)


    def test_precision_fix_changes_only_anchor_json_digits(self):
        docs = ROOT / 'docs/round3/20261017-qc-anchor-precision'
        before = (docs / 'anchors_before.R').read_bytes()
        current = (ROOT / 'skills/seurat-qc/tests/anchors.R').read_bytes()
        old_call = b'jsonlite::write_json(result, output, auto_unbox = TRUE, pretty = TRUE)'
        new_call = b'jsonlite::write_json(result, output, auto_unbox = TRUE, pretty = TRUE, digits = 17)'
        self.assertEqual(before.count(old_call), 1)
        self.assertEqual(current, before.replace(old_call, new_call))
        binding = json.loads((docs / 'SOURCE_BINDINGS.json').read_text())
        self.assertEqual(hashlib.sha256(before).hexdigest(), binding['anchor_before_sha256'])
        for path, digest in binding['unchanged_sources'].items():
            self.assertEqual(hashlib.sha256((ROOT/path).read_bytes()).hexdigest(), digest, path)
        self.assertFalse(binding['native_executed'])
        self.assertIsNone(binding['owner_visual_review'])

    def test_serialization_regression_uses_production_csv_and_json_calls(self):
        script = (ROOT/'skills/seurat-qc/tests/test_anchor_serialization.R').read_text()
        for required in ['os_seurat_write_tables', 'parse(writer_path)',
                         'tests/anchors.R', 'quote(jsonlite::write_json)',
                         'old_call$digits <- NULL', '!passes(old$first_cell_mito_percent)',
                         'identical(anchor$tolerance,5e-8)', 'identical(obtained$fractions,result$fractions)']:
            self.assertIn(required, script)
        self.assertNotIn('library(Seurat)', script)
        docs = ROOT / 'docs/round3/20261017-qc-anchor-precision'
        binding = json.loads((docs/'SOURCE_BINDINGS.json').read_text())
        for path, before in binding['request_before'].items():
            current = json.loads((ROOT/path).read_text())
            self.assertEqual(current['checks'][:-1],before['checks'])
            self.assertEqual(current['checks'][-1], ['Rscript','skills/seurat-qc/tests/test_anchor_serialization.R','/evidence/qc-anchor-serialization'])
            self.assertEqual(current['stages'],before['stages'])
            for key in ['modules','image_candidate','write_golden','fixtures_to_fetch','full_regression']:
                self.assertEqual(current[key],before[key])


if __name__ == '__main__':
    unittest.main(defaultTest='QCCanonicalContracts', verbosity=2)

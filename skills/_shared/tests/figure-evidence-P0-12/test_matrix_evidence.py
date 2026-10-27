"""Validate archived invented matrix evidence, not native engine acceptance."""
from pathlib import Path
import hashlib
import json
import struct
import unittest

ROOT = Path(__file__).resolve().parents[4]
E = ROOT / 'acceptance/figure-evidence-P0-12/matrix-semantics'


def read(path):
    return json.loads(path.read_text())


def resolved(relative):
    p = (ROOT / relative).resolve()
    assert p.is_relative_to(ROOT.resolve()), relative
    return p


class MatrixEvidenceTest(unittest.TestCase):
    def test_provenance_bytes(self):
        manifest = read(E / 'ARTIFACT_PROVENANCE.json')
        self.assertEqual(len({r['path'] for r in manifest}), len(manifest))
        self.assertEqual(sum(r['path'].endswith(('.pdf', '.png')) for r in manifest), 42)
        for row in manifest:
            with self.subTest(path=row['path']):
                data = resolved(row['path']).read_bytes()
                self.assertEqual(len(data), row['bytes'])
                self.assertEqual(hashlib.sha256(data).hexdigest(), row['sha256'])
                self.assertEqual(hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest(), row['git_blob_sha1'])
                self.assertIn('Project-invented', row['provenance'])

    def test_item_references_and_complete_requirements(self):
        document = read(ROOT / 'docs/build/figure-evidence-P0-12/MATRIX_SEMANTICS_REQUIREMENTS.json')
        items = document['items']
        index = read(E / 'ARTIFACT_INDEX.json')
        self.assertEqual({i['id'] for i in items}, {'FE-008', 'FE-018', 'FE-019', 'FE-020', 'FE-021'})
        self.assertEqual({i['id'] for i in items}, {i['item'] for i in index})
        self.assertEqual(sum(len(i['source_requirements']) for i in items), 48)
        self.assertEqual(sum(len(r['acceptance_criteria']) for i in items for r in i['source_requirements']), 163)
        for item in items:
            self.assertFalse(item['full_item_complete'])
            self.assertIsNone(item['owner_visual_review'])
            self.assertTrue(item['remaining_work'])
        for item in index:
            self.assertIsNone(item['owner_visual_review'])
            self.assertEqual(item['evidence_status'], 'pending')
            for preset, stages in item['presets'].items():
                self.assertTrue(resolved(stages['comparison']).is_file())
                for stage in ('before', 'after'):
                    ref = read(ROOT / 'acceptance/figure-evidence-P0-12' / item['item'] / stage / preset / 'ARTIFACTS.json')
                    self.assertEqual(ref['artifacts'], stages[stage])
                    for path in stages[stage]:
                        self.assertTrue(resolved(path).is_file())

    def test_identical_inputs_and_physical_size(self):
        before = (E / 'before/FIXTURES.json').read_bytes()
        self.assertEqual(before, (E / 'after/FIXTURES.json').read_bytes())
        checksum = hashlib.sha256(before).hexdigest()
        for journal, width in (('nature', 183), ('cell', 174)):
            for name in ('distance', 'states', 'top', 'composition'):
                for stage in ('before', 'after'):
                    spec = read(E / stage / journal / (name + '.figure_spec.json'))
                    self.assertEqual((spec['journal'], spec['width_mm'], spec['height_mm']), (journal, width, 100))
                    png = (E / stage / journal / (name + '.png')).read_bytes()
                    self.assertEqual(png[:8], b'\x89PNG\r\n\x1a\n')
                    pixels = struct.unpack('>II', png[16:24])
                    self.assertLessEqual(abs(pixels[0] - width * spec['png_dpi'] / 25.4), 1)
                    self.assertLessEqual(abs(pixels[1] - 100 * spec['png_dpi'] / 25.4), 1)
        for row in read(E / 'ARTIFACT_PROVENANCE.json'):
            self.assertEqual(row['fixture_sha256'], checksum)

    def test_exported_matrix_semantics(self):
        for journal in ('nature', 'cell'):
            distance = read(E / 'after' / journal / 'distance.figure_spec.json')
            self.assertEqual((distance['counts']['n_samples'], distance['counts']['n_features']), (6, 4))
            contract = distance['definition']['matrix_contract']
            self.assertEqual(contract['matrix_kind'], 'distance')
            self.assertEqual(contract['clustering_provenance']['preprocessing'], 'unknown')
            self.assertEqual(contract['clipping']['limits'][0], 0)
            self.assertEqual(distance['data']['row_order'], distance['data']['col_order'])
            guides = distance['notes']['panel_contract']['guides']
            self.assertTrue({'row:condition', 'col:condition', 'row:time', 'col:time'} <= set(guides))
            states = read(E / 'after' / journal / 'states.figure_spec.json')
            self.assertEqual(states['counts']['original_missing_cells'], 1)
            self.assertEqual(states['counts']['source_states']['infinite'], 1)
            self.assertEqual(states['counts']['states']['undefined_constant'], 6)
            legend = states['definition']['matrix_contract']['state_legend']
            self.assertEqual(len({v['shape'] for v in legend.values()}), len(legend))
            top = read(E / 'after' / journal / 'top.figure_spec.json')
            self.assertEqual((top['counts']['n_selected_features'], top['counts']['n_source_samples'], top['counts']['n_display_columns']), (3, 6, 6))
            self.assertEqual(top['definition']['aggregation']['n_replicates'], {'reference': 3, 'treated': 3})
            self.assertEqual(top['definition']['aggregation']['independent_unit'], 'unknown')
            self.assertEqual(top['definition']['top_feature_selection']['rank_order_ids'], ['feature2', 'feature3', 'feature1'])
            composition = read(E / 'after' / journal / 'composition.figure_spec.json')['definition']['composition']
            self.assertTrue(composition['effective'])
            self.assertTrue(composition['shared_legend_rendered'])
            self.assertTrue(composition['linked_rows'] and composition['linked_cols'])
            self.assertEqual(composition['shared_axes'], 'none')
            self.assertEqual(composition['contracts'][0], composition['contracts'][1])


if __name__ == '__main__':
    unittest.main()

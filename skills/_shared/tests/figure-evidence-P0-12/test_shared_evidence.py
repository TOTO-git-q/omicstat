"""Check archived artificial group1 evidence, not a native engine acceptance."""
from pathlib import Path
import hashlib
import json
import struct
import unittest

ROOT=Path(__file__).resolve().parents[4]
E=ROOT/'acceptance/figure-evidence-P0-12/shared-semantics'

def read(path):
    return json.loads(path.read_text())

def resolved(relative):
    p=(ROOT/relative).resolve()
    assert p.is_relative_to(ROOT.resolve()), relative
    return p

class SharedEvidenceTest(unittest.TestCase):
    def test_provenance_bytes(self):
        manifest=read(E/'ARTIFACT_PROVENANCE.json')
        self.assertEqual(len({r['path'] for r in manifest}),len(manifest))
        self.assertEqual(sum(r['path'].endswith(('.pdf','.png')) for r in manifest),52)
        for row in manifest:
            with self.subTest(path=row['path']):
                data=resolved(row['path']).read_bytes()
                self.assertEqual(len(data),row['bytes'])
                self.assertEqual(hashlib.sha256(data).hexdigest(),row['sha256'])
                self.assertEqual(hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest(),row['git_blob_sha1'])
                self.assertIn('Project-invented',row['provenance'])

    def test_item_references_and_complete_requirements(self):
        items=read(ROOT/'docs/build/figure-evidence-P0-12/SHARED_SEMANTICS_REQUIREMENTS.json')['items']
        index=read(E/'ARTIFACT_INDEX.json')
        self.assertEqual({i['id'] for i in items},{i['item'] for i in index})
        self.assertEqual(sum(len(i['source_requirements']) for i in items),118)
        for item in index:
            self.assertIsNone(item['owner_visual_review'])
            self.assertEqual(item['evidence_status'],'pending')
            for preset,stages in item['presets'].items():
                self.assertTrue(resolved(stages['comparison']).is_file())
                for stage in ('before','after'):
                    ref=read(ROOT/'acceptance/figure-evidence-P0-12'/item['item']/stage/preset/'ARTIFACTS.json')
                    self.assertEqual(ref['artifacts'],stages[stage])
                    for p in stages[stage]:self.assertTrue(resolved(p).is_file())

    def test_identical_inputs_and_physical_size(self):
        before=(E/'before/FIXTURES.json').read_bytes()
        self.assertEqual(before,(E/'after/FIXTURES.json').read_bytes())
        checksum=hashlib.sha256(before).hexdigest()
        for journal,width in (('nature',183),('cell',174)):
            for name in ('mixed','muscat','groups','embedding'):
                for stage in ('before','after'):
                    spec=read(E/stage/journal/(name+'.figure_spec.json'))
                    self.assertEqual((spec['journal'],spec['width_mm'],spec['height_mm']),(journal,width,90))
                    png=(E/stage/journal/(name+'.png')).read_bytes()
                    self.assertEqual(png[:8],b'\x89PNG\r\n\x1a\n')
                    pixels=struct.unpack('>II',png[16:24])
                    self.assertLessEqual(abs(pixels[0]-width*spec['png_dpi']/25.4),1)
                    self.assertLessEqual(abs(pixels[1]-90*spec['png_dpi']/25.4),1)
        for row in read(E/'ARTIFACT_PROVENANCE.json'):
            self.assertEqual(row['fixture_sha256'],checksum)

    def test_exported_semantics(self):
        for journal in ('nature','cell'):
            mixed=read(E/'after'/journal/'mixed.figure_spec.json')
            pop=mixed['counts']['semantic']['observed_populations']
            self.assertEqual(len(pop),1)
            self.assertEqual((pop[0]['n_observations'],pop[0]['n_independent']),(6,3))
            self.assertIsNone(mixed['definition']['numerator'])
            self.assertIsNone(mixed['definition']['denominator'])
            embedding=read(E/'after'/journal/'embedding.figure_spec.json')
            self.assertEqual(sum(embedding['counts'].values()),5)
            self.assertEqual(embedding['counts']['Missing metadata'],1)
            self.assertEqual(embedding['encodings']['colour']['Missing metadata'],'#666666')
            self.assertEqual(embedding['encodings']['shape']['Missing metadata'],4)
            self.assertEqual(embedding['notes']['category_encoding']['colour']['Missing metadata'],'#666666')
            muscat=read(E/'after'/journal/'muscat.figure_spec.json')
            self.assertEqual(muscat['definition']['statistics'][0]['n_missing'],1)
            self.assertIn('within-cluster',muscat['caption'])
            groups=read(E/'after'/journal/'groups.figure_spec.json')
            self.assertEqual(groups['notes']['comparisons']['p'],[.053,.012])
            self.assertEqual(groups['notes']['comparisons']['statistic_kind'],['raw_p','adjusted_p'])
            self.assertIn('supplied paired t',groups['caption'])

if __name__=='__main__':
    unittest.main()

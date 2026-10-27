"""Promoted package inventory, unchanged anchor tolerances and port invariants."""
import copy,csv,hashlib,json,pathlib,tempfile,unittest,sys
ROOT=pathlib.Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
from acceptance.common import anchor_result
from package_inventory import packages
MODS=['drc-dose','lme4-lmm','emmeans-contrast','proda-diff','msstats-diff','drc-calibrate','nlme-dose']
class CandidateReentryTests(unittest.TestCase):
 def test_promoted_packages_are_in_production_inventory(self):
  base=packages(ROOT);candidate=packages(ROOT,candidate=True)
  self.assertEqual(base['proda'],'proDA');self.assertEqual(candidate['proda'],'proDA')
  self.assertEqual(candidate['msstats'],'MSstats')
 def test_inventory_requires_actual_digest_and_image(self):
  with tempfile.TemporaryDirectory() as tmp:
   root=pathlib.Path(tmp);p=root/'env/candidates/fixture/observed_packages.csv';p.parent.mkdir(parents=True)
   p.write_bytes((ROOT/'env/candidates/20261016-models/observed_packages.csv').read_bytes())
   proof=json.loads((ROOT/'env/candidates/20261016-models/observed_packages.provenance.json').read_text());q=p.with_suffix('.provenance.json')
   for field,value in [('sha256','0'*64),('observed_image_id','planned-tag'),('purpose','production')]:
    d=copy.deepcopy(proof);d[field]=value;q.write_text(json.dumps(d))
    with self.subTest(field=field),self.assertRaises(ValueError):packages(root,candidate=True)
 def test_shared_fixture_and_producer_changes_invalidate_fingerprint(self):
  from accept_module import source_fingerprint
  with tempfile.TemporaryDirectory() as tmp:
   r=pathlib.Path(tmp);p=r/'skills/emmeans-contrast/tests/acceptance.json';p.parent.mkdir(parents=True)
   p.write_text(json.dumps({'chain':{'upstream_module':'lme4-lmm'}}))
   source=r/'tests/candidate-models/anchors.R';source.parent.mkdir(parents=True);source.write_text('first')
   a=source_fingerprint(r,'emmeans-contrast',None,None);source.write_text('changed')
   b=source_fingerprint(r,'emmeans-contrast',None,None);self.assertNotEqual(a,b)
   producer=r/'skills/lme4-lmm/scripts/core.R';producer.parent.mkdir(parents=True);producer.write_text('producer')
   self.assertNotEqual(b,source_fingerprint(r,'emmeans-contrast',None,None))
 def test_absolute_tolerance_is_not_silently_scaled(self):
  a=dict(expected=600,tolerance=.02,tolerance_kind='absolute')
  self.assertTrue(anchor_result(a,600.019)['pass']);self.assertFalse(anchor_result(a,600.03)['pass'])
  self.assertTrue(anchor_result(dict(expected=600,tolerance=.02),600.03)['pass'])
  with self.assertRaises(ValueError):anchor_result(a|dict(tolerance_kind='invented'),600)
 def test_all_ports_accepted_sealed_and_deduplicated(self):
  for m in MODS:
   p=ROOT/'skills'/m;d=json.loads((p/'module.json').read_text());self.assertEqual(d['status'],'accepted');self.assertTrue(d['reference']['enabled']);self.assertIn('owner_accepted_2026_10_20',d['status_notes'])
   self.assertTrue((p/'module_lock.json').is_file());self.assertEqual([x.relative_to(p).as_posix() for x in p.rglob('*golden*')],['tests/golden_manifest.csv'])  # sealed in S5; owner accepted in conv6
   self.assertFalse((p/'scripts/module_support.R').exists());self.assertFalse((p/'scripts/model_figures.R').exists())
   rows=list(csv.DictReader((p/'tests/refusals.csv').read_text().splitlines()));self.assertGreaterEqual(len(rows),5)
   reg=json.loads((p/'scripts/calls_registry.json').read_text());self.assertTrue(reg['captured_signatures'])
   self.assertIn('--study-contract',json.loads((p/'tests/acceptance.json').read_text())['canonical']['argv'])
if __name__=='__main__':unittest.main()

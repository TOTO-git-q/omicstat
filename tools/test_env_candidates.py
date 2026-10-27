#!/usr/bin/env python3
"""Real local invariant tests; Docker actions are mocked, never image evidence."""
import copy,hashlib,importlib.util,io,json,pathlib,subprocess,sys,tarfile,tempfile,unittest
from unittest.mock import patch
ROOT=pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"tools/env"));sys.path.insert(0,str(ROOT/"tools"))
import common,build_candidate,promote,resolve_sources,check_registry,refdata
BASE="package,version,source\nbase,1,base\n";NEW="package,version,source,deps\nbase,1,base,\nextra,2,CRAN,base\n"
ID="sha256:"+"a"*64;CHILD="sha256:"+"b"*64

class CandidateTests(unittest.TestCase):
 def setUp(self):
  self.t=tempfile.TemporaryDirectory();self.root=pathlib.Path(self.t.name);self.c=self.root/'env/candidates/test';self.c.mkdir(parents=True)
  self.m=dict(schema='omicstat.env-candidate.v1',id='test',lane='R',base_image='omicstat-r:1',base_image_id=ID,image_tag='omicstat-r:candidate-test',target_layer='L9_models',target_env_version='2',new_packages=['extra'],state='resolved')
  (self.c/'manifest.json').write_text(common.dump(self.m));(self.c/'sources').mkdir();(self.c/'sources/extra.tar.gz').write_bytes(b'fixture')
  self.rows=[dict(kind='source',package='extra',version='2',url='https://example.org/extra.tar.gz',filename='extra.tar.gz',sha256=common.sha(self.c/'sources/extra.tar.gz'))]
  (self.c/'sources.lock.json').write_text(common.dump({'sources':self.rows}));(self.c/'Dockerfile').write_text('ARG BASE_IMAGE\nFROM ${BASE_IMAGE}\n')
  (self.root/'env/owner_decisions.json').write_text(common.dump({'environment_promotion_allowed':False}))
 def tearDown(self):self.t.cleanup()
 def test_additive_exact_rows(self):
  self.assertTrue(common.additive_diff(BASE,NEW,['extra'])['ok'])
  for bad in [NEW.replace('base,1','base,2'),NEW.replace('base,1,base,\n',''),NEW.replace('extra,2','unexpected,2')]:self.assertFalse(common.additive_diff(BASE,bad,['extra'])['ok'])
  self.assertFalse(common.additive_diff(BASE,NEW.replace('source,deps','source,other'),['extra'])['ok'])
 def test_check_without_docker(self):
  with patch('build_candidate.inspect',side_effect=AssertionError('Docker forbidden')):
   r=build_candidate.build(self.c,self.root);self.assertEqual(r['state'],'ready_to_build');self.assertFalse(r['executed'])
  (self.c/'sources/extra.tar.gz').write_text('changed');self.assertEqual(build_candidate.build(self.c,self.root)['state'],'blocked')
 def test_existing_tag_refusal(self):
  with patch('build_candidate.inspect',return_value={'Id':ID}),patch('build_candidate.subprocess.run',return_value=subprocess.CompletedProcess([],0)) as run:
   with self.assertRaisesRegex(ValueError,'OS_ENV_TAG_EXISTS'):build_candidate.build(self.c,self.root,True)
   self.assertEqual(run.call_count,1)
 def test_parent_identity_refusal(self):
  with patch('build_candidate.inspect',return_value={'Id':CHILD}),patch('build_candidate.subprocess.run') as run:
   with self.assertRaisesRegex(ValueError,'identity drift'):build_candidate.build(self.c,self.root,True)
   run.assert_not_called()
 def fake_build(self,new=NEW,layers=None):
  base={'Id':ID,'RootFS':{'Layers':['layer1']},'Size':50};child={'Id':CHILD,'RootFS':{'Layers':layers or ['layer1','layer2']},'Size':80}
  def command(*args):return BASE.rstrip() if args[-2:]==(ID,'/opt/omicstat/pkg_lock.csv') else new.rstrip() if args[-2:]==(CHILD,'/opt/omicstat/pkg_lock.csv') else 'mock session'
  with patch('build_candidate.inspect',side_effect=[base,child,base]),patch('build_candidate.command',side_effect=command),patch('build_candidate.subprocess.run',side_effect=[subprocess.CompletedProcess([],1,stderr='No such image'),subprocess.CompletedProcess([],0)]):return build_candidate.build(self.c,self.root,True)
 def test_mock_build_layer_inventory_and_evidence(self):
  r=self.fake_build();self.assertEqual(r['state'],'built');self.assertTrue(r['filesystem_prefix_preserved']);self.assertTrue((self.c/'candidate_report.json').exists());self.assertEqual(r['packages_sha256'],common.sha(self.c/'packages.csv'))
 def test_mock_reject_wrong_installed_additive_version(self):
  r=self.fake_build(NEW.replace("extra,2","extra,9"));self.assertEqual(r["state"],"rejected");self.assertFalse(r["inventory_diff"]["locked_versions_match"])
 def test_mock_reject_changed_inventory(self):self.assertEqual(self.fake_build(NEW.replace('base,1','base,9'))['state'],'rejected')
 def test_mock_reject_replaced_layer(self):
  with self.assertRaisesRegex(ValueError,'filesystem layers'):self.fake_build(layers=['repacked'])
 def test_owner_apply_gate_has_zero_side_effects(self):
  before=sorted(str(p.relative_to(self.root)) for p in self.root.rglob('*'))
  with patch('promote.subprocess.run',side_effect=AssertionError('must not run')):
   with self.assertRaisesRegex(PermissionError,'deferred_by_owner'):promote.apply(self.c,self.root,{})
  self.assertEqual(before,sorted(str(p.relative_to(self.root)) for p in self.root.rglob('*')))
 def test_promotion_dry_run_builds_change_set_without_writes(self):
  self.fake_build()
  (self.root/'env/r-env.json').write_text(common.dump({'image':'omicstat-r','image_tag':'1','env_version':'1','layers':['L0_base']}))
  (self.root/'env/image_id.txt').write_text(ID+'\n');(self.root/'env/pkg_lock.csv').write_text(BASE);(self.root/'SUITE.md').write_text('# Suite\n')
  target=self.root/'tools/upgrade';target.mkdir(parents=True);(target/'news_filter.py').write_bytes((ROOT/'tools/upgrade/news_filter.py').read_bytes())
  before=(self.root/'env/r-env.json').read_bytes()
  r=promote.plan(self.c,self.root);self.assertEqual(r['canonical_tag'],'omicstat-r:2');self.assertIn('docs/upgrade/2/news_filter.md',r['changes']);self.assertEqual((self.root/'env/r-env.json').read_bytes(),before)
  cfg=json.loads(r['changes']['env/r-env.json']);self.assertEqual(cfg['candidate_history'],['env/history/test']);self.assertEqual(cfg['layers'],['L0_base','L9_models'])
  (self.c/'packages.csv').write_text(NEW+'bad,1,other,\n')
  with self.assertRaisesRegex(ValueError,'evidence changed'):promote.plan(self.c,self.root)
 def test_offline_source_identity_and_order(self):
  p=self.c/'sources/extra.tar.gz'
  with tarfile.open(p,'w:gz') as t:
   data=b'Package: extra\nVersion: 2\nImports: base\n';member=tarfile.TarInfo('extra/DESCRIPTION');member.size=len(data);t.addfile(member,io.BytesIO(data))
  self.m['sources']=[dict(self.rows[0],sha256=common.sha(p))];(self.c/'manifest.json').write_text(common.dump(self.m))
  r=resolve_sources.resolve(self.c,self.root);self.assertEqual(r['state'],'resolved');self.assertEqual(common.load(self.c/'manifest.json')['install_order'],['extra'])
  self.assertEqual(resolve_sources.install_order([{'package':'a','dependencies':['b']},{'package':'b'}]),['b','a'])
  with self.assertRaisesRegex(ValueError,'cycle'):resolve_sources.install_order([{'package':'a','dependencies':['b']},{'package':'b','dependencies':['a']}])
 def test_source_resolution_cannot_drop_requested(self):
  self.m['sources']=[dict(self.rows[0],package='different')];(self.c/'manifest.json').write_text(common.dump(self.m))
  with self.assertRaises((ValueError,tarfile.ReadError)):resolve_sources.resolve(self.c,self.root)
 def test_isolated_profile_blocks_additive_build_and_resolve(self):
  self.m['isolated_profile']='env/py/isolated/test';(self.c/'manifest.json').write_text(common.dump(self.m))
  self.assertTrue(any('isolated dependency profile required'in e for e in build_candidate.build(self.c,self.root)['errors']))
  with self.assertRaisesRegex(ValueError,'additive resolution forbidden'):resolve_sources.resolve(self.c,self.root)
 def test_repository_candidates_metadata_only(self):
  errors,rows=check_registry.check(ROOT);self.assertEqual(errors,[]);self.assertEqual(len(rows),10)

class ReferenceTests(unittest.TestCase):
 def setUp(self):
  self.t=tempfile.TemporaryDirectory();self.root=pathlib.Path(self.t.name);self.f=self.root/'data.tsv';self.f.write_text('id\tvalue\na\t1\n');self.p=self.root/'provenance.json'
  self.entry=dict(id='collectri_human',kind='geneset',source_url='https://example.org/data',version='1',sha256=common.sha(self.f),licence='CC-BY-NC-4.0',licence_status='verified',redistribution='user_supplied',species='human',consumers=[],fetch={'script':None,'args':[]},tier='container',status='ready',payload={'path':'data.tsv','hash_kind':'file'})
 def tearDown(self):self.t.cleanup()
 def test_metadata_licence_and_owner_gate(self):
  x={'schema':'omicstat.refdata.v2','entries':[self.entry]};self.assertEqual(refdata.metadata(x,self.root),[])
  x['entries'][0]['redistribution']='bundled_in_image';self.assertTrue(any('owner requires' in e for e in refdata.metadata(x,self.root)))
  x['entries'][0]['redistribution']='build_cached';self.assertTrue(any('internal-use' in e for e in refdata.metadata(x,self.root)))
 def test_payload_hash_and_escape(self):
  self.assertEqual(refdata.check_entry(self.entry,self.root)['status'],'pass');self.f.write_text('changed');self.assertEqual(refdata.check_entry(self.entry,self.root)['status'],'fail')
  self.entry['payload']['path']='../escape';self.assertEqual(refdata.check_entry(self.entry,self.root)['status'],'fail')
 def test_pending_is_not_pass(self):
  self.entry['status']='pending';self.assertEqual(refdata.check_entry(self.entry,self.root)['status'],'pending')
 def test_user_supplied_hash_and_required_provenance(self):
  p={k:self.entry[k] for k in ('source_url','version','licence','sha256')};p.update(refdata_id=self.entry['id'],permitted_use='Internal analysis under supplied terms');self.p.write_text(common.dump(p))
  self.assertEqual(refdata.user_supplied(self.f,self.p,self.entry['id']),p)
  self.f.write_text('changed')
  with self.assertRaisesRegex(ValueError,'MISMATCH'):refdata.user_supplied(self.f,self.p,self.entry['id'])
  del p['permitted_use'];self.p.write_text(common.dump(p))
  with self.assertRaisesRegex(ValueError,'MISSING'):refdata.user_supplied(self.f,self.p,self.entry['id'])
 def test_symlink_tree_refused(self):
  (self.root/'outside').symlink_to('/etc/hosts')
  with self.assertRaisesRegex(ValueError,'symlink'):refdata.tree_digest(self.root)
if __name__=='__main__':unittest.main()

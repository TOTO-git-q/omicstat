"""Offline synthetic archive tests; no registry/network/install/Docker action."""
import copy, hashlib, io, json, pathlib, sys, tarfile, tempfile, unittest
from unittest.mock import patch
ROOT=pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools/env'))
import prepare_locked_sources as ps

def archive(path,package='extra',version='2.0',imports='base (>= 1.0)',bad=None):
 with tarfile.open(path,'w:gz')as t:
  members={package+'/DESCRIPTION':f'Package: {package}\nVersion: {version}\nDepends: R (>= 4.0)\nImports: {imports}\n'.encode(),package+'/R/extra.R':b'extra <- function() 1\n'}
  if bad:members[bad]=b'x'
  for name,data in members.items():
   m=tarfile.TarInfo(name);m.size=len(data);t.addfile(m,io.BytesIO(data))

class SourceTests(unittest.TestCase):
 def setUp(self):
  self.t=tempfile.TemporaryDirectory();self.root=pathlib.Path(self.t.name);self.c=self.root/'env/candidates/test';self.c.mkdir(parents=True);self.cache=self.root/'cache';self.cache.mkdir();archive(self.cache/'extra.tar.gz')
  self.row=dict(kind='source',package='extra',version='2.0',filename='extra.tar.gz',url='https://cran.r-project.org/src/contrib/extra.tar.gz',sha256=ps.sha(self.cache/'extra.tar.gz'))
  self.m=dict(schema='omicstat.env-candidate.v1',id='test',lane='R',base_image='omicstat-r:1',base_image_id='sha256:'+'a'*64,image_tag='omicstat-r:candidate-test',target_layer='L9_models',target_env_version='2',new_packages=['extra'],state='resolved',install_order=['extra'],sources=[self.row])
  (self.root/'env/pkg_lock.csv').write_text('package,version\nbase,1.0\n');(self.root/'env/r-env.json').write_text(json.dumps(dict(image='omicstat-r',image_tag='1',r_version='4.5.0')));self.save()
 def tearDown(self):self.t.cleanup()
 def save(self):
  (self.c/'manifest.json').write_text(json.dumps(self.m));(self.c/'sources.lock.json').write_text(json.dumps({'sources':self.m['sources']}));self.lock=ps.sha(self.c/'sources.lock.json')
 def run_prepare(self,**kwargs):return ps.prepare(self.c,self.root,expected_lock_sha256=self.lock,**kwargs)
 def test_default_missing_is_read_only_and_no_network(self):
  before=sorted(str(p)for p in self.root.rglob('*'))
  with patch('urllib.request.build_opener',side_effect=AssertionError('network forbidden')):r=self.run_prepare()
  self.assertEqual(r['state'],'blocked');self.assertEqual(r['errors'],['missing source: extra.tar.gz']);self.assertFalse(r['dependency_closure_verified']);self.assertEqual(before,sorted(str(p)for p in self.root.rglob('*')))
 def test_complete_verified_cache_and_dependency_closure(self):
  r=self.run_prepare(source_cache=self.cache);self.assertEqual(r['state'],'ready_for_offline_build');self.assertTrue(r['dependency_closure_verified']);self.assertEqual({e['dependency']for e in r['dependency_edges']},{'R','base'});self.assertTrue(r['locks_unchanged']);self.assertFalse(r['installed']);self.assertFalse(r['image_built']);self.assertEqual(ps.sha(self.c/'sources.lock.json'),self.lock)
  self.assertEqual(self.run_prepare()['state'],'ready_for_offline_build')
 def test_request_hash_drift_refuses_before_writes(self):
  with self.assertRaisesRegex(ValueError,'source-lock SHA mismatch'):ps.prepare(self.c,self.root,expected_lock_sha256='0'*64,source_cache=self.cache)
  self.assertFalse((self.c/'sources').exists())
 def test_coverage_duplicate_and_order_are_complete(self):
  self.m['new_packages'].append('missing');self.save()
  with self.assertRaisesRegex(ValueError,'cover every'):self.run_prepare()
  self.m['new_packages']=['extra'];self.m['install_order']=[];self.save()
  with self.assertRaisesRegex(ValueError,'install order'):self.run_prepare()
  self.m['install_order']=['extra'];self.m['sources'].append(self.row);self.save()
  with self.assertRaisesRegex(ValueError,'duplicate'):self.run_prepare()
 def test_cached_checksum_mismatch_is_never_installed_or_promoted(self):
  (self.cache/'extra.tar.gz').write_bytes(b'not the reviewed archive')
  with self.assertRaisesRegex(ValueError,'SHA mismatch'):self.run_prepare(source_cache=self.cache)
  self.assertFalse((self.c/'sources/extra.tar.gz').exists());self.assertEqual(list((self.c/'sources').glob('*.part')),[])
 def test_existing_corruption_never_replaced_or_downloaded(self):
  folder=self.c/'sources';folder.mkdir();(folder/'extra.tar.gz').write_bytes(b'corrupt')
  with patch('urllib.request.build_opener',side_effect=AssertionError('network forbidden')):r=self.run_prepare(download=True)
  self.assertEqual(r['state'],'blocked');self.assertEqual((folder/'extra.tar.gz').read_bytes(),b'corrupt')
 def test_missing_or_too_old_dependency_blocks(self):
  for dep in ['unknown','base (>= 2.0)']:
   archive(self.cache/'extra.tar.gz',imports=dep);self.row['sha256']=ps.sha(self.cache/'extra.tar.gz');self.save()
   if (self.c/'sources/extra.tar.gz').exists():(self.c/'sources/extra.tar.gz').unlink()
   r=self.run_prepare(source_cache=self.cache);self.assertEqual(r['state'],'blocked');self.assertFalse(r['dependency_closure_verified']);self.assertTrue(any('unsatisfied dependency' in e for e in r['errors']))
 def test_identity_and_binary_and_unsafe_archive_are_rejected(self):
  for kwargs,match in [(dict(package='other'),'package/version'),(dict(bad='extra/Meta/package.rds'),'binary'),(dict(bad='../outside'),'unsafe')]:
   archive(self.cache/'extra.tar.gz',**kwargs);self.row['sha256']=ps.sha(self.cache/'extra.tar.gz');self.save()
   with self.assertRaisesRegex(ValueError,match):self.run_prepare(source_cache=self.cache)
   self.assertFalse((self.c/'sources/extra.tar.gz').exists())
 def test_inherited_package_replacement_and_wrong_parent_refused(self):
  (self.root/'env/pkg_lock.csv').write_text('package,version\nbase,1.0\nextra,1\n')
  with self.assertRaisesRegex(ValueError,'inherited'):self.run_prepare()
  (self.root/'env/pkg_lock.csv').write_text('package,version\nbase,1.0\n');self.m['base_image']='omicstat-r:other';self.save()
  with self.assertRaisesRegex(ValueError,'parent inventory'):self.run_prepare()
 def test_manifest_disagreement_refused(self):
  self.m['sources']=[dict(self.row,version='9')];(self.c/'manifest.json').write_text(json.dumps(self.m))
  with self.assertRaisesRegex(ValueError,'identities differ'):self.run_prepare()
 def test_https_and_version_semantics(self):
  for url in ['http://cran.r-project.org/a','https://user:pass@example.org/a','file:///tmp/a','https://example.org/a#fragment']:
   with self.assertRaises(ValueError):ps.https_url(url)
  self.assertEqual(ps.compare_version('1.0-0','1.0'),0);self.assertGreater(ps.compare_version('1.10','1.9'),0)
 def test_required_preparation_is_enforced_by_offline_builder(self):
  import build_candidate
  self.m['source_preparation_required']=True;self.save();(self.c/'Dockerfile').write_text('ARG BASE_IMAGE\nFROM ${BASE_IMAGE}\n')
  with patch('build_candidate.inspect',side_effect=AssertionError('Docker forbidden')):
   result=build_candidate.build(self.c,self.root,False)
  self.assertEqual(result['state'],'blocked');self.assertFalse(result['source_download_automatic']);self.assertFalse(result['source_preparation']['dependency_closure_verified'])
  self.run_prepare(source_cache=self.cache)
  with patch('build_candidate.inspect',side_effect=AssertionError('Docker forbidden')):
   result=build_candidate.build(self.c,self.root,False)
  self.assertEqual(result['state'],'ready_to_build');self.assertTrue(result['source_preparation']['dependency_closure_verified']);self.assertFalse(result['executed'])
 def test_model_lock_covers_all_eleven_including_drc(self):
  c=ROOT/'env/candidates/20261016-models';m=ps.manifest(c,ROOT);rows=ps.sources(c);self.assertEqual(len(rows),11);self.assertEqual({r['package']for r in rows},set(m['new_packages']));d=next(r for r in rows if r['package']=='drc');self.assertEqual(d['version'],'3.0-1');self.assertEqual(len(d['sha256']),64)
  request=json.loads((ROOT/'acceptance/requests/P0-4.json').read_text());self.assertEqual(request['image_candidate'],'env/candidates/20261016-models');lock=request['source_locks'][0];self.assertEqual(lock['sha256'],ps.sha(c/'sources.lock.json'));self.assertEqual(lock['required_packages'],m['new_packages'])
if __name__=='__main__':unittest.main(verbosity=2)

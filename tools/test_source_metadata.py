#!/usr/bin/env python3
"""Metadata-only unit/contract tests. No package install, image, or native pass."""
import copy
import hashlib
import json
import pathlib
import shutil
import subprocess
import sys
import tempfile
import tomllib
import unittest
from unittest.mock import patch
ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools/env'))
import audit_source_metadata as audit
import source_metadata as sm
import build_candidate
import resolve_sources

ACT = pathlib.Path('env/py/candidates/20261016-py-activity')
VEL = pathlib.Path('env/py/candidates/20261016-py-velocity')
RSP = pathlib.Path('env/candidates/20261016-spatial')

class MetadataTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.tmp.name)/'repo'; self.root.mkdir()
        shutil.copytree(ROOT/'env',self.root/'env',ignore=shutil.ignore_patterns('__pycache__'))
        for p in (ROOT/'skills').glob('*/scripts/calls_registry.json'):
            q=self.root/p.relative_to(ROOT);q.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,q)
        shutil.copyfile(ROOT/'.dockerignore',self.root/'.dockerignore')
        self.c=self.root/ACT
        self.m=self.read(ACT/'manifest.json');self.data=self.read(self.m['source_metadata']['path'])
    def tearDown(self): self.tmp.cleanup()
    def read(self,p):return json.loads((self.root/p).read_text())
    def write(self,p,d):
        p=self.root/p;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(d,indent=2)+'\n')
    def rebind(self,m=None,data=None):
        m=self.m if m is None else m;data=self.data if data is None else data
        self.write(m['source_metadata']['path'],data)
        m['source_metadata']['sha256']=sm.digest(self.root/m['source_metadata']['path'])
        p=pathlib.Path(m['source_metadata']['path']).parent/'manifest.json';self.write(p,m)
    def official(self,name='liana'):
        row=next(x for x in self.data['packages'] if x['package']==name)
        return row,self.read(row['metadata']['path'])
    def save_official(self,row,metadata):
        self.write(row['metadata']['path'],metadata)
        sha=sm.digest(self.root/row['metadata']['path'])
        row['metadata']['sha256']=sha;row['version_evidence']['sha256']=sha
        self.rebind()
    def inspect(self):return sm.inspect_metadata(self.c,self.m,self.root)
    def test_all_seven_families_eight_lanes_remain_blocked(self):
        r=audit.audit(self.root);self.assertTrue(r['metadata_valid']);self.assertEqual(r['state'],'blocked')
        self.assertEqual((r['families'],r['candidate_lanes'],r['unique_exact_direct_python_artifacts']),(7,8,7))
        self.assertTrue(all(c['state']=='blocked' and c['metadata_valid'] for c in r['candidates']))
        self.assertFalse(r['install_executed']);self.assertFalse(r['candidate_build_executed']);self.assertFalse(r['native_acceptance_verified'])
    def test_default_cli_nonzero_and_metadata_only_mode_labelled(self):
        for args,code in [([],1),(['--validate-metadata'],0)]:
            p=subprocess.run([sys.executable,str(ROOT/'tools/env/audit_source_metadata.py'),'--root',str(self.root),*args],capture_output=True,text=True)
            self.assertEqual(p.returncode,code,p.stderr);r=json.loads(p.stdout)
            self.assertEqual(r['state'],'blocked');self.assertTrue(r['metadata_only_validation_is_not_build_acceptance'])
    def test_official_liana_baseline_conflict_is_exact(self):
        data,observations=self.inspect();r=sm.python_compatibility(data,observations,self.m,self.root)
        self.assertEqual(r['conflicts'],[{'package':'liana','dependency':'pandas','requirement':'pandas<3','actual':'3.0.5'}])
        self.assertFalse(r['transitive_closure_verified']);self.assertFalse(r['native_compatibility_verified'])
    def test_target_markers_are_linux_cpython312_not_current_host(self):
        d,o=self.inspect();r=sm.python_compatibility(d,o,self.m,self.root)
        self.assertEqual(r['environment']['python_full_version'],'3.12.13')
        self.assertEqual(r['environment']['sys_platform'],'linux');self.assertEqual(r['environment']['platform_machine'],'x86_64')
        self.assertTrue(any('extra ==' in x['requirement'] for x in r['skipped_nonapplicable_markers']))
        self.assertFalse(any(x['dependency']=='corneto' for x in r['evaluated']))
    def test_missing_transitive_work_not_reported_solved(self):
        d,o=self.inspect();r=sm.python_compatibility(d,o,self.m,self.root)
        self.assertTrue(r['missing_direct_dependencies']);self.assertFalse(r['transitive_closure_verified'])
    def test_resolve_refuses_before_uv_or_network(self):
        with patch('resolve_sources.python_sources',side_effect=AssertionError('uv forbidden')) as resolver,patch('urllib.request.urlopen',side_effect=AssertionError('network forbidden')) as network:
            with self.assertRaisesRegex(ValueError,'pandas<3.*pandas=3.0.5'):
                resolve_sources.resolve(self.c,self.root,download=True,lock_python=True)
            resolver.assert_not_called();network.assert_not_called()
    def test_build_execute_cannot_reach_docker(self):
        with patch('build_candidate.inspect',side_effect=AssertionError('Docker forbidden')) as docker,patch('build_candidate.subprocess.run',side_effect=AssertionError('build forbidden')) as run:
            r=build_candidate.build(self.c,self.root,execute=True)
            self.assertEqual(r['state'],'blocked');self.assertFalse(r['executed'])
            self.assertTrue(any('pandas<3' in e for e in r['errors']));docker.assert_not_called();run.assert_not_called()
    def test_exact_jsonschema_resolver_input_and_metadata(self):
        deps=tomllib.loads((self.c/'pyproject.toml').read_text())['project']['dependencies']
        self.assertIn('jsonschema==4.26.0',deps);self.assertNotIn('jsonschema>=4',deps)
        self.assertEqual(next(x for x in self.data['packages'] if x['package']=='jsonschema')['version'],'4.26.0')
    def test_bound_metadata_content_drift(self):
        (self.root/self.m['source_metadata']['path']).write_text('{}\n')
        with self.assertRaisesRegex(ValueError,'SHA mismatch'):self.inspect()
    def test_metadata_digest_cannot_be_short(self):
        self.m['source_metadata']['sha256']='abc'
        with self.assertRaisesRegex(ValueError,'exact SHA256'):self.inspect()
    def test_metadata_path_traversal_refused(self):
        self.m['source_metadata']['path']='../outside'
        with self.assertRaisesRegex(ValueError,'unsafe relative'):self.inspect()
    def test_symlink_escape_refused_without_read(self):
        external=pathlib.Path(self.tmp.name)/'outside.json';external.write_text('{}')
        (self.root/'link.json').symlink_to(external);self.m['source_metadata']['path']='link.json'
        with self.assertRaisesRegex(ValueError,'escapes repository'):self.inspect()
    def test_wrong_candidate_id(self):
        self.data['candidate_id']='other';self.rebind()
        with self.assertRaisesRegex(ValueError,'identity'):self.inspect()
    def test_wrong_parent_id(self):
        self.data['parent_image']['id']='sha256:'+'0'*64;self.rebind()
        with self.assertRaisesRegex(ValueError,'parent image'):self.inspect()
    def test_missing_requested_record(self):
        self.data['packages']=self.data['packages'][:-1];self.rebind()
        with self.assertRaisesRegex(ValueError,'omits requested'):self.inspect()
    def test_new_package_declaration_not_silently_dropped(self):
        self.m['new_packages'].append('unreviewed')
        with self.assertRaisesRegex(ValueError,'coverage differs'):self.inspect()
    def test_duplicate_normalized_package_refused(self):
        x=copy.deepcopy(self.data['packages'][0]);x['package']=x['package'].upper();self.data['packages'].append(x);self.rebind()
        with self.assertRaisesRegex(ValueError,'duplicate'):self.inspect()
    def test_unknown_scope_refused(self):
        self.data['packages'][0]['scope']='ignored';self.rebind()
        with self.assertRaisesRegex(ValueError,'scope'):self.inspect()
    def test_no_cache_or_native_attestation_from_metadata(self):
        for key in ['artifact_bytes_verified_in_this_revision','native_verified_in_this_revision']:
            original=copy.deepcopy(self.data);self.data[key]=True;self.rebind()
            with self.assertRaisesRegex(ValueError,'cannot assert'):self.inspect()
            self.data=original;self.rebind()
    def test_no_fake_complete_closure(self):
        self.data['closure_state']='complete';self.rebind()
        with self.assertRaisesRegex(ValueError,'complete closure'):self.inspect()
    def test_lineage_inventory_bytes_bound(self):
        p=self.root/self.data['lineage_baseline']['path'];p.write_text(p.read_text().replace('3.0.5','2.3.3'))
        with self.assertRaisesRegex(ValueError,'inventory SHA'):self.inspect()
    def test_official_metadata_package_version_drift(self):
        row,m=self.official();m['version']='9.0';self.save_official(row,m)
        with self.assertRaisesRegex(ValueError,'package/version'):self.inspect()
    def test_official_metadata_url_exact_release(self):
        row,m=self.official();m['source_url']='https://pypi.org/pypi/liana/json';self.save_official(row,m)
        with self.assertRaisesRegex(ValueError,'pinned release'):self.inspect()
    def test_wrong_artifact_digest_refused(self):
        row,_=self.official();row['artifact']['sha256']='0'*64;self.rebind()
        with self.assertRaisesRegex(ValueError,'differs from official'):self.inspect()
    def test_selected_python_version_bound_to_existing_implementation(self):
        row,_=self.official();row['implementation_binding']['git_blob']='0'*40;self.rebind()
        with self.assertRaisesRegex(ValueError,'reviewed implementation'):self.inspect()
    def test_official_metadata_does_not_override_scientific_version_pin(self):
        row,_=self.official();row['version']='9.9.9';self.rebind()
        with self.assertRaisesRegex(ValueError,'reviewed implementation'):self.inspect()
    def test_yanked_release_refused(self):
        row,m=self.official();m['yanked']=True;self.save_official(row,m)
        with self.assertRaisesRegex(ValueError,'yanked'):self.inspect()
    def test_after_cutoff_official_artifact_refused(self):
        row,m=self.official();later='2026-09-16T00:00:00Z';row['artifact']['uploaded_utc']=later
        next(x for x in m['files'] if x['filename']==row['artifact']['filename'])['upload_time_iso_8601']=later
        self.save_official(row,m)
        with self.assertRaisesRegex(ValueError,'fixed cutoff'):self.inspect()
    def test_no_credentials_nonofficial_host_or_query(self):
        for url in ['http://files.pythonhosted.org/a','https://user:secret@files.pythonhosted.org/a','https://other.example/a','https://files.pythonhosted.org/a?token=x','https://files.pythonhosted.org/a#x']:
            with self.assertRaises(ValueError):sm.official_url(url,'files.pythonhosted.org')
    def test_filename_url_disagreement(self):
        with self.assertRaisesRegex(ValueError,'filename disagree'):sm.official_url('https://files.pythonhosted.org/wrong.whl','files.pythonhosted.org','right.whl')
    def test_compiled_direct_wheel_cannot_use_pure_python_exception(self):
        row,m=self.official();old=row['artifact']['filename'];new='liana-1.10.0-cp312-cp312-linux_x86_64.whl'
        item=next(x for x in m['files'] if x['filename']==old)
        item['filename']=new;item['url']=item['url'].replace(old,new)
        row['artifact']['filename']=new;row['artifact']['url']=item['url'];self.save_official(row,m)
        with self.assertRaisesRegex(ValueError,'pure-Python target'):self.inspect()
    def test_wrong_python_requirement_stops_additive_resolver(self):
        row,m=self.official();m['requires_python']='>=3.13';self.save_official(row,m)
        self.assertTrue(any('python=3.12.13' in e for e in sm.additive_metadata_errors(self.c,self.m,self.root)))
    def test_invalid_dependency_is_fail_closed(self):
        row,m=self.official();m['requires_dist'].append('not a valid requirement $$$');self.save_official(row,m)
        self.assertTrue(any('source metadata guard' in e for e in sm.additive_metadata_errors(self.c,self.m,self.root)))
    def test_r_unknown_versions_and_hashes_stay_null(self):
        out=audit.audit(self.root)
        unresolved=[p for c in out['candidates'] for p in c.get('unresolved_sources',[])]
        self.assertEqual({p['package'] for p in unresolved if p['version'] is None},{'tximeta','decoupleR','liana','ChAMP'})
        self.assertEqual(len(unresolved),19)
    def test_r_version_evidence_is_exact_module_blob(self):
        m=self.read('env/candidates/20261016-sc-qc/manifest.json');d=self.read(m['source_metadata']['path'])
        d['packages'][0]['version']='999';self.rebind(m,d)
        with self.assertRaisesRegex(ValueError,'version evidence mismatch'):sm.inspect_metadata(self.root/'env/candidates/20261016-sc-qc',m,self.root)
    def test_bioc_source_policy_no_invented_archives(self):
        m=self.read('env/candidates/20261016-epigenomics/manifest.json');d=self.read(m['source_metadata']['path'])
        for p in d['packages']:
            self.assertIsNone(p['artifact'])
            if p['package']!='Signac':self.assertEqual(p['artifact_policy'],'bioconductor_source_only')
        d['packages'][0]['artifact']={'kind':'ppm_binary'};self.rebind(m,d)
        with self.assertRaisesRegex(ValueError,'R archive was not obtained'):sm.inspect_metadata(self.root/'env/candidates/20261016-epigenomics',m,self.root)
    def test_r_inherited_spatial_versions_and_rfast2_exclusion(self):
        m=self.read(RSP/'manifest.json');d=self.read(m['source_metadata']['path']);p=self.root/d['lineage_baseline']['path']
        p.write_text(p.read_text()+'Rfast2,0.0.0,CRAN,synthetic,\n');d['lineage_baseline']['sha256']=sm.digest(p);self.rebind(m,d)
        with self.assertRaisesRegex(ValueError,'forbidden native engine'):sm.inspect_metadata(self.root/RSP,m,self.root)
    def test_isolated_128_tuples_and_three_local_builds(self):
        m=self.read(VEL/'manifest.json');d=self.read(m['source_metadata']['path']);r=sm.verify_isolated_metadata(self.root,d['existing_isolated_profile'])
        self.assertEqual(r['locked_wheel_count'],128);self.assertEqual(r['official_artifact_count'],128)
        self.assertEqual(set(r['locally_built']),{'docrep==0.3.2','loompy==3.0.8','PIMS==0.7'})
        self.assertFalse(r['production_image_verified']);self.assertFalse(r['current_cache_verified'])
    def test_isolated_lock_bytes_cannot_drift(self):
        m=self.read(VEL/'manifest.json');d=self.read(m['source_metadata']['path']);b=d['existing_isolated_profile']
        p=self.root/b['path']/'wheels.lock.json';p.write_bytes(p.read_bytes()+b' ')
        with self.assertRaisesRegex(ValueError,'isolated metadata SHA'):sm.verify_isolated_metadata(self.root,b)
    def test_local_build_source_sha_is_not_wheel_sha(self):
        m=self.read(VEL/'manifest.json');d=self.read(m['source_metadata']['path']);b=d['existing_isolated_profile'];p=pathlib.Path(b['path'])/'wheels.lock.json';lock=self.read(p)
        row=next(x for x in lock['wheels'] if x['locally_built']);self.assertNotEqual(row['sha256'],row['official_artifact']['sha256'])
        row['locally_built']=False;self.write(p,lock);b['wheels_lock_sha256']=sm.digest(self.root/p)
        with self.assertRaisesRegex(ValueError,'downloaded wheel identity'):sm.verify_isolated_metadata(self.root,b)
    def test_isolated_profiles_still_block_additive_path(self):
        with self.assertRaisesRegex(ValueError,'isolated dependency profile required'):resolve_sources.resolve(self.root/VEL,self.root)
    def test_source_index_detects_unregistered_binding_removal(self):
        del self.m['source_metadata'];self.write(ACT/'manifest.json',self.m)
        r=audit.audit(self.root);self.assertFalse(r['metadata_valid']);self.assertTrue(any('binding differs' in e for e in r['errors']))
    def test_audit_does_not_modify_inputs_or_locks(self):
        before={str(p.relative_to(self.root)):sm.digest(p) for p in self.root.rglob('*') if p.is_file()}
        with patch('urllib.request.urlopen',side_effect=AssertionError('network forbidden')),patch('subprocess.run',side_effect=AssertionError('subprocess forbidden')):audit.audit(self.root)
        after={str(p.relative_to(self.root)):sm.digest(p) for p in self.root.rglob('*') if p.is_file()}
        self.assertEqual(before,after)

if __name__=='__main__':unittest.main(verbosity=2)

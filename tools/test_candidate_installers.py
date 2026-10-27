#!/usr/bin/env python3
"""Real offline synthetic-package installs in disposable libraries/venvs.

These test installer mechanics, not scientific package or production images.
"""
import hashlib,io,json,os,pathlib,shutil,subprocess,sys,tarfile,tempfile,unittest,venv,zipfile
ROOT=pathlib.Path(__file__).resolve().parents[1]
def write(p,x):p.write_text(json.dumps(x,indent=2)+'\n')
class InstallerTests(unittest.TestCase):
 def setUp(self):
  self.t=tempfile.TemporaryDirectory();self.d=pathlib.Path(self.t.name);(self.d/'sources').mkdir()
 def tearDown(self):self.t.cleanup()
 def setup_manifest(self,name,file):
  write(self.d/'manifest.json',{'lane':'R' if name=='omicCandidateToy' else 'py','new_packages':[name],'install_order':[name]})
  write(self.d/'sources.lock.json',{'sources':[{'kind':'source','url':'https://example.org/installer-test/' + file.name,'package':name,'version':'0.0.1','filename':file.name,'sha256':hashlib.sha256(file.read_bytes()).hexdigest()}]})
 def test_python_actual_offline_wheel_install(self):
  envdir=self.d/'venv';venv.EnvBuilder(with_pip=True).create(envdir);py=str(envdir/'bin/python')
  wheel=self.d/'sources/omic_candidate_toy-0.0.1-py3-none-any.whl';dist='omic_candidate_toy-0.0.1.dist-info'
  contents={'omic_candidate_toy.py':'VALUE=42\n',dist+'/METADATA':'Metadata-Version: 2.1\nName: omic-candidate-toy\nVersion: 0.0.1\n',dist+'/WHEEL':'Wheel-Version: 1.0\nGenerator: omicstat-test\nRoot-Is-Purelib: true\nTag: py3-none-any\n'}
  contents[dist+'/RECORD']=''.join(k+',,\n' for k in contents)+dist+'/RECORD,,\n'
  with zipfile.ZipFile(wheel,'w') as z:
   for k,v in contents.items():z.writestr(k,v)
  self.setup_manifest('omic-candidate-toy',wheel)
  env=dict(os.environ,OMICSTAT_CANDIDATE_DIR=str(self.d),OMICSTAT_CANDIDATE_WRITER=str(ROOT/'env/py/write_py_installed.py'),OMICSTAT_CANDIDATE_INVENTORY=str(self.d/'packages.csv'))
  cmd=[py,str(ROOT/'tools/env/install_candidate.py')]
  subprocess.run(cmd,env=env,check=True,capture_output=True,text=True)
  subprocess.run([py,'-c','import omic_candidate_toy; assert omic_candidate_toy.VALUE==42'],check=True)
  self.assertIn('omic-candidate-toy,0.0.1,pip',(self.d/'packages.csv').read_text())
  second=subprocess.run(cmd,env=env,capture_output=True,text=True);self.assertNotEqual(second.returncode,0);self.assertIn('refusing to replace inherited',second.stderr)
 @unittest.skipUnless(os.environ.get('OMICSTAT_TEST_RSCRIPT'),'set OMICSTAT_TEST_RSCRIPT to run real R install')
 def test_r_actual_offline_source_install(self):
  archive=self.d/'sources/omicCandidateToy_0.0.1.tar.gz'
  contents={'DESCRIPTION':'Package: omicCandidateToy\nVersion: 0.0.1\nTitle: Offline Installer Test Fixture\nDescription: A tiny synthetic local fixture, not a scientific analysis package.\nAuthors@R: person("Test", "Fixture", email="test@example.org", role=c("aut","cre"))\nLicense: CC0\n','NAMESPACE':'export(toy)\n','R/toy.R':'toy <- function() 42\n'}
  with tarfile.open(archive,'w:gz') as t:
   for k,v in contents.items():
    b=v.encode();m=tarfile.TarInfo('omicCandidateToy/'+k);m.size=len(b);t.addfile(m,io.BytesIO(b))
  self.setup_manifest('omicCandidateToy',archive);shutil.copy(ROOT/'env/r/write_pkg_lock.R',self.d/'write_pkg_lock.R');lib=self.d/'Rlib';lib.mkdir()
  env=dict(os.environ,OMICSTAT_CANDIDATE_DIR=str(self.d),OMICSTAT_CANDIDATE_INVENTORY=str(self.d/'packages.csv'),R_LIBS_USER=str(lib)+os.pathsep+os.environ.get('R_LIBS_USER',''))
  cmd=[os.environ['OMICSTAT_TEST_RSCRIPT'],str(ROOT/'tools/env/install_candidate.R')]
  r=subprocess.run(cmd,env=env,capture_output=True,text=True)
  self.assertEqual(r.returncode,0,r.stdout+'\n'+r.stderr);self.assertIn('"omicCandidateToy","0.0.1"',(self.d/'packages.csv').read_text())
  second=subprocess.run(cmd,env=env,capture_output=True,text=True);self.assertNotEqual(second.returncode,0);self.assertIn('refusing to replace an inherited',second.stderr)
if __name__=='__main__':unittest.main()

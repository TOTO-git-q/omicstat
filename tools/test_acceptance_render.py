#!/usr/bin/env python3
"""Separate-lane rendering contract; mocks dispatch only, not scientific evidence."""
import pathlib,tempfile,unittest,json
from unittest.mock import Mock
from acceptance.pipeline import Pipeline
from acceptance.runner import Runner
class RenderDispatch(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.root=pathlib.Path(self.tmp.name);self.out=self.root/'evidence';self.out.mkdir();self.pipe=object.__new__(Pipeline);self.pipe.root=self.root;self.pipe.out=self.out;self.pipe.module={'lane':'py'};self.pipe.runner=Runner(self.root,self.out,native=False,image='sha256:'+'1'*64);self.pipe.render_runner=None;self.run=self.out/'run';(self.run/'figure_data').mkdir(parents=True);(self.run/'figure_data/figure_request.json').write_text('{}')
 def tearDown(self):self.tmp.cleanup()
 def test_requires_separate_renderer(self):
  with self.assertRaisesRegex(ValueError,'separately verified R'):self.pipe.render_output(self.run,'render-test')
 def test_selects_r_runner(self):
  # Dispatch double includes the actual Runner receipt fields required since
  # the source-bound rendering audit. It is not native scientific evidence.
  renderer=Mock();renderer.path.side_effect=str;renderer.native=False;renderer.image='sha256:'+'2'*64
  log=self.out/'render.log';log.write_text('SYNTHETIC renderer dispatch receipt only\n')
  renderer.run.return_value={'ok':True,'argv':['Rscript','synthetic-contract-renderer'],'returncode':0,'timed_out':False,'log':'render.log'}
  self.pipe.render_runner=renderer;receipt=self.pipe.render_output(self.run,'render-test');argv,stage=renderer.run.call_args.args
  self.assertEqual(argv[0],'Rscript');self.assertEqual(stage,'render-test');self.assertIn('--run-dir',argv)
  import hashlib
  self.assertEqual(receipt['log_sha256'],hashlib.sha256(log.read_bytes()).hexdigest());self.assertEqual(receipt['image_id'],renderer.image)
  self.assertFalse(receipt['native']);self.assertEqual(receipt['returncode'],0)
 def test_failed_renderer_blocks(self):
  renderer=Mock();renderer.path.side_effect=str;renderer.run.return_value={'ok':False,'log':'render.log'};self.pipe.render_runner=renderer
  with self.assertRaisesRegex(ValueError,'render.log'):self.pipe.render_output(self.run,'render-test')
 def test_existing_r_lane_not_double_rendered(self):self.pipe.module['lane']='R';self.pipe.render_output(self.run,'render-test')
 def test_no_request_no_dispatch(self):(self.run/'figure_data/figure_request.json').unlink();self.pipe.render_output(self.run,'render-test')
 def test_renderer_identity_binds_fingerprint(self):
  from accept_module import source_fingerprint
  engine={'tag':'omicstat-py:test','id':'sha256:'+'1'*64};one={'engine':engine,'renderer':{'tag':'omicstat-r:test','id':'sha256:'+'2'*64}};two={'engine':engine,'renderer':{'tag':'omicstat-r:test','id':'sha256:'+'3'*64}}
  self.assertNotEqual(source_fingerprint(self.root,'omicstat-test',None,one),source_fingerprint(self.root,'omicstat-test',None,two))
if __name__=='__main__':unittest.main()

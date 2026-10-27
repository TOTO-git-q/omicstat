#!/usr/bin/env python3
"""Contract schemas, strict migration gate, and runtime negative tests."""
import copy, json, pathlib, sys, tempfile, unittest
import lint_contracts as lc
sys.path.insert(0,str(lc.ROOT/'skills/_shared/py'))
from ospy.handoff import write_handoff, read_handoff
from ospy.errors import OmicstatError

class Contracts(unittest.TestCase):
    def test_repository(self):
        errors,stats=lc.lint();self.assertEqual(errors,[]);self.assertGreater(stats['calls_registries'],0)
    def test_prefix_accepts_package_declared_by_request_lock(self):
        import shutil, package_inventory
        with tempfile.TemporaryDirectory() as td:
            root=pathlib.Path(td)
            (root/'acceptance/requests').mkdir(parents=True);(root/'env/candidates/c1').mkdir(parents=True)
            (root/'acceptance/requests/r.json').write_text(json.dumps({'modules':['abc-test'],'image_candidate':'env/candidates/c1'}))
            self.assertEqual(package_inventory.declared(root,'abc-test'),{})
            (root/'env/candidates/c1/sources.lock.json').write_text(json.dumps({'sources':[{'package':'ABC'}]}))
            self.assertEqual(package_inventory.declared(root,'abc-test'),{'abc':'ABC'})
            self.assertEqual(package_inventory.declared(root,'other-test'),{})
            (root/'acceptance/requests/r.json').write_text(json.dumps({'modules':['abc-test'],'image_candidate':'env/candidates/missing'}))
            self.assertEqual(package_inventory.declared(root,'abc-test'),{})
    def test_calls_required(self):
        s=lc.load(lc.SCHEMAS/'calls_registry.v1.schema.json')
        d={'module':'omicstat-test','module_version':'1','package_versions':{},'calls':[{'fn':'stats::lm','args':{'formula':{'value':'y~x','source':'user_required','pack':'C','function_default':''}}}]}
        self.assertEqual(lc.validate(d,s),[])
        for key in ['value','source','pack','function_default']:
            bad=copy.deepcopy(d);del bad['calls'][0]['args']['formula'][key];self.assertTrue(lc.validate(bad,s),key)
        del d['module_version'];self.assertTrue(lc.validate(d,s))
    def test_scanner(self):
        self.assertEqual(lc.handoff_literals('list(path = x, type = "invented_type")','.R'),[(1,'invented_type')])
        self.assertEqual(lc.handoff_literals('arrow(type="closed")','.R'),[])
        self.assertEqual(lc.handoff_literals('{"path": path, "type": "invented_type"}','.py'),[(1,'invented_type')])
    def test_conditional_type_scanner(self):
        source='{"path": path, "type": "feature_table" if name == "feature_table" else "cell_metadata" if name == "cell_metadata" else "analysis_table"}'
        self.assertEqual([t for _,t in lc.handoff_literals(source,'.py')],['feature_table','cell_metadata','analysis_table'])
        self.assertEqual(lc.handoff_literals('list(path=x,type=if (name=="not_a_type") "Seurat" else "AnnData")','.R'),[(1,'Seurat'),(1,'AnnData')])
        self.assertEqual(lc.handoff_literals('dict(path=x,type="analysis_table")','.py'),[(1,'analysis_table')])
    def test_every_registered_type_runtime(self):
        types=[x['id'] for x in lc.load(lc.SCHEMAS/'handoff_types.v1.json')['types']]
        self.assertIn('analysis_table',types)
        self.assertEqual(len(types),len(set(types)))
        with tempfile.TemporaryDirectory() as td:
            p=pathlib.Path(td)/'envelope-only-fixture.h5ad';p.write_text('synthetic envelope payload, not a biological AnnData object\n')
            for typ in types:
                write_handoff(td,'x','omicstat-test','1',{'result':{'path':str(p),'type':typ}})
                self.assertEqual(read_handoff(td)['objects']['result']['type'],typ)
    def test_runtime(self):
        with tempfile.TemporaryDirectory() as td:
            p=pathlib.Path(td)/'counts.csv';p.write_text('gene,s1\na,1\n')
            obj={'counts':{'path':str(p),'type':'count_matrix'}}
            write_handoff(td,'x','omicstat-test','1',obj)
            self.assertEqual(read_handoff(td)['objects']['counts']['type'],'count_matrix')
            obj['counts']['type']='invented_type'
            with self.assertRaisesRegex(OmicstatError,'OS_HANDOFF_TYPE_UNKNOWN'):write_handoff(td,'x','omicstat-test','1',obj)
            hp=pathlib.Path(td)/'objects/handoff.json';d=json.loads(hp.read_text());d['objects'][0]['type']='invented_type';hp.write_text(json.dumps(d))
            with self.assertRaisesRegex(OmicstatError,'OS_HANDOFF_TYPE_UNKNOWN'):read_handoff(td)
if __name__=='__main__':unittest.main()

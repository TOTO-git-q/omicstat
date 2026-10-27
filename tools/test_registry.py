#!/usr/bin/env python3
import hashlib,json,pathlib,tempfile,unittest
import sync_registry as s
class Registry(unittest.TestCase):
    def test_idempotent(self):
        drift,counts=s.sync(check=True);self.assertEqual(drift,[]);self.assertEqual(counts['total'],len(list((s.ROOT/'skills').glob('*/module.json'))))
    def test_promoted_routes_and_reference_inventory(self):
        out, counts = s.generated()
        registered = [json.loads(p.read_text()) for p in (s.ROOT/'skills').glob('*/module.json')]
        accepted = [m for m in registered if m['status']=='accepted']
        expected_status = dict(s.collections.Counter(m['status'] for m in registered))
        self.assertEqual(counts['by_status'], expected_status)
        self.assertEqual(counts['routed'], len(accepted))
        methods = json.loads(out['reference_service/app/method_map.json'])['modules']
        self.assertEqual(len(methods), sum(m['reference']['enabled'] for m in accepted))
        names = [m['module'] for m in methods]
        self.assertEqual(names[:3], ['deseq2-wald','deseq2-qc','deseq2-lrt'])
        self.assertNotIn('omicstat-selftest', names)
        if not any(m['status']=='candidate' for m in registered):
            self.assertNotIn('| candidate |', out['SUITE.md'])
        self.assertEqual(names, json.loads(out['reference_service/app/schemas/literature_request.v1.json'])['properties']['module']['enum'][:-1])
        self.assertEqual(names, [p['module'] for p in json.loads(out['reference_service/app/discovery_profiles.json'])['profiles']])

    def test_markers_preserve_prose(self):
        self.assertEqual(s.replace_block('left\n'+s.BEGIN+'\nold\n'+s.END+'\nright','new'),'left\n'+s.BEGIN+'\nnew\n'+s.END+'\nright')
        with self.assertRaises(ValueError):s.replace_block(s.BEGIN+s.BEGIN+s.END,'bad')
    def test_no_protected_generation(self):
        out,_=s.generated();self.assertFalse(any('module_lock.json' in p or '/golden' in p for p in out))
        for p in (s.ROOT/'skills').glob('*/module_lock.json'):
            lock=json.loads(p.read_text())
            for rel in lock['files']:
                if rel in out:self.assertEqual((s.ROOT/rel).read_text(),out[rel],rel)
    def test_publication_bytes_preserved(self):
        out,_=s.generated();p='skills/_shared/publication/module_rules_v1.json';self.assertEqual(out[p],(s.ROOT/p).read_text())
if __name__=='__main__':unittest.main()

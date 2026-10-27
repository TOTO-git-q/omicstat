#!/usr/bin/env python3
"""Regression for actual R argument declarations in user-supplied refdata consumers."""
import json,pathlib,tempfile,unittest
from refdata import metadata
class ProvenanceFlag(unittest.TestCase):
    def verify(self,source):
        with tempfile.TemporaryDirectory() as tmp:
            root=pathlib.Path(tmp);d=root/'skills/example';(d/'scripts').mkdir(parents=True)
            (d/'module.json').write_text(json.dumps({'name':'example','refdata':['ambient'],'refdata_contracts':{'ambient':{'input_flag':'--background','provenance_flag':'--background-provenance'}}}))
            (d/'scripts/main.R').write_text(source)
            reg={'schema':'omicstat.refdata.v2','entries':[dict(id='ambient',kind='reference_profiles',source_url=None,version=None,sha256=None,licence=None,redistribution='user_supplied',species=['human'],consumers=['example'],fetch={},tier='dev',status='pending')]}
            return metadata(reg,root)
    def test_literal_cli(self):self.assertEqual(self.verify('flags <- "--background-provenance"'),[])
    def test_r_declaration(self):self.assertEqual(self.verify('os_flag("background-provenance", "character")'),[])
    def test_r_whitespace_single_quote(self):self.assertEqual(self.verify("os_flag ( 'background-provenance', 'character')"),[])
    def test_missing(self):self.assertEqual(len(self.verify('os_flag("background", "character")')),1)
    def test_prefix_not_accepted(self):self.assertEqual(len(self.verify('os_flag("background-provenance-other", "character")')),1)
if __name__=='__main__':unittest.main()

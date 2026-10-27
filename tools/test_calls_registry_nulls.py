#!/usr/bin/env python3
"""Required explicit nulls for arguments forwarded through native R ellipses."""
import copy
import json
from pathlib import Path
import unittest
import lint_contracts
ROOT = Path(__file__).resolve().parents[1]
SCHEMA = json.loads((ROOT/'skills/_shared/schemas/calls_registry.v1.schema.json').read_text())

class CallsNullSchemaTests(unittest.TestCase):
    def test_null_is_explicit_and_absence_is_rejected(self):
        fixture = {'module':'omicstat-test','module_version':'0.1.0','package_versions':{'stats':'4.6.1'},'calls':[{'fn':'stats::lm','args':{'forwarded':{'value':False,'source':'Declared forwarded argument','pack':'test','function_default':None}}}]}
        self.assertEqual(lint_contracts.validate(fixture, SCHEMA), [])
        absent = copy.deepcopy(fixture)
        del absent['calls'][0]['args']['forwarded']['function_default']
        self.assertTrue(any('function_default' in error for error in lint_contracts.validate(absent, SCHEMA)))

    def test_actual_emptydrops_forwarded_defaults_have_null_key(self):
        registry = json.loads((ROOT/'skills/dropletutils-emptydrops/scripts/calls_registry.json').read_text())
        self.assertEqual(lint_contracts.validate(registry, SCHEMA), [])
        call = next(x for x in registry['calls'] if x['fn']=='DropletUtils::emptyDrops')
        for argument in ['ignore','niters','alpha','known.empty','by.rank']:
            with self.subTest(argument=argument):
                self.assertIn('function_default', call['args'][argument])
                self.assertIsNone(call['args'][argument]['function_default'])
                evidence = registry['captured_signatures']['forwarded_arguments'][argument]
                self.assertEqual(evidence['destination'], 'DropletUtils::testEmptyDrops')
                self.assertIn('function_default', evidence)

if __name__=='__main__':
    unittest.main()

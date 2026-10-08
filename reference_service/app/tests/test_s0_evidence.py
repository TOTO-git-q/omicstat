"""Real S0 bundle and store integration: no network or live service."""
import copy
from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import sqlite3
import unittest
from unittest.mock import patch

import curation
from reference_core import ReferenceStore
import service
from s0_loader import load
from scratch import scratch_directory
from test_reference_core import contract

ROOT = Path(__file__).resolve().parents[1]
BUNDLE = ROOT / 's0_evidence/catalog.json'


class S0EvidenceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.bundle = json.loads(BUNDLE.read_text())

    def test_counts_and_columns(self):
        b = self.bundle
        self.assertEqual(38, len(b['counts']))
        self.assertEqual(len(b['papers']), len({p['pmid'] for p in b['papers']}))
        self.assertEqual([], b['decisions'])
        self.assertFalse(b['execution_authorized'])
        self.assertFalse(b['automatic_parameter_application'])
        for module, stats in b['counts'].items():
            rows = [u for u in b['usages'] if u['module_tags'] == [module]]
            self.assertEqual(stats[stats['column']], len(rows), module)
            self.assertEqual({stats['column']}, {u['column'] for u in rows})
            self.assertEqual(stats['parameters'], sum(len(u['parameters']) for u in rows))
            self.assertEqual(stats['coverage'], sum(len(u['coverage']) for u in rows))
        self.assertEqual(38, sum(s['column'] == 'reviewed_supplement' for s in b['counts'].values()))
        self.assertEqual(0, sum(s['column'] == 'discovery' for s in b['counts'].values()))

    def test_exclusions_coverage_and_eligibility(self):
        gate = ReferenceStore.__new__(ReferenceStore)
        excluded = {(e['module'], e['pmid'], e['parameter']) for e in self.bundle['excluded']}
        eligible = Counter()
        for u in self.bundle['usages']:
            module = u['module_tags'][0]
            for p in u['parameters'] + u['coverage'] + u['context']:
                self.assertNotIn((module, u['paper']['pmid'], p['extraction_key']), excluded)
                self.assertIsNot(p['applies'], False)
                self.assertTrue(p['provenance']['sha256'])
            self.assertTrue(all(p['value'].lower() != 'not reported' for p in u['parameters']))
            self.assertTrue(all(p['value'].lower() == 'not reported' for p in u['coverage']))
            if u['column'] == 'discovery':
                self.assertFalse(gate._eligible(u))
                forged = copy.deepcopy(u)
                forged.update(reviewer_status='root_reviewed', verification_status='primary_source_methods_verified')
                self.assertFalse(gate._eligible(forged))
            elif gate._eligible(u):
                eligible[module] += 1
                broken = copy.deepcopy(u)
                broken['parameters'][0]['source_locator']['snippet'] = ''
                self.assertFalse(gate._eligible(broken))
        for module, stats in self.bundle['counts'].items():
            self.assertEqual(stats['eligible_usages'], eligible[module], module)

    def test_store_roundtrip_reload_and_demotion(self):
        seed_hash = hashlib.sha256((ROOT / 'seed/catalog.json').read_bytes()).hexdigest()
        with scratch_directory() as directory, patch.dict(os.environ, {'OMICSTAT_REFERENCE_DATA': directory}):
            data = Path(directory)
            try:
                self.assertEqual('loaded', load(BUNDLE, data)['status'])
                with sqlite3.connect(data / 'reference.sqlite') as db:
                    version = db.execute("SELECT value FROM curation_state WHERE key='supplement_version'").fetchone()[0]
                    counts = dict(db.execute('SELECT record_type,count(*) FROM records GROUP BY record_type'))
                    self.assertEqual({}, counts)
                self.assertEqual('unchanged', load(BUNDLE, data)['status'])
                with sqlite3.connect(data / 'reference.sqlite') as db:
                    self.assertEqual(version, db.execute("SELECT value FROM curation_state WHERE key='supplement_version'").fetchone()[0])
                for module in ('deseq2-wald', 'seurat-cluster'):
                    found = service.invoke(service.search, module=module, limit=1)
                    self.assertEqual([], found['results'])
                    hit = found['reviewed_supplement']['results'][0]
                    self.assertTrue(hit['citations'])
                    self.assertEqual('S0_verified_or_redone_supplement', hit['label'])
                    self.assertTrue(hit['reported_parameters'])
                    advice = service.invoke(service.core().advise, module, contract())
                    self.assertNotIn('response_omitted', advice)
                    self.assertTrue(advice['parameter_options'])
                    for option in advice['parameter_options']:
                        self.assertEqual('reviewed_supplement', option['column'])
                        self.assertTrue(option['citations'])
                    self.assertFalse(advice['execution_authorized'])
                    self.assertFalse(advice['automatic_parameter_application'])
                for module, stats in self.bundle['counts'].items():
                    found = service.search(module=module, limit=1)
                    column = stats['column']
                    self.assertEqual(stats[column], found[column]['total'], module)
                    if column == 'discovery':
                        self.assertEqual([], service.core().advise(module, contract())['parameter_options'])
                ident = next(u['usage_id'] for u in self.bundle['usages'] if u['column'] == 'reviewed_supplement')
                with sqlite3.connect(data / 'reference.sqlite') as db:
                    db.execute("UPDATE reviewed_supplement SET status='demoted' WHERE supplement_id=?", (ident,))
                changed = copy.deepcopy(self.bundle)
                changed['test_reload'] = True
                new_bundle = data / 'changed.json'
                new_bundle.write_text(json.dumps(changed))
                load(new_bundle, data)
                with sqlite3.connect(data / 'reference.sqlite') as db:
                    self.assertEqual('demoted', db.execute('SELECT status FROM reviewed_supplement WHERE supplement_id=?', (ident,)).fetchone()[0])
            finally:
                for key in list(service._instances):
                    if key.startswith(directory):
                        obj = service._instances.pop(key)
                        if hasattr(obj, 'close'):
                            obj.close()
        self.assertEqual(seed_hash, hashlib.sha256((ROOT / 'seed/catalog.json').read_bytes()).hexdigest())

"""Importer determinism and repeatable option mapping using isolated inputs."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import import_s0_evidence as importer


class ImporterTests(unittest.TestCase):
    def test_idempotent_with_mapping_refresh_and_coverage(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            literature = root / 'acceptance/exemplars/deseq2-wald/literature'
            literature.mkdir(parents=True)
            verification = root / 'docs/build/S0_VERIFICATION_M3M4.md'
            verification.parent.mkdir(parents=True)
            verification.write_text('## 2. verification\n## 3. corrections\n')
            article = {'pmid': '123', 'pmcid': 'PMC123', 'title': 'Synthetic paper', 'year': 2025, 'journal': 'Synthetic'}
            (literature / 'corpus.jsonl').write_text(json.dumps(article) + '\n')
            rows = [dict(article, parameter='alpha', value=' 0.05. ', snippet='alpha was 0.05.', section_path='Methods', applies=True, ecosystem='n/a'),
                    dict(article, parameter='filter', value='not reported', snippet='', section_path='Methods', applies=True),
                    dict(article, parameter='unused', value='9', applies=False)]
            (literature / 'extraction.jsonl').write_text(''.join(json.dumps(r)+'\n' for r in rows))
            # Merged worktrees contain copied M3/M4 extracts, sometimes without
            # their corpus. They must not be imported as reviewed M1/M2 evidence.
            copied = root / 'acceptance/exemplars/scanpy-cluster/literature'
            copied.mkdir(parents=True)
            (copied / 'extraction.jsonl').write_text(json.dumps(rows[0]) + '\n')
            with patch.object(importer, 'git', return_value='synthetic-provenance'):
                a = importer.build(root, [('M12', root)], root)
                self.assertEqual(importer.encoded(a), importer.encoded(importer.build(root, [('M12', root)], root)))
                self.assertEqual({'deseq2-wald'}, set(a['counts']))
                self.assertEqual(['deseq2-wald'], a['usages'][0]['module_tags'])
                p = a['usages'][0]['parameters'][0]
                self.assertEqual('0.05', p['value'])
                self.assertEqual('alpha was 0.05.', p['source_locator']['snippet'])
                self.assertEqual('pending', p['mapping_status'])
                self.assertEqual(1, len(a['usages'][0]['coverage']))
                options = root / 'skills/deseq2-wald/references/options.md'
                options.parent.mkdir(parents=True)
                options.write_text('| option | locked default | required? | S0 extraction parameter key |\n|---|---|---|---|\n| `--alpha` | 0.1 | no | `alpha` |\n')
                b = importer.build(root, [('M12', root)], root)
                self.assertEqual(['--alpha'], b['usages'][0]['parameters'][0]['options'])
                self.assertEqual(importer.encoded(b), importer.encoded(importer.build(root, [('M12', root)], root)))
                self.assertTrue(any(i['role'] == 'option_mapping' and i['sha256'] == importer.sha(options) for i in b['inputs']))

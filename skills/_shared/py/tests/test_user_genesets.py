#!/usr/bin/env python3
"""Unit tests of ospy.user_genesets (user-supplied gene-set contract).

Standard library only; mirrors skills/_shared/tests/test_user_genesets.R.
Usage: python skills/_shared/py/tests/test_user_genesets.py. ASCII only.
"""
import hashlib
import json
import pathlib
import sys
import tempfile
import unittest

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
from ospy import user_genesets as U          # noqa: E402
from ospy.errors import OmicstatError        # noqa: E402


class UserGenesetTests(unittest.TestCase):
    def setUp(self):
        self.dir = pathlib.Path(tempfile.mkdtemp(prefix='ugs_'))
        self.sets = {'hsa04110': ['CDK1', 'CCNB1', 'MCM2'], 'KEGG_APOPTOSIS': ['CASP3', 'BAX', 'CDK1']}
        self.panel = self.dir / 'panel.json'
        self.panel.write_text(json.dumps({k: {'genes': v, 'lineage': 'L', 'order': i} for i, (k, v) in enumerate(self.sets.items())}))

    def prov(self, **over):
        d = {'source': 'PanglaoDB', 'name': 'test panel', 'version_or_release': 'r1', 'download_time': '2026-10-09',
             'urls': 'https://panglaodb.se', 'sha256': hashlib.sha256(self.panel.read_bytes()).hexdigest(),
             'terms': 'academic terms', 'terms_url': None, 'id_type': 'SYMBOL', 'species': 'human'}
        d.update(over)
        p = self.dir / ('prov_%d.json' % len(list(self.dir.iterdir())))
        p.write_text(json.dumps(d))
        return str(p)

    def code(self, fn):
        with self.assertRaises(OmicstatError) as cm:
            fn()
        return cm.exception.code

    def test_resolve_check_and_methods(self):
        rec = U.resolve(str(self.panel), {'gene-sets-provenance': self.prov()}, self.sets)
        self.assertEqual(rec['species'], 'Homo sapiens')
        self.assertTrue(rec['sha256_verified_against_provenance'])
        self.assertEqual(rec['urls'], ['https://panglaodb.se'])
        rec = U.check(rec, self.sets, 'SYMBOL', ['CDK1', 'CCNB1', 'MCM2', 'CASP3', 'BAX', 'X'], 'the features', '--feature-id-type', 'Homo_sapiens')
        self.assertEqual(rec['overlap']['n_present'], 5)
        s = U.methods_sentence(rec)
        self.assertIn('Gene sets: test panel (Homo sapiens), retrieved from PanglaoDB on 2026-10-09, release r1, used under academic terms', s)
        self.assertIn('supplied by the user, not bundled with omicstat', s)

    def test_refusals(self):
        self.assertEqual(self.code(lambda: U.resolve(str(self.panel), {'gene-sets-source': 'x'}, self.sets)), 'OS_MISSING_PARAMETER')
        self.assertEqual(self.code(lambda: U.resolve(str(self.panel), {'gene-sets-provenance': self.prov(sha256='0' * 64)}, self.sets)), 'OS_REFDATA_MISMATCH')
        self.assertEqual(self.code(lambda: U.resolve(str(self.panel), {'gene-sets-provenance': self.prov(), 'gene-sets-version': 'r2'}, self.sets)), 'OS_CONFLICTING_PARAMETERS')
        self.assertEqual(self.code(lambda: U.resolve(str(self.panel), {'gene-sets-provenance': self.prov(id_type='ENTREZID')}, self.sets)), 'OS_GENE_SET_ID_MISMATCH')
        rec = U.resolve(str(self.panel), {'gene-sets-provenance': self.prov()}, self.sets)
        self.assertEqual(self.code(lambda: U.check(rec, self.sets, 'ENTREZID', ['CDK1'], 'u', '--feature-id-type')), 'OS_GENE_SET_ID_MISMATCH')
        self.assertEqual(self.code(lambda: U.check(rec, self.sets, 'SYMBOL', ['CDK1', 'BAX'], 'u', '--feature-id-type', 'mouse')), 'OS_GENE_SET_SPECIES_MISMATCH')
        self.assertEqual(self.code(lambda: U.check(rec, {'a': ['A%d' % i for i in range(30)]}, 'SYMBOL', ['A1'], 'u', '--feature-id-type')), 'OS_GENE_SET_LOW_OVERLAP')
        self.assertEqual(self.code(lambda: U.read_provenance(self.prov(sha256=None))), 'OS_INVALID_INPUT')


if __name__ == '__main__':
    unittest.main()

"""Administrator-only S0 bundle loader into the existing supplement/discovery stores."""
from __future__ import annotations
import argparse
from contextlib import closing
import hashlib
import json
from pathlib import Path
import sqlite3
import curation
from harvest import HarvestStore
from reference_core import ReferenceStore

STAMP = '2026-09-30T00:00:00+00:00'  # import provenance date, not a fabricated review timestamp

def dump(obj):
    return json.dumps(obj, ensure_ascii=False, sort_keys=True, separators=(',', ':'))

def load(bundle_path: Path, data_dir: Path) -> dict:
    data_dir = data_dir.resolve()
    raw = bundle_path.read_bytes()
    bundle = json.loads(raw)
    if bundle.get('schema') != 'omicstat.s0-evidence.v1':
        raise ValueError('Unsupported S0 bundle schema')
    if bundle.get('decisions'):
        raise ValueError('S0 import cannot introduce scientific decisions')
    # Reuse registry and referential-integrity validation without putting anything in seed records.
    validator = ReferenceStore.__new__(ReferenceStore)
    validator.registered_modules = curation.known_modules()
    validator._validate_catalog(bundle)
    for usage in bundle['usages']:
        if not usage['usage_id'].startswith('S0-') or usage['column'] not in {'reviewed_supplement', 'discovery'}:
            raise ValueError('Invalid S0 usage identity/column')
        if usage['column'] == 'discovery' and validator._eligible(usage):
            raise ValueError('Discovery cannot be eligible')
    data_dir.mkdir(parents=True, exist_ok=True)
    # Keep the immutable empty seed, harvest schema, and additive curation schema intact.
    seed = Path(__file__).with_name('seed') / 'catalog.json'
    store = ReferenceStore(data_dir / 'reference.sqlite', seed)
    store.close()
    curation.ensure_schema(data_dir)
    HarvestStore(data_dir / 'harvest.sqlite')
    digest = hashlib.sha256(raw).hexdigest()
    with closing(sqlite3.connect(data_dir / 'reference.sqlite', isolation_level=None)) as con:
        con.execute('ATTACH DATABASE ? AS harvest', (str(data_dir / 'harvest.sqlite'),))
        con.execute('BEGIN IMMEDIATE')
        try:
            existing = con.execute("SELECT value FROM curation_state WHERE key='s0_bundle_sha256'").fetchone()
            if existing and existing[0] == digest:
                con.execute('COMMIT')
                return {'status': 'unchanged', 'bundle_sha256': digest, 'usages': len(bundle['usages']), 'seed_modified': False}
            version = int(con.execute("SELECT value FROM curation_state WHERE key='supplement_version'").fetchone()[0]) + 1
            # Remove stale import-owned rows only; preserve curator demotions and unrelated data.
            ids = {u['usage_id'] for u in bundle['usages'] if u['column'] == 'reviewed_supplement'}
            for (ident,) in con.execute("SELECT supplement_id FROM reviewed_supplement WHERE supplement_id LIKE 'S0-%'").fetchall():
                if ident not in ids:
                    con.execute("UPDATE reviewed_supplement SET status='demoted',demote_reason='S0 source removed or reclassified',demoted_in_version=? WHERE supplement_id=?", (version, ident))
            discovery_ids = {u['usage_id'] for u in bundle['usages'] if u['column'] == 'discovery'}
            for (ident,) in con.execute("SELECT candidate_id FROM harvest.candidates WHERE candidate_id LIKE 'S0-%'").fetchall():
                if ident not in discovery_ids:
                    con.execute("UPDATE harvest.candidates SET status='excluded' WHERE candidate_id=?", (ident,))
            for usage in bundle['usages']:
                ident, paper = usage['usage_id'], usage['paper']
                if usage['column'] == 'reviewed_supplement':
                    review = {'reviewer': 'S0 evidence import', 'source_locators': usage['source_locator']['observations'],
                              'findings': ['Published parameter observations from S0 literature extraction.'],
                              'limitations': usage['limitations'], 'proposed_module_tags': usage['module_tags'], 'usage': usage}
                    con.execute("""INSERT INTO reviewed_supplement(supplement_id,review_id,candidate_id,modules_json,review_json,candidate_json,locator_json,curator,note,promoted_at,supplement_version,status,searchable)
                        VALUES(?,?,?,?,?,?,?,?,?,?,?,'active',?) ON CONFLICT(supplement_id) DO UPDATE SET
                        modules_json=excluded.modules_json,review_json=excluded.review_json,candidate_json=excluded.candidate_json,
                        locator_json=excluded.locator_json,supplement_version=excluded.supplement_version,searchable=excluded.searchable""",
                        (ident, ident + '-review', ident, dump(usage['module_tags']), dump(review), dump(paper), dump(usage['source_locator']),
                         'S0 verified/redone evidence import', usage['provenance']['evidence_state'], STAMP, version,
                         ReferenceStore._searchable(usage)))
                else:
                    first = next((p['source_locator'] for p in usage['parameters'] if p['source_locator']['snippet']), {})
                    record = paper | {'module': usage['module_tags'][0], 'usage': usage,
                                      'signal': first | {'matched': usage['method']}, 'provenance': usage['provenance']}
                    con.execute("""INSERT INTO harvest.candidates(candidate_id,title,module,status,flags_json,provenance_json,record_json,created_at)
                        VALUES(?,?,?,'screened',?,?,?,?) ON CONFLICT(candidate_id) DO UPDATE SET
                        title=excluded.title,module=excluded.module,status=excluded.status,flags_json=excluded.flags_json,
                        provenance_json=excluded.provenance_json,record_json=excluded.record_json""",
                        (ident, paper['title'], usage['module_tags'][0], dump(['S0_unreviewed']), dump(usage['provenance']), dump(record), STAMP))
            con.execute("UPDATE curation_state SET value=? WHERE key='supplement_version'", (str(version),))
            con.execute("INSERT OR REPLACE INTO curation_state(key,value) VALUES('s0_bundle_sha256',?)", (digest,))
            con.execute('COMMIT')
        except Exception:
            con.execute('ROLLBACK')
            raise
    return {'status': 'loaded', 'bundle_sha256': digest, 'usages': len(bundle['usages']), 'seed_modified': False}

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--bundle', type=Path, default=Path(__file__).with_name('s0_evidence') / 'catalog.json')
    ap.add_argument('--data-dir', type=Path, required=True)
    args = ap.parse_args()
    print(dump(load(args.bundle, args.data_dir)))

if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""Deterministic offline S0 import. Source worktrees are strictly read-only.

Generate the image-carried bundle, then optionally load an explicitly named
staging data directory. Never discovers or writes a running service volume.
"""
from __future__ import annotations
import argparse
from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

HERE = Path(__file__).resolve().parent
LANE_A = set('seurat-qc seurat-cluster seurat-integrate seurat-markers seurat-modulescore scater-qc scran-cluster batchelor-integrate scran-markers aucell-score'.split())
LANE_B = set('singler-annotate muscat-pseudobulk speckle-propeller monocle3-trajectory cellchat-communication slingshot-trajectory wgcna-network maftools-landscape immunedeconv-infiltration'.split())
LANE_C = set('scanpy-qc scanpy-cluster scanpy-markers scvi-integrate scanvi-annotate'.split())
M12_MODULES = set('deseq2-wald deseq2-qc deseq2-lrt edger-qlf limma-voom limma-array limma-dupcor sva-batch clusterprofiler-ora clusterprofiler-gsea clusterprofiler-compare fgsea-prerank gsva-score limma-camera'.split())
REVIEWED_B = {'singler-annotate', 'muscat-pseudobulk', 'speckle-propeller',
              'monocle3-trajectory', 'cellchat-communication', 'wgcna-network'}

def encoded(obj):
    return json.dumps(obj, ensure_ascii=False, sort_keys=True, indent=2) + '\n'

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def git(root, *args):
    return subprocess.check_output(['git', '-C', str(root), *args], text=True).strip()

def mappings(path):
    """Read the named extraction-key column, allowing one key to map to many CLI options."""
    result = defaultdict(set)
    if not path.exists():
        return {}
    key_index = None
    for line in path.read_text().splitlines():
        if not line.strip().startswith('|'):
            continue
        cells = [c.strip().replace('`', '') for c in line.strip().strip('|').split('|')]
        if any('extraction' in c.lower() and ('key' in c.lower() or 'parameter' in c.lower()) for c in cells):
            key_index = next(i for i, c in enumerate(cells) if 'extraction' in c.lower())
            continue
        if key_index is None or len(cells) <= key_index:
            continue
        options = re.findall(r'--[a-zA-Z0-9][\w.-]*', cells[0])
        for key in re.split(r'[,;/\s]+', cells[key_index]):
            if key and key.lower() not in {'none', 'n/a', '-', 'pending'} and not set(key) <= {'-', ':'}:
                result[key].update(options)
    return {key: sorted(value) for key, value in sorted(result.items()) if value}

def build(repo, sources, verify):
    papers, usages, inputs, excluded, counts = {}, [], [], [], {}
    def record_input(root, path, role):
        relative = path.relative_to(root).as_posix()
        entry = {'source': root.name, 'branch': git(root, 'branch', '--show-current'),
                 'commit': git(root, 'rev-parse', 'HEAD'), 'file': relative,
                 'sha256': sha(path), 'role': role}
        if entry not in inputs:
            inputs.append(entry)
        return entry
    report_path = verify / 'docs/build/S0_VERIFICATION_M3M4.md'
    record_input(verify, report_path, 'verification_report')
    report = report_path.read_text()
    for source_kind, root in sources:
        if source_kind in {'A', 'B'}:
            record_input(root, root / f'docs/build/S0_REDO_lane_{source_kind.lower()}.md', 'redo_report')
        for extract in sorted(root.glob('acceptance/exemplars/*/literature/extraction.jsonl')):
            module = extract.parents[1].name
            # The merged repo also contains copied M3/M4 extracts; import those
            # only from their original lane, preserving the evidence column.
            if module not in {'M12': M12_MODULES, 'A': LANE_A, 'B': LANE_B, 'C': LANE_C}[source_kind]:
                continue
            column = 'reviewed_supplement' if source_kind in {'M12', 'A'} or module in REVIEWED_B else 'discovery'
            state = 'verified_S0' if source_kind == 'M12' else 'redone_after_verification' if column == 'reviewed_supplement' else 'partially_redone' if module == 'slingshot-trajectory' else 'not_redone'
            provenance = record_input(root, extract, 'extraction') | {'evidence_state': state}
            corpus_path = extract.with_name('corpus.jsonl')
            record_input(root, corpus_path, 'corpus')
            notes = extract.with_name('l3_notes.md')
            if notes.exists():
                record_input(root, notes, 'l3_notes')
            corpus = {str(r['pmid']): r for r in map(json.loads, corpus_path.read_text().splitlines())}
            option_path = repo / f'skills/{module}/references/options.md'
            option_map = mappings(option_path)
            if option_path.exists():
                record_input(repo, option_path, 'option_mapping')
            failures = set()
            verification = verify / f'acceptance/exemplars/{module}/literature/verification.json'
            if column == 'discovery':
                if not verification.exists():
                    raise ValueError(f'Missing verification: {module}')
                record_input(verify, verification, 'record_verification')
                failures.update((str(f['pmid']), f['parameter']) for f in json.loads(verification.read_text())['failures'])
                # §2 tables are a second explicit source of exact failed rows.
                section = report.split('## 2.', 1)[1].split('## 3.', 1)[0]
                active = False
                for line in section.splitlines():
                    if line.startswith('### '):
                        active = line.startswith('### ' + module + '（')
                    if active:
                        match = re.match(r'\|\s*(\d+)\s*\|[^|]+\|\s*`([^`]+)`', line)
                        if match:
                            failures.add(match.groups())
            grouped = defaultdict(list)
            stats = Counter()
            for line_no, line in enumerate(extract.read_text().splitlines(), 1):
                row = json.loads(line)
                pmid, key = str(row['pmid']), row['parameter']
                reason = None
                if row.get('applies') is False:
                    reason = 'applies_false'
                elif column == 'discovery' and (pmid, key) in failures:
                    reason = 'verification_failed_record'
                elif module == 'scanpy-qc' and pmid == '32832599':
                    reason = 'verification_section_3_not_applicable'
                elif source_kind == 'C' and key in {'settings_preset', 'mean_in_log_space'}:
                    reason = 'verification_section_3_alpha_only'
                elif module == 'immunedeconv-infiltration' and pmid == '32647202' and key == '_applies':
                    reason = 'verification_section_3_nonverbatim'
                if reason:
                    stats[reason] += 1
                    excluded.append({'module': module, 'pmid': pmid, 'parameter': key, 'line': line_no, 'reason': reason})
                    continue
                grouped[pmid].append((line_no, row))
            for pmid, rows in sorted(grouped.items()):
                article = corpus.get(pmid, {'pmid': pmid, 'pmcid': rows[0][1]['pmcid'], 'title': f'PMID {pmid} (corpus metadata pending)'})
                if pmid not in corpus:
                    stats['metadata_pending'] += 1
                paper_id = 'PMID-' + pmid
                paper = {k: article.get(k) for k in ('pmid', 'pmcid', 'title', 'year', 'journal', 'doi', 'licence', 'jats_sha256')}
                paper['metadata_status'] = 'corpus_metadata' if pmid in corpus else 'pending_missing_corpus_row'
                paper.update(paper_id=paper_id, url=f'https://pubmed.ncbi.nlm.nih.gov/{pmid}/')
                # Same PMID metadata is selected deterministically from the first source/module.
                papers.setdefault(paper_id, paper)
                parameters, coverage, context = [], [], []
                for line_no, row in rows:
                    key = row['parameter']
                    locator = {'url': f"https://pmc.ncbi.nlm.nih.gov/articles/{row['pmcid']}/",
                               'snippet': row.get('snippet', ''), 'section_path': row.get('section_path', ''), 'line': line_no}
                    obs = {'extraction_key': key, 'value': str(row['value']).strip().rstrip('.,;:!?。；，'),
                           'source_locator': locator, 'ecosystem': row.get('ecosystem'), 'applies': row.get('applies'),
                           'note': row.get('note', ''), 'options': option_map.get(key, []),
                           'mapping_status': 'mapped' if key in option_map else 'pending', 'provenance': provenance}
                    if key.startswith('_'):
                        context.append(obs)
                    elif str(row['value']).strip().lower() == 'not reported':
                        coverage.append(obs)
                    else:
                        parameters.append(obs)
                # Missing locators remain browseable but cannot be proposed.
                eligible = column == 'reviewed_supplement' and bool(parameters) and all(
                    p['source_locator']['snippet'] and p['source_locator']['section_path'] for p in parameters)
                usage = {'usage_id': f'S0-{module}-{pmid}', 'paper_id': paper_id, 'paper': papers[paper_id],
                         'module_tags': [module], 'method': module, 'column': column, 'parameters': parameters,
                         'coverage': coverage, 'context': context, 'provenance': provenance,
                         'ecosystems': sorted({str(r.get('ecosystem', 'n/a')) for _, r in rows}),
                         'support_role': 'direct_application', 'reviewer_status': 'ready_for_root_review' if eligible else 'unverified',
                         'verification_status': 'primary_source_methods_verified' if eligible else 'not_verified',
                         'implementation_compatibility': {'status': 'inventory_supported', 'scope': 'module mapping; locked version transfer requires review'},
                         'source_locator': {'observations': [p['source_locator'] for p in parameters]},
                         'limitations': ['Study-specific observations, never defaults.', 'S0 verified/redone evidence is not independent S3 acceptance or current-design compatibility.'],
                         'execution_authorized': False, 'automatic_parameter_application': False}
                usages.append(usage)
                stats[column] += 1
                stats['parameters'] += len(parameters)
                stats['coverage'] += len(coverage)
                stats['eligible_usages'] += int(eligible)
                stats['mapped_parameters'] += sum(p['mapping_status'] == 'mapped' for p in parameters)
            counts[module] = dict(sorted(stats.items())) | {'column': column, 'mapping_file': 'present' if option_path.exists() else 'pending'}
    return {'schema': 'omicstat.s0-evidence.v1', 'papers': sorted(papers.values(), key=lambda p: p['paper_id']),
            'usages': sorted(usages, key=lambda u: u['usage_id']), 'decisions': [], 'inputs': sorted(inputs, key=lambda i: (i['source'], i['file'])),
            'counts': dict(sorted(counts.items())), 'excluded': sorted(excluded, key=lambda e: (e['module'], e['line'])),
            'execution_authorized': False, 'automatic_parameter_application': False}

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--repo', type=Path, default=HERE.parent)
    ap.add_argument('--lane-a', type=Path, default=Path.home() / 'omic-s0-a')
    ap.add_argument('--lane-b', type=Path, default=Path.home() / 'omic-s0-b')
    ap.add_argument('--lane-c', type=Path, default=Path.home() / 'omic-s0-c')
    ap.add_argument('--verify', type=Path, default=Path.home() / 'omic-verify')
    ap.add_argument('--out', type=Path, default=HERE / 'app/s0_evidence/catalog.json')
    ap.add_argument('--data-dir', type=Path, help='Explicit OFFLINE staging directory to load; never the live volume')
    args = ap.parse_args()
    bundle = build(args.repo, [('M12', args.repo), ('A', args.lane_a), ('B', args.lane_b), ('C', args.lane_c)], args.verify)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(encoded(bundle))
    if args.data_dir:
        sys.path.insert(0, str(HERE / 'app'))
        from s0_loader import load
        print(encoded(load(args.out, args.data_dir)))
    print(encoded({'papers': len(bundle['papers']), 'usages': len(bundle['usages']), 'counts': bundle['counts']}))

if __name__ == '__main__':
    main()

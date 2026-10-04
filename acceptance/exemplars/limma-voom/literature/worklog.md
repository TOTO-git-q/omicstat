## 2026-09-27 07:32 UTC retriever (haiku)

**Search**: limma-voom
- Status: FAILED - EBI 500 error on PMC8733895 full text XML
- Recording error: `requests.exceptions.HTTPError: 500 Server Error: for url: https://www.ebi.ac.uk/europepmc/webservices/rest/PMC8733895/fullTextXML`

**L1 from Bioconductor 3.23**:
- limma 3.68.5 @ RELEASE_3_23 (commit: 825d1c8330)
- edgeR 4.10.5 @ RELEASE_3_23 (commit: c4a54bdaec)

Next: extraction (pending successful literature search)

## 2026-09-27T07:37:44Z main session
- search rerun after collect.py was made robust to per-article Europe PMC 500 errors (previous run aborted). corpus 30 l3 10 gates {'screened': 30, 'licence_not_countable': 12, 'excluded_by_regex': 18, 'pubtype_excluded': 1, 'no_methods_signal': 1, 'fulltext_http_error': 2}
- next: extraction

## 2026-09-27T10:15:00Z extractor (sonnet)
- limma-voom: extracted 6/30 articles (PMC13588164, PMC11790030, PMC8783691, PMC7755902, PMC10721151, PMC9724437). All snippets verified with `collect.py check`.
- applies=no for PMC13588164 (limma-voom applied to CRISPR-screen sgRNA counts, not bulk RNA-seq).
- Next: PMC13544910 (pmid 42695984), continuing through the remaining corpus in file order.

## 2026-09-27T11:00:00Z extractor (sonnet)
- limma-voom: extracted 12/30 articles (added PMC13544910, PMC12685072, PMC9800282, PMC7748411, PMC13506345, PMC12779551). All snippets verified with `collect.py check`.
- applies=no for PMC7748411 (DE calls on public microarray/RNA-seq datasets use generic 'Limma package'; voom mentioned only as background justification for simulated-data value ranges, not applied in the real-data pipeline).
- Next: PMC11602167 (pmid 39470725), continuing through the remaining corpus in file order.

## 2026-09-27T11:40:00Z extractor (sonnet)
- limma-voom: extracted 18/30 (added PMC11602167, PMC10637000, PMC8664842, PMC7849384, PMC13450212, PMC11551748). All snippets verified with `collect.py check`.
- applies=no for PMC11602167 (limma-voom named only as a benchmark comparator for a spatial-transcriptomics method, no parameters given), PMC10637000 (voom/limma+TMM used on ChIP-seq peak counts; the paper's RNA-seq DE uses edgeR exactTest), PMC7849384 (MAnorm2 ChIP-seq stats paper; voom/limma used on genomic-interval peak counts as a baseline comparator).
- Next: PMC9683707 (pmid 36417539), continuing through the remaining corpus in file order.

## 2026-09-27T12:20:00Z extractor (sonnet)
- limma-voom: extracted 24/30 (added PMC9683707, PMC13455466, PMC12643938, PMC10667096, PMC13558064, PMC12643502). All snippets verified with `collect.py check`.
- applies=no for PMC12643938 (limma-voom applied to pseudobulk from scRNA-seq, not bulk RNA-seq).
- Fixed a pmid mix-up: PMC10637000 (transposable-element paper) was mistakenly written with pmid 37903863 (belongs to PMC10667096); corrected to its real pmid 37950299 in all 9 of its lines.
- Next: PMC10635649 (pmid 37902626), continuing through the remaining corpus in file order.

## 2026-09-27T13:00:00Z extractor (sonnet)
- limma-voom: extraction complete, 30/30 articles, 270 lines (9 per article) in extraction.jsonl. All snippets verified with `collect.py check`.
- applies=no (5/30): PMC13588164 (CRISPR-screen sgRNA counts), PMC11602167 (limma-voom named only as a benchmark comparator, no parameters), PMC10637000 (voom/limma+TMM used on ChIP-seq peak counts; RNA-seq DE uses edgeR exactTest), PMC7849384 (MAnorm2 ChIP-seq stats paper; voom/limma used on peak counts), PMC12643938 (limma-voom applied to pseudobulk from scRNA-seq).
- Next: l3_notes.md for the 10 L3+L4 articles, then summarize + commit.

## 2026-09-27T14:15:00Z verifier (sonnet)
- limma-voom: independent verification, 20% sample (6/30 articles: PMC7673985, PMC9684074, PMC10635649, PMC10667096, PMC13506345, PMC13588164; pmids 33203890, 36344764, 37902626, 37903863, 42581186, 42758820), 54/54 extraction.jsonl lines checked (9 params x 6 articles).
- Fresh PubMed esummary echo: 6/6 title+year match.
- All 40 non-empty snippets: FOUND via `collect.py check`, all <=25 words, pmid/pmcid pairs match corpus.jsonl. Spot-checked verbatim transcription of an in-text typo ("eBayer" for eBayes, PMC10635649) and correct disambiguation of a two-part eBayes/treat pipeline (PMC13506345).
- `_applies` calls confirmed against the module definition: yes for PMC7673985, PMC9684074, PMC10635649, PMC10667096, PMC13506345 (voom/voomLmFit on bulk cytoplasmic RNA-seq exon/intron counts); no for PMC13588164 (CRISPR activation screen sgRNA counts, per the explicit module exclusion).
- 14/54 "not reported" lines checked against full Methods text via `collect.py methods`: all 14 confirmed genuinely absent from the matched Methods section (including correctly distinguishing a sample-level QC filter from the module's gene-level low-expression filter in PMC10667096, and a generic "normalized for sequencing depth" phrase with no named method in PMC13588164).
- pass_rate 54/54 = 1.0 -> verdict PASS.
- Wrote acceptance/exemplars/limma-voom/literature/verification.json.

## 2026-09-27T07:21Z — extractor (sonnet)
Articles done (5/30): PMC13577902 (42736449), PMC12755864 (41474973), PMC11694761 (39622635),
PMC10760525 (38065624), PMC9977155 (36577520, L3+L4, _applies=no: LRT-only, no Wald anywhere;
regex candidates for padj_cutoff on this article point to GOstats FDR<5% and a one-way-ANOVA
0.05 cutoff, both unrelated to the DESeq2 LRT call -- wrong).
All snippets verified with `collect.py check` before writing. extraction.jsonl has 50 lines (5
articles x 10 rows: _applies + 9 profile parameters incl. deseq2_version).
Next PMID to process: 33340372 (PMC7917550).

## 2026-09-27T07:45Z — extractor (sonnet)
Articles done (10/30): + PMC7917550 (33340372), PMC12890503 (41424389), PMC11687419 (39708805,
L3+L4 -- two separate DESeq2 Wald analyses in one paper, RNA-seq vs TT-seq, different
padj/lfc filters; recorded RNA-seq as primary, noted TT-seq divergence), PMC10760521 (37973194),
PMC8805715 (34933938, two mutant-vs-WT DESeq2 calls, met-2 set-25 and blmp-1, different lfc
filter; met-2 set-25 used as primary).
extraction.jsonl now has 100 lines (10 articles x 10 rows). All snippets verified with
`collect.py check`. No new systematically-wrong regex pattern beyond the PMC9977155 case already
logged.
Next PMID to process: 33355311 (PMC7849389).

## 2026-09-27T08:10Z — extractor (sonnet)
Articles done (15/30): + PMC7849389 (33355311), PMC13534236 (42680562, L3+L4), PMC13534237
(42680560, L3+L4, clean DTE exemplar: DESeq2 v1.38.3, Wald test, BH, |log2FC|>2 & padj<0.05),
PMC12807877 (41413654, L3+L4), PMC11802321 (39689710, pairwise per-timepoint contrasts from one
fitted model, prefilter=avg count>10, lfc_filter=|log2FC|>0.15 (~10%) combined with padj<0.05 and
an SE<0.5 criterion not in our parameter list).
extraction.jsonl now has 150 lines (15 articles x 10 rows). All snippets verified with
`collect.py check`.
Next PMID to process: 38092730 (PMC10719396, L3+L4).

## 2026-09-27T08:45Z — extractor (sonnet)
Articles done (20/30): + PMC10719396 (38092730, L3+L4, per-strain/per-OG metatranscriptomics,
Wald test explicitly named, apeglm shrinkage, padj<0.05), PMC8656144 (34887515, L3+L4, two
DESeq2 analyses -- liver RNA-seq FDR<0.1/FC>1.5 vs miRNA-seq FDR<0.05/FC>2, liver used as
primary), PMC7849303 (33300615), PMC13534238 (42595445), PMC12893922 (41407857, L3+L4, richest
article so far: 3 separate Wald comparisons each with its own explicit design formula
(~donor+condition_l3 / ~batch+donor+condition_l1 / ~sex+cell_type), ashr shrinkage,
fold-change thresholds 1.5/1.5/4, alpha=0.05, PLUS a separate explicit LRT comparison
(~donor vs reduced ~1) in the same Methods paragraph -- excellent concrete Wald-vs-LRT
contrast for l3_notes.md).
extraction.jsonl now has 200 lines (20 articles x 10 rows). All snippets verified with
`collect.py check`.
Next PMID to process: 37956308 (PMC10711424).

## 2026-09-27T09:10Z — extractor (sonnet)
Articles done (24/30): + PMC10711424 (37956308), PMC9829537 (36510111, two parallel DESeq2
analyses human+mouse, Wald test explicit, FDR<0.01; mouse-section version string "DESeq2 v.
2.0.265" looks like a citation-superscript run-on artifact -- treated as unreliable, human
"v.1.38.1" used instead), PMC7821903 (33298436, L3+L4, rich exemplar: design "~ source +
disease status", prefilter "<250 total reads/cohort", BH, FDR<0.05, v1.12.4),
PMC13534285 (42469015, minimal DESeq2 mention only; a padj<0.05 cutoff exists in the article
but belongs to MACS2 ATAC-seq peak calling, not the RNA-seq DESeq2 call -- flagged in note).
extraction.jsonl now has 240 lines (24 articles x 10 rows). All snippets verified with
`collect.py check`.
Next PMID to process: 41398052 (PMC12807875).

## 2026-09-27T09:35Z — extractor (sonnet)
Articles done (27/30): + PMC12807875 (41398052, design "~Treatment", BH, v1.36.0; separate
non-DESeq2 binomial-GLM Wald test for allelic imbalance, out of scope), PMC10711438 (37953377,
Paramecium time course, contrast-based extraction implying Wald but word never used, fold-change
>=2 & padj<0.05, v1.30.1), PMC9703767 (36443871, L3+L4, two DESeq2 analyses -- poly(A) RNA-seq
FDR<0.05/FC>2/prefilter count>=1-in-1-control vs PRO-Seq+ChAR-Seq FDR<0.05 only/prefilter
<5 reads in all samples; poly(A) used as primary).
extraction.jsonl now has 270 lines (27 articles x 10 rows). All snippets verified with
`collect.py check`.
Next PMID to process: 34876496 (PMC8744682).

## 2026-09-27T09:55Z — extractor (sonnet)
Articles done (30/30, ALL): + PMC8744682 (34876496), PMC11730331 (39639179, spike-in-normalized
mouse embryo RNA-seq, BH, padj<=0.05, |log2FC|>1, v1.30.1), PMC10760458 (37871969, minimal:
explicit two-group DESeq2 v1.28.1, details deferred to Supplemental Methods not in the
retrieved text).
extraction.jsonl complete: 300 lines = 30 articles x 10 rows (_applies + 9 profile parameters).
All snippets verified with `collect.py check` before writing (zero unverified snippets).
Extraction pass for all 30 corpus articles is DONE. Next step: write l3_notes.md for the 10
L3+L4 articles (36577520, 39708805, 42680562, 42680560, 41413654, 38092730, 34887515, 41407857,
33298436, 36443871), then run `collect.py summarize deseq2-wald`.

## 2026-09-27T10:15Z — extractor (sonnet)
Wrote l3_notes.md for the 10 L3+L4 articles (PMC9977155, PMC11687419, PMC13534236, PMC13534237,
PMC12807877, PMC10719396, PMC8656144, PMC12893922, PMC7821903, PMC9703767): own-words close
reading of DEG-table presentation, figures, and Methods-sentence structure, quotes <=25 words and
verified with `collect.py check`. Cross-cutting finding: figure type tied to a specific DESeq2
call is stated in only 2/10 Methods regions (PMC10719396 EnhancedVolcano; PMC9703767 PRO-Seq
volcano+Wald); DEG-table column/sort/truncation format is not stated in any of the 10 (that detail
lives in Results/captions, outside what `collect.py methods` returns). Corrected PMC9703767's
`test` row (36443871) from "not reported" to "Wald test" after finding it named for the PRO-Seq
DESeq2 call during close reading.
Module extraction + L3 notes are now fully complete: extraction.jsonl has 300 lines (30 articles
x 10 rows), l3_notes.md covers all 10 L3+L4 articles. Ready for `collect.py summarize` and the
independent verifier.

## 2026-09-27T07:53Z — verifier (sonnet)
Independent verification of the completed extraction (300 lines = 30 articles x 10 rows), never
the extractor of this module. Sample: `collect.py sample deseq2-wald --frac 0.2` -> 6 PMIDs
(33298436, 33300615, 36510111, 37973194, 39622635, 41407857) = 60 extraction.jsonl lines.
Echo (fresh esummary.fcgi calls, independent of the stored efetch archive): 6/6 titles and years
matched corpus.jsonl exactly. Snippet re-check: every non-empty snippet (13 unique texts across
the 6 articles) is <=25 words and returned FOUND via `collect.py check`; re-read
`collect.py methods deseq2-wald <PMCID>` for all 6 articles to confirm every "not reported" line
and every _applies=yes call. Result: 59/60 lines pass. One failure: PMID 41407857 (PMC12893922)
`lfc_filter` marked "not reported" although Methods > IPA literally states "|log2 fold change| > 1"
for a DESeq2 re-analysis of the public GSE84073 bulk dataset -- a fourth DESeq2 use in this
multi-comparison paper that the extractor's notes elsewhere (design, padj_cutoff, lfc_threshold_test)
partly document but did not carry through to this row. All other "not reported" calls, all
version/design/shrinkage/test/p_adjust_method/prefilter values, and all _applies=yes calls
confirmed correct and in-scope (bulk RNA-seq, not single-cell/pseudobulk/microbiome) against the
Methods text. Pass rate 59/60 = 98.33% >= 95%, echo 6/6 -> **verdict: pass**. Wrote
`verification.json`. Extraction for deseq2-wald stands as-is; no rework needed.

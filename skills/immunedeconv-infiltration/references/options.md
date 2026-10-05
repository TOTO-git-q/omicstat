# Locked options

| option | locked default / vignette value | required? | S0 extraction parameter key |
|---|---|---|---|
| --method-args | NULL; offline named JSON native arguments | no | none |
| --cibersort-abs-method | sig.score; no.sumto1 alternative | no | none |
| --input | none | no | none |
| --from-run | none | no | none |
| --upstream-object | expression_matrix | no | none |
| --outdir | none | yes | none |
| --spec | none | no | none |
| --method | required; all locked human methods below | yes | method |
| --input-scale | required; TPM, or log2TPM for MCP-counter | yes | input_scale |
| --tumor | TRUE | no | tumor |
| --arrays | FALSE | no | arrays |
| --scale-mrna | TRUE | no | scale_mrna |
| --rmgenes | NULL | no | rmgenes |
| --seed | 20260925 explicit suite seed | no | none |
| --journal | nature | no | none |
| --accept-licence | none; epic or cibersort | conditional | none |
| --cibersort-source | none; user-supplied R source | conditional | none |
| --cibersort-matrix | none; user-supplied LM22 | conditional | none |
| --indications | NULL; one cancer type/sample required for TIMER/ConsensusTME | conditional | indications |
| --expected-cell-types | NULL; all xCell types | conditional | none |
| --xcell-threads | 1 explicit execution choice; locked wrapper uses 2 | conditional | none |
| --xcell-alpha | 0.5 locked xCell default | conditional | none |
| --xcell-scale | TRUE locked xCell default | conditional | none |
| --consensus-stat-method | ssgsea locked top-level wrapper | conditional | none |

## Method, licence and signature audit (locked sources, 2026-10-01)

| method | availability | native output / comparison | licence | offline data source |
|---|---|---|---|---|
| quantiseq | enabled | cell fractions, across samples and cell types | quantiseqr GPL-3 | TIL10 packaged in quantiseqr 1.20.0 |
| mcp_counter | enabled | abundance scores, same cell type across samples only | MCPcounter 1.2.0 GPL-3; upstream Source/License GPL-3 | genes/probesets from ebecht/MCPcounter b6eac73e91c246fcff0bb1a5c68a816cd588fc48; build downloaded and SHA-256 registered |
| epic | requires --accept-licence epic | cell fractions, across samples and cell types, includes uncharacterized | EPIC 1.1.7 LICENSE: academic non-commercial only; no redistribution/sublicensing; agreed-user access; publication attribution | EPIC package TRef/BRef; inherited private image only; never copied into repository |
| xcell | enabled | enrichment scores, same cell type across samples only; not fractions | xCell 1.1.0 GPL-3 | bundled xCell.data; attach package before native workflow |
| timer | enabled; --indications required | abundance scores; compare same cell type across samples, not different cell types | GPL-2 per pinned immunedeconv README method licence table | packaged extdata/timer/immune_datasets + cancer-specific precalculated genes |
| abis | enabled | estimated percentages, can be negative; native unconstrained estimates retained | GPL-2 per pinned immunedeconv README | packaged extdata/abis RNA-seq signatures; arrays route excluded by declared RNA-seq scale |
| consensus_tme | enabled; --indications required | ssGSEA enrichment scores; same cell type across samples only | ConsensusTME GPL-3 | packaged consensus signatures by cancer type; GSVA native ssGSEA workflow |
| estimate | enabled | stromal/immune/ESTIMATE scores and separate TumorPurity estimate; not immune fractions | GPL-2 per pinned immunedeconv README | packaged extdata/estimate/estimate_genes.rds |
| cibersort | conditional user-supplied route; refused without acknowledgement/files | relative fractions of signature cell types | licensed non-commercial; no redistribution | --cibersort-source and --cibersort-matrix only; source/LM22 never bundled |
| cibersort_abs | conditional user-supplied route; refused without acknowledgement/files | absolute score, not a fraction | same CIBERSORT licence | same user-supplied files; native absolute=TRUE |

Audit sources: installed DESCRIPTION, function bodies and EPIC LICENSE from the locked image; [pinned immunedeconv README method licence table](https://github.com/omnideconv/immunedeconv/blob/e625e6c28ed14a30f9f40f159925cc9f0df4fa49/README.md); [pinned MCP-counter GPL-3](https://github.com/ebecht/MCPcounter/blob/b6eac73e91c246fcff0bb1a5c68a816cd588fc48/Source/License). The README's claim that immunedeconv itself is BSD disagrees with the installed GPL-2 + file LICENSE: installed licence takes precedence. No restricted files are exported or bundled anew.

Scale contract: linear non-log TPM for all RNA-seq workflows; MCP-counter receives an explicit log2(TPM+1) transform for TPM or no transform for declared log2TPM, avoiding its max>50 heuristic. This module supports human symbols and RNA-seq, arrays=false. TIMER indications use its documented lower-case cancer types; ConsensusTME upper-cases internally. Supply one type per sample in matrix order; no melanoma inference is made from file names. ConsensusTME ssgsea is fixed by the public top-level wrapper; alternate frameworks require a separately verified custom workflow.

Scores are never labelled cell fractions. Their figure colours are within-row z-scores for sample comparison only; the native CSV retains the package's output. ESTIMATE purity and score rows have separate native units. ABIS estimates are percentages and are neither clipped nor renormalized.

Before choosing each judgement option, query reference_advise(module='immunedeconv-infiltration', ...) and reference_search. The Racle melanoma example is quantiseq, TPM, tumor=true, arrays=false, scale_mrna=true; TIMER/ConsensusTME use SKCM only for this documented melanoma anchor. If evidence is absent, ask the user; method frequency does not set a default. CIBERSORT successful computation cannot be verified on Racle without the user's licensed files; refusal paths are verified instead.

`--method-args` supplies a named JSON object forwarded to the selected native method through deconvolute(...). Values override method convenience options, including abs_method; use --cibersort-abs-method for the dedicated CIBERSORT flag (locked sig.score; alternative no.sumto1). The top-level selector/input/absolute controls are reserved; use their CLI flags. ABIS/ESTIMATE have no top-level supplementary forwarding and refuse nonempty method-args. Licence acknowledgement and user CIBERSORT source/matrix remain mandatory. Arguments actually forwarded appear in Methods/provenance.

MCP-counter method-args cannot override `log_transform`, `feature_types`/`featuresType`, `genes` or `probesets`: scale follows `--input-scale`, and reference tables are hash-verified from the locked registry.

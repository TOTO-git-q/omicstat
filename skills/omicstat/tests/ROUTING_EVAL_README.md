> **Blind evaluation status (2026-10-04):** three blinded readings by gpt-6.1-sol (low)
> on the installed router; round 3 on `integrate/final` 6a88d3f scored 123/133 = 0.925
> primary (gate 0.90 PASS) and 132/133 = 0.992 within expected+acceptable (gate 0.98
> PASS). Rounds, router changes and the five policy-driven record updates are in
> `docs/build/ROUTING_BLIND_EVAL.md`. The one remaining miss (R116) is a questionable
> record left for the owner.

# omicstat routing evaluation set

`routing_eval.jsonl` is the machine-checkable acceptance artifact for
ENGINEERING_PLAN SS5.3 and gate **G5** (ENGINEERING_PLAN SS8): the router
(`skills/omicstat/SKILL.md`) is a map with no engine of its own, and this file is
how its mapping decisions get graded before anything downstream trusts it.

It contains **133 questions** (id `R001`-`R133`), one JSON object per line.

## Record schema

```json
{"id": "R001", "question": "...", "language": "zh|en|mixed",
 "expected": "<module>" | {"pipeline": ["m1", "m2", ...]} | {"out_of_scope": "<reason>"},
 "acceptable": [ "<module>" | {"pipeline": [...]} | {"out_of_scope": "..."} , ... ],
 "family": "...", "tests": "what disambiguation this probes", "note": "..."}
```

- `expected` is the single first-choice answer.
- `acceptable` lists every other answer that should NOT be scored as a miss (a
  legitimate sensitivity-analysis alternative, a defensible ecosystem choice under
  genuine ambiguity, etc.). It is `[]` when there is exactly one correct answer.
- A pipeline answer is an **ordered** list of module names, matching one of the
  SS3.x / SS5.1 recipes (or a subset/superset explicitly allowed in `acceptable`
  when the recipe has optional branches, e.g. the integration step that only
  applies to multi-sample data).
- An out-of-scope answer never names a module; it names the reason and, where the
  plan says so, which other system the question belongs to (medstat, phase 2,
  outside the suite entirely).
- Every module name appearing anywhere in the file (in `expected` or `acceptable`,
  bare or inside a `pipeline` list) is one of the 38 modules in ENGINEERING_PLAN
  SS1.2 (bulk 8, enrichment 6, single-cell Seurat 5 / Bioconductor 5 / back-end 6,
  network/mutation/infiltration 3, scverse 5 per SS10.2). No invented module names
  appear; this was checked mechanically (see Validation).

## Scoring rule (ENGINEERING_PLAN SS5.3 / G5)

Run all 133 questions through a **reader-only** agent (see below), collect its
first-choice module/pipeline/out-of-scope call for each, and compare against this
file:

- **First-choice hit rate >= 90%**: the agent's single top answer equals `expected`
  (pipeline answers compare the full ordered module list; a pipeline that matches
  an entry in `acceptable` also counts as a first-choice hit if the agent explicitly
  offered it as its primary answer).
- **First choice OR an acceptable alternative >= 98%**: the agent's answer equals
  `expected` or any entry in `acceptable`.
- Any miss under the 98% line is a routing-tree bug, not a scoring-tolerance issue:
  go back and fix the disambiguation tree in `SKILL.md` SS2 (or the pipeline recipe
  in SS3, or the out-of-scope table in SS4) that produced the wrong answer, then
  re-run this entire set once. ENGINEERING_PLAN SS5.2 says this explicitly:
  "未命中的条目回头修消歧树，然后重测一次" (a missed item sends you back to fix the
  disambiguation tree, then you re-test once).
- The evaluation set itself is then frozen together with the router version it was
  scored against (see "Frozen version" below); a routing regression is anything
  that drops either rate below its gate on a re-run.

## How a reader-only agent should answer

The grading agent must **only read `skills/omicstat/SKILL.md`** (the router) --
never a module's own `SKILL.md`, `PACK.md`, source, or this eval file's `expected`
column. This mirrors how a real user-facing routing decision is made (SKILL.md
SS "Operating rules": confirm the mapping in one sentence, name the primary module
and any second candidate with a reason, never invent a capability) and is also
the G8 "blind test" agent posture (ENGINEERING_PLAN SS8), reused here at smaller
scale for G5.

For each question, in order:
1. Read the question as a user would type it (Chinese, English or mixed is
   equally valid input per SKILL.md rule 5).
2. Decide: does it name (or clearly point at) exactly one module; does it name an
   ordered chain across SS3's pipeline recipes; or does it fall in SS4's
   out-of-scope / not-covered table?
3. If two modules could plausibly apply, follow SKILL.md's own instruction: name
   both, say which is primary, and give the one-line reason from SS2 -- but still
   record a single first-choice module for scoring.
4. Never fabricate a module name absent from SKILL.md SS1/SS2/SS3; if nothing in
   the router covers the question, the answer is out-of-scope, not a guess.
5. Record the first-choice answer (module name, ordered pipeline list, or
   out-of-scope) against the question's `id` for grading; do not look at this
   file's `expected`/`acceptable` columns while answering.

## Coverage table

### Questions per module (mentions in `expected` + `acceptable`, incl. pipeline membership; every module >= 2)

| Module | # | Module | # | Module | # | Module | # |
|---|---|---|---|---|---|---|---|
| deseq2-qc | 5 | seurat-qc | 7 | singler-annotate | 7 | wgcna-network | 2 |
| deseq2-wald | 9 | seurat-cluster | 6 | muscat-pseudobulk | 15 | maftools-landscape | 2 |
| deseq2-lrt | 4 | seurat-integrate | 4 | speckle-propeller | 7 | immunedeconv-infiltration | 3 |
| edger-qlf | 6 | seurat-markers | 5 | cellchat-communication | 2 | scanpy-qc | 8 |
| limma-voom | 6 | seurat-modulescore | 2 | monocle3-trajectory | 6 | scanpy-cluster | 8 |
| limma-array | 3 | scater-qc | 5 | slingshot-trajectory | 5 | scanpy-markers | 3 |
| limma-dupcor | 3 | scran-cluster | 3 | | | scvi-integrate | 4 |
| sva-batch | 4 | batchelor-integrate | 3 | | | scanvi-annotate | 4 |
| clusterprofiler-ora | 7 | scran-markers | 4 | | | | |
| clusterprofiler-gsea | 7 | aucell-score | 2 | | | | |
| clusterprofiler-compare | 4 | | | | | | |
| fgsea-prerank | 7 | | | | | | |
| gsva-score | 5 | | | | | | |
| limma-camera | 4 | | | | | | |

`muscat-pseudobulk`'s count is high because it is also the correct redirect target
for most of the pseudo-replication-trap questions (markers mistaken for
condition-level inference) and appears in several SS3.5 pipeline lists.

### Questions per family / trap type

| Family | # questions | What it probes |
|---|---|---|
| `module-coverage` | 76 | >=2 realistic questions per module (all 38), zh/en/mixed, with and without package names |
| `pipeline` | 10 | One (or more) question per SS3.x / SS5.1 standard multi-module recipe, including the M3c scverse chain (SS10.8 point 5) |
| `out-of-scope` | 9 | Survival, prediction models, clinical-covariate association, FASTQ->counts, CIBERSORT licence, KEGG bundled data, meta-analysis, diagnostic accuracy, GEO/TCGA fetch |
| `enrichment-choice` | 7 | ORA vs GSEA vs GSVA vs camera vs compare, resolved by input shape (thresholded list / ranked list / per-sample score / design-aware competitive test / multi-group comparison) |
| `de-engine-choice` | 6 | Bulk DE engine by data type and design: two-group counts, microarray-already-normalized trap, repeated measures, multi-group/LRT, single-cell condition (redirect to pseudobulk), quality-heterogeneous samples |
| `ecosystem-choice` | 6 | Seurat vs Bioconductor vs scverse: object type (`.rds` Seurat / SCE), `.h5ad` default-to-scverse rule (ENGINEERING_PLAN SS10.7), "reproduce paper X that used scanpy", field-majority fallback when neither an object nor a paper is given |
| `pseudo-replication-trap` | 5 | markers (cluster-level) mistaken for condition-level DE, across all three front-end ecosystems (Seurat/scran/scanpy), and the explicit cell-vs-sample replication-unit question |
| `trajectory-ecosystem` | 4 | monocle3 (Seurat line) vs slingshot (Bioconductor line) by front-end ecosystem; scverse has no native trajectory module (back-end modules only via explicit conversion) |
| `lexical-trap` | 4 | Negative examples from the limma-camera PACK's S1-approved P-3 appendix: "camera" as a microscope camera (zh + en), "FRY" as a gene symbol rather than `limma::fry()` (two framings) |
| `batch-correction-scope` | 3 | `sva-batch`'s corrected matrix is for display/scoring only; batch for a DE test goes into the design formula, never a pre-corrected matrix (`OS_BATCH_CORRECTED_INPUT`) |
| `proportion-test` | 3 | Cell-type proportion differences between conditions (`speckle-propeller`) vs expression differences, including a naive-chi-square redirect |

Language mix: 71 `zh`, 60 `en`, 2 `mixed`.

## Validation performed

The eval set was generated and checked by a one-off Python script (not committed;
per the task brief only `routing_eval.jsonl` and this README are added to the
repository). The script:

1. Builds the canonical 38-module set from ENGINEERING_PLAN SS1.2 / SS10.2 and
   asserts its length is exactly 38.
2. For every record, walks `expected` and every entry of `acceptable` and asserts
   each bare module name, and each module name inside a `pipeline` list, is a
   member of that 38-module set (an `AssertionError` aborts generation on any
   unknown name -- none were raised).
3. Round-trips every record through `json.dumps`/`json.loads` to confirm the file
   is valid line-delimited JSON.
4. Counts mentions of every module across `expected`+`acceptable` and asserts
   none falls below 2.

A second, independent check was run directly against the written file: every one
of its 133 lines parses with `json.loads`, and every record carries all eight
required keys (`id`, `question`, `language`, `expected`, `acceptable`, `family`,
`tests`, `note`).

## Frozen version

- **Date frozen**: 2026-10-07 (UMAP display lane; original 133 records retained).
- **Router file hashed**: `skills/omicstat/SKILL.md`.
- **sha256**: `ee9852bc96922cb922ba556ac89bce70ab0a40a1446649cbb7e2b23b9c388c13`
- **Router revision at freeze time**: `feat/umap-display` working tree, pending the external helper commit; exact before/after hashes are in `docs/build/routing_umap/router_hashes.json`.

If `SKILL.md` changes after this date -- a new module installed, a disambiguation
tree edited, a pipeline recipe added -- recompute the sha256 (`sha256sum
skills/omicstat/SKILL.md`) and update the three lines above before treating a
subsequent G5 run's pass/fail as meaningful. A stale hash here means nobody can
tell whether a scoring change came from the router or from drift in this file.

## UMAP display lane extension (2026-10-07)

The dataset now contains 139 questions, retaining all 133 existing cases and adding six English/Chinese cases for scanpy-annotate, scanpy-purity and scanpy-ingest. These are three additional display/annotation modules, bringing the method map to 41 targets (plus two utility entries in the router). Blind before/after observations and scoring for the final ASCII router are recorded in docs/build/UMAP_DISPLAY_REPORT.md; the interim after-reading is retained separately.

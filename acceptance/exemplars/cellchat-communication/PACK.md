# PACK — cellchat-communication

S0 evidence pack and S1 draft. This version is the redo after the independent verification of 2026-09-29 (`docs/build/S0_REDO_lane_b.md`); this lane does not write `verification.json`.

| Layer | Evidence |
|---|---|
| L1 | CellChat **2.2.0.9001**, GitHub commit `75253cd0c9e68410e6e721a6d3a0419a1d7e358f`: core Rd/defaults, rendered single/multiple/spatial tutorials, NEWS, README and the embedded human/mouse databases with sha256 in `L1_github/`. The pinned source has no CITATION file; the absence is recorded. |
| L2 | Original CellChat 2021 method paper, PMC7889871, pinned by URL and sha256 in `L2/`. Historical descriptions do not define this locked build's defaults. |
| L3 | 9 applicable tier-A application papers, close read in `literature/l3_notes.md`; the tenth tier-A item is the L2 method paper. |
| L4 | 30 licensed, open-access, PubMed-echoed articles; **28/30 applicable**, 2/30 excluded with Methods reasons. |

## T — table skeleton

Retain a complete LR-level table with source cell group, target cell group, ligand, receptor/complex, signaling pathway, communication probability/strength, inference P, selected database subset, and sample/condition provenance. A pathway table records aggregate strength and cell-group centrality separately. State whether plotted edges represent counts or weights. Store all pairs before display filtering; a Top-N panel is a view, not the result.

## F — figure grammar

Use a directed source-to-target network or circle plot with node labels and a legend defining edge width (count or summed weight), plus a bubble plot for named LR pairs with axes source and target cell groups. Pair condition-comparison heatmaps with the separate condition networks and the numerical difference table. Spatial edges require a coordinate/distance scale in the caption. These are draft display choices supported by locked tutorials and Methods, not universal visual defaults.

## W — wording

Methods template: “Normalized `<assay/layer>` expression and `<cell label>` were passed to CellChat (commit `75253cd`, v2.2.0.9001). `<species/database subset>` was used; `computeCommunProb(type=<...>, trim=<...>, raw.use=<...>, population.size=<...>, nboot=<...>)` inferred LR probabilities, and `filterCommunication(min.cells=<...>, min.samples=<...>)` filtered them before pathway and network aggregation.” Results template: “The `<condition>` network contained `<n>` retained directed LR interactions among `<n>` cell groups under the stated threshold; `<source>` to `<target>` contributed `<weight>` for `<pathway>`.” Call these transcriptomic *inferences*, not direct proof of physical signaling. “Default parameters” in an older paper does not report any locked argument value.

## V — variant frequencies

Redo after independent verification (2026-09-29): corrections from the verifier plus a whole-corpus scan for versions, database, estimator, trim and minimum-cell statements; counts below are recomputed from `extraction.jsonl` per ecosystem.

Denominator: **28 applicable / 30 corpus**. Front end among applicable: **Seurat 22/28, mixed 5/28, scverse 0/28, Bioconductor-only 0/28, not stated 1/28**. Ecosystem labels: three Scanpy front ends that feed CellChat (R) were relabelled from scverse to mixed (42758809, 38127424, 36543915; lane B rule: a Python front end feeding an R module is mixed, as for muscat 41565468 and SingleR 41384492); 41411065 was mixed here but Seurat in speckle-propeller and is now Seurat (Seurat + Signac; AnnData only for Xenium data). The one article with no described front end (34331449, the CellCall tool paper, where CellChat is a default-parameter comparator) carries the label `n/a` in place of the invalid "not reported" (open item). The two exclusions are a CellChatDB-only use (37970848) and the original method paper (33597522).

| Reported variant | Seurat (n=22) | Mixed (n=5) | not stated (n=1) | All applicable (n=28) |
|---|---:|---:|---:|---:|
| Input normalized matrix for CellChat | 3 | 2 | 0 | 5; not reported 23 |
| Named database / species / subset | 6 | 2 | 1 | 9 (incl. 1 with two manual pairs, 1 CellCall-embedded set); not reported 19 |
| Cell group definition (`group.by`) | 1 | 1 | 0 | 2; not reported 26 |
| `truncatedMean` | 1 | 2 | 0 | 3; `type` not reported 25 |
| Explicit `trim` (0.1 twice, one written as "10%"; 0.05 once) | 0.1: 1 | 0.1: 1, 0.05: 1 | 0 | 3; not reported 25 |
| Network strength or `aggregateNet` described | 8 | 2 | 0 | 10; not reported 18 |
| `computeCommunProbPathway` named | 4 | 1 | 0 | 5; not reported 23 |
| Centrality named | 2 | 1 | 0 | 3; not reported 25 |
| Minimum cells: `filterCommunication(min.cells=10)` / groups below 30 cells removed before CellChat | 10: 1 | 30: 1 | 0 | 2; not reported 26 |
| Communication-comparison P cutoff | 0.1: 1 | 0 | 0 | 1; not reported 27 |
| Package version stated (v2 written without a minor version in two) | 15 | 2 | 0 | 17; not reported 11 |

No inferred-parameter value has a >50% majority in the applicable corpus. "Interaction strength" (7/28) and a named `aggregateNet` call (3/28) describe different reporting levels, so their combined 10/28 is not a shared function setting. Truncated-mean estimation is reported by 3/28 and `triMean` by none, so the tutorial's `triMean` is not evidenced by any exemplar. Spatial values in PMC13510688 apply to its spatial arm only. No scverse-front-end paper reports a `type`, trim or DB choice except PMC9839452 (truncated mean of 10%, mixed), so no scverse-specific default follows. PMC11631771's pre-analysis removal of groups below 30 cells is not an explicit `filterCommunication(min.cells=30)` call.

## C — replay and printed anchors

Registry #28 / fetch F14 pins the CellChat tutorial's figshare human-skin `data_humanSkin` file (DOI 10.6084/m9.figshare.24470719.v1) with a verified sha256; `CellChatDB.human` is also copied from the pinned source and hashed in L1. The locked tutorial loads normalized expression and metadata, selects `meta$condition == "LS"`, uses `group.by="labels"`, assigns `CellChatDB.human` and its `Secreted Signaling` subset, then calls `computeCommunProb(type="triMean")`, `filterCommunication(min.cells=10)`, `computeCommunProbPathway()` and `aggregateNet()`. Assert data dimensions, cell-group labels and deterministic network table fields against the rendered tutorial where printed. Its elapsed seconds and timestamped status lines are nondeterministic and are not numerical assertions. The tutorial's local absolute path is replaced by F14 in replay, with the same file content.

## D — function default / official guide / exemplar evidence

The table below covers each profile parameter. A “not an argument” cell means it is an input/preprocessing or reporting choice. Function defaults come from locked Rd and `defaults.tsv`; guide cells describe the locked tutorial, not a package-wide mandate. Exact Methods frequencies count applicable papers only.

| Parameter (profile) | Function default, locked build | Locked tutorial / guide | Exemplar evidence (n=28) | S1 draft |
|---|---|---|---|---|
| `input_assay` (D-CC1) | assay=NULL; object supplies matrix | normalized data matrix | normalized expression matrix 2/28 (Seurat 2); normalized count matrix with cell annotation metadata 1/28 (mixed 1); normalized gene expression matrix 1/28 (mixed 1); normalized count matrix, Seurat RNA/data 1/28 (Seurat 1); not reported 23/28 | Require explicit normalized layer |
| `group_by` (D-CC2) | group.by=NULL | labels for matrix; group.by required for object | cell-type annotations with predicted spatial regions (CellTrek) 1/28 (mixed 1); cell identities via setIdent() 1/28 (Seurat 1); not reported 26/28 | Explicit cell labels |
| `datatype` (D-CC3) | RNA | RNA example; spatial tutorial separate | spatial 1/28 (Seurat 1); not reported 27/28 | Explicit RNA or spatial branch |
| `database` (D-CC4) | assigned to object, not function arg | human DB; Secreted Signaling subset | CellChatDB (species not stated) 2/28 (Seurat 2); 1,141 L-R interactions embedded in CellCall, used for CellChat and the other comparators 1/28 (n/a 1); CellChatDB.human 1/28 (Seurat 1); human CellChatDB 1/28 (mixed 1); CellChatDB human 1/28 (Seurat 1); CellChatDB plus two manually curated pairs (SPP1-PTGER4, LGALS9-SLC1A5) 1/28 (Seurat 1); human ligand-receptor database 1/28 (mixed 1); CellChatDB.mouse 1/28 (Seurat 1); not reported 19/28 | Pin species and subset |
| `identify_overexpressed` (D-CC5) | preprocessing function, not this arg | calls both gene and interaction filters | identifyOverExpressedGenes 6/28 (Seurat 5, mixed 1); not reported 22/28 | Run and record thresholds |
| `type` (D-CC6) | triMean first choice | triMean; truncatedMean sensitivity | truncatedMean 2/28 (Seurat 1, mixed 1); truncated mean (10%) 1/28 (mixed 1); not reported 25/28 | Pin triMean; optional sensitivity |
| `trim` (D-CC7) | 0.1 | 0.1 for truncatedMean example | 0.1 1/28 (Seurat 1); 0.1 (a truncated mean of 10%, as written) 1/28 (mixed 1); 0.05 1/28 (mixed 1); not reported 25/28 | Explicit when truncatedMean |
| `lr_use` (D-CC8) | NULL | no LR.use in main recipe | not reported 28/28 | Explicit pair subset if used |
| `raw_use` (D-CC9) | TRUE | TRUE; FALSE only after projectData | not reported 28/28 | Pin TRUE unless projection requested |
| `population_size` (D-CC10) | FALSE | TRUE considered for unsorted cells | not reported 28/28 | Make sorting assumption explicit |
| `distance_use` (D-CC11) | TRUE | spatial branch uses distances | TRUE 1/28 (Seurat 1); not reported 27/28 | Apply only for spatial data |
| `interaction_range` (D-CC12) | 250 | spatial range is technology-specific | 250 1/28 (Seurat 1); not reported 27/28 | Require coordinates and range units |
| `k_min` (D-CC13) | 10 | spatial neighbor criterion | not reported 28/28 | Pin only with spatial validation |
| `contact_dependent` (D-CC14) | TRUE | spatial tutorial distinguishes contact | TRUE 1/28 (Seurat 1); not reported 27/28 | Apply only for spatial data |
| `nboot` (D-CC15) | 100 | not overridden in main tutorial | not reported 28/28 | Explicit 100 with fixed seed |
| `seed_use` (D-CC16) | 1L | not overridden in main tutorial | not reported 28/28 | Record seed |
| `filter_min_cells` (D-CC17) | 10 | 10 in main tutorial | 30 (cell groups with fewer than 30 cells removed when the object was created) 1/28 (mixed 1); 10 1/28 (Seurat 1); not reported 26/28 | Explicit 10 provisionally; show exclusions |
| `aggregation` (D-CC18) | aggregateNet object input | count and weight networks | interaction strength 7/28 (Seurat 6, mixed 1); aggregateNet 3/28 (Seurat 2, mixed 1); not reported 18/28 | Retain both count and weight |
| `p_cutoff` (D-CC19) | no cutoff in computeCommunProb; 0.05 filter thresh | significant pairs are filtered | 0.1 1/28 (Seurat 1); not reported 27/28 | Report exact inferential scope |
| `pathway` (D-CC20) | computeCommunProbPathway thresh=0.05 | calls pathway aggregation | computeCommunProbPathway 5/28 (Seurat 4, mixed 1); not reported 23/28 | Retain pathway and LR tables |
| `centrality` (D-CC21) | netAnalysis_computeCentrality slot.name=netP | netP centrality example | netAnalysis_computeCentrality 2/28 (mixed 1, Seurat 1); centrality scores 1/28 (Seurat 1); not reported 25/28 | Compute after network aggregation |
| `version` (D-CC22) | 2.2.0.9001 pinned commit | tutorial at same commit | 2.1.2 3/28 (Seurat 3); 1.1.3 3/28 (Seurat 2, mixed 1); 1.4.0 2/28 (Seurat 2); 2 (written as v2) 2/28 (Seurat 2); 1.1.2 1/28 (Seurat 1); 1.1.0 1/28 (Seurat 1); 2.0 1/28 (Seurat 1); 1.1.1 1/28 (Seurat 1); 1.0.0 1/28 (Seurat 1); 1.6.1 1/28 (mixed 1); 1.5.0 1/28 (Seurat 1); not reported 11/28 | Store commit and DB hash |
| `assay` (D-CC23) | NULL | matrix from normalized data | RNA 1/28 (Seurat 1); not reported 27/28 | Require source assay/layer |
| `coordinates` (D-CC24) | NULL | required for spatial branch | not reported 28/28 | Require explicit spatial coordinates |
| `spatial_factors` (D-CC25) | NULL | required for spatial branch | not reported 28/28 | Pin technology-specific scale factors |
| `scale_distance` (D-CC26) | 0.01 | spatial scale varies by platform | 4.5 1/28 (Seurat 1); not reported 27/28 | Calibrate with physical units |
| `contact_range` (D-CC27) | NULL | spatial contact radius varies | 15 1/28 (Seurat 1); not reported 27/28 | Explicit radius with units |
| `contact_knn_k` (D-CC28) | NULL | optional contact KNN | not reported 28/28 | Explicit only when used |
| `contact_dependent_forced` (D-CC29) | FALSE | not overridden in main tutorial | not reported 28/28 | Pin FALSE provisionally |
| `do_symmetric` (D-CC30) | TRUE | spatial distance symmetry | not reported 28/28 | Pin TRUE provisionally |
| `kh` (D-CC31) | 0.5 | not overridden in main tutorial | not reported 28/28 | Pin 0.5 provisionally |
| `hill_n` (D-CC32) | 1 | not overridden in main tutorial | not reported 28/28 | Pin 1 provisionally |
| `filter_min_samples` (D-CC33) | NULL | multi-sample support in NEWS | not reported 28/28 | Require replicate policy in S1 |
| `rare_keep` (D-CC34) | FALSE | not overridden in main tutorial | not reported 28/28 | Pin FALSE provisionally |
| `nonfilter_keep` (D-CC35) | FALSE | not overridden in main tutorial | not reported 28/28 | Pin FALSE provisionally |
| `sources_use` (D-CC36) | NULL | can select sender groups | not reported 28/28 | Explicit only for focused views |
| `targets_use` (D-CC37) | NULL | can select receiver groups | not reported 28/28 | Explicit only for focused views |
| `signaling_use` (D-CC38) | NULL | can select pathways | not reported 28/28 | Retain global table before subset |
| `pairlr_use` (D-CC39) | NULL | can select LR pairs | not reported 28/28 | Retain global table before subset |
| `remove_isolate` (D-CC40) | TRUE | network plot omits isolated nodes | not reported 28/28 | Report retained groups |
| `aggregate_thresh` (D-CC41) | 0.05 | 0.05 in aggregation | not reported 28/28 | Explicit 0.05 provisionally |
| `centrality_slot` (D-CC42) | netP | netP in tutorial | not reported 28/28 | Record slot |

The package's `triMean`, 100 permutations, filtering thresholds and spatial parameters are locked defaults or guide examples, not exemplar majorities. `interaction.range=250` and `contact.range=15` are spatial distances, not numerical tolerances. The 0.1 communication-comparison P cutoff is a single paper's analysis choice. For multi-condition comparisons, independent biological samples and consistent cell labels must be recorded; merged cells alone do not supply condition-level replication.

## X — version-sensitive items

- CellChatDB v2 expands the ligand-receptor catalogue, including non-protein signaling. The locked tutorial warns against assigning the whole database uncritically and uses a Secreted Signaling subset for its human-skin example. Record database species, subset and file hash.
- NEWS 2.1.2 changes multi-sample consistency handling in `filterCommunication`, treats ECM-receptor signaling as diffusible in spatial analysis, and changes metadata naming from `slices` to `samples`. NEWS 2.1.1 adds a configurable spatial `contact.range`.
- Application papers report versions from 1.0.0 through 2.1.2; their unspecified defaults cannot be projected onto 2.2.0.9001. PMC8626557's superscript citation 40 follows v1.1.1 in JATS; flattened text looks like v1.1.140.
- The GitHub source lacks an `inst/CITATION`/root `CITATION` file at the pinned commit; `CITATION.absent.txt` records this and the original method paper is pinned in L2.

## S1 drafts and pending decisions

1. Pin the GitHub commit and exact human/mouse DB hashes. Require explicit species, subset, normalized expression layer and cell labels; keep `Secreted Signaling` as a tutorial-based preset, while other subsets are deliberate choices.
2. Start with `type="triMean"`, `raw.use=TRUE`, `nboot=100`, `seed.use=1L`, `filterCommunication(min.cells=10)` and 0.05 network filtering from locked L1. S1 must decide the biological-replicate rule for condition comparisons and whether `min.samples` is required.
3. Keep spatial inference separate: coordinates, physical units, scale factors, interaction/contact ranges and platform assumptions are mandatory before spatial probability calculation. The one explicit spatial parameter set in L3 is not a general default.
4. Preserve complete LR and pathway tables, edge count and weight, source/target direction, permutation P, database subset and provenance. Draw only filtered views from those tables; label communication as inferred.
5. Review how scverse AnnData input is normalized and converted. The three Scanpy-front-end studies (now labelled mixed) supply no explicit estimator or DB choice beyond one truncated mean of 10%, so they cannot set an ecosystem-specific default.

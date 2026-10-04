# S3 independent review request: limma-dupcor 1.0.0

Review S2 against the frozen PACK S1 appendix P-1..P-3. In particular, check that each block is a described, repeated and estimable correlated unit; that the estimated consensus is passed explicitly to `lmFit` and reported; that RNA mode uses two voom/duplicateCorrelation rounds; and that array moderation inherits the limma-array platform choices. This lane makes no S3 acceptance judgment.

## Anchors and outputs

- Illumina User's Guide §17.3: hash-pinned F7-F9 from `acceptance/data/ANCHOR_REGISTRY.md` (sha256 `6493d66dabb22fbd11023c5f412482edd972ad222fea3865d530335905cda0ed`, `1ce713157988d8bfb195c93b08c079aa63daf25ae95e817d2bff797e24423ba9`, `8a52b386e482ba0f686e0b4c57c2fd593621dbfeae9b72f64dc512b26f337ddb`). The fixture replays `read.ilmn` → `neqc` → detection P < 0.05 on at least three arrays. There are 24,691 expressed probes and 12 arrays in 3 donor blocks of size 4. The guide prints consensus 0.134; the locked limma 3.68.5 run estimates 0.1344848639, which rounds to 0.134. Output: `/home/<user>/omic-build-logs/build_m1b/limma-dupcor-smoke/a0/`. This run sets `--trend true --robust false` to match the guide's Illumina moderation, leaving the correlation estimate unchanged by moderation.
- Yoruba User's Guide §18.1: hash-pinned F10 (sha256 `62abb9669bf545e70bfa4abf3a8e99a86d49f35b8bd0ef7801deb8db0486a01b`). Direct locked-package replay uses 16,918 filtered genes and 86 lanes. First consensus: 0.4449716; second: 0.4454514. The guide prints **0.446** after both rounds. This is an explicit printed-precision anchor gap; no estimator or filter was changed to force a match. Replay code: `skills/limma-dupcor/tests/fixtures/replay_yoruba.R`; log: `/home/<user>/omic-build-logs/build_m1b/dupcor_golden.log`.
- Synthetic paired RNA fixture checks the engine's two-round path, `treat`, display-only filtering, and EList handoff. Container smoke and golden passed, as did call registry/default drift, flag documentation, lint, typed refusals, verified `--from-run`, tamper refusal and byte-identical `--spec` replay of tables, PNGs and figure specs. Figures opened: Illumina volcano, MD and SA diagnostic, plus RNA volcano and MD; no clipped labels and the dense MD plot is readable. Figure captions state n and the relevant BH/display thresholds. Goldens and module lock were generated in `omicstat-r:2026.09.1`.

## Needs owner decision

- The frozen array rule registers Agilent `trend=TRUE, robust=TRUE`; it does not give a preset for Illumina or other platforms. The engine requires both choices explicitly for non-Agilent arrays. Confirm future platform presets and whether guide replay should continue to use its `trend=TRUE, robust=FALSE` call when DE values are reviewed.
- Confirm treatment of the Yoruba 0.4454514 versus printed 0.446 gap in S3. The two source-derived rounds and exact locked value are available for independent investigation.
- The non-Agilent SA diagnostic is a shared figure-layer rendering of mean expression versus residual variability. Confirm whether an exact `limma::plotSA` rendering is required for this platform.

## Proposed installation records

Router row: `| paired or repeated-unit expression comparison with donor/patient/clone block, 配对差异表达 | limma-dupcor | scripts/run_limma_dupcor.R |`

Rules record: `{ "id": "PUB-M-LIMD-001", "module": "limma-dupcor", "category": "design_conditional", "rule": "Require a described repeated and estimable correlated block; report the estimated consensus, block sizes and RNA voom/correlation rounds; use explicit platform moderation, BH adjustment, and separate prespecified treat from display-only FC filtering." }`

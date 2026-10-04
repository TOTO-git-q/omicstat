---
name: limma-array
description: Run limma differential expression on normalized log2 microarrays and produce a complete probe table with optional gene annotation, a Down/NotSig/Up summary, volcano and MD figures, and a filled Methods/Results draft. Use for a target-vs-reference comparison on Agilent arrays or another array platform with explicitly selected moderation options; other groups may stay in the design. Chinese triggers include 芯片差异表达, 探针过滤, limma. NOT for raw RNA-seq counts (use limma-voom); NOT for repeated correlated units (use limma-dupcor).
---

## When to use / when not

Use for a target-versus-reference comparison of normalized log2 arrays. With `--keep-other-levels`, arrays of further condition levels stay in the design (as in the User's Guide 17.4 `~Treatment` fit) and contribute to the residual variance; only the named coefficient is tested. Use `limma-voom` for raw counts or `limma-dupcor` for repeated correlated units.

## Input requirements

Provide a probe-by-array log2 matrix, matching sample table, platform, reference and target. Supply known control probe IDs or declare they were removed upstream. A 0/1 detection matrix may be supplied with explicit `--background-k`; no detection data means no expression filter. Distinct probes remain distinct unless a validated technical-ID map is given. `--probe-annotation` attaches an explicit probe-to-gene mapping (unmapped probes are marked, never guessed). `--preprocessing` records the upstream background correction/normalization as the user declares it; without it the Methods say it was not stated. `--from-run` accepts a verified expression matrix and sample table.

## Run

`Rscript scripts/run_limma_array.R --matrix log2_arrays.csv --samples samples.csv --platform agilent --controls-removed --reference control --target treated --outdir run`

### Via MCP

Select `limma-array` with the same arguments. `--help` lists every option; `--trend` and `--robust` are especially important for non-Agilent arrays. See `references/parameters.md` for all flags and fixed calls.

## What gets produced

The complete inferential table is `tables/feature_table.csv`; `tables/limma_full.csv` preserves limma columns. The volcano and MD figures, figure specs, filled Methods/Results draft, QC table, results JSON, and verified fit handoff are under their named directories. `tables/probe_mapping.csv` preserves original probe-to-technical-ID mapping; `tables/feature_annotation.csv` (with `--probe-annotation`) holds symbol, Entrez ID, annotation status and member probe IDs per tested feature; `tables/direction_summary.csv` gives Down / NotSig / Up for the tested coefficient. The Methods draft states the control removal, the above-background rule with its k, technical averaging counts, design levels, trend/robust and their source, the annotation and the declared preprocessing of the actual run. Every auxiliary input file is hashed in provenance.

## Reading the results

The Agilent preset uses `eBayes(trend=TRUE, robust=TRUE)` unless explicitly overridden. Other normalized platforms require explicit values and receive a mean-variance diagnostic. A minimum-effect `treat` and the display-only filter are separate decisions; the latter never changes adjusted P values.

## When a QC rule fires

`LA-01..LA-05` cover low replication, few probes, unavailable adjusted P values, nonfinite effects, and universal significance. Input, design, control, and detection-data errors stop fitting. See `references/qc-rules.md`.

## Known limitations

The User's Guide 17.4 raw read (44254 x 19), the guide-route replay without the annotation filter and the technical-ID replay run on every smoke test. The full printed chain (27024 x 19, decideTests Down 756 / NotSig 24734 / Up 1534, top-20 table with RT1-Bb logFC 9.33) needs `RnAgilentDesign028282.db` 3.2.3 and `org.Rn.eg.db` 3.23.0 in the acceptance layer; until they are there the smoke test prints a `NOT-RUN ANCHOR` line (see `acceptance/exemplars/limma-array/S4_FIXES.md`). Non-Agilent platform presets remain an owner decision; this engine requires explicit trend and robust choices.

## Reference files

`method-basis.md` gives locked evidence; `parameters.md` documents flags; `qc-rules.md` lists rules and sources; `reporting-templates.md` supplies filled prose; `troubleshooting.md` maps typed errors to fixes.

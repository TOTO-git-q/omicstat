# P0-13 B4: copied prediction workup in existing glmnet-coxsig

ported_from: TOTO-git-q/medstat@12292d0:skills/cpm-pipeline/scripts/cpm_core.R
ported_from: TOTO-git-q/medstat@12292d0:skills/cpm-pipeline/scripts/calibration_binned.R
ported_from: TOTO-git-q/medstat@12292d0:skills/cpm-pipeline/scripts/cpm_qc.R

Exact source commit12292d020ef4a8575a3a1db880b81786ee3547fa; all ten read code/documentation
files have raw-byte Git/SHA256 identities in PORT_SOURCE.json. Eleven selected functions have
before/after hashes and explicit adaptations. No MedStat write, environment, MCP or runtime import.
This package is B4 only. It is not a completion claim for P0-12/13/14 or all native acceptance.

## Actual implementation
- Existing module identity, candidate status and expression handoff remain. Three original
  compute/render/QC function bodies are unchanged under private names, with default workup=none.
- Riley wrapper uses declared external planning assumptions/citation and every candidate gene,
  never a post-selection parameter count. Preserve criteria labels and original computed values.
- Copied Harrell loop retains sampling, optimism and source percentile construction. The callback
  repeats actual penalized glmnet CV/fit with original biological folds; source unpenalized rms
  refit is not substituted. Measured calibration slopes replace the source apparent-slope1 identity.
  Every attempted/failed draw is counted; there is no replacement or hidden budget reduction.
- Training-only offset-Breslow baseline is bound to the entire original signature and workup.
  External evaluation consumes frozen coefficients, preprocessing, lambda, cutoff, horizon, bins
  and baseline. Its diagnostic slope cannot update predictions. Native formals/versions are recorded.
- Copied aggregate KM calibration uses at least10 independent subjects per bin and complete
  original/displayed/omitted accounting. No smoothing, early-censor recoding or extrapolation.
  Shared os_calibration renders real computed intervals and labels dataset/n/slope/OE. It does no fit.
- Seventeen explicit new flags, none silently recommended. Source B>=200 retained; B>2000 is an
  explicit serial technical refusal. Applicable source QC formulas CPM-01/04/05/06 retained; other
  source families are not asserted to pass. Candidate publication blocker remains unconditional.

## Scientific adaptation and acceptance boundary
Source CPM's selected-variable unpenalized refit and this original penalized prediction model are
different. Source slope1 and worked-example decimal precision cannot be transferred silently.
Same-input copied-helper checks, independent fixed-LP baseline arithmetic, actual penalized
bootstrap and frozen external CLI/replay are required in the exact OmicStat lineage. No native
equality or uncertainty coverage is claimed from Python/static tests. The source percentile
construction is disclosed, not independently certified. Failed-fit conditioning can bias results.

The source verified CPM-one-predictor case is synthetic logistic AUC, not the selected survival
method. Its reference/runner are preserved as code, with applicability explicit. The source
binned-censoring fixture is invented and included for same-input native parity. Original eight
glmnet5.0 printed CoxExample coefficients and5e-9 tolerance remain unchanged. Four additional
native software-contract anchors require actual execution and cannot replace owner evidence.

## Explicit open requirements
Rscript and Docker are absent here. The official pmsampsize1.1.3 source archive was actually
acquired:15074 bytes, SHA2560801e590432715f06d3ed70dde47fcc2f2fe2ac76f38867c5a9ba6476d3c9069.
Its14 source MD5 entries and existing source-archive guard pass. DESCRIPTION requires R>=2.1,
suggests stats and declares no compilation; source inspection is not an installed-version check.
An OmicStat-owned candidate build/installed inventory remains unavailable. Existing timeROC
candidate requirements also remain real. Nothing is installed, relocked, promoted or substituted.
The env/candidates requirements file is a blocked planning record, not an install lock or image.
Real biological official-anchor input/cache, dataset SHA and owner aggregate contact sheet remain
unavailable. No patient source rows were read/downloaded; no paper panels or row-level data are
included. Exact S0 and20-record figure coverage remain unverified. New calibration restyle is open.

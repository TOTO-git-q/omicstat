# P0-13 proc-roc candidate pack

Ported from TOTO-git-q/medstat@12292d020ef4a8575a3a1db880b81786ee3547fa:
skills/diagnostic-accuracy/. See source identity, function hashes and explicit
adapter differences under skills/proc-roc/references. No MedStat runtime dependency.

This is a partial source/contract delivery. Native OmicStat R4.6.1 anchors, replay,
refusals, chain, figures, exact independent pROC closure and owner visual review
have not passed here. The original counted-2x2 example is synthetic and can only
validate arithmetic/contracts. No clinical patient rows or original paper images
are distributed. Genuine official aSAH source identity/receipt is pending.

The request is acceptance/requests/P0-13-proc-roc.json. Golden and seal are read-only
deferred_by_owner. Required missing inventory gates must remain visible. A fresh
executor evidence directory must preserve earlier failures and identify tested_head.

## C. Machine-readable anchors
<!-- anchors:begin -->
| ID | Metric | Expected | Tolerance | Source | Scope | How |
|---|---|---|---|---|---|---|
| sensitivity | Original counted-2x2 sensitivity | 0.9 | 1e-10 | https://github.com/TOTO-git-q/medstat/blob/12292d020ef4a8575a3a1db880b81786ee3547fa/skills/diagnostic-accuracy/tests/verified/REFERENCE.md | Pinned original synthetic numerical anchor, not real owner data; native OmicStat R4.6.1 execution required | replay |
| specificity | Original counted-2x2 specificity | 0.8 | 1e-10 | https://github.com/TOTO-git-q/medstat/blob/12292d020ef4a8575a3a1db880b81786ee3547fa/skills/diagnostic-accuracy/tests/verified/REFERENCE.md | Pinned original synthetic numerical anchor, not real owner data; native OmicStat R4.6.1 execution required | replay |
| ppv | Original counted-2x2 ppv | 0.8181818181818182 | 1e-10 | https://github.com/TOTO-git-q/medstat/blob/12292d020ef4a8575a3a1db880b81786ee3547fa/skills/diagnostic-accuracy/tests/verified/REFERENCE.md | Pinned original synthetic numerical anchor, not real owner data; native OmicStat R4.6.1 execution required | replay |
| auc_pair_count | Original counted-2x2 auc_pair_count | 0.98 | 1e-10 | https://github.com/TOTO-git-q/medstat/blob/12292d020ef4a8575a3a1db880b81786ee3547fa/skills/diagnostic-accuracy/tests/verified/REFERENCE.md | Pinned original synthetic numerical anchor, not real owner data; native OmicStat R4.6.1 execution required | replay |
| auc_delong_ci_low_delta | Independent formula or copied-original paired contract: auc_delong_ci_low_delta | 0 | 1e-09 | Independent formula and adapter check in skills/proc-roc/tests/test_helpers.R and tests/run_anchors.R; original numerical inputs are separately bound by tests/fixtures/SOURCE.json | Supplementary deterministic source/formula check, not a value printed in the original reference; no observed native result claimed | replay |
| auc_delong_ci_high_delta | Independent formula or copied-original paired contract: auc_delong_ci_high_delta | 0 | 1e-09 | Independent formula and adapter check in skills/proc-roc/tests/test_helpers.R and tests/run_anchors.R; original numerical inputs are separately bound by tests/fixtures/SOURCE.json | Supplementary deterministic source/formula check, not a value printed in the original reference; no observed native result claimed | replay |
| paired_delong_p_delta | Independent formula or copied-original paired contract: paired_delong_p_delta | 0 | 1e-09 | Independent formula and adapter check in skills/proc-roc/tests/test_helpers.R and tests/run_anchors.R; original numerical inputs are separately bound by tests/fixtures/SOURCE.json | Supplementary deterministic source/formula check, not a value printed in the original reference; no observed native result claimed | replay |
| paired_auc_difference_delta | Independent formula or copied-original paired contract: paired_auc_difference_delta | 0 | 1e-09 | Independent formula and adapter check in skills/proc-roc/tests/test_helpers.R and tests/run_anchors.R; original numerical inputs are separately bound by tests/fixtures/SOURCE.json | Supplementary deterministic source/formula check, not a value printed in the original reference; no observed native result claimed | replay |
| holm_adjustment_delta | Independent formula or copied-original paired contract: holm_adjustment_delta | 0 | 1e-09 | Independent formula and adapter check in skills/proc-roc/tests/test_helpers.R and tests/run_anchors.R; original numerical inputs are separately bound by tests/fixtures/SOURCE.json | Supplementary deterministic source/formula check, not a value printed in the original reference; no observed native result claimed | replay |
| wilson_sensitivity_low_delta | Independent formula or copied-original paired contract: wilson_sensitivity_low_delta | 0 | 1e-09 | Independent formula and adapter check in skills/proc-roc/tests/test_helpers.R and tests/run_anchors.R; original numerical inputs are separately bound by tests/fixtures/SOURCE.json | Supplementary deterministic source/formula check, not a value printed in the original reference; no observed native result claimed | replay |
| simel_lr_positive_delta | Independent formula or copied-original paired contract: simel_lr_positive_delta | 0 | 1e-09 | Independent formula and adapter check in skills/proc-roc/tests/test_helpers.R and tests/run_anchors.R; original numerical inputs are separately bound by tests/fixtures/SOURCE.json | Supplementary deterministic source/formula check, not a value printed in the original reference; no observed native result claimed | replay |
| simel_lr_positive_low_delta | Independent formula or copied-original paired contract: simel_lr_positive_low_delta | 0 | 1e-09 | Independent formula and adapter check in skills/proc-roc/tests/test_helpers.R and tests/run_anchors.R; original numerical inputs are separately bound by tests/fixtures/SOURCE.json | Supplementary deterministic source/formula check, not a value printed in the original reference; no observed native result claimed | replay |
| same_input_before_after_auc_delta | Independent formula or copied-original paired contract: same_input_before_after_auc_delta | 0 | 1e-09 | Independent formula and adapter check in skills/proc-roc/tests/test_helpers.R and tests/run_anchors.R; original numerical inputs are separately bound by tests/fixtures/SOURCE.json | Supplementary deterministic source/formula check, not a value printed in the original reference; no observed native result claimed | replay |
<!-- anchors:end -->

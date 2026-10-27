# omicstat-samplesize candidate pack

ported_from: TOTO-git-q/medstat@12292d020ef4a8575a3a1db880b81786ee3547fa:skills/sample-size/

Status: partial source delivery; native anchors/replay/refusals/figures not run; owner review null. This is a pack description, not ACCEPTANCE.json.

- Source identity and byte verification: docs/build/P0-13-samplesize/SOURCE_VERIFICATION.json.
- Exact adaptations: skills/omicstat-samplesize/references/PORT_ADAPTATIONS.json and docs/build/P0-13-samplesize/ARCHIVAL_SOURCE_ADAPTATION.patch.
- Actual local tests/nonpasses: docs/build/P0-13-samplesize/TEST_SUMMARY.json and evidence/.
- Full requirement status: docs/build/P0-13-samplesize/source_requirements.json and GAPS.md.
- Native acceptance request: acceptance/requests/P0-13-samplesize.json; parent f5ec7329a1eaf99f950f4c135678f50d4c5b8241.

Original five package engines and six QC conditions are copied/adapted. Scientific assumptions are explicit; no technical-repeat pseudoreplication, retrospective observed power, guessed native defaults or fabricated CIs. The shared planning curve depicts model scenarios, not measured observations. Current synthetic fixture is for contracts only; no owner-facing contact sheet has been produced. No MedStat runtime dependency or report theme is retained.

## C. Machine-readable anchors
<!-- anchors:begin -->
| ID | Metric | Expected | Tolerance | Source | Scope | How |
|---|---|---|---|---|---|---|
| SS-V1_mean_n1 | Independent means: analyzable n per arm | 64 | 0 | https://github.com/TOTO-git-q/medstat/blob/12292d020ef4a8575a3a1db880b81786ee3547fa/skills/sample-size/tests/verified/run_verified.R | Ported original independent numerical oracle; freshly obtained R4.6.1 results required | replay |
| SS-V1_mean_total | Independent means: total analyzable biological n | 128 | 0 | https://github.com/TOTO-git-q/medstat/blob/12292d020ef4a8575a3a1db880b81786ee3547fa/skills/sample-size/tests/verified/run_verified.R | Ported original independent numerical oracle; freshly obtained R4.6.1 results required | replay |
| SS-V2_logrank_events | Balanced HR 0.67 log-rank required events | 196 | 0 | https://github.com/TOTO-git-q/medstat/blob/12292d020ef4a8575a3a1db880b81786ee3547fa/skills/sample-size/tests/verified/run_verified.R | Ported original independent numerical oracle; freshly obtained R4.6.1 results required | replay |
| SS-V2_logrank_total | HR 0.67, event probability 0.4, total analyzable biological n | 490 | 0 | https://github.com/TOTO-git-q/medstat/blob/12292d020ef4a8575a3a1db880b81786ee3547fa/skills/sample-size/tests/verified/run_verified.R | Ported original independent numerical oracle; freshly obtained R4.6.1 results required | replay |
| paired_oracle_delta | Paired n versus native pwr.t.test | 0 | 0 | Pinned MedStat samplesize_engines.R and native package replay; supplementary same-package check, not an independent printed anchor | Supplementary three-design native package consistency | replay |
| anova_oracle_delta | ANOVA n versus native pwr.anova.test | 0 | 0 | Pinned MedStat samplesize_engines.R and native package replay; supplementary same-package check, not an independent printed anchor | Supplementary three-design native package consistency | replay |
| proportions_oracle_delta | Proportion n versus native pwr.2p.test | 0 | 0 | Pinned MedStat samplesize_engines.R and native package replay; supplementary same-package check, not an independent printed anchor | Supplementary three-design native package consistency | replay |
<!-- anchors:end -->

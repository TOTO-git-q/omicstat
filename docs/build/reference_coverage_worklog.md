# reference_coverage worklog (branch infra/reference-coverage, worktree ~/omic-ref-coverage on GT103)

Plan: owner-approved scope P0, P1, P2, P3 plus tools/upgrade/news_filter.py. Not done on purpose: Bioc 3.24 image, dry_run_goldens,
plan_upgrade, pkg_diff, light tier (P5). Resume rule: read this file, continue at "Next step"; do not redo anything marked VERIFIED.

## Owner answers (2026-10-10)
1. Skip Bioc 3.24. 2. Monthly digest file on GT103 + `last_digest` in cli.py status + monthly systemd user timer; no push.
3. One-off refetch of the S0 full texts approved (EPMC >= 1 s spacing, resumable, failure log). 4. Light tier: no.
5. Lexicon = omics packages + omics method names only. 6. First 3 watch profiles = top 3 FEASIBLE of the first probe ranking.
Later the same day: one-off private lab-reading scan (separate store, never exported, appendix of this month's digest only, no recurring scan).

## State (all VERIFIED unless noted)
| # | Step | State |
|---|---|---|
| 1 | P0 reconcile (order-preserving extension) + map-reconcile CLI + tests | DONE, live (reconciled on the first cycle, next_module limma-voom kept) |
| 2 | P1 lexicon v1 (205 entries, 178 rank-eligible), build_lexicon.py | DONE |
| 3 | P1 method_mentions migration v3-001-coverage, tokens only | DONE, live |
| 4 | P1 S0 methods_used: 753/753 papers refetched from Europe PMC (efetch/*.xml in the S0 branches are PubMed records without body: 0 usable locally), 0 failures, 17 papers whose JATS hash differs from the recorded one | DONE, in bundle |
| 5 | P2 probe.py + S0 baseline (266 rows) + CLI + worker hook | DONE, live; first month used the 400 cap (83 failed attempts); owner one-off top-up of 90 requests completed all 135 no-module candidates |
| 6 | P2 digest (reference_digest.py) + user timer + last_digest pointer | DONE, digest-2026-10 written, timer next 2026-11-03 04:04 JST |
| 7 | P3 defaults report + default_context in advise | DONE, live-checked (scanpy-markers --test flagged) |
| 8 | news_filter + demo on the locked NEWS (docs/upgrade/2026.10.1/affected_modules.md) | DONE |
| 9 | Lab-reading one-off scan (PaperFlow read-only), appendix, release guards (make_release) | DONE |
| 10 | Deploy: image 4fbef843a4e1 live (ops dirs deploy4-a19df03..., deploy4-4fbef84...) | DONE |
| 11 | Watch profiles: macs/homer/enrichr retired; accepted doublet-detection, sctransform, proteomics-de (owner choice) | DONE |
| 12 | Merge to integrate/final + push | see DEPLOYMENT_LOG / final report |

## Next step
November: the probe covers the module-covered lexicon terms and starts the yearly history of trend-family members (default budget 400).

## Log
- 2026-10-10: worktree from e9881a4; commits b80ae6d (P0), 5d68b3f (P1-P3 code), a19df03 (bundle), dd2b333, 4fbef84 (probe fix), a40cd7e, f23f847.
- Tests at the end: app 151 (in image, 2 skipped), reference_service/tests 27, tools/upgrade 5, release guards 2 (outside the repo), fork_status clean,
  tools/check_reference_integration PASS, tools/test_build_contracts 13 OK.

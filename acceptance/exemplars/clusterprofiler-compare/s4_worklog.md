# clusterprofiler-compare S4 worklog

Branch `s4/cp-ora-compare` (worktree `E:/claude workspace/skills-dev/omic-s4-cp-ora-compare`, from integrate/m1m2 @fb63e52).
GT103 run dir: `~/omic-build-logs/s4/cp-ora-compare/` (shared by clusterprofiler-ora and clusterprofiler-compare; smoke tmp per module via OMICSTAT_TEST_TMP=/omicstat/_smoke/<module>).

## Verified state

- 2026-09-29: read brief, S3 reviews, S3 report sec 2/4/5, PACK (both), scripts, tests.
- 2026-09-29: Astra compare ALL probe (`~/omic-s3-runs/clusterprofiler-compare/_s3/all-probe`): X1 BP/CC/MF input 198/201/205, background 11525/11914/11822; X2 input 746/768/758 (recounted from its enrichment_full.csv).
- 2026-09-29: book chapter comparecluster-analysis.qmd at pinned commit 549613197f fetched read-only; sha256 e4c2ea01...a6ab matches L2/manifest.tsv; original example at lines 31-42.

- 2026-09-29: probes (GT103 cp-ora-compare-src/all/simp/orig/pt logs): enrichGO ALL pool FALSE = one enrichGO per ontology (BH per ontology, verified 0 diff); pool TRUE = one family; simplify BP (2588 terms) ~882 s; book example replay exact (1020 rows).
- 2026-09-29: code committed (0c34982 ORA, af63e4f compare); goldens written in container (ora-gold / cmp-gold logs), locks written (lock-ora / lock-cmp), normal reruns ora-final / cmp-final SMOKE PASSED with golden PASS, lock --check OK (lock-check log). Figures copied and viewed.
- 2026-09-29: S4_FIXES.md written; goldens, locks, S4_FIXES, worklogs committed.

## Next step

Done for S4. Waiting for coordinator / independent re-review. If a shared change lands on integrate/m1m2: merge it, re-run both smoke tests in cp-ora-compare, regenerate goldens/locks if outputs change.

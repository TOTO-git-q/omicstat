# Worklog -- anchor dataset registry (brief VENDOR_INTEGRATION_BRIEF §4)

Resume protocol: read this file top to bottom; the last "Stopped at" line says
where to continue. Registry = `acceptance/data/ANCHOR_REGISTRY.md`; downloads =
`acceptance/data/fetch_anchor_data.sh` (files git-ignored by `acceptance/data/.gitignore`,
which now also un-ignores this file and the registry).

## 2026-09-27 session (branch claude/gallant-fermat-ifhpkl worktree)

- Task B (GT103 container MCP test failures) dropped by the owner (budget); no mcp/ change
  made. Root-cause notes are in the session report only.
- Inventory: installed vignettes of the 33 modules' packages grepped for data loading
  (`system.file("doc", package=)`); edgeR / limma user's guides read from their PDFs
  (text via ghostscript `txtwrite`, no pdftotext on this host).
- Lookups (read-only, no e-mail): `geo_meta.fetch_series` for GSE60450, GSE63310, GSE60361,
  GSE96583, GSE33005, GSE52778, GSE18508, GSE19446; `arrayexpress_experiments`
  `fetch_experiment` + `get_experiment_files` for E-GEOD-33005 (40 files; the raw zip named
  in the limma guide is no longer listed, individual files and the SDRF are). ExperimentHub
  ids/paths from `experimenthub.sqlite3` (sha256 6b9f7759...ac0c).
- Verified state: `bash acceptance/data/fetch_anchor_data.sh` downloads 27 files (~282 MB)
  and every sha256 checks OK (run twice; one run after deleting two files, with the group
  filter `bulk`). Every downloaded file was loaded in R 4.5.3 once (dimensions in the registry).
- Not resolved: WGCNA FemaleLiver-Data.zip (source TLS certificate expired; web.archive.org
  unreachable through the proxy). OSCA-book chapter datasets were not verified (raw GitHub
  paths guessed wrong); registry marks those alternatives "not verified".
- Printed anchor values read in this session: limma UG 17.3 dupcor 0.134; 18.1 dupcor 0.446;
  18.1 camera Y 13 Up 2.40e-262, X 54 Down 5.58e-26. All other printed values are for the
  module builders to read at S0.

Stopped at: Task A complete (registry + fetch script committed). Open items for the owner:
registry section 4 (data packages missing from the container layers; hub accessors;
Bioc 3.22 vs 3.23), WGCNA anchor file.

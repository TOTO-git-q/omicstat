# tools/lit — S0 literature and L1 collection (omicstat)

ENGINEERING_PLAN §2.1–2.3. Retrieval only (Python, venv `/opt/retrieval-venv`, dependencies =
`vendor/claude_science/requirements.txt` + `pypdf`); the analysis engines never import this code. HTTP goes
through the vendored Claude Science clients, imported read-only (no bytecode is written into
`vendor/`).

| File | Role |
|---|---|
| `journals_seed.json` → `build_journals.py` → `journals.json` | whitelist gate; every ISSN echoed by a live Europe PMC query (tier A = L3 + L4, tier B = L4 only) |
| `discovery_profiles.json` | per module: Europe PMC section query (package + analysis-part feature), Methods signal regex, exclude regex, parameters (PACK D rows) with candidate regexes |
| `omlit.py` | gates: whitelist, publication type, year; Methods-region locator; signal; licence (CC BY / CC BY-NC / CC0 without a TDM prohibition count); snippet ≤ 25 words; PubMed efetch echo |
| `collect.py` | `search`, `methods`, `check`, `sample`, `summarize` (see its docstring) |
| `collect_l1_release.py` | L1 from the locked release: `git.bioconductor.org` branch `RELEASE_3_23` + rendered vignettes of `bioconductor.org/packages/3.23/` (HTML; PDF-only vignettes such as the edgeR / limma User's Guides are converted with `pypdf`, which is installed in the retrieval venv in addition to the vendor requirements; the PDF URL and sha256 head the `.rendered.txt`) |
| `vendor_live_check.py` | one real call per vendored component |
| `test_omlit.py` | offline tests |

Environment: `OMICSTAT_CONTACT_EMAIL` (sent to NCBI / EBI; default a placeholder), `OPENALEX_API_KEY`
(optional; OpenAlex is not used without it).

## Per-module outputs: `acceptance/exemplars/<module>/`

```
L1/                      dev-tier export of the installed package (tools/collect_l1.R)
L1_bioc3.23/             locked-release export (collect_l1_release.py)
L2/                      optional: external documentation pinned by commit + sha256 (not copied when unlicensed)
literature/
  search_log.json        query, hits per year, gate counts, hashes of journals/profiles
  corpus.jsonl           screened, countable, PMID-verified articles (layer L3+L4 or L4)
  efetch/<PMID>.xml      PubMed records (proof of the echo)
  extraction.jsonl       parameter values (extractor)
  l3_notes.md            close reading of the L3 exemplars, in own words (extractor)
  verification.json      independent re-check of a >= 20 % sample (verifier)
  worklog.md             resumable log of every agent that worked on the module
PACK.md                  sections T F W V C D X + draft S1 decisions (main session)
```

## Roles (owner's instruction of 2026-09-27)

| Role | Model | Does |
|---|---|---|
| Retriever (one per module family) | haiku | runs `collect.py search <module>` for each module of the family; on failures re-runs, never edits profiles; logs to `worklog.md` |
| Parameter extractor | sonnet | for every corpus article: `collect.py methods <module> <PMCID>`, reads the Methods text, writes one `extraction.jsonl` line per profile parameter; for L3 articles also `l3_notes.md` |
| Data agent | sonnet | anchor datasets, reference data registry |
| Independent verifier | sonnet, never the agent that retrieved or extracted the module | `collect.py sample` (≥ 20 %), re-checks: PubMed efetch echo (fresh call), `collect.py check` for every snippet, the value is what the snippet says; writes `verification.json`; < 95 % pass -> the module's extraction is redone |
| Main session | — | profiles and regexes, V-section counts, D-section three-way table, draft S1 decisions, final PACK |

### extraction.jsonl — one line per (article, parameter)

```json
{"pmid": "12345678", "pmcid": "PMC...", "parameter": "padj_cutoff", "value": "0.05" | "not reported",
 "snippet": "<= 25 words copied verbatim from the Methods>", "section_path": "Methods > RNA-seq analysis",
 "applies": true, "note": "optional, e.g. 'value given for the proteomics analysis, not the RNA-seq'",
 "ecosystem": "seurat | bioconductor | scverse | mixed | n/a"}
```

Single-cell modules (M3, plan v1.1 part X §10.7): every article records the ecosystem it used --
`seurat`, `bioconductor` or `scverse` (scanpy / AnnData / scvi-tools), `mixed` when the front end
crosses ecosystems (say which in `note`). V majorities are counted per ecosystem; scverse defaults
come only from scverse papers, and the scverse share of the corpus is reported as is.

Rules: copy values only as written (no inference from figures, Results or defaults); when the paper
does not state the value write `"not reported"` with an empty snippet; one extra line per article with
`"parameter": "_applies"` answers "does this article run this module's analysis part?" (`value` yes/no
+ snippet) -- articles with `no` are excluded from the V counts.

### Worklog protocol

Every agent appends to `acceptance/exemplars/<module>/literature/worklog.md`: date/time, agent role,
what was verified (counts, files, hashes), and the exact point to resume from. A new agent reads the
worklog first and continues from the last verified state; nothing is redone that the log marks verified.

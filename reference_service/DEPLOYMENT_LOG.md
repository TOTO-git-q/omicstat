# Deployment log - omicstat-reference

## 2026-09-29 (18:20Z) fork1: omics-only omicstat_reference fork (current)

Owner decision (2026-09-29): omics-only fork, registry from the method map, empty seed, full rename.
It resolves the two open decisions of the first deployment: D1 (scaffold seed) and D2 (leftover
medstat wording).

- **Release:** omic-MCP `infra/omicstat-reference` @ `7d73145`, shipped to
  `~/omic-infra-reference/release/`. The previous release is kept as
  `release.prev-20260928T182021Z`.
- **Code:** the fork in `app/` (base medstat-reference `07fdebd`; 28 files modified, 25 removed, 2
  added; every change is declared in `FORK_CHANGES.json`; `fork_status.py --verify-base` found no
  problems).
- **Runtime reset** (the seed and method-map hashes changed), `reset_runtime_gt103.sh --yes pre-fork1`:
  - stopped only `omicstat-reference`;
  - backup `~/omic-infra-reference/runtime-backups/runtime-20260928T182031Z-pre-fork1.tar`, sha256
    verified, containing the m7 data (reference/harvest sqlite with the 10 m7 discoveries, worker
    status, worker.jsonl);
  - old data moved to `runtime/data.pre-fork1-20260928T182031Z` (kept);
  - fresh `runtime/data` created. `runtime/logs` was kept (append).
- **Image:** `omicstat-reference:20260929-fork1` (id `84780d57a57f`). The previous image
  `omicstat-reference:20260929-m7` is kept for rollback, together with the moved-aside data.
- **Container:** `omicstat-reference` was recreated by `docker compose up -d` (project
  `omicstat-reference` only). It has a read-only root, `cap_drop ALL`, user 1000:1000, no ports,
  mounts `runtime/data -> /data` and `runtime/logs -> /logs`, and env `OMICSTAT_REFERENCE_*`.
- **medstat-reference** (container, image, `/home/<user>/medstat-reference`, repository) was not
  touched and was still `Up 4 days (healthy)` after the deployment.
- **Deploy log:** `~/omic-build-logs/infra-reference/deploy-20260928T182046Z.log`. Reset log:
  `reset-20260928T182031Z.log`.

### Verification

| Check | Result |
|---|---|
| Host tests in the deploy (fork provenance + config through the fork loaders) | 12 run, OK (1 skipped: `build_config --check` needs git) |
| Full fork suite **inside the new image** (`--network none --read-only`) | 119 run, OK (2 skipped: the wrapper check, which needs the repository outside the image) |
| Laptop test runs | app suite 119 OK; outer suite 12 OK; `build_config.py --check` OK; offline MCP smoke PASSED |
| Health | `healthy` |
| `cli.py status` | curated 0 / 0 / 0; `seed_status empty_no_curated_evidence`; `registered_modules 38`; all 38 in `modules_without_curated_evidence`; `deployment gt103-docker` |
| Empty-seed search and advise (remote MCP): deseq2-wald, scran-cluster, wgcna-network, scanvi-annotate | search `curated_evidence = no_curated_evidence_yet`; advise with a full omics StudyContract `review_required` + `no_curated_evidence_yet`; `execution_authorized` and `automatic_parameter_application` false. `rcs-analysis` gives `unknown_module` |
| Remote MCP smoke (`tests/smoke_reference_stdio.py --remote`, same ssh command as the registration) | PASSED, read-only. `serverInfo.name = omicstat_reference`; 10 tools, same names and input schemas as before |
| Wrapper smoke (`tests/smoke_omicstat_entry.py`) | PASSED: 5 omicstat tools with byte-identical schemas; guidance names `omicstat_reference` and `no_curated_evidence_yet`; resource `omicstat://reference-workflow` |
| First worker cycle on the fresh data (automatic at 18:20:53Z) | completed in 185 s: 27 requests, **10 screened** (deseq2-lrt ... fgsea-prerank). deseq2-wald and deseq2-qc were deferred by two transient `network_failure` errors (upstream retry behaviour); `excluded_by_regex` 3. Next cycle 2026-09-29 05:20 +08:00 |
| Three columns (`cli.py search --module edger-qlf`) | `[curated, reviewed_supplement, discovery]`: curated 0 (`no_curated_evidence_yet`), reviewed_supplement 0, discovery 1 `unreviewed_machine_screened` (Nucleic Acids Research, tier A, "Materials and methods > Transcriptomics", glmQLFit snippet) |

### Registration snippets (text only; not applied)

These are unchanged from the m7 entry below. Only the key `omicstat_reference` names the tools, and
the server now also calls itself `omicstat_reference`. Adjust the omicstat checkout path in the
`omicstat` entry to the checkout that is registered.

Claude `E:\claude workspace\.mcp.json`, under `mcpServers` (adjust `OMICSTAT_ORIGINAL_SERVER` and the
entry path to the omicstat checkout that is registered; the worktree path below is an example):

```json
"omicstat": {
  "type": "stdio",
  "command": "C:\\Users\\<user>\\AppData\\Local\\Programs\\Python\\Python312\\python.exe",
  "args": ["E:\\claude workspace\\skills-dev\\omic-infra-reference\\reference_service\\omicstat_entry.py"],
  "env": {"OMICSTAT_ORIGINAL_SERVER": "E:\\claude workspace\\skills-dev\\omic-infra-reference\\mcp\\server.py"},
  "timeout": 1800000
},
"omicstat_reference": {
  "type": "stdio",
  "command": "C:\\Windows\\System32\\OpenSSH\\ssh.exe",
  "args": ["-T", "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=yes", "-o", "ConnectTimeout=8",
           "-o", "IdentitiesOnly=yes", "-o", "ServerAliveInterval=15", "-o", "ServerAliveCountMax=2",
           "-i", "C:\\Users\\<user>\\.ssh\\id_ed25519", "<user>@<analysis-host>",
           "docker exec -i omicstat-reference python /app/server.py"],
  "env": {"PROGRAMDATA": "C:\\ProgramData"},
  "timeout": 120000
}
```

Codex `config.toml`:

```toml
[mcp_servers.omicstat]
command = 'C:\Users\<user>\AppData\Local\Programs\Python\Python312\python.exe'
args = ['E:\claude workspace\skills-dev\omic-infra-reference\reference_service\omicstat_entry.py']

[mcp_servers.omicstat.env]
OMICSTAT_ORIGINAL_SERVER = 'E:\claude workspace\skills-dev\omic-infra-reference\mcp\server.py'

[mcp_servers.omicstat_reference]
command = 'C:\Windows\System32\OpenSSH\ssh.exe'
args = ['-T', '-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=yes', '-o', 'ConnectTimeout=8', '-o', 'IdentitiesOnly=yes', '-o', 'ServerAliveInterval=15', '-o', 'ServerAliveCountMax=2', '-i', 'C:\Users\<user>\.ssh\id_ed25519', '<user>@<analysis-host>', 'docker exec -i omicstat-reference python /app/server.py']
startup_timeout_sec = 30

[mcp_servers.omicstat_reference.env]
PROGRAMDATA = 'C:\ProgramData'
```

### Remaining limitations

- The curated column is empty until seed evidence is curated. Replacing the seed later needs
  `reset_runtime_gt103.sh`, or a fresh `reference.sqlite` only, which keeps the harvest state but
  drops curator promotions.
- `reference_advise` has no omics module-specific rules yet; it checks the common StudyContract fields
  only.
- The legacy-v1 migration path from the base stays in `harvest.py`. It is inert here.

---

## 2026-09-29 (17:45Z) M7 first deployment: unchanged vendored copy (superseded by fork1)

- Release: omic-MCP `infra/omicstat-reference` @ `d5a76cc` (shipped with `git archive` to
  `~/omic-infra-reference/release/`, `RELEASE_COMMIT` recorded). Code = medstat-reference v2 `07fdebd`
  vendored byte-identical (61 files, manifest verified by the deploy's own test run); configuration =
  `config/` (38 journals, 38 profiles, 38-module method map, scaffold seed, omics request schema).
- Image `omicstat-reference:20260929-m7` (id `c6d5ed557c17`); base `python:3.12-slim@sha256:57cd7c3a...`
  and the `pip install mcp==1.28.0` layer were cache hits shared with medstat-reference's build.
- Container `omicstat-reference`, compose project `omicstat-reference`; read-only root, `cap_drop ALL`,
  user 1000:1000, no ports. Mounts `~/omic-infra-reference/runtime/data -> /data`,
  `~/omic-infra-reference/runtime/logs -> /logs`. `medstat-reference` (container, image, data) untouched
  and still `Up 4 days (healthy)` after the deployment.
- Deploy log: `~/omic-build-logs/infra-reference/deploy-20260928T174510Z.log` (offline tests 10 run,
  9 OK + 1 skipped (config rebuild needs git) -> stage -> build -> up -> health OK -> status).

### Verification

| Check | Result |
|---|---|
| `worker.py --health` | healthy (compose status `healthy`) |
| `cli.py status` | curated 0 papers / 0 usages / 38 decisions (scaffold); `seed_status scaffold_no_curated_evidence`; method map `active`, 38 modules, `next_module deseq2-wald` at start; `deployment gt103-docker-omicstat-reference` |
| First worker cycle (started automatically at 17:45Z) | completed in 150 s, 28 requests, **10 screened** (deseq2-wald ... clusterprofiler-compare), gates: duplicate 2, excluded_by_regex 4, off_topic 4; no errors; next cycle 2026-09-29 04:45 +08:00 |
| Three search columns (`cli.py search --module deseq2-wald` and MCP) | `columns_order = [curated, reviewed_supplement, discovery]`; curated = `OMIC-SCAFFOLD-deseq2-wald`; reviewed_supplement total 0; discovery label `unreviewed_machine_screened`, 1 item (Science Advances, tier A, snippet from "MATERIALS AND METHODS > RNA sequencing analysis") |
| Remote MCP stdio (`tests/smoke_reference_stdio.py --remote`, same ssh command as the registration) | PASSED, read-only: 10 tools; status; module search; `rcs-analysis` refused as `unknown_module`; advise `needs_input`; candidates listed |
| Wrapper (`tests/smoke_omicstat_entry.py`, laptop) | PASSED: 5 omicstat tools, input/output schemas and annotations byte-identical to `mcp/server.py`, guidance suffix on list_modules/describe/run only, resource `omicstat://reference-workflow` |

### Registration snippets (not applied; for the main session / owner)

Claude `E:\claude workspace\.mcp.json`, under `mcpServers` (adjust `OMICSTAT_ORIGINAL_SERVER` and the
entry path to the omicstat checkout that is registered; the worktree path below is an example):

```json
"omicstat": {
  "type": "stdio",
  "command": "C:\\Users\\<user>\\AppData\\Local\\Programs\\Python\\Python312\\python.exe",
  "args": ["E:\\claude workspace\\skills-dev\\omic-infra-reference\\reference_service\\omicstat_entry.py"],
  "env": {"OMICSTAT_ORIGINAL_SERVER": "E:\\claude workspace\\skills-dev\\omic-infra-reference\\mcp\\server.py"},
  "timeout": 1800000
},
"omicstat_reference": {
  "type": "stdio",
  "command": "C:\\Windows\\System32\\OpenSSH\\ssh.exe",
  "args": ["-T", "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=yes", "-o", "ConnectTimeout=8",
           "-o", "IdentitiesOnly=yes", "-o", "ServerAliveInterval=15", "-o", "ServerAliveCountMax=2",
           "-i", "C:\\Users\\<user>\\.ssh\\id_ed25519", "<user>@<analysis-host>",
           "docker exec -i omicstat-reference python /app/server.py"],
  "env": {"PROGRAMDATA": "C:\\ProgramData"},
  "timeout": 120000
}
```

Codex `config.toml`:

```toml
[mcp_servers.omicstat]
command = 'C:\Users\<user>\AppData\Local\Programs\Python\Python312\python.exe'
args = ['E:\claude workspace\skills-dev\omic-infra-reference\reference_service\omicstat_entry.py']

[mcp_servers.omicstat.env]
OMICSTAT_ORIGINAL_SERVER = 'E:\claude workspace\skills-dev\omic-infra-reference\mcp\server.py'

[mcp_servers.omicstat_reference]
command = 'C:\Windows\System32\OpenSSH\ssh.exe'
args = ['-T', '-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=yes', '-o', 'ConnectTimeout=8', '-o', 'IdentitiesOnly=yes', '-o', 'ServerAliveInterval=15', '-o', 'ServerAliveCountMax=2', '-i', 'C:\Users\<user>\.ssh\id_ed25519', '<user>@<analysis-host>', 'docker exec -i omicstat-reference python /app/server.py']
startup_timeout_sec = 30

[mcp_servers.omicstat_reference.env]
PROGRAMDATA = 'C:\ProgramData'
```

### Known limitations at deployment

- Scaffold seed (worklog D1): curated column carries one no-evidence record per module; no seed
  papers/usages; `reference_advise` has no omics module rules (common fields only).
- Upstream self-description (worklog D2): the server names itself `medstat_reference` and some texts say
  "Medstat" / "27 modules"; env var names are `MEDSTAT_REFERENCE_*`. Code is unchanged by design.
- Method map and seed are bound by the stores; changing them later needs a new sqlite (DEPLOYMENT.md).
- Discovery items are machine-screened only (e.g. the first deseq2-wald hit runs DESeq2 on TPM values);
  they are never evidence until reviewed and promoted.

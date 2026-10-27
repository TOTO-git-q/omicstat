# omicstat-reference: GT103 Docker deployment and operations

`omicstat_reference` is an omics-only fork of the medstat-reference v2 code base (`app/`; provenance
and changelog in `FORK.md`). It runs as its own instance, with its own image, compose project,
container and data directory. It shares nothing with the running `medstat-reference` (image,
container, `/home/<user>/medstat-reference/`, data). Never operate on the medstat-reference instance
from here.

## Architecture

```text
analysis agent
  |- omicstat MCP (laptop: reference_service/omicstat_entry.py -> omic-MCP mcp/server.py; 5 tools, schemas unchanged)
  '- omicstat_reference MCP (SSH stdio -> GT103 docker exec -i omicstat-reference python /app/server.py; 10 tools)
                                      |
                        ~/omic-infra-reference/runtime/data  (reference / harvest / reviews sqlite)
                                      ^
                  resident worker in the same container, one cycle every three hours:
                  literature requests first (<= 4 screened/day) -> then the 38-module rotation (method_map.json)
                                      ^
                  Europe PMC / NCBI official REST (ALLOWED_HOSTS unchanged from the base)
```

| Item | medstat-reference (do not touch) | omicstat-reference |
|---|---|---|
| Directory | `/home/<user>/medstat-reference` | `/home/<user>/omic-infra-reference/{release,context,runtime}` |
| Compose project / container | `medstat-reference` | `omicstat-reference` (top-level `name:` in `compose.yaml`) |
| Image | `medstat-reference:20260924-v2` | `omicstat-reference:20260929-fork1` (previous: `omicstat-reference:20260929-m7`, the unchanged-vendor build) |
| MCP server name | `medstat_reference` | `omicstat_reference` |
| Environment | `MEDSTAT_REFERENCE_*` | `OMICSTAT_REFERENCE_*` |
| Data / logs | `./data`, `./logs` in its directory | `~/omic-infra-reference/runtime/data`, `.../runtime/logs` |
| Ports | none | none |
| Module registry | 27 medstat modules (seed tags) | 38 omicstat modules (`app/method_map.json`) |
| Seed | 100 papers / 100 usages / 37 decisions | empty (every module answers `no_curated_evidence_yet`) |
| Journals | 114 clinical and methods journals | 38 omics journals (tier A 23, tier B 15) |

Container invariants (unchanged from the base):
- read-only root filesystem, `cap_drop: [ALL]`, `no-new-privileges`, UID/GID 1000;
- no listening port;
- writes only to `/data` and `/logs`;
- 512 MB memory, 1 CPU.

Literature handling is unchanged too:
- no institutional subscription and no PDF download;
- full text is parsed in memory only;
- only <=25-word snippets, section locators and the full-text SHA-256 are stored.

## Layout on GT103

```text
~/omic-infra-reference/
  release/             committed reference_service/ of one omic-MCP commit (RELEASE_COMMIT), incl. compose.yaml
  release.prev-<UTC>/  previous releases (kept)
  context/             Docker build context = app/ + STAGED.json (stage_build.py)
  context.prev-<UTC>/  previous contexts
  runtime/data/        persistent: reference.sqlite, harvest.sqlite, reviews.sqlite, worker_status.json, backups/
  runtime/logs/        persistent: worker.jsonl
  runtime/data.<label>-<UTC>/   data directories moved aside by reset_runtime_gt103.sh (never deleted)
  runtime-backups/     runtime-<UTC>-<label>.tar + .sha256
~/omic-build-logs/infra-reference/deploy-<UTC>.log, reset-<UTC>.log
```

## Configuration

`build_config.py` writes the configuration files into `app/` from pinned inputs
(`config_sources.json`). `build_config.py --check` and the tests verify them.
- `journals.json`: from omic-MCP `tools/lit/journals.json`.
- `discovery_profiles.json`: the S0 profiles of four branches; all 38 have `profile_status ok`
  according to the S0 live logs; the query window is 2020 to today.
- `method_map.json`: **the module registry**; router section 1 first, then ENGINEERING_PLAN 1.2,
  then 10.2.
- `decision_rules.json`: the common advise fields are the omicstat StudyContract fields, plus omics
  covariate-purpose prompts; there are no module rules yet.
- `seed/catalog.json`: empty.
- `schemas/literature_request.v1.json`: omics `study_context` enums; the module enum is filled from
  the registry.

**Frozen after first start.**
- The harvest store binds the method-map hash. A changed `method_map.json` stops harvesting with
  `method_map_changed`.
- The reference store binds the seed SHA-256. A changed seed refuses to open with `seed_mismatch`.

Changing either means `reset_runtime_gt103.sh`: back up, move the old data aside and start fresh
sqlite files. Curator promotions and harvest state are dropped from the live store; they stay in the
backup and in the moved-aside directory.

## Deploy / redeploy (main session)

On the laptop, in the omic-MCP checkout, with the change committed and pushed:

```bash
# 1. ship the committed reference_service/ (keeps the previous release as release.prev-<UTC>)
bash reference_service/ship_to_gt103.sh      # also runs deploy_gt103.sh in the foreground
# for a long build, ship only (the git archive | ssh part of ship_to_gt103.sh), then run detached:
ssh <user>@<analysis-host> 'setsid nohup bash ~/omic-infra-reference/release/deploy_gt103.sh >/dev/null 2>&1 < /dev/null &'
ssh <user>@<analysis-host> 'tail -n 40 $(ls -t ~/omic-build-logs/infra-reference/deploy-*.log | head -1)'
```

When the seed or method map changes, run this **before** `deploy_gt103.sh`:
`bash ~/omic-infra-reference/release/reset_runtime_gt103.sh --yes <label>`. It stops only this
compose service, writes `runtime-backups/runtime-<UTC>-<label>.tar` plus its sha256 and verifies it,
moves `runtime/data` to `runtime/data.<label>-<UTC>`, and creates an empty `runtime/data`.

`deploy_gt103.sh` (on GT103) runs these steps in order:
1. Checks compose isolation: project and container `omicstat-reference`, no medstat names, no
   ports, and any existing `omicstat-reference` container must belong to this project.
2. Runs the host tests: fork provenance and configuration through the fork's loaders.
3. Stages `context/`.
4. `docker compose build`.
5. Runs the **full fork test suite inside the new image**: a one-off `--rm --network none
   --read-only` container.
6. `docker compose up -d`, which recreates only `omicstat-reference`.
7. Health, for up to 120 s.
8. Prints `cli.py status` and `/app/STAGED.json`.

The script has no `down`, `rm` or `prune`, and never deletes `runtime/`.

After start, the worker runs its first cycle immediately: up to 60 requests to Europe PMC/NCBI and
<= 10 screened. After that it runs every three hours, at most eight attempts a day.

## Verification

```bash
cd ~/omic-infra-reference/release
docker compose ps
docker exec omicstat-reference python /app/worker.py --health
docker exec omicstat-reference python /app/cli.py status      # curated 0/0/0, registered_modules 38
docker exec omicstat-reference python /app/cli.py search --module deseq2-wald --limit 3   # curated_evidence no_curated_evidence_yet
```

From the laptop:

```bash
python reference_service/tests/smoke_reference_stdio.py --remote ssh -T -o BatchMode=yes <user>@<analysis-host> docker exec -i omicstat-reference python /app/server.py
python reference_service/tests/smoke_omicstat_entry.py
python -m unittest discover -s reference_service/tests -p "test_*.py"
(cd reference_service/app && python -m unittest discover -s tests -p "test_*.py")
```

## Curator commands (CLI only)

```bash
docker exec omicstat-reference python /app/cli.py list-reviews --pending
docker exec omicstat-reference python /app/cli.py promote --review-id R --curator NAME [--note "..."]
docker exec omicstat-reference python /app/cli.py demote --supplement-id S --reason "..." [--curator NAME]
docker exec omicstat-reference python /app/cli.py domain-list [--status proposed]
docker exec omicstat-reference python /app/cli.py domain-accept --id D --curator NAME [--discovery-profile /data/profile.json]
docker exec omicstat-reference python /app/cli.py domain-ack --id D --curator NAME [--note "..."]
docker exec omicstat-reference python /app/cli.py request-status LR-xxxxxxxxxxxxxxxx
docker exec omicstat-reference python /app/cli.py backup --label manual
```

## Stop / roll back (this instance only)

- **Stop:** `cd ~/omic-infra-reference/release && docker compose stop`. Never use `down`, and never run
  compose in `/home/<user>/medstat-reference`.
- **Roll back to the previous release:**
  1. `docker compose stop`.
  2. Swap the directories:
     `mv release release.bad-<UTC> && mv release.prev-<UTC> release && mv context context.bad-<UTC> && mv context.prev-<UTC> context`.
  3. If the previous release used another seed or method map, also swap `runtime/data` with the
     matching `runtime/data.<label>-<UTC>`.
  4. `docker compose -f release/compose.yaml build && docker compose -f release/compose.yaml up -d`.

## Registration (done by the main session or the owner, not by the build agent)

The Claude (`E:\claude workspace\.mcp.json`) and Codex (`config.toml`) snippets are in
`DEPLOYMENT_LOG.md`.
- `omicstat_reference` uses the same SSH options as `medstat_reference`, with the container name
  changed.
- `omicstat` points at `reference_service/omicstat_entry.py`, with `OMICSTAT_ORIGINAL_SERVER` set to
  the omicstat `mcp/server.py` to be used.

## Coverage upgrade operations (from 2026-10-10)

| Item | Where |
|---|---|
| Method map | 41 modules (38 analysis + 3 display modules appended); a pure extension reconciles on its own; see FORK.md |
| Probe | worker, one chunk per cycle after the harvest; `docker exec omicstat-reference python /app/cli.py probe --dry-run` shows the plan; ledger in `harvest.sqlite` (`probe_runs`, `method_probe`) |
| Digest | `~/omic-infra-reference/release/reference_digest.py`, systemd user timer `omicstat-reference-digest.timer` (3rd of each month 04:00), installed with `systemd/install_digest_timer.sh`; output `runtime/reports/digest-YYYY-MM.md` + `.json`; pointer in `cli.py status` (`last_digest`) |
| Reports mount | `../runtime/reports:/reports:ro` (the container cannot write reports); `deploy_gt103.sh` creates the directory before `up` |
| Rebuild inputs | `python build_lexicon.py` (lexicon), `python build_probe_baseline.py` (needs the S0 lane worktrees), `python import_s0_evidence.py` (S0 bundle, methods_used sidecar `s0_methods_used.json`, option defaults) |
| Redeploy | DEPLOY_SEED.md procedure (backup compose + image tag + data tar with sha256, stop only this service, loader, offline verification, switch, health) |
| Rollback | restore `data.before.tar` and `compose.before.yaml` of the deploy's ops directory (see DEPLOYMENT_LOG.md); the previous image tags stay on the host |

Budget and licence rules: probe at most 400 requests per month; no full text; the journal whitelist is not widened;
KEGG, CADD, PanglaoDB and DepMap are never bundled or downloaded (the lexicon marks them `licence_note`, never ranked).

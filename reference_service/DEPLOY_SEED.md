# S0 evidence deployment — owner approval required

These steps have **not** been executed. The lane never operated on the running service or its volume. Curated seed remains empty. Deploy only after the owner approves the image/volume change and accepts or resolves the inherited `build_config.py --check` method-map mismatch documented in REF_SEED_REPORT.md.

## 1. Review and build a new image

On GT103, use the helper-committed lane revision (do not use the moving worktree as an approved release). Confirm `RELEASE_COMMIT` and the source bundle hash against the report. Re-run the importer when the module lanes deliver `references/options.md`; review any changed counts, mappings, exclusions and source commits, then re-run both test suites before approving the refreshed bundle. No scientific decisions are imported.

```bash
RELEASE_COMMIT='APPROVED_FULL_COMMIT'  # replace with the approved full commit before execution
SEED_RELEASE=/home/<user>/omic-sol61/ref_seed/approved-$RELEASE_COMMIT
SEED_TAG=omicstat-reference:20261001-s0-$RELEASE_COMMIT
mkdir -p "$SEED_RELEASE"
git -C /home/<user>/omic-ref-seed archive "$RELEASE_COMMIT" reference_service | tar -x -C "$SEED_RELEASE"
python3 "$SEED_RELEASE/reference_service/fork_status.py"
python3 "$SEED_RELEASE/reference_service/stage_build.py" --out "$SEED_RELEASE/context" --commit "$RELEASE_COMMIT"
docker build -t "$SEED_TAG" "$SEED_RELEASE/context"
```

No reuse of the old image tag. `app/s0_evidence/catalog.json` and `app/s0_loader.py` are carried by the staged image; the bundle is **not automatically loaded at worker startup**. Keep the approved compose file and old image tag for rollback. Do not invoke or change `deploy_gt103.sh` or reset the runtime.

## 2. Quiesce, back up, and load

The following production operations require owner approval; they are outside this lane's authorization. Confirm the deployment paths with the owner's records before running. Stop only this compose service to obtain a consistent backup of all stores and worker state. Save the old compose configuration and image identity. Never operate on medstat-reference.

```bash
SEED_OPS=/home/<user>/omic-sol61/ref_seed/deploy-$RELEASE_COMMIT
SEED_DATA=/home/<user>/omic-infra-reference/runtime/data
SEED_COMPOSE=/home/<user>/omic-infra-reference/release/compose.yaml
mkdir -p "$SEED_OPS"
cp "$SEED_COMPOSE" "$SEED_OPS/compose.before.yaml"
docker inspect --format '{{.Config.Image}} {{.Image}}' omicstat-reference > "$SEED_OPS/image.before.txt"
docker compose -f "$SEED_COMPOSE" stop omicstat-reference
tar -cpf "$SEED_OPS/data.before.tar" -C "$SEED_DATA" .
sha256sum "$SEED_OPS/data.before.tar" > "$SEED_OPS/data.before.tar.sha256"
docker run --rm --network none --user "$(id -u):$(id -g)" --read-only \
  -v "$SEED_DATA":/data -w /app "$SEED_TAG" \
  python /app/s0_loader.py --bundle /app/s0_evidence/catalog.json --data-dir /data
```

The loader changes only import-owned `S0-*` supplement/candidate rows and curation version/hash. It preserves unrelated records and supplement demotions; it adds no seed papers, usages or decisions. Repeating the same bundle returns `unchanged`. A failed transaction rolls back both SQLite stores; keep the backup regardless. If an import identity moves out of its column it is demoted/excluded. Six distinct PMIDs currently have explicitly pending corpus metadata; review these gaps before relying on them.

## 3. Verify offline, switch image, verify service

Before restarting the worker, run against the actual loaded volume, using the new image (the tmpfs is required: with a read-only root SQLite has no temp space for the supplement sort and fails with `disk I/O error`):

```bash
docker run --rm --network none --user "$(id -u):$(id -g)" --read-only \
  --tmpfs /tmp:rw,noexec,nosuid,size=33554432,mode=1777 \
  -e OMICSTAT_REFERENCE_DATA=/data -v "$SEED_DATA":/data -w /app "$SEED_TAG" python -c '
import json, sqlite3
from pathlib import Path
import service
b=json.loads(Path("s0_evidence/catalog.json").read_text())
assert service.core().status()["counts"] == {"papers":0,"usages":0,"decisions":0}
for m,s in b["counts"].items():
 r=service.search(module=m,limit=1)
 assert r["results"] == []
 print(m, "bundle usages", s[s["column"]], "search total including pre-existing records", r[s["column"]]["total"])
with sqlite3.connect("/data/reference.sqlite") as db:
 for u in b["usages"]:
  if u["column"]=="reviewed_supplement":
   row=db.execute("SELECT status FROM reviewed_supplement WHERE supplement_id=?",(u["usage_id"],)).fetchone()
   assert row and row[0] in ("active","demoted")
   if row[0]=="demoted": print("OWNER MUST REVIEW DEMOTION",u["usage_id"])
with sqlite3.connect("/data/harvest.sqlite") as db:
 for u in b["usages"]:
  if u["column"]=="discovery":
   assert db.execute("SELECT status FROM candidates WHERE candidate_id=?",(u["usage_id"],)).fetchone()==("screened",)
c={k:([] if v=="list_or_not_applicable" else "owner-specified study context") for k,v in service.core()._common_required().items()}
for m in ("deseq2-wald","seurat-cluster"):
 a=service.invoke(service.core().advise,m,c)
 assert a["parameter_options"] and not a["execution_authorized"] and not a["automatic_parameter_application"]
 assert all(o["column"]=="reviewed_supplement" and o["citations"] for o in a["parameter_options"])
for m,s in b["counts"].items():
 if s["column"]=="discovery": assert service.core().advise(m,c)["parameter_options"]==[]
print(json.dumps(service.status(),ensure_ascii=False))'
```

Compare exact imported active counts with bundle counts and list every pre-existing demotion; no unexplained count difference is acceptable. The shown synthetic context is an interface check, not a real study recommendation. Advice returns an initial page of at most three supplement usages, with total/returned counts; search/get retrieves the rest. Search columns must remain separate, and `no_curated_evidence_yet` must remain true.

Edit only the owner-approved production compose `image:` to `$SEED_TAG` (leave other invariants unchanged), then:

```bash
docker compose -f "$SEED_COMPOSE" up -d --no-build omicstat-reference
docker inspect --format '{{.Config.Image}} {{.State.Health.Status}}' omicstat-reference
docker exec -i omicstat-reference python /app/cli.py status
```

Confirm the new image, healthy worker, unchanged empty-seed hash, expected S0 bundle hash, and perform MCP `reference_search` and `reference_advise` for the two modules above through the owner's existing client. Keep logs and the backup.

## 4. Roll back

After owner authorization, quiesce the same service, verify the backup checksum, move the failed data directory aside (retain it for investigation), restore the stopped snapshot, and restore the old compose/image. This rolls back post-backup worker/curation state as well as the S0 import.

```bash
docker compose -f "$SEED_COMPOSE" stop omicstat-reference
sha256sum -c "$SEED_OPS/data.before.tar.sha256"
mv "$SEED_DATA" "$SEED_DATA.failed-$RELEASE_COMMIT"
mkdir -p "$SEED_DATA"
tar -xpf "$SEED_OPS/data.before.tar" -C "$SEED_DATA"
cp "$SEED_OPS/compose.before.yaml" "$SEED_COMPOSE"
docker compose -f "$SEED_COMPOSE" up -d --no-build omicstat-reference
docker inspect --format '{{.Config.Image}} {{.State.Health.Status}}' omicstat-reference
docker exec -i omicstat-reference python /app/cli.py status
```

Retain both images, the failed volume, backup and operation logs. Do not remove/prune images or containers.

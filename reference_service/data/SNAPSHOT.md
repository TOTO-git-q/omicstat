# Reference companion data snapshot (2026-10-09)

A read-only, consistent copy (SQLite backup API, then `VACUUM`) of the live data directory of the deployed reference companion, taken from image `omicstat-reference:20261009-keyparam-94d280b28e43` (source commit `d0a0aea`).

| File | sha256 | Content |
|---|---|---|
| `reference.sqlite` | `61a6d225af3071890d6a732eb9de141db75ac6dc8ae3c0e404b6cf51714b3273` | the **reviewed supplement**: 958 usage records from the S0 evidence of all 38 modules (M1/M2 verified in S0; lane A and lane B redone after independent verification; the five scverse modules, maftools and immunedeconv re-extracted on 2026-10-09 for their key parameters over the full corpus with every snippet verbatim-checked), each with the reported parameters, the verbatim Methods snippet and section, the PubMed id and the extraction provenance (branch, commit, file sha256); curation state and metadata. The curated seed table (`records`) is empty by design. |
| `harvest.sqlite` | `fd5b621bd79630321e1468a1b80101f908250152b39847eb06ac0cdeffe207d5` | the **unreviewed discovery** column: the daily harvester's own finds (70 screened, 33 metadata-only), 194 superseded S0 candidates kept with status `excluded` (never searched, advised or promotable), 234 screened-out records, the daily run ledger, identity aliases, and the harvester's method-map cursor. |

The same evidence is also shipped as a deterministic bundle, `reference_service/app/s0_evidence/catalog.json` (753 papers, 958 usages, all reviewed), which `app/s0_loader.py` loads into an empty or existing data directory; the importer that builds it is `reference_service/import_s0_evidence.py`. The databases here add what only the running service has: the harvester's state and its discovery candidates.

## Using it

Copy both files into the service's data directory (the volume mounted at `/data`, see `compose.yaml`) while the service is stopped, then start it. To rebuild from the bundle instead, start with an empty data directory and run

```bash
docker run --rm --network none -v <data dir>:/data <image> python /app/s0_loader.py --bundle /app/s0_evidence/catalog.json --data-dir /data
```

## Boundaries

- Every record is an observation of what a published study reported, not a default or a recommendation; `reference_advise` returns parameter options only from the reviewed column and marks them `automatic_parameter_application: false`.
- Snippets are short verbatim quotations from open-access Methods sections; full texts are not included.
- No credentials, API keys, host names or personal data are stored in either file (scanned before release).

## Operator note: method-map changes

The harvester stores the method map's hash with its cursor. When the method map changes (for example module statuses at installation), the next daily run stops with `method_map_changed` until an operator reconciles the cursor. On 2026-10-04 the order of the 38 modules was unchanged, so the stored hash was updated and the cursor kept (`muscat-pseudobulk`) after a `cli.py backup`. A dedicated CLI command for this does not exist yet.

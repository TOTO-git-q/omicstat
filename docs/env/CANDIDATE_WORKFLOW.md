# Candidate environments and offline reference data

Owner section 0 is binding. Environment promotion, deployment, golden writes
and sealing remain frozen. All new scientific modules remain candidates.
`env/owner_decisions.json` is the machine-readable copy of that decision.

## Prepare, resolve, build

R candidates live in `env/candidates/`, Python candidates in
`env/py/candidates/`. Every candidate records one lane, immutable parent image
ID, a fresh candidate tag, additive package set and target layer/version.
The ten checked-in plans cover L9–L15 and py-L2–L4. Only the L9 model source
lock is resolved from the verified go-live snapshot. No checked-in plan is a
claim that a new image was built here. Seurat spatial currently needs no new
known R package, so L15 remains an empty, unresolved plan rather than adding
an unrelated dependency.

1. On the authorized build machine, resolve the parent's exact Docker ID.
   Downstream candidates need the actual parent inventory, not guessed pins.
2. For R, put exact, reviewed package/version/HTTPS archive records in
   `manifest.sources`. Include all missing dependencies, never inherited
   packages. Use the pinned CRAN snapshot/Bioconductor release; do not take
   latest releases. For Python, the candidate `pyproject.toml` extends the
   parent's roots. The resolver preserves inherited lock identities and
   hashes and uses the fixed `exclude_newer` cutoff.
3. `python3 tools/env/resolve_sources.py <candidate> --download`
   (`--lock-python` additionally for Python). The explicit download is a
   build-time action. Cached resolution works without `--download`.
   Archive metadata, exact versions, hashes and dependency install order are
   recorded. Python resolves compatible locked Linux CPython wheels; no
   silent source build or dependency upgrade is allowed.
4. `python3 tools/env/build_candidate.py <candidate> --check`
   reports unresolved sources, native prerequisites and parent identities.
   A planned or missing-source candidate returns nonzero. `--plan-only` has
   the same read-only readiness semantics; it does not report a build pass.
5. Authorized exec runs `--build`. The image build is `--network=none` and
   `--pull=false`, and refuses an existing candidate tag. Each offline
   installer refuses inherited package replacement. Parent image ID, layer
   prefix, every inherited inventory field, and the exact set of additions
   are checked. Real inventories/session data and `candidate_report.json`
   are exported only after a real Docker run. A rejected build may leave its
   candidate tag; inspect it and choose a new reviewed tag, never overwrite.

JAGS and other native prerequisites must be separately resolved and verified
in the parent image. `system_requirements_verified` is an exec evidence
assertion, not a switch to skip installation. Record the check output in the
candidate evidence. Do not download native libraries during offline builds.
Every >4 GiB layer growth is flagged; no squash/repack breaks the lineage.

## Promotion is currently a read-only proposal

`python3 tools/env/promote.py <candidate> --dry-run` requires real successful
build evidence and prepares the exact metadata diff, preimage hashes, layer
append, affected modules, a real NEWS scan (missing NEWS remains explicit),
SUITE section and history destination. Python includes its actual uv lock,
resolver input and exported hash requirements. No canonical file changes.
`--apply` immediately refuses under the current owner decision. It is not an
acceptance or deployment command. Future explicitly authorized application
rechecks evidence and file preimages, refuses existing tags, verifies the
candidate ID, backs up metadata, tags the canonical image and archives the
candidate. If an apply fails after tagging, the error reports this explicitly
for inspection; it never claims zero writes or silently retries.

Bootstrap build scripts refuse to rebuild an appended lineage from an old
recipe. Reconstruct a fresh candidate from archived sources after review.
The environment consistency test checks the original recipe prefix and the
ordered archived additive layers.

## Reference registry v2

`env/refdata_registry.json` preserves legacy fields for existing readers and
adds structured licence, redistribution, consumers, fetch recipe and payload
metadata. Unknown versions/hashes/terms are null and `pending`, never a ready
asset. `refdata.v2.schema.json` validates the v2 document. `--metadata-only`
checks structural contracts; it is explicitly different from payload
acceptance. `python3 tools/refdata.py --check --payload-root <root>` verifies
file/tree hashes offline, returns nonzero for unresolved entries, and rejects
path escapes or symlink trees. No fetching or deployment is performed.

Restricted/custom terms require user-supplied data or an explicit internal-use
cache declaration. Bundling requires verified allowlisted terms. KEGG remains
excluded. Owner-required DoRothEA/CollecTRI/PROGENy/OmniPath resources remain
`user_supplied`, irrespective of a blanket upstream licence inference.
New module declarations must name input and `--…-provenance` flags. Runtime
R `os_user_refdata()` and Python `ospy.refdata.user_supplied()` check resource
ID, HTTPS source, explicit version/licence/permitted use and the actual file
SHA before parsing. They do not execute or deserialize models. A provenance
statement records the user's terms; it does not confer redistribution rights.

## Local tests

- `python3 tools/test_env_candidates.py`: invariant tests; Docker is mocked.
- `python3 tools/test_candidate_installers.py`: actual offline synthetic wheel
  install in a disposable virtualenv; set `OMICSTAT_TEST_RSCRIPT` and an
  isolated `R_LIBS_USER` for the actual synthetic R source install.
- `Rscript skills/_shared/tests/test_refdata.R`: runtime provenance gate.
- `python3 env/test_env_config.py`, `python3 env/py/test_py_env_config.py`,
  `python3 tools/lint_contracts.py --check`.

Synthetic package installs verify plumbing, not scientific module results or
production R/Bioconductor compatibility. Real image builds and module
acceptance belong to exec and remain outstanding.

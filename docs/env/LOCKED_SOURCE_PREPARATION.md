# Locked model source preparation

This PR binds `image_candidate` to `env/candidates/20261016-models`. Its
`sources.lock.json` contains all 11 additive archive identities, including drc:
package, exact version, HTTPS URL, flat filename and SHA256. Each applicable
request lists the exact lock digest and complete required package set. This is
not proof that the 11 archives are already cached or that the image was built.

1. Use the request's `source_preparation[].check` command first. It is read-only
   and offline. Missing archives are blocked. The lock/manifest never change.
2. Only on an authorized source-preparation machine, use the separately listed
   `authorized_download` command. It downloads only pinned bytes, validates
   hashes and source identities, and verifies required dependency versions and
   order against the bound parent inventory. It never installs or invokes R,
   Docker, promotion or a scientific engine. The option is not automatic and
   does not override any prior rejected network action.
3. Alternatively `--source-cache /authorized/cache` copies matching preobtained
   archives. Different bytes with the same package/version are rejected. It
   cannot replace corrupt existing cache files. No archive is bundled in Git.
4. Retain the preparation JSON report, then use the declared offline candidate
   build command. Builds now enforce source/dependency checks before Docker.
   The parent tag/ID and inherited inventory/layers still must match. There is
   no online fallback, package upgrade, tag replacement or image promotion.
5. Run the exact PR request after the candidate really builds, retaining its
   immutable image ID and results. Missing native anchors or resources remain
   blocked. Golden/seal stay deferred_by_owner and visual review stays null.

The cloud attempt to read the locked Posit drc archive returned HTTP CONNECT
403. An existing CRAN drc 3.0-1 archive has different bytes and was not substituted.
No source hash was guessed or relaxed. Current offline readiness therefore
reports all 11 missing pinned archives. Source preparation remains an exec-side
prerequisite, not a claimed successful image build.

`python3 tools/test_locked_source_preparation.py` uses only project-invented
archives and mocked forbidden network/Docker boundaries. It covers missing
cache, exact hashes, identity, dependency closure/order/versions, binary-archive
refusal, path/HTTPS guards, immutable locks and enforced build readiness.

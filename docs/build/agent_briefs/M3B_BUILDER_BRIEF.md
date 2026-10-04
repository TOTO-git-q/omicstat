# M3b builder supplement — chain state (S5 documentation sync)

This repository supplement records the current contract for the six neutral
single-cell back ends. It supplements the original lane brief
`~/omic-tasks/sol61_build_m3b.md` and `BUILDER_BRIEF.md`; historical failures and
owner questions stay in their build/S3 reports.

`skills/_shared/scripts/convert.R::os_sc_chain_state(h)` reads an upstream
`read_handoff()` result. It returns `list(front_end_ecosystem = eco)`, taking
`h$ecosystem`, or `h$state$front_end_ecosystem` when the upstream is neutral.
Pass this state onward through `write_handoff(state = ...)` without replacing
other upstream state. A neutral back end records `backend_ecosystem: neutral`
in provenance and retains the original front-end label across multiple back ends.

Coordinator decision 4 is reversible by the owner: Python→R crossing emits
informational `OS_ECOSYSTEM_CROSSING`, without refusal or a new label.
`OS_ECOSYSTEM_MIXED` still refuses a front-end chain that switches ecosystems.
Conversion requires named assay/layer roles and preserves cells, genes,
clusters and existing embeddings; a back end does not re-cluster/re-embed.

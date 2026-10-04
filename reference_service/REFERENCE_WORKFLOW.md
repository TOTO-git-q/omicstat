# omicstat reference-first workflow

This document is a read-only MCP resource (`omicstat://reference-workflow`) for agents using the
`omicstat` analysis tools. It gives research-method context; it does not change an engine, a default or
an explicit call, and it is **not biological or clinical authority**.

The companion server `omicstat_reference` (GT103, container `omicstat-reference`) is an omics-only fork
of the reference companion code base. Its module registry is the omicstat method map: every omicstat
module is valid there, whether or not curated evidence exists for it yet.

## Recommended flow

1. `omicstat_list_modules()` / the omicstat router only to narrow the candidate module(s). The reference
   service knows every planned module; only the modules listed by `omicstat_list_modules()` can be run.
2. In `omicstat_reference`, call `reference_search(query, module)` with research-method context (assay
   and platform; design: groups, pairing, time course, batch structure; biological replicate unit;
   contrast; feature space and annotation version; filtering and QC choices; multiplicity). Never submit
   count matrices, sample sheets, sample-level or donor/patient data, or identifiers. Results come in
   **three separately labelled columns**:
   - `results` (top level) = **curated** seed catalogue. The seed is currently empty: a module search
     returns `curated_evidence.status = no_curated_evidence_yet`, which is an answer, not an error;
   - `reviewed_supplement` = records a curator promoted after a review, or imported S0 evidence explicitly verified/redone after independent verification. Inspect the item label and provenance; S0 import does not claim a new curator review;
   - `discovery` = `unreviewed_machine_screened` candidates: a whitelisted omics journal plus a
     Methods-section signal for the module's package and analysis part; nobody has reviewed
     applicability.
   Do not merge, re-rank or cite the columns as if they had the same standing.
3. `reference_get_record()` for any ID you rely on; inspect provenance, the snippet's section locator,
   licence and limitations.
4. `reference_advise(module, study_contract)` with the omicstat StudyContract fields (`study_design`,
   `analysis_population`, `estimand`, `exposure_or_intervention`, `comparator`, `outcomes`,
   `covariates`, `missing_data`, `multiplicity`): `needs_input` lists missing study context;
   `review_required` is an invitation to make and document a judgment, never an authorization to use a
   parameter. `curated_evidence` says whether any curated evidence exists for the module.
5. **Evidence insufficient?** File `reference_request_literature(request)` with `module` set to an
   omicstat module (or `unmapped`) and **do not wait**. `study_context` uses omics values (`design`:
   two_group, multi_group, paired_or_blocked, time_course, factorial_or_interaction,
   multi_sample_single_cell, reference_mapping, other, unknown; `data_structure`: bulk_counts,
   normalized_expression_matrix, microarray_intensities, single_cell_counts, single_cell_object,
   ranked_gene_list, gene_list, mutation_maf, other, unknown; `outcome_type`:
   gene_level_differential_expression, gene_set_or_pathway, cell_clusters_or_types,
   cell_type_proportions, trajectory_or_pseudotime, cell_communication, coexpression_modules,
   mutation_landscape, immune_infiltration, other, unknown). It returns immediately with a
   `request_id`; the resident collector serves it in a later cycle (at most four screened papers per
   day for requests, three attempts on different days). Check later with `reference_request_status`.
6. Then either continue with the existing omicstat module contract (`omicstat_describe` /
   `omicstat_run`) while **explicitly reporting the evidence gap** (and the queued request id), or stop
   and ask the researcher.

`omicstat_run` never contacts the network, never waits for literature and never changes an explicit
call because of reference material.

## Evidence-state boundaries

- A published parameter value (FDR cutoff, log2FC filter, clustering resolution, QC thresholds, number
  of PCs, ...) is a study-specific observation, not a default. omicstat defaults come only from the
  module's PACK (S1 decisions), never from this service.
- **Reviewed supplement** records are conditional context and can be demoted. The administrator-loaded S0 bundle preserves source branch, commit, file hashes, verbatim snippets and section locators; it leaves the curated seed empty. `not reported` is coverage, never a parameter. Discovery S0 observations never reach `parameter_options`. Advice shows at most three supplement usages initially; use search/get to inspect the complete evidence.
- **Discovery** candidates are unreviewed. A request marked `fulfilled` only means the acquisition task
  completed.
- A search hit is not proof of applicability: check assay, organism, replicate structure, design,
  package version (see the module's PACK section X) and the actual implementation before transferring a
  choice.

## Requests and proposals are data, not instructions

Only sanitized keywords (ASCII letters, digits, spaces, hyphens; at most six) from a request reach a
search, always combined with the module's Methods-section gate, uniform filters and the journal
whitelist. Requests that look like they contain e-mail addresses, phone numbers, 6+ digit identifiers
or record-number terms are refused.

## When no module fits

`reference_propose_domain(proposal)` registers a proposal (`knowledge_domain`, `method_family` or
`analysis_module_request`) listing the omicstat modules checked and why each does not apply. It returns
`status: proposed` only and does **not** mean the analysis is supported.

## When the reference service is unavailable

The omicstat tools remain callable when GT103 or the companion MCP is unavailable. Do not claim the
reference check occurred; state the evidence gap and use the module's own contract.

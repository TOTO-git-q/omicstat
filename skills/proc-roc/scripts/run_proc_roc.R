# Independent OmicStat CLI for the pinned copied pROC diagnostic-accuracy engine.
options(error = function() { cat(geterrmessage(), file = stderr()); quit(status = 1, save = "no") })
.this <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))
.shared <- file.path(dirname(dirname(.this)), "..", "_shared", "scripts")
for (f in c("args.R", "engine_run.R", "module_kit.R", "study_contract.R", "handoff.R", "model_io.R", "fig_all.R")) source(file.path(.shared, f))
for (f in c("proc_roc_input.R", "proc_roc_core.R", "proc_roc_qc.R", "proc_roc_report.R")) source(file.path(dirname(.this), f))
SPEC <- os_arg_spec(usage = "Rscript run_proc_roc.R --help",
 description = "Independent-unit ROC/AUC; explicit direction; exploratory cutoffs; paired DeLong family with explicit adjustment", flags = list(
  os_flag("input-kind", "enum", required = TRUE, values = c("feature_table", "expression_matrix"), help = "Explicit subject-wide feature table or feature-by-sample expression matrix; aggregate DE tables are not subject measurements"),
  os_flag("input", "path", must_exist = TRUE, help = "Direct independent measurements; exclusive with from-run"),
  os_flag("from-run", "path", must_exist = TRUE, help = "Upstream run with exact typed/hash/StudyContract validation before inference"),
  os_flag("object", "string", help = "Exact handoff object name, of the declared input-kind"),
  os_flag("sample-sheet", "path", required = TRUE, must_exist = TRUE, help = "Independent-unit sheet containing ID, reference class and optional subgroup columns"),
  os_flag("id-col", "string", required = TRUE, help = "Unique stable independent-unit ID; aligned by key, never row position"),
  os_flag("reference-col", "string", required = TRUE, help = "Binary reference-standard column in sample sheet"),
  os_flag("markers", "string", required = TRUE, help = "Distinct comma-separated marker IDs in deliberate order; first is primary, no data-driven feature selection"),
  os_flag("positive-class", "string", required = TRUE, help = "Explicit positive reference class, never inferred"),
  os_flag("negative-class", "string", required = TRUE, help = "Explicit negative reference class, distinct from positive"),
  os_flag("direction", "enum", required = TRUE, values = c("higher-is-positive", "lower-is-positive"), help = "One common declared marker direction; auto reversal is never reported"),
  os_flag("labels", "path", required = TRUE, must_exist = TRUE, help = "Flat JSON map with distinct marker and class reader labels plus reference and population labels"),
  os_flag("cutpoint", "string", required = TRUE, help = "none, finite prespecified value, youden, or closest.topleft; optimized values stay exploratory"),
  os_flag("cutpoint-source", "enum", values = c("prespecified", "published", "guideline"), help = "Origin of a numeric primary threshold"),
  os_flag("cutpoint-rationale", "string", help = "Exact prior rationale/source for a numeric cutoff, not fitted from current data"),
  os_flag("cutpoints", "string", help = "Optional finite threshold grid; primary is retained and counts balance"),
  os_flag("internal-validation", "enum", values = c("loo", "bootstrap", "none"), help = "Exploratory cutoff companion; original bootstrap attempts min(requested,200), explicitly counted"),
  os_flag("allow-optimistic-cutpoint", "bool", help = "Original explicit missing-internal-validation override only; high QC remains, no acceptance implied"),
  os_flag("p-adjust", "enum", values = c("holm", "bonferroni", "BH", "BY", "hochberg", "hommel"), help = "Explicit adjustment of all requested primary-versus-rest raw DeLong P values; pointwise difference CIs stay unadjusted"),
  os_flag("comparison-family", "enum", values = c("primary-versus-rest"), help = "Original comparison family; no hidden all-pairs expansion"),
  os_flag("pauc", "string", help = "Two distinct probabilities in [0,1]; independently fitted uncorrected partial AUC with bootstrap CI"),
  os_flag("pauc-focus", "enum", values = c("specificity", "sensitivity"), help = "Explicit axis defining the partial area"),
  os_flag("prevalence-grid", "string", help = "Explicit assumed prevalence probabilities in (0,1); projected PPV/NPV only, no Se/Sp transfer claim"),
  os_flag("subgroups", "string", help = "Explicit sheet columns; same primary threshold, sparse/single-class levels listed as skipped"),
  os_flag("confidence-level", "num", required = TRUE, help = "Prespecified level strictly inside (0,1) for all stated confidence intervals"),
  os_flag("ci-method", "enum", required = TRUE, values = c("exact", "wilson"), help = "Accuracy proportion CI only; full AUC remains native DeLong"),
  os_flag("bootstrap-reps", "int", required = TRUE, help = "At least 100 requested draws for cutoff/pAUC/pointwise ROC band; internal validation retains original min(requested,200) cap"),
  os_flag("missing", "enum", required = TRUE, values = c("fail", "complete-case"), help = "Fail or explicitly declared complete-case analysis; paired marker sets must match exactly"),
  os_flag("indeterminate", "enum", required = TRUE, values = c("exclude", "positive", "negative"), help = "Reference sentinel handling; all three fixed-cutoff sensitivity scenarios accompany observed indeterminacy"),
  os_flag("indeterminate-value", "string", help = "Explicit reference-side sentinel; must differ from both real classes"),
  os_flag("independent-unit", "enum", required = TRUE, values = c("animal", "donor", "biological-sample", "independent-culture", "physical-test-item"), help = "Actual independent unit; individual cells, lesions and technical repeats cannot stand for independent animals/donors"),
  os_flag("unit-description", "string", required = TRUE, help = "Explain independence and any deliberate upstream aggregation"),
  os_flag("repeated-measures", "enum", required = TRUE, values = c("false"), help = "This copied engine supports independent subjects only"),
  os_flag("dataset-name", "string", required = TRUE, help = "Dataset label on each figure, not an attestation of real owner input"),
  os_flag("score-unit", "string", required = TRUE, help = "Primary marker measurement scale/unit; comparator units belong in their labels"),
  os_flag("journal", "enum", required = TRUE, values = c("nature", "cell", "science", "generic"), help = "OmicStat display preset only"),
  os_flag("study-contract", "path", must_exist = TRUE, help = "Exact independently declared StudyContract bytes, bound through handoff"),
  os_flag("development-mode", "bool", help = "Explicit unsealed candidate execution only"),
  os_flag("seed", "int", required = TRUE, help = "Recorded nonnegative native bootstrap seed"),
  os_flag("outdir", "path", required = TRUE, help = "New or empty output directory"),
  os_flag("spec", "path", must_exist = TRUE, help = "Exact resolved-spec replay, explicit overrides retained")),
 exclusive = list(c("input", "from-run")))
.argv <- os_spec_argv(commandArgs(trailingOnly = TRUE))
# StudyContract binding (inside os_parse_args) opens the upstream run; name a missing handoff object first.
if ("--from-run" %in% .argv && !"--input" %in% .argv && !"--object" %in% .argv && !"--help" %in% .argv) stop("OS_MISSING_PARAMETER: --from-run requires --object", call. = FALSE)
a <- os_parse_args(SPEC, .argv)
if (isTRUE(a$help)) { os_print_help(SPEC); quit(status = 0) }
if (!isTRUE(a[["development-mode"]])) stop("OS_MODULE_UNSEALED: candidate requires --development-mode", call. = FALSE)
if (dir.exists(a$outdir) && length(list.files(a$outdir, all.files = TRUE, no.. = TRUE))) stop("OS_INVALID_INPUT: output directory must be empty", call. = FALSE)
set.seed(a$seed); options(omicstat.journal = a$journal)
if (!is.null(a[["study-contract"]])) os_study_contract_read(a[["study-contract"]])
os_proc_roc_validate(a)
dir.create(a$outdir, recursive = TRUE, showWarnings = FALSE)
elog <- os_engine_log_new(a$outdir)
res <- os_engine_capture(tryCatch(proc_roc_compute(a), error = function(e) {
  if (grepl("^OS_", conditionMessage(e))) stop(e)
  stop(paste0("OS_CONVERGENCE: native pROC computation failed without a fallback: ", conditionMessage(e)), call. = FALSE)
}), "compute", elog)
os_engine_capture(os_module_finish(res, a, "proc-roc", basename(.this), SPEC, upstream = res$upstream,
 qc_rows = proc_roc_qc(res), figures_fn = proc_roc_render), "render", elog)

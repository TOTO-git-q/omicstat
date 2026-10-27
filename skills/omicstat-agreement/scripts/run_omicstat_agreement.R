# Independent OmicStat candidate CLI around the pinned copied agreement methods.
options(error = function() { cat(geterrmessage(), file = stderr()); quit(status = 1, save = "no") })
.this <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))
.shared <- file.path(dirname(dirname(.this)), "..", "_shared", "scripts")
for (f in c("args.R", "engine_run.R", "module_kit.R", "study_contract.R", "handoff.R", "model_io.R", "fig_all.R"))
  source(file.path(.shared, f))
source(file.path(dirname(.this), "omicstat_agreement_core.R"))
source(file.path(dirname(.this), "omicstat_agreement_qc.R"))
source(file.path(dirname(.this), "omicstat_agreement_report.R"))
SPEC <- os_arg_spec(usage = "Rscript run_omicstat_agreement.R --help",
 description = "Explicit-design independent agreement analysis; no automatic estimator substitution", flags = list(
  os_flag("analysis", "enum", required = TRUE, values = c("kappa", "fleiss", "icc", "bland-altman"), help = "Explicit agreement chance/design model"),
  os_flag("input", "path", required = TRUE, must_exist = TRUE, help = "Complete input CSV; no silent deletion"),
  os_flag("labels", "path", required = TRUE, must_exist = TRUE, help = "Unique nonblank JSON/YAML/CSV reader-facing labels, including population and measurement"),
  os_flag("format", "enum", required = TRUE, values = c("wide", "long", "counts"), help = "Explicit input arrangement; ICC and Bland-Altman currently require wide"),
  os_flag("confidence-level", "num", required = TRUE, help = "Prespecified interval confidence level in (0,1); LoA population coverage stays 95%"),
  os_flag("missing", "enum", required = TRUE, values = c("fail"), help = "Missing ratings are fatal; complete-case deletion is never silent"),
  os_flag("independent-unit", "enum", required = TRUE, values = c("animal", "donor", "biological-sample", "independent-culture", "physical-test-item", "aggregate-unit"), help = "Actual independent unit; counts tables explicitly declare aggregate-unit"),
  os_flag("unit-description", "string", required = TRUE, help = "Explain independence and any deliberately performed upstream aggregation"),
  os_flag("repeated-measures", "enum", required = TRUE, values = c("false"), help = "Repeated/clustered measurements are unsupported by the copied independent-unit methods"),
  os_flag("outcome-unit", "string", required = TRUE, help = "Common measurement unit for continuous methods; dimensionless for categorical coefficients"),
  os_flag("dataset-name", "string", required = TRUE, help = "Dataset label printed on every figure; does not attest real owner data"),
  os_flag("id-col", "string", help = "Stable independent-unit ID column"),
  os_flag("rater-cols", "string", help = "Distinct comma-separated rater/method column names in deliberate order"),
  os_flag("rater-col", "string", help = "Long-format rater-ID column"),
  os_flag("rating-col", "string", help = "Long-format observed category column"),
  os_flag("count-col", "string", help = "Counts-table non-negative integer frequency column; every cell including zero is explicit"),
  os_flag("scale", "enum", values = c("nominal", "ordinal"), help = "Category scale; ordinal order must be declared"),
  os_flag("levels", "string", help = "Complete comma-separated ordered categories; never inferred for ordinal data"),
  os_flag("weights", "enum", values = c("none", "both"), help = "Nominal/Fleiss none; ordinal Cohen both retains linear primary and quadratic sensitivity"),
  os_flag("ci-method", "enum", values = c("analytic", "bootstrap"), help = "Cohen analytic or subject bootstrap; Fleiss requires subject bootstrap"),
  os_flag("bootstrap-reps", "int", help = "At least 100 subject bootstrap draws; recorded even when analytic was explicitly selected"),
  os_flag("interpretation", "enum", values = c("none", "landis-koch", "mchugh"), help = "Descriptive convention, never a universal adequacy threshold"),
  os_flag("paradox-agreement", "num", help = "Optional Cohen-kappa warning threshold in [0,1]; original source convention 0.8 is retained when absent; changes warning only"),
  os_flag("paradox-kappa", "num", help = "Optional Cohen-kappa warning threshold in [0,1]; original source convention 0.6 is retained when absent; changes warning only"),
  os_flag("paradox-prevalence-index", "num", help = "Optional Cohen-kappa warning threshold in [0,1]; original source convention 0.5 is retained when absent; changes warning only"),
  os_flag("paradox-bias-index", "num", help = "Optional Cohen-kappa warning threshold in [0,1]; original source convention 0.2 is retained when absent; changes warning only"),
  os_flag("marginal-divergence", "num", help = "Optional Cohen-kappa warning threshold in [0,1]; original source convention 0.2 is retained when absent; changes warning only"),
  os_flag("icc-model", "enum", values = c("oneway", "twoway"), help = "ICC model explicitly chosen from design, never inferred"),
  os_flag("icc-definition", "enum", values = c("agreement", "consistency"), help = "Absolute agreement versus consistency are different estimands"),
  os_flag("icc-unit", "enum", values = c("single", "average"), help = "Single rater or mean of raters; changes the estimand"),
  os_flag("rater-population", "enum", values = c("random", "fixed"), help = "Random rater population or the fixed raters studied"),
  os_flag("same-raters", "enum", values = c("true", "false"), help = "Whether every independent subject has the same raters"),
  os_flag("icc-fixed-agreement-rationale", "string", help = "Why the fixed set itself is the target of absolute agreement"),
  os_flag("adequacy-threshold", "num", help = "Optional independently prespecified adequacy threshold in [0,1]"),
  os_flag("adequacy-rationale", "string", help = "Source and purpose of an optional prespecified adequacy threshold"),
  os_flag("method-a-col", "string", help = "Numeric method A column, in the same declared unit as B"),
  os_flag("method-b-col", "string", help = "Numeric method B column, distinct from A"),
  os_flag("difference", "enum", values = c("a-minus-b", "b-minus-a"), help = "Signed difference orientation; has no default"),
  os_flag("acceptability-limit-lower", "num", help = "Optional prespecified lower acceptable difference, supplied with upper"),
  os_flag("acceptability-limit-upper", "num", help = "Optional prespecified upper acceptable difference, supplied with lower"),
  os_flag("acceptability-rationale", "string", help = "Concrete source and purpose of prespecified acceptability limits"),
  os_flag("journal", "enum", required = TRUE, values = c("nature", "cell", "science", "generic"), help = "OmicStat display preset only"),
  os_flag("study-contract", "path", must_exist = TRUE, help = "Exact validated StudyContract bytes"),
  os_flag("development-mode", "bool", help = "Explicit candidate-only execution"),
  os_flag("seed", "int", required = TRUE, help = "Recorded reproducibility seed for native subject bootstrap"),
  os_flag("outdir", "path", required = TRUE, help = "New or empty output directory"),
  os_flag("spec", "path", must_exist = TRUE, help = "Exact resolved-spec replay")))
a <- os_parse_args(SPEC, os_spec_argv(commandArgs(trailingOnly = TRUE)))
if (isTRUE(a$help)) { os_print_help(SPEC); quit(status = 0) }
if (!isTRUE(a[["development-mode"]])) stop("OS_MODULE_UNSEALED: candidate requires --development-mode", call. = FALSE)
if (dir.exists(a$outdir) && length(list.files(a$outdir, all.files = TRUE, no.. = TRUE)))
  stop("OS_INVALID_INPUT: output directory must be empty", call. = FALSE)
set.seed(a$seed); options(omicstat.journal = a$journal)
os_agreement_validate(a)
if (!is.null(a[["study-contract"]])) os_study_contract_read(a[["study-contract"]])
dir.create(a$outdir, recursive = TRUE, showWarnings = FALSE)
elog <- os_engine_log_new(a$outdir)
res <- os_engine_capture(tryCatch(omicstat_agreement_compute(a), error = function(e) {
  if (grepl("^OS_", conditionMessage(e))) stop(e)
  stop(paste0("OS_CONVERGENCE: native agreement computation failed: ", conditionMessage(e)), call. = FALSE)
}), "compute", elog)
os_engine_capture(os_module_finish(res, a, "omicstat-agreement", basename(.this), SPEC,
 qc_rows = omicstat_agreement_qc(res), figures_fn = omicstat_agreement_render), "render", elog)

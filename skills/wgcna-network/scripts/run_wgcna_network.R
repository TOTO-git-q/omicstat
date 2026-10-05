# WGCNA network entry: input, computation, rendering, QC, provenance.
options(error = function() { cat(geterrmessage(), file = stderr()); quit(status = 1, save = "no") })
.this <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))
.module_dir <- dirname(dirname(.this)); .suite <- dirname(dirname(.module_dir))
.shared <- file.path(.suite, "skills", "_shared", "scripts")
for (f in c("args.R", "engine_run.R", "module_kit.R", "effect_table.R", "handoff.R", "fig_all.R", "m4_io.R", "fig_mod_m4.R")) source(file.path(.shared, f))
for (f in c("wgcna_network_core.R", "wgcna_network_report.R", "wgcna_network_qc.R")) source(file.path(dirname(.this), f))
SPEC <- os_arg_spec(usage = "Rscript run_wgcna_network.R --input <csv>|--from-run <dir> --power <number> --input-scale <scale> --samples <csv> --traits <columns> --outdir <dir>",
 description = "Exploratory WGCNA modules and Pearson trait associations.", flags = list(
 os_flag("gsg-weights","string",help="Native goodSamplesGenes weights; JSON value or RDS wrapper; omitted uses locked value"),
 os_flag("gsg-min-fraction","string",help="Native goodSamplesGenes minFraction; JSON value or RDS wrapper; omitted uses locked value"),
 os_flag("gsg-min-nsamples","string",help="Native goodSamplesGenes minNSamples; JSON value or RDS wrapper; omitted uses locked value"),
 os_flag("gsg-min-ngenes","string",help="Native goodSamplesGenes minNGenes; JSON value or RDS wrapper; omitted uses locked value"),
 os_flag("gsg-tol","string",help="Native goodSamplesGenes tol; JSON value or RDS wrapper; omitted uses locked value"),
 os_flag("gsg-min-relative-weight","string",help="Native goodSamplesGenes minRelativeWeight; JSON value or RDS wrapper; omitted uses locked value"),
 os_flag("soft-weights","string",help="Native pickSoftThreshold weights; JSON value or RDS wrapper; omitted uses locked value"),
 os_flag("soft-rsquared-cut","string",help="Native pickSoftThreshold RsquaredCut; JSON value or RDS wrapper; omitted uses locked value"),
 os_flag("soft-remove-first","string",help="Native pickSoftThreshold removeFirst; JSON value or RDS wrapper; omitted uses locked value"),
 os_flag("soft-n-breaks","string",help="Native pickSoftThreshold nBreaks; JSON value or RDS wrapper; omitted uses locked value"),
 os_flag("soft-cor-fnc","string",help="Native pickSoftThreshold corFnc; package::function; omitted uses locked value"),
 os_flag("soft-cor-options","string",help="Native pickSoftThreshold corOptions; JSON value or RDS wrapper; omitted uses locked value"),
 os_flag("network-cor-type","string",help="Native blockwiseModules corType; JSON value or RDS wrapper; omitted uses locked value"),
 os_flag("network-max-poutliers","string",help="Native blockwiseModules maxPOutliers; JSON value or RDS wrapper; omitted uses locked value"),
 os_flag("network-quick-cor","string",help="Native blockwiseModules quickCor; JSON value or RDS wrapper; omitted uses locked value"),
 os_flag("network-pearson-fallback","string",help="Native blockwiseModules pearsonFallback; JSON value or RDS wrapper; omitted uses locked value"),
 os_flag("network-cosine-correlation","string",help="Native blockwiseModules cosineCorrelation; JSON value or RDS wrapper; omitted uses locked value"),
 os_flag("network-tomdenom","string",help="Native blockwiseModules TOMDenom; JSON value or RDS wrapper; omitted uses locked value"),
 os_flag("network-replace-missing-adjacencies","string",help="Native blockwiseModules replaceMissingAdjacencies; JSON value or RDS wrapper; omitted uses locked value"),
 os_flag("network-suppress-tomfor-zero-adjacencies","string",help="Native blockwiseModules suppressTOMForZeroAdjacencies; JSON value or RDS wrapper; omitted uses locked value"),
 os_flag("network-suppress-negative-tom","string",help="Native blockwiseModules suppressNegativeTOM; JSON value or RDS wrapper; omitted uses locked value"),
 os_flag("network-detect-cut-height","string",help="Native blockwiseModules detectCutHeight; JSON value or RDS wrapper; omitted uses locked value"),
 os_flag("network-pam-stage","string",help="Native blockwiseModules pamStage; JSON value or RDS wrapper; omitted uses locked value"),
 os_flag("network-min-core-kme","string",help="Native blockwiseModules minCoreKME; JSON value or RDS wrapper; omitted uses locked value"),
 os_flag("network-min-core-kmesize","string",help="Native blockwiseModules minCoreKMESize; JSON value or RDS wrapper; omitted uses locked value"),
 os_flag("network-min-kmeto-stay","string",help="Native blockwiseModules minKMEtoStay; JSON value or RDS wrapper; omitted uses locked value"),
 os_flag("network-impute","string",help="Native blockwiseModules impute; JSON value or RDS wrapper; omitted uses locked value"),
 os_flag("eigengene-impute","string",help="Native moduleEigengenes impute; JSON value or RDS wrapper; omitted uses locked value"),
 os_flag("eigengene-n-pc","string",help="Native moduleEigengenes nPC; JSON value or RDS wrapper; omitted uses locked value"),
 os_flag("eigengene-align","string",help="Native moduleEigengenes align; JSON value or RDS wrapper; omitted uses locked value"),
 os_flag("eigengene-exclude-grey","string",help="Native moduleEigengenes excludeGrey; JSON value or RDS wrapper; omitted uses locked value"),
 os_flag("eigengene-sub-hubs","string",help="Native moduleEigengenes subHubs; JSON value or RDS wrapper; omitted uses locked value"),
 os_flag("eigengene-scale","string",help="Native moduleEigengenes scale; JSON value or RDS wrapper; omitted uses locked value"),
 os_flag("cor-use","string",help="Native cor use; JSON value or RDS wrapper; omitted uses locked value"),
 os_flag("cor-method","string",help="Native cor method; JSON value or RDS wrapper; omitted uses locked value"),
 os_flag("cor-weights-x","string",help="Native cor weights.x; JSON value or RDS wrapper; omitted uses locked value"),
 os_flag("cor-weights-y","string",help="Native cor weights.y; JSON value or RDS wrapper; omitted uses locked value"),
 os_flag("cor-cosine","string",help="Native cor cosine; JSON value or RDS wrapper; omitted uses locked value"),
 os_flag("cor-cosine-x","string",help="Native cor cosineX; JSON value or RDS wrapper; omitted uses locked value"),
 os_flag("cor-cosine-y","string",help="Native cor cosineY; JSON value or RDS wrapper; omitted uses locked value"),
 os_flag("cor-quick","string",help="Native cor quick; JSON value or RDS wrapper; omitted uses locked value"),
 os_flag("trait-p-adjust","enum",default="BH",values=stats::p.adjust.methods,help="Added exploratory trait-summary adjustment across all module-trait tests; native P retained"),
 os_flag("input", "path", must_exist = TRUE, help = "feature-by-sample expression CSV"),
 os_flag("from-run", "path", must_exist = TRUE, help = "verified expression hand-off"),
 os_flag("upstream-object", "string", default = "expression_matrix", help = "upstream expression object"),
 os_flag("outdir", "path", required = TRUE, help = "output directory"),
 os_flag("spec", "path", must_exist = TRUE, help = "resolved spec replay"),
 os_flag("input-scale", "enum", required = TRUE, values = c("normalized_array", "vst", "logcpm", "log2_tpm"), help = "declared normalized continuous input scale"),
 os_flag("preprocessing", "string", required = TRUE, help = "normalization and gene filtering audit"),
 os_flag("outlier-rule", "string", required = TRUE, help = "prior sample exclusion rule or explicit none-reviewed"),
 os_flag("samples", "path", required = TRUE, must_exist = TRUE, help = "sample and numeric trait table"),
 os_flag("traits", "string", required = TRUE, help = "comma separated numeric traits"),
 os_flag("power", "num", required = TRUE, range = c(0.01, 100), help = "scientifically selected soft power; tutorial example 6"),
 os_flag("power-reason", "string", required = TRUE, help = "power selection rationale"),
 os_flag("powers", "string", default = "1,2,3,4,5,6,7,8,9,10,12,14,16,18,20", help = "diagnostic power vector"),
 os_flag("network-type", "enum", default = "unsigned", values = c("unsigned", "signed", "signed hybrid"), help = "network adjacency type"),
 os_flag("tom-type", "enum", default = "signed", values = c("signed", "unsigned"), help = "TOM type; tutorial example unsigned"),
 os_flag("min-module-size", "int", range = c(2, 100000), help = "minimum genes per module; absent resolves locked min(20,nGenes/2); tutorial example 30"),
 os_flag("deep-split", "int", default = 2L, range = c(0, 4), help = "dynamic tree split sensitivity"),
 os_flag("merge-height", "num", default = 0.15, range = c(0, 1), help = "eigengene merge distance; tutorial example 0.25"),
 os_flag("max-block-size", "int", default = 5000L, range = c(40, 100000), help = "network block size"),
 os_flag("pam-respects-dendro", "enum", default = "true", values = c("true", "false"), help = "PAM dendrogram constraint; tutorial false"),
 os_flag("reassign-threshold", "num", default = 0.000001, range = c(0, 1), help = "module reassignment P ratio; tutorial 0"),
 os_flag("seed", "int", default = 20260925L, help = "network RNG seed"),
 os_flag("journal", "enum", default = "nature", values = c("nature", "cell", "science", "generic"), help = "figure preset")), exclusive = list(c("input", "from-run")))
a <- os_parse_args(SPEC, os_spec_argv(commandArgs(trailingOnly = TRUE)))
if (isTRUE(a$help)) { os_print_help(SPEC); quit(status = 0) }
options(omicstat.journal = a$journal); set.seed(a$seed)
dir.create(a$outdir, recursive = TRUE, showWarnings = FALSE); elog <- os_engine_log_new(a$outdir)
inp <- os_engine_capture(os_m4_input(a, allow_missing = TRUE), "input", elog)
st <- os_engine_capture(os_align_samples(inp$mat, os_read_sample_table(a$samples, "sample"), "sample"), "sample alignment", elog)
traits <- strsplit(a$traits, ",", fixed = TRUE)[[1]]
if (!all(traits %in% names(st)) || anyDuplicated(traits)) stop("OS_MISSING_COLUMN: unique named traits required.", call. = FALSE)
for (tr in traits) {
  raw_trait <- st[[tr]]
  st[[tr]] <- suppressWarnings(as.numeric(raw_trait))
  if (any(is.na(st[[tr]]) & !is.na(raw_trait)) || any(is.infinite(st[[tr]])) || sum(!is.na(st[[tr]])) < 3L || !isTRUE(stats::sd(st[[tr]], na.rm = TRUE) > 0)) stop("OS_INVALID_DESIGN: traits must be numeric and nonconstant with at least three observed finite values.", call. = FALSE)
}
if (ncol(inp$mat) < 4 || nrow(inp$mat) < 4) stop("OS_INVALID_INPUT: goodSamplesGenes requires at least four samples and genes.", call. = FALSE)
res <- os_engine_capture(wgcna_network_compute(a, inp$mat, st), "compute", elog)
qc <- os_engine_capture(wgcna_network_qc(res), "qc", elog); os_write_qc_results(qc, a$outdir)
os_engine_capture(wgcna_network_render(res, a, .module_dir, inp$upstream), "render", elog)
os_engine_capture(os_write_provenance(a$outdir, "wgcna-network", WG_MODULE_VERSION, os_canonical_argv(SPEC, a), .this, a$seed,
 inputs = list(expression = inp$path, samples = a$samples), outputs = c("tables/gene_modules.csv", "tables/module_traits.csv"), upstream = inp$upstream,
 extra = list(input_scale = a[["input-scale"]], preprocessing = a$preprocessing, outlier_rule = a[["outlier-rule"]], resolved_min_module_size = res$minSize, native_controls=res$native_controls), packages = "WGCNA"), "provenance", elog)
cat(sprintf("%d of %d rules triggered; read %s first\n", qc$n_triggered, qc$n_rules, qc$read_first))

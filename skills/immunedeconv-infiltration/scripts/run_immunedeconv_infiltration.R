options(error = function() { cat(geterrmessage(), file = stderr()); quit(status = 1, save = "no") })
.this <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))
.module_dir <- dirname(dirname(.this)); .suite <- dirname(dirname(.module_dir)); .shared <- file.path(.suite, "skills", "_shared", "scripts")
for (f in c("args.R", "module_kit.R", "handoff.R", "engine_run.R", "fig_all.R", "m4_io.R", "fig_mod_m4.R")) source(file.path(.shared, f))
source(file.path(dirname(.this), "immunedeconv_infiltration_core.R"))
SPEC <- os_arg_spec(usage = "Rscript run_immunedeconv_infiltration.R --input <csv>|--from-run <dir> --method <method> --input-scale TPM --outdir <dir>", flags = list(
 os_flag("input", "path", must_exist = TRUE, help = "human gene symbol x sample expression CSV"),
 os_flag("from-run", "path", must_exist = TRUE, help = "verified neutral expression upstream"),
 os_flag("upstream-object", "string", default = "expression_matrix", help = "upstream expression object"),
 os_flag("outdir", "path", required = TRUE, help = "output directory"),
 os_flag("spec", "path", must_exist = TRUE, help = "resolved options replay"),
 os_flag("method", "string", required = TRUE, help = "locked human deconvolution method; see options.md"),
 os_flag("input-scale", "string", required = TRUE, help = "TPM; MCP-counter also accepts log2TPM"),
 os_flag("method-args","path",must_exist=TRUE,help="named JSON object of selected method native arguments; read options.md for forwarding and reserved keys"),
 os_flag("cibersort-abs-method","enum",default="sig.score",values=c("sig.score","no.sumto1"),help="native CIBERSORT absolute score method; JSON method-args abs_method overrides this flag"),
 os_flag("tumor", "enum", default = "true", values = c("true", "false"), help = "tumor RNA-seq; locked wrapper TRUE"),
 os_flag("arrays", "enum", default = "false", values = c("true", "false"), help = "locked FALSE; arrays unsupported in TPM workflow"),
 os_flag("rmgenes", "string", help = "comma separated upstream exclusion; NULL default"),
 os_flag("scale-mrna", "enum", default = "true", values = c("true", "false"), help = "mRNA abundance scaling"),
 os_flag("accept-licence", "string", help = "required acknowledgement epic or cibersort; academic non-commercial terms"),
 os_flag("cibersort-source", "path", must_exist = TRUE, help = "user licensed CIBERSORT R source; never bundled"),
 os_flag("cibersort-matrix", "path", must_exist = TRUE, help = "user licensed LM22 matrix; never bundled"),
 os_flag("indications", "string", help = "required for TIMER/ConsensusTME; one cancer type per input sample"),
 os_flag("expected-cell-types", "string", help = "comma separated xCell cell types; NULL uses all"),
 os_flag("xcell-threads", "int", default = 1, range = c(1, 64), help = "explicit deterministic worker count"),
 os_flag("xcell-alpha", "num", default = 0.5, range = c(0, 1), help = "locked xCell spillover alpha"),
 os_flag("xcell-scale", "enum", default = "true", values = c("true", "false"), help = "locked xCell score scaling"),
 os_flag("consensus-stat-method", "enum", default = "ssgsea", values = c("ssgsea"), help = "locked top-level wrapper ssGSEA"),
 os_flag("seed", "int", default = 20260925, range = c(1, 1000000000), help = "explicit seed"),
 os_flag("journal", "enum", default = "nature", values = c("nature", "cell", "science", "generic"), help = "suite style")), exclusive = list(c("input", "from-run")))
a <- os_parse_args(SPEC, os_spec_argv(commandArgs(trailingOnly = TRUE)))
if (isTRUE(a$help)) { os_print_help(SPEC); quit(status = 0) }
set.seed(a$seed); options(omicstat.journal = a$journal)
inp <- os_m4_input(a); dir.create(a$outdir, recursive = TRUE, showWarnings = FALSE)
elog <- os_engine_log_new(a$outdir)
res <- os_engine_capture(immunedeconv_infiltration_compute(a, inp$mat), "official deconvolute Racle workflow", elog)
resolved_native <- attr(res,"omicstat_native_args")
tab <- as.data.frame(res)
if (ncol(tab) != ncol(inp$mat) + 1 || !identical(names(tab)[-1], colnames(inp$mat)) || any(!is.finite(as.matrix(tab[-1])))) stop("OS_RESULT_INVALID: native result sample axes or estimates invalid.", call. = FALSE)
os_m4_write_tables(list(infiltration = tab), a$outdir)
dir.create(file.path(a$outdir, "objects"), showWarnings = FALSE); saveRDS(res, file.path(a$outdir, "objects", "infiltration.rds"))
utils::write.csv(data.frame(gene_symbol = rownames(inp$mat), inp$mat, check.names = FALSE), file.path(a$outdir, "objects", "expression.csv"), row.names = FALSE)
fig <- os_finalize_figure(os_m4_infiltration(tab, a), file.path(a$outdir, "figures", "infiltration"), width = "double", journal = a$journal, root = a$outdir)
values <- list(input_description = if(a[["input-scale"]] == "log2TPM") "log2(TPM+1)" else "non-log TPM", result_kind = if(a$method == "estimate") "score/purity result rows" else "cell-type result rows", version = as.character(utils::packageVersion("immunedeconv")), n = ncol(inp$mat), genes = nrow(inp$mat), cells = nrow(tab), method = a$method, unit = id_method_unit(a$method), licence = if (a$method == "epic") "EPIC academic non-commercial; no redistribution; agreed users only" else if (a$method %in% c("cibersort", "cibersort_abs")) "user-supplied licensed CIBERSORT; no redistribution" else "see pinned method licence/data sources in references/options.md", options = jsonlite::toJSON(a, auto_unbox = TRUE),native_args=jsonlite::toJSON(resolved_native,auto_unbox=TRUE,null="null"))
os_m4_draft(.module_dir, values, list(infiltration = fig), a$outdir)
jsonlite::write_json(values, file.path(a$outdir, "results.json"), auto_unbox = TRUE, pretty = TRUE)
write_handoff(a$outdir, os_run_id(a$outdir), "immunedeconv-infiltration", ID_MODULE_VERSION, objects = list(infiltration = list(path = file.path(a$outdir, "objects", "infiltration.rds"), type = "infiltration"), expression_matrix = list(path = file.path(a$outdir, "objects", "expression.csv"), type = "expression_matrix")), state = list(ecosystem = "neutral", input_scale = a[["input-scale"]], method = a$method, unit = id_method_unit(a$method)), upstream_runs = inp$upstream$upstream_runs %||% character(0))
os_write_provenance(a$outdir, "immunedeconv-infiltration", ID_MODULE_VERSION, os_canonical_argv(SPEC, a), .this, a$seed, inputs = list(expression = inp$path), outputs = "tables/infiltration.csv", upstream = inp$upstream, packages = unique(c("immunedeconv", switch(a$method, quantiseq="quantiseqr", epic="EPIC", xcell="xCell", mcp_counter="MCPcounter", consensus_tme="ConsensusTME", "immunedeconv"))), extra = list(resolved_native=resolved_native,method=a$method, unit=id_method_unit(a$method), licence_acknowledgement=a[["accept-licence"]], restricted_files=if(a$method %in% c("cibersort","cibersort_abs")) list(source=digest::digest(file=a[["cibersort-source"]],algo="sha256"),matrix=digest::digest(file=a[["cibersort-matrix"]],algo="sha256")) else NULL))
cat("immunedeconv infiltration completed\n")

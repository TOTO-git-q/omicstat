# sc_backend_io.R -- neutral single-cell backend input and output contract.
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || (length(a) == 1 && is.na(a))) b else a
os_backend_flags <- function(seed = 20260925L) list(
  os_flag("input", "path", must_exist = TRUE, help = "clustered SCE/Seurat RDS or AnnData h5ad"),
  os_flag("from-run", "path", must_exist = TRUE, help = "verified upstream run with a single-cell object"),
  os_flag("object-name", "string", help = "upstream object name; required if more than one single-cell object"),
  os_flag("cluster-col", "string", required = TRUE, help = "cell metadata cluster column"),
  os_flag("counts-layer", "string", help = "source raw count assay/layer; explicitly name when needed"),
  os_flag("logcounts-layer", "string", help = "source normalized log expression assay/layer"),
  os_flag("source-assay", "string", help = "Seurat source assay (required for Seurat)"),
  os_flag("ecosystem", "enum", values = c("seurat", "bioconductor", "scverse"), help = "front-end chain ecosystem; required with direct input"),
  os_flag("outdir", "path", required = TRUE, help = "output directory"),
  os_flag("spec", "path", must_exist = TRUE, help = "replay resolved_spec.json; explicit flags win"),
  os_flag("seed", "int", default = seed, help = "recorded random seed"),
  os_flag("journal", "enum", default = "nature", values = c("nature", "cell", "science", "generic"), help = "figure style preset"))

os_backend_input <- function(a, need = c("counts", "logcounts")) {
  h <- NULL; path <- a$input
  if (!is.null(a[["from-run"]])) {
    h <- read_handoff(a[["from-run"]])
    nm <- a[["object-name"]]
    candidates <- names(Filter(function(o) o$type %in% names(OS_SC_TYPES), h$objects))
    if (is.null(nm)) {
      if (length(candidates) != 1L) stop("OS_HANDOFF_MISMATCH: select --object-name from the single-cell objects.", call. = FALSE)
      nm <- candidates[1]
    }
    os_handoff_assert_uncorrected(h, nm, purpose = "single-cell inference")
    if (!h$objects[[nm]]$type %in% names(OS_SC_TYPES)) stop("OS_HANDOFF_MISMATCH: selected object is not single-cell.", call. = FALSE)
    path <- h$objects[[nm]]$path
    eco <- os_sc_chain_state(h)$front_end_ecosystem
    if (!is.null(a$ecosystem) && !identical(a$ecosystem, eco)) stop("OS_ECOSYSTEM_MIXED: requested ecosystem differs from upstream chain.", call. = FALSE)
    if (!eco %in% unname(OS_SC_TYPES)) stop("OS_HANDOFF_MISMATCH: upstream must declare front_end_ecosystem.", call. = FALSE)
  } else {
    if (is.null(path) || is.null(a$ecosystem)) stop("OS_MISSING_PARAMETER: give --input and --ecosystem, or --from-run.", call. = FALSE)
    eco <- a$ecosystem
  }
  embedded <- .os_sc_embedded_state(.os_sc_source(path))
  if (isTRUE(embedded$batch_corrected_lineage)) stop("OS_BATCH_CORRECTED_INPUT: embedded object state records batch-corrected expression; use uncorrected data for inference.", call. = FALSE)
  if (!is.null(embedded$front_end_ecosystem) && !identical(embedded$front_end_ecosystem, eco))
    stop("OS_ECOSYSTEM_MIXED: declared ecosystem differs from embedded front-end chain.", call. = FALSE)
  layers <- character(0)
  if (!is.null(a[["counts-layer"]])) layers[["counts"]] <- a[["counts-layer"]]
  if (!is.null(a[["logcounts-layer"]])) layers[["logcounts"]] <- a[["logcounts-layer"]]
  if (!all(need %in% names(layers))) stop(sprintf("OS_MISSING_PARAMETER: explicitly name %s layers.", paste(need, collapse = ", ")), call. = FALSE)
  cv <- os_sc_convert(x = path, to = "SingleCellExperiment", consumer = "back_end", layers = layers,
                      cluster_col = a[["cluster-col"]], source_assay = a[["source-assay"]])
  list(sce = cv$object, conversion = cv$step, path = path, upstream = h, ecosystem = eco,
       crossing = identical(eco, "scverse"), state = utils::modifyList(utils::modifyList(embedded, h$state %||% list()), list(front_end_ecosystem = eco)))
}

os_backend_csv <- function(tab, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(tab, path, row.names = FALSE, na = "NA", eol = "\n", quote = TRUE)
  invisible(path)
}
os_backend_column <- function(sce, col) {
  if (!col %in% colnames(SummarizedExperiment::colData(sce))) stop(sprintf("OS_MISSING_COLUMN: no cell metadata column %s.", col), call. = FALSE)
  x <- as.character(SummarizedExperiment::colData(sce)[[col]])
  if (anyNA(x) || any(!nzchar(x))) stop(sprintf("OS_INVALID_INPUT: missing/empty %s values.", col), call. = FALSE)
  x
}
os_backend_replicates <- function(sce, sample_col, condition_col, reference, target) {
  sm <- os_backend_column(sce, sample_col); gr <- os_backend_column(sce, condition_col)
  st <- unique(data.frame(sample = sm, condition = gr))
  if (anyDuplicated(st$sample)) stop("OS_INVALID_DESIGN: sample maps to multiple conditions.", call. = FALSE)
  if (!all(c(reference, target) %in% st$condition) || identical(reference, target)) stop("OS_INVALID_DESIGN: two distinct observed conditions required.", call. = FALSE)
  st <- st[st$condition %in% c(reference, target), , drop = FALSE]
  n <- table(factor(st$condition, levels = c(reference, target)))
  if (any(n < 2L)) stop("OS_QC_BLOCKER: each condition needs at least two replicate samples; cells are not replicates.", call. = FALSE)
  list(samples = st, counts = n, selected = sm %in% st$sample)
}

# Package options are JSON-valued flags; absent flags retain lazy locked defaults.
# Each formal is exposed independently, including list controls and NULL choices.
os_backend_function_flags <- function(fn, prefix, exclude = character()) {
  fm <- formals(fn)
  lapply(setdiff(names(fm), c('...', exclude)), function(nm) {
    os_flag(paste0(prefix, '-', gsub('[._]', '-', tolower(nm))), 'string',
      help = paste0('JSON value for ', nm, '; absent: locked default ', paste(deparse(fm[[nm]]), collapse = ' ')))
  })
}
os_backend_function_options <- function(fn, a, prefix, fixed = list()) {
  fm <- formals(fn); given <- fixed
  for(nm in setdiff(names(fm), '...')) {
    flag <- paste0(prefix, '-', gsub('[._]', '-', tolower(nm)))
    if(!is.null(a[[flag]])) {
      value <- jsonlite::fromJSON(a[[flag]], simplifyVector=TRUE)
      if(is.list(value) && identical(names(value),'rds')) value <- readRDS(value$rds)
      given[nm] <- list(value)
    }
  }
  resolver <- fn
  body(resolver) <- substitute(mget(KEYS, envir=environment(), inherits=FALSE), list(KEYS=setdiff(names(fm),'...')))
  do.call(resolver, given)
}

os_backend_finish <- function(r, inp, a, module, entry) {
  dir.create(file.path(a$outdir, 'objects'), recursive = TRUE, showWarnings = FALSE)
  saveRDS(r$native, file.path(a$outdir, 'objects', 'native.rds'), version = 3)
  S4Vectors::metadata(r$sce)$omicstat <- utils::modifyList(inp$state, list(backend = module))
  path <- file.path(a$outdir, 'objects', 'sce.rds'); saveRDS(r$sce, path, version = 3)
  write_handoff(a$outdir, basename(a$outdir), module, '1.0.0',
    list(sce = list(path = path, type = 'SingleCellExperiment')), ecosystem = 'neutral',
    state = utils::modifyList(inp$state, list(backend = module)), contract_hash = inp$upstream$contract_hash %||% NA_character_,
    upstream_runs = inp$upstream$upstream_runs %||% character())
  for (nm in names(r$tables)) os_backend_csv(r$tables[[nm]], file.path(a$outdir, 'tables', paste0(nm, '.csv')))
  prefix <- c('muscat-pseudobulk'='MP','speckle-propeller'='SP','slingshot-trajectory'='SL','monocle3-trajectory'='MT','cellchat-communication'='CC')[[module]]
  qc <- os_qc_finalize(list(os_qc_rule(paste0(prefix,'-01'), 'Python to R crossing', inp$crossing, 'info',
    'OS_ECOSYSTEM_CROSSING: Python front end feeds neutral R backend; upstream ecosystem is preserved.', 'Preserve upstream ecosystem.', 'build_m3b lane rule'),
    os_qc_rule(paste0(prefix,'-02'), 'output shape', ncol(r$sce) == 0, 'blocker', 'No cells.', 'Review inputs.', 'Package workflow sanity')), paste0('tables/',names(r$tables)[1],'.csv'))
  os_write_qc_results(qc, a$outdir)
  os_write_text(c(paste0('# ',module,' Methods'),
    paste0('Analysis used ', paste(names(r$versions),unlist(r$versions),collapse='; '), '.'),
    paste0('Functions: ',paste(r$functions,collapse=', '),'.'),
    paste0('Actual options: ',jsonlite::toJSON(r$options,auto_unbox=TRUE,null='null',force=TRUE)),
    paste0('Seed: ',a$seed,'.'),r$note %||% ''),file.path(a$outdir,'draft','methods_results.md'))
  dir.create(file.path(a$outdir,'results'),recursive=TRUE,showWarnings=FALSE)
  jsonlite::write_json(list(n_cells=ncol(r$sce),n_features=nrow(r$sce),seed=a$seed,native_options=r$options),file.path(a$outdir,'results','analysis_summary.json'),auto_unbox=TRUE,pretty=TRUE,null='null',force=TRUE,digits=NA)
  files <- list(input=inp$path)
  for(nm in c('trajectory-rds','graph-genes-file')) if(!is.null(a[[nm]])) files[[nm]] <- a[[nm]]
  for(nm in names(a)) if(is.character(a[[nm]]) && length(a[[nm]])==1L && startsWith(trimws(a[[nm]]),'{')) {
    js <- tryCatch(jsonlite::fromJSON(a[[nm]]),error=function(e)NULL)
    if(is.list(js) && identical(names(js),'rds')) files[[nm]] <- js$rds
  }
  os_write_provenance(a$outdir,module,'1.0.0',attr(a, "canonical"),basename(entry),a$seed,
    inputs=files,outputs=paste0('tables/',names(r$tables),'.csv'),upstream=inp$upstream,
    extra=list(front_end_ecosystem=inp$ecosystem,backend_ecosystem="neutral",conversion=inp$conversion,python_to_r_crossing=inp$crossing))
}
os_backend_proportions <- function(sce, cluster_col, sample_col, condition_col) {
  d <- data.frame(sample=os_backend_column(sce,sample_col), condition=os_backend_column(sce,condition_col), celltype=os_backend_column(sce,cluster_col))
  as.data.frame(stats::aggregate(rep(1,nrow(d)),by=d,FUN=sum)) |> stats::setNames(c('sample','condition','celltype','n'))
}
# One anchor run and one equivalent --from-run run, with native-table goldens.
os_backend_smoke <- function(module_dir, sce, args, main_table, check, golden=TRUE) {
  suite <- dirname(dirname(module_dir)); module <- basename(module_dir)
  root <- file.path(Sys.getenv('OMICSTAT_TEST_TMP',tempdir()),paste0(module,'-smoke'))
  dir.create(root,recursive=TRUE,showWarnings=FALSE)
  input <- file.path(root,'input.rds'); saveRDS(sce,input)
  entry <- file.path(module_dir,'scripts',paste0('run_',gsub('-','_',module),'.R'))
  run <- function(av, name) {
    log <- file.path(root,paste0(name,'.log'))
    rc <- system2('Rscript',c(shQuote(entry),vapply(av,shQuote,'')),stdout=log,stderr=log)
    if(rc!=0L) stop(paste(readLines(log),collapse='\n'))
  }
  direct <- file.path(root,'direct'); chain <- file.path(root,'chain')
  run(c('--input',input,'--ecosystem','bioconductor',args,'--outdir',direct),'direct')
  check(direct)
  upstream <- file.path(root,'upstream'); dir.create(file.path(upstream,'objects'),recursive=TRUE,showWarnings=FALSE)
  cp <- file.path(upstream,'objects','sce.rds'); saveRDS(sce,cp)
  write_handoff(upstream,'anchor-upstream','anchor-fixture','1.0.0',list(sce=list(path=cp,type='SingleCellExperiment')),
    ecosystem='bioconductor',state=list(front_end_ecosystem='bioconductor',clustered=TRUE,annotated=TRUE))
  run(c('--from-run',upstream,args,'--outdir',chain),'chain')
  stopifnot(identical(digest::digest(file=file.path(direct,main_table),algo='sha256'),digest::digest(file=file.path(chain,main_table),algo='sha256')))
  h <- read_handoff(chain); stopifnot(identical(os_sc_chain_state(h)$front_end_ecosystem,'bioconductor'))
  if (identical(Sys.getenv('OMICSTAT_TEST_H5AD'),'1')) {
    roles <- intersect(c('counts','logcounts'),SummarizedExperiment::assayNames(sce))
    mapping <- stats::setNames(roles,roles)
    cc <- args[match('--cluster-col',args)+1L]
    xp <- if('logcounts' %in% roles) 'logcounts' else 'counts'
    h5 <- file.path(root,'input.h5ad')
    cv <- os_sc_convert(sce,to='AnnData',consumer='back_end',layers=mapping,cluster_col=cc,x_role=xp,file=h5)
    av <- args
    for(role in roles) {
      flag <- paste0('--',role,'-layer'); value <- cv$step$target$layers[[role]]
      at <- match(flag,av)
      if(is.na(at)) av<-c(av,flag,value) else av[at+1L]<-value
    }
    ann <- file.path(root,'anndata')
    # This h5ad is a format export of the Bioconductor anchor, so preserve
    # that declared chain; do not decide the Python-to-R ecosystem label.
    run(c('--input',h5,'--ecosystem','bioconductor',av,'--outdir',ann),'anndata')
    check(ann)
    stopifnot(identical(digest::digest(file=file.path(direct,main_table),algo='sha256'),digest::digest(file=file.path(ann,main_table),algo='sha256')))
    cat('PASS: non-root offline h5ad input matches the original native result table\n')
  }
  stopifnot(system2('Rscript',c(shQuote(file.path(suite,'tools','check_calls.R')),shQuote(module_dir)))==0L)
  stopifnot(system2('python3',c(shQuote(file.path(suite,'tools','lint_r.py')),shQuote(module_dir)))==0L)
  if(golden) {
    if(identical(Sys.getenv('OMICSTAT_WRITE_GOLDEN'),'1')) os_golden_write(module_dir,direct,main_table)
    g <- os_golden_check(module_dir,direct)
    stopifnot(identical(g$status,"PASS"))
  }
  cat('PASS: PACK C anchor, native output, --from-run chain equality, static calls/default drift and golden\n')
  invisible(direct)
}
os_backend_s4_function <- function(pkg, fn, signature) {
  loadNamespace(pkg)
  meth <- methods::selectMethod(getExportedValue(pkg,fn),signature=signature)
  eval(body(meth)[[2]][[3]],environment(meth))
}

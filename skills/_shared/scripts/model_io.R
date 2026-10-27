# Shared, typed model output. No lock/golden writer or implicit acceptance.
os_module_finish <- function(res, a, module, entry, spec, upstream = NULL,
                             qc_rows = NULL, objects = NULL, figures_fn = NULL) {
  out <- a$outdir
  if (!is.character(out) || length(out) != 1L || !nzchar(out)) os_input_stop('outdir is required')
  resource_outputs<-character()
  if(!is.null(res$resource_sampling_evidence)) {
    evidence<-res$resource_sampling_evidence
    allowed<-c('provenance/resource_sampling.json','provenance/resource_sampling_methods.txt')
    if(!is.list(evidence)||!identical(names(evidence),allowed))stop('OS_INVALID_RESULT: exact resource evidence paths required',call.=FALSE)
    for(path in allowed)if(!file.exists(file.path(out,path))||!identical(digest::digest(file=file.path(out,path),algo='sha256'),evidence[[path]]))
      stop('OS_INVALID_RESULT: resource sampling evidence changed or disappeared',call.=FALSE)
    resource_outputs<-allowed
  }
  for (d in c('tables','objects','qc','provenance','draft','figures'))
    dir.create(file.path(out,d), recursive = TRUE, showWarnings = FALSE)
  safe_name <- function(nm) {
    if (!grepl('^[A-Za-z0-9][A-Za-z0-9_.-]*$',nm) || grepl('..',nm,fixed=TRUE))
      os_input_stop('unsafe output name')
    nm
  }
  for (nm in names(res$tables)) {
    safe_name(nm); table <- res$tables[[nm]]
    if (!is.data.frame(table)) os_input_stop(paste(nm,'must be a data frame'))
    path <- file.path(out,'tables',paste0(nm,'.csv'))
    if (nm == 'feature_table') {
      write_feature_table(table,path)
    } else {
      if (nm == 'effect_table') {
        # Validate canonical effect tables without rewriting legacy model columns.
        if (all(c('analysis_id','n_unweighted','model_spec_hash') %in% names(table))) {
          validation <- validate_effect_table(table)
          if (!isTRUE(validation$ok)) os_input_stop(paste(validation$errors,collapse='; '))
        }
        else if (!all(c('term','estimate','ci_low','ci_high') %in% names(table))) os_input_stop('effect_table needs term, estimate, ci_low and ci_high')
      }
      utils::write.csv(table,path,row.names=FALSE,na='')
    }
  }
  if (is.null(objects)) {
    objects <- list(model=list(value=res$object,type=res$handoff_type %||% 'calibration_model'),
                    metadata=list(value=res$metadata,type='development_model_metadata'))
  }
  descriptors <- list()
  for (nm in names(objects)) {
    safe_name(nm); o <- objects[[nm]]; os_handoff_type_check(o$type)
    path <- file.path(out,'objects',paste0(nm,'.rds'))
    if (!is.null(o$path)) {
      src <- normalizePath(o$path,mustWork=TRUE)
      if (!identical(src,normalizePath(path,mustWork=FALSE))) {
        if (!file.copy(src,path,overwrite=FALSE)) os_input_stop('could not copy object')
      }
    } else saveRDS(o$value,path,version=3)
    descriptors[[nm]] <- list(path=path,type=o$type)
  }
  rows <- c(qc_rows %||% list(os_qc_rule('DEV-01','Candidate module',TRUE,'blocker',
       'Owner review and production acceptance remain pending.','Do not use for manuscript inference.')),res$qc)
  qc <- os_qc_finalize(rows,if ('effect_table' %in% names(res$tables)) 'tables/effect_table.csv' else paste0('tables/',names(res$tables)[1],'.csv'))
  os_write_qc_results(qc,out)
  os_write_text(c('Candidate result; publication blocked until owner review.',res$method %||% ''),file.path(out,'draft','methods.txt'))
  contract_hash <- upstream$contract_hash %||% NA_character_
  if (!is.null(a[['study-contract-sha256']]) && is.null(a[['study-contract']])) stop('OS_MISSING_PARAMETER: a caller hash cannot replace contract bytes',call.=FALSE)
  if (!is.null(a[['study-contract']]) && exists('os_study_contract_read',mode='function')) contract_hash <- os_study_contract_read(a[['study-contract']],upstream=upstream)$sha256
  version <- res$module_version %||% '0.1.0'
  write_handoff(out,os_run_id(out),module,version,objects=descriptors,contract_hash=contract_hash,
    ecosystem=res$ecosystem %||% 'neutral',state=utils::modifyList(utils::modifyList(upstream$state %||% list(),res$state %||% list()),
       list(candidate=TRUE,development_only=TRUE,acceptance_pending=TRUE,model_ready=isTRUE(res$ready))),
    upstream_runs=upstream$upstream_runs %||% character(0))
  if (!is.null(figures_fn)) figures_fn(res,out,module)
  inputs <- if (is.null(upstream)) list(input=a$input) else list(handoff=file.path(a[['from-run']],'objects','handoff.json'))
  inputs <- utils::modifyList(inputs, res$input_files %||% list())
  outputs <- list.files(out,recursive=TRUE);outputs <- outputs[!startsWith(outputs,'provenance/') & outputs!='qc/engine_warnings.csv']
  outputs<-c(outputs,resource_outputs)
  os_write_provenance(out,module,version,os_canonical_argv(spec,a),entry,a$seed,inputs,outputs,upstream,
    extra=list(validation_status='candidate',scientific_choices=res$metadata),packages=res$packages %||% character())
  cat(sprintf('%d of %d rules triggered; read %s first\n',qc$n_triggered,qc$n_rules,qc$read_first))
  invisible(list(qc=qc,objects=descriptors,outputs=outputs))
}

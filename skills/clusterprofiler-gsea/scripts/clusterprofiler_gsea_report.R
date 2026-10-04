cg_render <- function(r,x,a,ref) {
  tab <- os_enrich_canonical(r$raw,database=paste("GO",a$ontology))
  tab$significant_bh05 <- !is.na(tab$padj)&tab$padj<0.05
  if (a[["exploratory-fdr"]]) tab$exploratory_bh25 <- !is.na(tab$padj)&tab$padj<0.25
  path <- file.path(a$outdir,"tables","enrichment_full.csv"); os_enrich_write_csv(tab,path)
  figs <- list()
  if (any(!is.na(tab$padj)&tab$padj<a$alpha)) {
    dot <- os_cp_gsea_dotplot(tab,a[["top-n"]],a$alpha,a$ontology,a$journal)
    figs$dotplot <- os_finalize_figure(dot,file.path(a$outdir,"figures","gsea_dotplot"),journal=a$journal)
    sgn <- os_cp_gsea_dotplot_signed(tab,min(a[["top-n"]],10L),a$alpha,a$ontology,x$direction,x$negative_end,a$journal,
                                     score_signs=cg_score_signs(x$scores))
    figs$dotplot_signed <- os_finalize_figure(sgn,file.path(a$outdir,"figures","gsea_dotplot_signed"),journal=a$journal)
    core <- stats::setNames(strsplit(as.character(r$raw$core_enrichment),"/",fixed=TRUE),as.character(r$raw$ID))
    rid <- os_cp_gsea_ridge(tab,core,x$scores,a$alpha,min(a[["top-n"]],12L),x$metric,a$journal)
    figs$ridge <- os_finalize_figure(rid,file.path(a$outdir,"figures","gsea_ridge"),journal=a$journal)
    top <- tab[which.min(ifelse(is.na(tab$padj),Inf,tab$padj)),,drop=FALSE]
    set <- r$result@geneSets[[as.character(top$term_id)]]
    if (length(set)) {
      curve <- os_cp_gsea_curve(x$scores,set,as.character(top$term_name),top$nes,top$padj,a$journal)
      figs$curve <- os_finalize_figure(curve,file.path(a$outdir,"figures","gsea_curve"),journal=a$journal)
    }
  }
  dir.create(file.path(a$outdir,"results"),recursive=TRUE,showWarnings=FALSE)
  jsonlite::write_json(list(module=CG_MODULE,module_version=CG_MODULE_VERSION,database="GO",ontology=a$ontology,
                            ranking_metric=x$metric,direction=x$direction,negative_end=x$negative_end,
                            statistic_kind=x$statistic_kind,lfc_type=x$lfc_type,contrast=x$contrast,ranking_source=x$source,
                            n_positive_scores=sum(x$scores>0),n_negative_scores=sum(x$scores<0),n_ranked=length(x$scores),
                            n_tested_sets=nrow(tab),n_significant_bh05=sum(tab$significant_bh05),
                            n_exploratory_bh25=if (a[["exploratory-fdr"]]) sum(tab$exploratory_bh25) else NULL,
                            alpha=a$alpha,minGSSize=a[["min-size"]],maxGSSize=a[["max-size"]],
                            pvalueCutoff_compute=1,pAdjustMethod="BH",exponent=1,seed=a$seed,
                            enrichit_version=as.character(utils::packageVersion("enrichit")),refdata=ref),
                       file.path(a$outdir,"results","clusterprofiler_gsea_results.json"),auto_unbox=TRUE,
                       pretty=TRUE,null="null",na="null")
  list(table=path,figures=figs)
}

# How NES is read (S5 R2). NES is relative enrichment toward the top (NES > 0)
# or the bottom (NES < 0) of the ranking. A ranking whose finite scores all
# share one sign still has both ends: with all scores positive the bottom holds
# the smallest positive scores, so a negative NES there does not by itself mean
# an effect opposite to the declared direction (and symmetrically when all
# scores are negative).
cg_score_signs <- function(s) if (any(s<0)&&any(s>0)) "both" else if (!any(s<0)) "positive" else "negative"
cg_nes_reading <- function(s,direction,negative_end) {
  base <- "NES is read as relative enrichment of a set toward the top (NES > 0, highest scores) or the bottom (NES < 0, lowest scores) of this ranking. "
  switch(cg_score_signs(s),
    both = base,
    positive = paste0(base,sprintf(paste0("All %d finite scores are %s, so no gene scores on the negative side of the contrast; the ranking still ",
                                          "has a bottom, formed by the smallest scores, and a negative NES marks relative enrichment there. It does ",
                                          "not by itself indicate %s. "),
                                   length(s),if (any(s==0)) "zero or positive" else "positive",negative_end)),
    negative = paste0(base,sprintf(paste0("All %d finite scores are %s, so no gene scores on the positive side of the contrast; the ranking still ",
                                          "has a top, formed by the scores closest to zero, and a positive NES marks relative enrichment there. It ",
                                          "does not by itself indicate %s. "),
                                   length(s),if (any(s==0)) "zero or negative" else "negative",direction)))
}

cg_draft <- function(r,x,a,render,module_dir) {
  t <- os_read_templates(file.path(module_dir,"references","reporting-templates.md"))
  v <- list(metric=x$metric,direction=x$direction,n_ranked=length(x$scores),ontology=a$ontology,
            ranking_detail=paste0(if (identical(x$statistic_kind,"effect_size")) sprintf("The ranking is an effect size (LFC type: %s). ",x$lfc_type)
                                  else "The ranking is a signed test statistic. ",
                                  sprintf("Contrast: %s (source: %s). ",x$contrast,x$source),
                                  cg_nes_reading(x$scores,x$direction,x$negative_end)),
            clusterprofiler_version=as.character(utils::packageVersion("clusterProfiler")),
            enrichit_version=as.character(utils::packageVersion("enrichit")),
            min_size=a[["min-size"]],max_size=a[["max-size"]],seed=a$seed,
            tested=nrow(r$raw),sig=sum(!is.na(r$raw$p.adjust)&r$raw$p.adjust<a$alpha),alpha=a$alpha,
            annotation_version=as.character(utils::packageVersion("org.Hs.eg.db")),
            exploratory=if (a[["exploratory-fdr"]]) "An exploratory BH 0.25 flag was declared before analysis and is separate from the main BH 0.05 inference." else "No exploratory 0.25 flag was requested.")
  caps <- vapply(names(render$figures),function(n) sprintf("- **%s**: %s",n,render$figures[[n]]$spec_obj$caption %||% ""),"")
  os_write_text(c("# Methods","",os_fill_template(t$methods,v),"","# Results","",os_fill_template(t$results,v),"",v$exploratory,
                  if (length(caps)) c("","# Figure legends","",caps),
                  if (!length(render$figures)) os_enrich_empty_note(os_enrich_canonical(r$raw),a$alpha)),
                file.path(a$outdir,"draft","methods_results.md"))
}

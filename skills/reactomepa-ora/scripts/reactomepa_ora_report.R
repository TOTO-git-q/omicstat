rpa_render <- function(res,out,module) {
 m<-res$metadata;t<-res$tables$enrichment_table
 if(!any(t$significant)) {os_write_text(os_enrich_empty_note(t,m$alpha),file.path(out,"draft/no_significant_terms.txt"));return(invisible(NULL))}
 p<-os_enrich_dotplot(t,x="gene_ratio",top_n=m$top_n,padj_threshold=m$alpha,database_label=paste("Reactome",m$organism),journal=m$journal)
 p<-os_with_meta(p,caption=paste(attr(p,"os_meta")$caption,m$multiplicity,paste("Refdata:",m$refdata_id)))
 os_finalize_figure(p,file.path(out,"figures/reactome_ora"),root=out)
}

ed_render <- function(res,out,module) {
 m<-res$metadata;cap<-paste(m$method,sprintf("%d zero-count barcodes omitted from log axes without a pseudocount; all remain in the output table.",m$n_zero))
 p<-os_diag_xy(res$tables$barcode_ranks,x="log10_rank",y="log10_total",kind="points",group="status",xlab="log10 barcode rank",ylab="log10 total UMI",hlines=log10(m$lower),caption=cap,figure_type="emptydrops_barcode_rank",journal=m$journal)
 p<-os_with_meta(p,counts=list(total=nrow(res$tables$barcodes),zero_omitted=m$n_zero,nonempty=m$n_nonempty),thresholds=list(lower=m$lower,fdr=m$fdr))
 os_finalize_figure(p,file.path(out,"figures/barcode_rank"),root=out)
 d<-res$tables$ambient_diagnostic
 if(nrow(d)){p<-os_diag_xy(d,x="log10_total",y="negative_log_probability",kind="points",group="status",xlab="log10 total UMI",ylab="Negative log probability",caption=paste(cap,"Only barcodes with an evaluated log probability are shown; this axis is not -log10 P."),figure_type="emptydrops_ambient_diagnostic",journal=m$journal);os_finalize_figure(p,file.path(out,"figures/ambient_diagnostic"),root=out)}
}

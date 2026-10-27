# Pure post-engine checks, independently exercised without substituting an engine.
ed_adjusted_p <- function(p,totals,lower,retain) {
 p[totals>=retain]<-0;p[totals<=lower]<-NA_real_
 stats::p.adjust(p=p,method="BH",n=sum(!is.na(p)))
}
ed_ambient_profile <- function(p,counts) {
 # Inspected upstream removes globally-zero genes internally; reconstruct only those.
 expressed<-(if(methods::is(counts,"sparseMatrix"))Matrix::rowSums(counts)else rowSums(counts))>0
 ids<-rownames(counts)[expressed]
 if(length(p)!=length(ids)||any(!is.finite(p))||any(p<0)||abs(sum(p)-1)>1e-8)stop("OS_INVALID_RESULT: ambient profile must cover every expressed gene",call.=FALSE)
 if(!is.null(names(p))){if(anyDuplicated(names(p))||!setequal(names(p),ids))stop("OS_INVALID_RESULT: ambient feature identity mismatch",call.=FALSE);p<-p[match(ids,names(p))]}
 out<-setNames(numeric(nrow(counts)),rownames(counts));out[expressed]<-p;out
}
ed_number <- function(x,allow_none=FALSE,allow_estimate=FALSE) {
 if(allow_none&&identical(x,"none"))return(Inf)
 if(allow_estimate&&identical(x,"estimate"))return(NULL)
 if(allow_estimate&&identical(x,"multinomial"))return(Inf)
 v<-suppressWarnings(as.numeric(x));if(length(v)!=1L||!is.finite(v)||v<=0)stop("OS_INVALID_PARAMETER: positive numeric choice required",call.=FALSE);v
}
ed_input <- function(a) {
 os_annotation_registry(a[["refdata-registry"]],a[["refdata-id"]],"dropletutils-emptydrops","annotation")
 p<-os_user_refdata(a$input,a[["input-provenance"]],a[["refdata-id"]])
 if(!identical(p$species,a$species)||!isTRUE(p$unfiltered_raw_counts))stop("OS_REFDATA_MISMATCH: species and unfiltered raw-count declaration required",call.=FALSE)
 x<-if(a$format=="rds")readRDS(a$input)else os_read_matrix(a$input,"raw droplet counts")
 if(!is.matrix(x)&&!methods::is(x,"sparseMatrix"))os_input_stop("matrix or sparseMatrix required, not filtered/lazy single-cell object")
 if(nrow(x)<2L||ncol(x)<3L||nrow(x)>40000L||ncol(x)>100000L)os_input_stop("raw matrix outside 40000-feature/100000-barcode limits; no downsampling")
 if(is.null(rownames(x))||is.null(colnames(x))||anyNA(rownames(x))||anyNA(colnames(x))||any(!nzchar(rownames(x)))||any(!nzchar(colnames(x)))||anyDuplicated(rownames(x))||anyDuplicated(colnames(x)))os_input_stop("unique nonempty feature and barcode identities required")
 values<-if(methods::is(x,"sparseMatrix"))x@x else as.vector(x)
 if(!is.numeric(values)||any(!is.finite(values))||any(values<0)||any(values!=floor(values)))os_input_stop("finite nonnegative integer UMI counts required; rounding is forbidden")
 totals<-if(methods::is(x,"sparseMatrix"))Matrix::colSums(x)else colSums(x)
 if(any(totals>.Machine$integer.max))os_input_stop("per-barcode count total exceeds supported integer range")
 ambient<-totals>0&totals<=a$lower
 if(sum(ambient)<20L||sum(totals[ambient])<100L)stop("OS_INVALID_DESIGN: at least20 nonzero ambient barcodes and100 pooled counts required",call.=FALSE)
 retain<-ed_number(a$retain,allow_none=TRUE);if(retain<=max(a$lower,a$ignore))stop("OS_INVALID_PARAMETER: retain must exceed lower and ignore or be none",call.=FALSE)
 alpha<-ed_number(a$alpha,allow_estimate=TRUE)
 tested<-totals>max(a$lower,a$ignore)
 if(!any(tested))stop("OS_EMPTY_DATA: no barcode above declared testing thresholds",call.=FALSE)
 n_sim<-sum(if(a[["test-ambient"]]=="true")totals>a$ignore else tested)
 if(n_sim*a$niters>20000000)os_input_stop("20-million barcode-simulation limit exceeded; choose justified settings or external execution, never automatic downsampling")
 list(counts=x,totals=totals,ambient=ambient,retain=retain,alpha=alpha,provenance=p,n_sim=n_sim)
}
ed_resolved_parameters <- function(md,a,input) {
 for(k in c("lower","niters","retain","alpha")){
  v<-md[[k]];if(length(v)!=1L||!is.numeric(v)||is.na(v)||v<=0)stop("OS_INVALID_RESULT: native emptyDrops resolved parameter missing or invalid",call.=FALSE)
 }
 if(md$lower!=a$lower||md$niters!=a$niters||md$retain!=input$retain||(!is.null(input$alpha)&&md$alpha!=input$alpha))stop("OS_INVALID_RESULT: native emptyDrops resolved parameters differ from explicit request",call.=FALSE)
 data.frame(parameter=c("lower","niters","retain","alpha"),requested=c(as.character(a$lower),as.character(a$niters),a$retain,a$alpha),resolved=vapply(md[c("lower","niters","retain","alpha")],function(z)if(is.infinite(z))"Inf"else format(z,digits=17,scientific=FALSE,trim=TRUE),""),source="Actual native emptyDrops result metadata",stringsAsFactors=FALSE)
}
ed_compute <- function(a) {
 x<-ed_input(a);contract<-if(!is.null(a[["study-contract"]]))os_study_contract_read(a[["study-contract"]]) else list(sha256=NULL);os_require_pkg("DropletUtils");os_require_pkg("BiocParallel")
 v<-utils::packageVersion("DropletUtils");if(v<"1.32.0"||v>="1.33.0")stop("OS_PACKAGE_VERSION: inspected1.32.x API required",call.=FALSE)
 result<-DropletUtils::emptyDrops(m=x$counts,lower=a$lower,retain=x$retain,barcode.args=list(),round=FALSE,test.ambient=a[["test-ambient"]]=="true",niters=a$niters,ignore=a$ignore,alpha=x$alpha,by.rank=NULL,known.empty=NULL,BPPARAM=BiocParallel::SerialParam(RNGseed=a$seed,progressbar=FALSE,stop.on.error=TRUE))
 d<-as.data.frame(result);need<-c("Total","LogProb","PValue","Limited","FDR")
 if(!all(need%in%names(d))||nrow(d)!=ncol(x$counts)||!identical(rownames(d),colnames(x$counts))||any(d$Total!=x$totals))stop("OS_INVALID_RESULT: engine barcode identities/totals differ",call.=FALSE)
 if(any(!is.na(d$PValue)&(!is.finite(d$PValue)|d$PValue<0|d$PValue>1))||any(!is.na(d$FDR)&(!is.finite(d$FDR)|d$FDR<0|d$FDR>1)))stop("OS_INVALID_RESULT: invalid Monte Carlo P or FDR",call.=FALSE)
 retained<-d$Total>=x$retain
 ok<-!is.na(d$FDR);wanted<-ed_adjusted_p(d$PValue,d$Total,a$lower,x$retain)
 if(!identical(is.na(wanted),is.na(d$FDR))||any(abs(wanted[ok]-d$FDR[ok])>1e-10))stop("OS_INVALID_RESULT: retained-zero and excluded-ambient BH family differs",call.=FALSE)
 called<-!is.na(d$FDR)&d$FDR<=a$fdr
 status<-ifelse(d$Total==0,"zero-count",ifelse(d$Total<=a$lower,"ambient-not-tested",ifelse(is.na(d$FDR),"ignored",ifelse(retained,"retained-by-count",ifelse(called,"nonempty-FDR","not-significant")))))
 tab<-data.frame(barcode=colnames(x$counts),total_umi=d$Total,log_probability=d$LogProb,p_value=d$PValue,limited=d$Limited,fdr=d$FDR,called_nonempty=called,retained_by_count=retained,status=status,stringsAsFactors=FALSE)
 md<-S4Vectors::metadata(result);resolved<-ed_resolved_parameters(md,a,x);ambient<-md$ambient
 ambient<-ed_ambient_profile(ambient,x$counts)
 sce<-SingleCellExperiment::SingleCellExperiment(assays=list(counts=x$counts),colData=S4Vectors::DataFrame(tab,row.names=tab$barcode))
 S4Vectors::metadata(sce)$omicstat<-list(front_end_ecosystem="bioconductor",unfiltered_raw_counts=TRUE,emptydrops_annotated=TRUE,qc_complete=FALSE,candidate=TRUE,development_only=TRUE)
 positive<-tab$total_umi>0;rank<-rank(-tab$total_umi[positive],ties.method="min");ranktab<-data.frame(barcode=tab$barcode[positive],log10_rank=log10(rank),log10_total=log10(tab$total_umi[positive]),status=tab$status[positive])
 diagnostic<-tab[!is.na(tab$log_probability)&tab$total_umi>0,,drop=FALSE];diagnostic$log10_total<-log10(diagnostic$total_umi);diagnostic$negative_log_probability<- -diagnostic$log_probability
 method<-sprintf("DropletUtils emptyDrops with lower=%s, niters=%s, retain=%s, alpha=%s, ignore=%s, test.ambient=%s; round=FALSE. BH after assigning total>=retain barcodes correction-P0 and excluding totals<=lower. FDR<=%s marks nonempty droplets, not healthy cells. All raw barcodes and counts retained.",a$lower,a$niters,a$retain,a$alpha,a$ignore,a[["test-ambient"]],a$fdr)
 meta<-list(lower=a$lower,fdr=a$fdr,niters=a$niters,retain=a$retain,alpha=a$alpha,ignore=a$ignore,test_ambient=a[["test-ambient"]],refdata=x$provenance,actual_engine=as.character(v),n_zero=sum(!positive),n_ambient=sum(x$ambient),n_tested=sum(ok),n_nonempty=sum(called),n_limited_unresolved=sum(d$Limited&!called,na.rm=TRUE),journal=a$journal,method=method)
 list(tables=list(barcodes=tab,engine_parameters=resolved,ambient_profile=data.frame(feature_id=rownames(x$counts),probability=as.numeric(ambient)),barcode_ranks=ranktab,ambient_diagnostic=diagnostic),object=sce,handoff_type="SingleCellExperiment",ecosystem="bioconductor",state=list(front_end_ecosystem="bioconductor",unfiltered_raw_counts=TRUE,emptydrops_annotated=TRUE,qc_complete=FALSE),metadata=meta,method=method,packages=c("DropletUtils","BiocParallel","SingleCellExperiment"),input_files=list(input=a$input,input_provenance=a[["input-provenance"]],refdata_registry=a[["refdata-registry"]],study_contract=a[["study-contract"]]),ready=FALSE)
}

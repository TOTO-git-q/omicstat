# Explicit-universe over-representation against the SHA-bound installed database.
rpa_ids <- function(path,column) {
 d<-utils::read.csv(path,colClasses="character",check.names=FALSE,stringsAsFactors=FALSE)
 if(!column %in% names(d))stop("OS_MISSING_COLUMN: identifier column is absent",call.=FALSE)
 x<-d[[column]]
 if(!length(x)||anyNA(x)||any(!grepl("^[1-9][0-9]*$",x))||anyDuplicated(x))os_input_stop("unique canonical positive Entrez IDs are required; no implicit conversion or deduplication")
 sort(x,method="radix")
}
rpa_input <- function(a) {
 if(a[["min-size"]]>a[["max-size"]])stop("OS_INVALID_PARAMETER: min-size exceeds max-size",call.=FALSE)
 q<-rpa_ids(a$input,a[["id-column"]]);u<-rpa_ids(a$universe,a[["id-column"]])
 if(length(q)>20000L||length(u)>60000L)stop("OS_INVALID_INPUT: explicit 20000 selected/60000 universe limit exceeded; no downsampling",call.=FALSE)
 if(!all(q %in% u)||setequal(q,u))stop("OS_INVALID_UNIVERSE: selected genes must be a proper subset of the eligible universe",call.=FALSE)
 list(query=q,universe=u)
}
rpa_effective <- function(x,ref,a) {
 annotated<-unique(ref$pairs$gene_id)
 report<-data.frame(gene_id=x$universe,selected=x$universe %in% x$query,annotated=x$universe %in% annotated,stringsAsFactors=FALSE)
 loss_u<-mean(!report$annotated);loss_q<-mean(!x$query %in% annotated)
 if(a[["universe-policy"]]=="strict"&&any(!report$annotated))stop("OS_INVALID_UNIVERSE: unannotated genes forbidden under strict policy",call.=FALSE)
 u<-intersect(x$universe,annotated);q<-intersect(x$query,u)
 if(length(q)<1L||length(u)<=length(q))stop("OS_INVALID_UNIVERSE: effective annotated universe must exceed nonempty selected set",call.=FALSE)
 pairs<-ref$pairs[ref$pairs$gene_id %in% u,,drop=FALSE]
 if(nrow(pairs)>2000000L)stop("OS_INVALID_INPUT: two-million effective-membership limit exceeded; no downsampling",call.=FALSE)
 list(query=q,universe=u,report=report,pairs=pairs,loss_u=loss_u,loss_q=loss_q)
}
rpa_compute <- function(a) {
 x<-rpa_input(a);contract<-if(!is.null(a[["study-contract"]]))os_study_contract_read(a[["study-contract"]]) else list(sha256=NULL);ref<-os_reactome_bound(a);eff<-rpa_effective(x,ref,a)
 ans<-ReactomePA::enrichPathway(gene=eff$query,pvalueCutoff=1,pAdjustMethod="BH",universe=eff$universe,minGSSize=a[["min-size"]],maxGSSize=a[["max-size"]],qvalueCutoff=1,organism=a$organism,readable=FALSE)
 if(is.null(ans))stop("OS_EMPTY_DATA: no nonzero overlap met declared set-size limits",call.=FALSE)
 raw<-as.data.frame(methods::slot(ans,"result"),stringsAsFactors=FALSE)
 if(!nrow(raw))stop("OS_EMPTY_DATA: no testable pathways",call.=FALSE)
 need<-c("ID","Description","GeneRatio","BgRatio","pvalue","p.adjust","Count","geneID")
 if(!all(need %in% names(raw))||anyDuplicated(raw$ID)||any(!is.finite(raw$pvalue))||any(!is.finite(raw$p.adjust)))stop("OS_INVALID_RESULT: invalid enrichment result",call.=FALSE)
 sets<-split(eff$pairs$gene_id,eff$pairs$term_id);N<-length(eff$universe);n<-length(eff$query)
 k<-vapply(as.character(raw$ID),function(id)length(intersect(sets[[id]],eff$query)),0L)
 # The engine lists overlapping genes in hash-table order, which differs between processes; restore the selected-set order so replays are byte-identical.
 raw$geneID<-vapply(as.character(raw$ID),function(id)paste(intersect(eff$query,sets[[id]]),collapse="/"),"")
 M<-vapply(as.character(raw$ID),function(id)length(unique(sets[[id]])),0L)
 p<-stats::phyper(q=k-1,m=M,n=N-M,k=n,lower.tail=FALSE,log.p=FALSE)
 adjusted<-stats::p.adjust(p=raw$pvalue,method="BH",n=nrow(raw))
 if(any(M<a[["min-size"]]|M>a[["max-size"]])||any(k!=raw$Count)||any(raw$GeneRatio!=paste(k,n,sep="/"))||any(raw$BgRatio!=paste(M,N,sep="/"))||max(abs(raw$pvalue-p))>1e-10||max(abs(raw$p.adjust-adjusted))>1e-10)stop("OS_INVALID_RESULT: engine count, universe or multiplicity contract drift",call.=FALSE)
 eligible<-vapply(sets,function(z)length(z)>=a[["min-size"]]&&length(z)<=a[["max-size"]]&&any(z %in% eff$query),logical(1))
 if(!setequal(names(sets)[eligible],raw$ID))stop("OS_INVALID_RESULT: incomplete or unexpected tested pathway family",call.=FALSE)
 tab<-data.frame(term_id=as.character(raw$ID),term_name=as.character(raw$Description),pvalue=raw$pvalue,padj=raw$p.adjust,n_genes=k,set_size=M,gene_ratio=k/n,n_effective_input=n,n_effective_background=N,background_ratio=M/N,genes=raw$geneID,significant=raw$p.adjust<a$alpha,test_family="Reactome nonzero-overlap size-eligible pathways",stringsAsFactors=FALSE)
 tab<-tab[order(tab$padj,tab$term_id,method="radix"),,drop=FALSE]
 method<-sprintf("ReactomePA1.56.0 one-sided hypergeometric ORA; explicit annotated background %d, selected %d; BH across %d nonzero-overlap size-eligible pathways. Zero-overlap pathways are outside the upstream testing family. No significance filtering before adjustment. Alpha %s is display/reporting only.",N,n,nrow(tab),a$alpha)
 meta<-list(refdata_id=ref$refdata_id,resource=ref$manifest,provenance=ref$provenance,organism=a$organism,selection_rule=a[["selection-rule"]],universe_policy=a[["universe-policy"]],loss_query=eff$loss_q,loss_universe=eff$loss_u,alpha=a$alpha,top_n=a[["top-n"]],journal=a$journal,n_input=length(x$query),n_universe=length(x$universe),n_tested=nrow(tab),multiplicity=method)
 list(tables=list(enrichment_table=tab,input_mapping=eff$report,effective_memberships=eff$pairs,raw_engine=raw),object=tab,handoff_type="enrichment_table",metadata=meta,method=method,packages=c("ReactomePA","reactome.db",os_reactome_species(a$organism)[2],"enrichit"),input_files=list(input=a$input,universe=a$universe,refdata=a[["refdata-input"]],refdata_provenance=a[["refdata-provenance"]],refdata_registry=a[["refdata-registry"]],study_contract=a[["study-contract"]]),ready=TRUE)
}

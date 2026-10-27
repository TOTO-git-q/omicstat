# Actual native tests; never replace emmeans inference with a mock.
here <- dirname(normalizePath(sub("^--file=","",grep("^--file=",commandArgs(FALSE),value=TRUE)[1])))
root <- normalizePath(file.path(here,"..","..",".."))
for (f in c("module_kit.R","candidate_model.R","effect_table.R")) source(file.path(root,"skills/_shared/scripts",f))
source(file.path(root,"skills/emmeans-contrast/scripts/emmeans_contrast_core.R"))
ex_require("lme4");ex_require("emmeans")
n <- 0L
ok <- function(x, label) {stopifnot(isTRUE(x));n <<- n+1L;cat("PASS",label,"\n")}
same <- function(x,y) isTRUE(all.equal(x,y,tolerance=1e-12))
d <- lme4::sleepstudy
d$period <- cut(d$Days,breaks=c(-1,2,4,6,9),labels=c("A","B","C","D"))
d$cohort <- factor(ifelse(as.integer(d$Subject)<=9,"first","second"))
fit <- lme4::lmer(Reaction~period*cohort+(1|Subject),data=d,REML=TRUE)
ok(!lme4::isSingular(fit),"real converged nonsingular mixed model")
hash <- paste(rep("0",64),collapse="")
tmp <- tempfile("emm-audit-");dir.create(tmp)
saveRDS(fit,file.path(tmp,"model.rds"))
saveRDS(list(n_obs=nrow(d),n_subject=18L,study_contract_sha256=hash),file.path(tmp,"metadata.rds"))
up <- list(module="lme4-lmm",state=list(model_ready=TRUE,development_only=TRUE),
 objects=list(model=list(path=file.path(tmp,"model.rds")),metadata=list(path=file.path(tmp,"metadata.rds"))))
a <- list(factor="period",by=NULL,weights="equal",`df-method`="asymptotic",adjust="none",`ci-level`=.95,`study-contract-sha256`=hash)
for (by in list(NULL,"cohort")) for (adjust in c("none","tukey","bonferroni","sidak")) {
 a$by <- by;a$adjust <- adjust
 got <- emmeans_contrast_compute(a,up)
 ref <- emmeans::emmeans(fit,specs="period",by=by,weights="equal",lmer.df="asymptotic",
  disable.pbkrtest=TRUE,disable.lmerTest=TRUE,pbkrtest.limit=3000L,lmerTest.limit=3000L)
 contrast <- emmeans::contrast(ref,method="pairwise",adjust=adjust)
 tab <- as.data.frame(summary(contrast,infer=c(TRUE,TRUE),level=.95,adjust=adjust,type="link"))
 means <- as.data.frame(summary(ref,infer=c(TRUE,FALSE),level=.95,type="link"))
 raw <- as.data.frame(summary(contrast,infer=c(FALSE,TRUE),adjust="none",type="link"))
 label <- paste(by %||% "all",adjust)
 ok(identical(got$tables$contrasts_native,tab),paste(label,"original contrast numerical and attribute parity"))
 ok(identical(got$tables$marginal_means,means),paste(label,"original pointwise mean interval parity"))
 ok(same(got$tables$effect_table$p_value,raw$p.value),paste(label,"raw P from independent native call"))
 ok(same(got$tables$effect_table$p_adjusted,tab$p.value),paste(label,"adjusted P from independent native call"))
 meta <- got$metadata$emmeans$summaries
 ok(identical(meta$contrasts_native$native_messages,attr(tab,"mesg")),paste(label,"all native messages retained"))
 ok(identical(meta$contrasts_native$native_summary_adjustment,attr(tab,"adjust")),paste(label,"actual native adjustment attribute"))
 ok(identical(meta$marginal_means$requested_adjustment,"none"),paste(label,"means explicitly unadjusted"))
 families <- got$tables$inference_families
 ok(all(families$cross_adjustment=="none"),paste(label,"no cross-family correction"))
 ok(all(families$rows_in_family[families$table=="contrasts_native"]==6L),paste(label,"six contrast rows per four-level family"))
 ok(all(families$rows_in_family[families$table=="marginal_means"]==4L),paste(label,"four mean rows distinct from contrast count"))
 ok(nrow(families)==if(is.null(by))3L else 6L,paste(label,"three separate table families per stratum"))
 if (!is.null(by)) ok(identical(unique(families$by_value),c("first","second")),paste(label,"by strata auditable"))
 saveRDS(got$metadata,file.path(tmp,"audit.rds"))
 ok(identical(readRDS(file.path(tmp,"audit.rds")),got$metadata),paste(label,"metadata survives serialization"))
 utils::write.csv(families,file.path(tmp,"inference_families.csv"),row.names=FALSE)
 ok(nrow(utils::read.csv(file.path(tmp,"inference_families.csv")))==nrow(families),paste(label,"CSV family metadata persists"))
}
# User/global emmeans options cannot change the declared mean-interval adjustment.
a$by <- "cohort";a$adjust <- "tukey"
before <- emmeans_contrast_compute(a,up)
old <- emmeans::emm_options(summary=list(adjust="bonferroni",cross.adjust="bonferroni"))
after <- tryCatch(emmeans_contrast_compute(a,up),finally=emmeans::emm_options(old))
ok(identical(before$tables$marginal_means,after$tables$marginal_means),"global summary options cannot alter explicit mean adjustment")
ok(identical(before$tables$contrasts_native,after$tables$contrasts_native),"global summary options cannot add cross-family adjustment")
# Holm is not exposed by the CLI. Test the annotation helper against its native
# different CI/P methods to prevent mistaking the common adjust attribute for CI.
ref <- emmeans::emmeans(fit,"period",weights="equal",lmer.df="asymptotic")
holm <- as.data.frame(summary(emmeans::contrast(ref,"pairwise"),infer=c(TRUE,TRUE),adjust="holm"))
h <- emmeans_summary_audit(holm,"native_probe","holm",NULL,TRUE,TRUE)
ok(any(grepl("Conf-level adjustment: bonferroni",h$metadata$native_messages,fixed=TRUE)),"native Holm probe retains Bonferroni CI message")
ok(any(grepl("P value adjustment: holm",h$metadata$native_messages,fixed=TRUE)),"native Holm probe retains Holm P message")
ok(!"ci_adjustment" %in% names(h$metadata),"no fabricated CI method from summary adjust attribute")
bad <- holm;attr(bad,"adjust") <- NULL
ok(inherits(tryCatch(emmeans_summary_audit(bad,"bad","holm",NULL,TRUE,TRUE),error=function(e)e),"error"),"missing native adjustment fails closed")
ok(inherits(tryCatch(emmeans_summary_audit(holm,"bad","holm","cohort",TRUE,TRUE),error=function(e)e),"error"),"changed by family fails closed")
cat("Actual runtime R",as.character(getRversion()),"emmeans",as.character(utils::packageVersion("emmeans")),"lme4",as.character(utils::packageVersion("lme4")),"\n")
cat(n,"adjustment audit checks passed. Production-pinned image remains unverified.\n")
unlink(tmp,recursive=TRUE)

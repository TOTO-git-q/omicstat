# Development validation only. No golden or locked-document anchor assertions yet.
here <- dirname(normalizePath(sub("^--file=","",grep("^--file=",commandArgs(FALSE),value=TRUE)[1])))
module <- dirname(here)
source(file.path(module,"..","_shared","scripts","module_kit.R"))
source(file.path(module,"..","_shared","scripts","candidate_model.R"))
source(file.path(module,"..","_shared","scripts","effect_table.R"))
source(file.path(module,"scripts","lme4_lmm_core.R"))
expect_error <- function(expr) { hit <- tryCatch({force(expr);FALSE},error=function(e) TRUE);stopifnot(hit) }
expect_error(ex_numeric(c("1","bad"),"test"))
expect_error(ex_formula("y ~ system('echo unsafe')",c("y","x")))
stopifnot(inherits(ex_formula("y ~ x + (1 | subject)",c("y","x","subject")),"formula"))
cat("Input validation checks passed. Numerical, CLI, replay and golden acceptance are still required.\n")
source(file.path(module,"..","_shared","scripts","module_kit.R"))
ex_require("lme4")
d <- lme4::sleepstudy
f <- tempfile(fileext=".csv");utils::write.csv(d,f,row.names=FALSE)
a <- list(input=f,response="Reaction",subject="Subject",formula="Reaction ~ Days + (Days | Subject)",estimation="REML",`singular-tolerance`=1e-4,`ci-level`=.95,`study-contract-sha256`=paste(rep("0",64),collapse=""))
r <- lme4_lmm_compute(a)
ref <- lme4::lmer(Reaction~Days+(Days|Subject),data=d,REML=TRUE,control=lme4::lmerControl(optimizer="nloptwrap"))
stopifnot(isTRUE(all.equal(unname(r$tables$effect_table$estimate),unname(lme4::fixef(ref)),tolerance=1e-8)))
stopifnot(r$metadata$n_subject==18L,r$metadata$n_obs==180L,all(is.na(r$tables$effect_table$p_value)))
a_bad <- a;a_bad$formula <- "Reaction ~ Days + I(Days^2) + (1 | Subject)";expect_error(lme4_lmm_compute(a_bad))
cat("Direct-package LMM equivalence passed; this is not a locked official anchor or full acceptance.\n")

# || expands to multiple terms but still names one subject grouping factor.
a_uncor <- a;a_uncor$formula <- "Reaction ~ Days + (Days || Subject)"
r_uncor <- lme4_lmm_compute(a_uncor)
ref_uncor <- lme4::lmer(Reaction~Days+(Days||Subject),data=d,REML=TRUE,control=lme4::lmerControl(optimizer="nloptwrap"))
stopifnot(isTRUE(all.equal(unname(lme4::fixef(r_uncor$object)),unname(lme4::fixef(ref_uncor)),tolerance=1e-8)))
bad_groups <- a;bad_groups$formula <- "Reaction ~ Days + (1 | Subject) + (1 | Days)"
expect_error(lme4_lmm_compute(bad_groups))
stopifnot(is.data.frame(stats::getCall(r$object)$data),is.logical(stats::getCall(r$object)$REML))
cat("Uncorrelated-slope and self-contained-call assertions passed.\n")

a_split <- a;a_split$formula <- "Reaction ~ Days + (1 | Subject) + (0 + Days | Subject)"
r_split <- lme4_lmm_compute(a_split)
stopifnot(isTRUE(all.equal(unname(lme4::fixef(r_split$object)),unname(lme4::fixef(ref_uncor)),tolerance=1e-8)))
a_fixed <- a;a_fixed$formula <- "Reaction ~ Days";expect_error(lme4_lmm_compute(a_fixed))

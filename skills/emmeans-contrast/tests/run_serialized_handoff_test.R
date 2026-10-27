# Deferred runtime regression: producer and consumer must be separate R processes.
# Run only after testing is resumed in the approved compatible isolated environment.
argv <- commandArgs(TRUE)
script <- normalizePath(sub("^--file=","",grep("^--file=",commandArgs(FALSE),value=TRUE)[1]))
root <- normalizePath(file.path(dirname(script),"..","..",".."))
source(file.path(root,"skills/_shared/scripts/module_kit.R"))
source(file.path(root,"skills/_shared/scripts/candidate_model.R"))
source(file.path(root,"skills/_shared/scripts/effect_table.R"))
source(file.path(root,"skills/_shared/scripts/module_kit.R"))
source(file.path(root,"skills/lme4-lmm/scripts/lme4_lmm_core.R"))
source(file.path(root,"skills/emmeans-contrast/scripts/emmeans_contrast_core.R"))
for (pkg in c("lme4","emmeans","lmerTest","pbkrtest")) ex_require(pkg)
hash <- paste(rep("0",64),collapse="")
if (!length(argv)) {
 tmp <- tempfile("serialized-lmm-");dir.create(tmp)
 run_child <- function(mode) {
  status <- system2(file.path(R.home("bin"),"Rscript"),c("--vanilla",shQuote(script),mode,shQuote(tmp)))
  if (!identical(status,0L)) stop(paste(mode,"child failed with status",status))
 }
 run_child("produce");run_child("consume")
 unlink(tmp,recursive=TRUE)
 cat("Cross-process serialized LMM/EMM regression passed; not full acceptance.\n")
} else if (argv[1]=="produce") {
 tmp <- argv[2]
 options(contrasts=c("contr.treatment","contr.poly"))
 d <- lme4::sleepstudy
 d$period <- factor(ifelse(d$Days<5,"early","late"),levels=c("early","late"))
 input <- file.path(tmp,"input.csv");utils::write.csv(d,input,row.names=FALSE)
 a <- list(input=input,response="Reaction",subject="Subject",formula="Reaction ~ period + (1 | Subject)",
  estimation="REML",`singular-tolerance`=1e-4,`ci-level`=.95,`study-contract-sha256`=hash)
 r <- lme4_lmm_compute(a);stopifnot(r$ready)
 saveRDS(r$object,file.path(tmp,"model.rds"));saveRDS(r$metadata,file.path(tmp,"metadata.rds"))
 # Direct upstream reference is made while original data are available.
 ref <- lmerTest::lmer(Reaction~period+(1|Subject),data=d,REML=TRUE,control=lme4::lmerControl(optimizer="nloptwrap"))
 expected <- lapply(c("asymptotic","kenward-roger","satterthwaite"),function(df) {
  emm <- emmeans::emmeans(ref,"period",weights="equal",lmer.df=df,
   disable.pbkrtest=df!="kenward-roger",disable.lmerTest=df!="satterthwaite",
   pbkrtest.limit=3000L,lmerTest.limit=3000L)
  as.data.frame(summary(emmeans::contrast(emm,"pairwise",adjust="none"),infer=c(TRUE,TRUE),type="link"))
 })
 names(expected) <- c("asymptotic","kenward-roger","satterthwaite")
 saveRDS(expected,file.path(tmp,"expected.rds"))
 unlink(input) # consumer cannot reconstruct from original CSV
} else if (argv[1]=="consume") {
 tmp <- argv[2]
 options(contrasts=c("contr.sum","contr.poly")) # deliberately differ from producer
 stopifnot(!exists("d",inherits=FALSE),!exists("a",inherits=FALSE),!exists("f",inherits=FALSE))
 expected <- readRDS(file.path(tmp,"expected.rds"))
 up <- list(module="lme4-lmm",state=list(model_ready=TRUE,development_only=TRUE),
  objects=list(model=list(path=file.path(tmp,"model.rds")),metadata=list(path=file.path(tmp,"metadata.rds"))))
 for (df in names(expected)) {
  args <- list(factor="period",by=NULL,weights="equal",`df-method`=df,adjust="none",`ci-level`=.95,`study-contract-sha256`=hash)
  got <- emmeans_contrast_compute(args,up)$tables$contrasts_native
  ref <- expected[[df]]
  lo <- if(df=="asymptotic") "asymp.LCL" else "lower.CL"
  hi <- if(df=="asymptotic") "asymp.UCL" else "upper.CL"
  for (nm in c("estimate","SE","df",lo,hi,"p.value"))
   stopifnot(isTRUE(all.equal(got[[nm]],ref[[nm]],tolerance=1e-8)))
  if (df!="asymptotic") stopifnot(all(is.finite(got$df)),all(got$df>0)) else stopifnot(all(is.infinite(got$df)),all(got$df>0))
 }
} else stop("Unknown regression child mode")

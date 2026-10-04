# Shared lane smoke harness; all data come from verified upstream runs.
os_seurat_test_setup <- function(module) {
 script <- normalizePath(sub("^--file=","",grep("^--file=",commandArgs(FALSE),value=TRUE)[1]))
 root <- normalizePath(file.path(dirname(script),"..","..",".."))
 mod <- file.path(root,"skills",module)
 for(f in c("module_kit.R","handoff.R","calls_check.R","fig_all.R","convert.R","sc_seurat_io.R")) source(file.path(root,"skills","_shared","scripts",f),local=.GlobalEnv)
 list(root=root,mod=mod,scratch=Sys.getenv("OMICSTAT_TEST_TMP",tempdir()),module=module)
}
os_seurat_test_run <- function(root,module,argv,expected=NULL) {
 pos <- which(startsWith(argv,"--")); dup <- pos[duplicated(argv[pos],fromLast=TRUE)]
 if(length(dup)) argv <- argv[-sort(unique(c(dup,dup+1L)))]
 log <- tempfile(tmpdir=Sys.getenv("OMICSTAT_TEST_TMP",tempdir()))
 status <- system2("Rscript",c(file.path(root,"skills",module,"scripts",paste0("run_",gsub("-","_",module),".R")),shQuote(argv)),stdout=log,stderr=log)
 txt <- paste(readLines(log,warn=FALSE),collapse="\n")
 if(is.null(expected) && status!=0L) stop(txt)
 if(!is.null(expected) && !(status!=0L && grepl(expected,txt,fixed=TRUE))) stop(paste("FAIL expected",expected,txt))
 invisible(txt)
}
os_seurat_test_static <- function(ctx) {
 for(tool in c("check_defaults.py","check_flag_docs.py","lint_r.py")) stopifnot(system2("python3",c(file.path(ctx$root,"tools",tool),ctx$mod))==0L)
 reg <- file.path(ctx$mod,"scripts","calls_registry.json")
 cc <- check_calls(list.files(file.path(ctx$mod,"scripts"),pattern="[.]R$",full.names=TRUE),reg)
 dd <- check_default_drift(reg)
 if(!cc$ok || !dd$ok) stop(paste(c(cc$problems,dd$problems),collapse="; "))
 cat("PASS static calls/default drift/docs/lint\n")
}
os_seurat_test_qc <- function(root,mat=NULL,tag="qc_chain") {
 archive <- file.path(root,"acceptance","data","pbmc3k_filtered_gene_bc_matrices.tar.gz")
 if(!file.exists(archive)) { cat("SKIP missing PBMC anchor\n"); quit(status=0) }
 stopifnot(digest::digest(file=archive,algo="sha256")=="847d6ebd9a1ec9a768f2be7e40ca42cbfe75ebeb6d76a4c24167041699dc28b5")
 raw <- file.path(Sys.getenv("OMICSTAT_TEST_TMP",tempdir()),"pbmc3k"); dir.create(raw,showWarnings=FALSE); utils::untar(archive,exdir=raw)
 input <- file.path(raw,"filtered_gene_bc_matrices","hg19"); fmt <- "10x"
 if(!is.null(mat)) { input <- file.path(Sys.getenv("OMICSTAT_TEST_TMP",tempdir()),paste0(tag,".rds")); saveRDS(mat,input); fmt <- "rds" }
 out <- file.path(Sys.getenv("OMICSTAT_TEST_TMP",tempdir()),tag)
 os_seurat_test_run(root,"seurat-qc",c("--input",input,"--input-format",fmt,"--organism","Homo_sapiens","--feature-type","symbol","--mito-pattern","^MT-","--min-cells","3","--create-min-features","200","--min-features","200","--max-features","2500","--min-counts","0","--max-counts","1000000000","--max-mito","5","--outdir",out))
 out
}
os_seurat_test_cluster <- function(root,up,tag="cluster_chain",extra=character(0)) {
 out <- file.path(Sys.getenv("OMICSTAT_TEST_TMP",tempdir()),tag)
 os_seurat_test_run(root,"seurat-cluster",c("--from-run",up,"--normalization","LogNormalize","--n-hvg","2000","--n-pcs","50","--dims","10","--neighbors","20","--umap-neighbors","30","--resolution","0.5",extra,"--outdir",out))
 out
}
os_seurat_test_determinism <- function(ctx,out,paths) {
 replay <- paste0(out,"_replay")
 os_seurat_test_run(ctx$root,ctx$module,c("--spec",file.path(out,"provenance","resolved_spec.json"),"--outdir",replay))
 for(p in paths) stopifnot(identical(digest::digest(file=file.path(out,p),algo="sha256"),digest::digest(file=file.path(replay,p),algo="sha256")))
 cat("PASS --spec determinism tables/PNGs\n")
}
os_seurat_test_handoffs <- function(ctx,up,base) {
 # Manifest mutations are restored; hash checks still precede input reads.
 path <- file.path(up,"objects","handoff.json"); original <- readLines(path,warn=FALSE)
 h <- jsonlite::fromJSON(path,simplifyVector=FALSE)
 run <- function(code) os_seurat_test_run(ctx$root,ctx$module,c(base,"--from-run",up,"--outdir",paste0(up,"_bad")),code)
 h$ecosystem <- "bioconductor"; jsonlite::write_json(h,path,auto_unbox=TRUE,pretty=TRUE,null="null"); run("OS_ECOSYSTEM_MIXED")
 h$ecosystem <- "neutral"; h$state$front_end_ecosystem <- "scverse"; jsonlite::write_json(h,path,auto_unbox=TRUE,pretty=TRUE,null="null"); run("OS_ECOSYSTEM_MIXED")
 h$ecosystem <- "seurat"; h$state$front_end_ecosystem <- "seurat"; h$state$batch_corrected_lineage <- TRUE; jsonlite::write_json(h,path,auto_unbox=TRUE,pretty=TRUE,null="null"); run("OS_BATCH_CORRECTED_INPUT")
 h$state$batch_corrected_lineage <- FALSE; h$state$seurat$qc_done <- FALSE; jsonlite::write_json(h,path,auto_unbox=TRUE,pretty=TRUE,null="null"); run("OS_CHAIN_STATE")
 os_write_text(original,path)
 h <- jsonlite::fromJSON(path,simplifyVector=FALSE); i <- which(vapply(h$objects,function(o) o$name=="seurat",TRUE)); h$objects[[i]]$sha256 <- "tampered"; jsonlite::write_json(h,path,auto_unbox=TRUE,pretty=TRUE,null="null"); run("OS_HANDOFF_MISMATCH")
 os_write_text(original,path)
 cat("PASS typed ecosystem/neutral lineage/corrected lineage/state/tamper handoffs\n")
}
os_seurat_test_finish <- function(ctx,out,paths) {
 if(Sys.getenv("OMICSTAT_WRITE_GOLDEN")=="1") os_golden_write(ctx$mod,out,paths)
 g <- os_golden_check(ctx$mod,out); if(g$status!="PASS") stop(paste("FAIL golden",g$status,paste(g$problems,collapse=",")))
 stopifnot(!file.exists(file.path(ctx$root,"Rplots.pdf")))
 cat("PASS container goldens and no Rplots.pdf\n")
}

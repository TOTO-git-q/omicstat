# requires: clusterProfiler, DOSE, org.Hs.eg.db, GO.db, jsonlite, digest
here <- dirname(normalizePath(sub("^--file=","",grep("^--file=",commandArgs(FALSE),value=TRUE)[1])))
mdir <- dirname(here); suite <- normalizePath(file.path(mdir,"..",".."))
for (f in c("module_kit.R","calls_check.R")) source(file.path(suite,"skills","_shared","scripts",f))
source(file.path(here,"fixtures","make_gcsample.R"))
fail <- character()
check <- function(ok,msg){cat(if(isTRUE(ok))"PASS: " else "FAIL: ",msg,"\n",sep="");if(!isTRUE(ok))fail<<-c(fail,msg)}
reg <- file.path(mdir,"scripts","calls_registry.json"); scripts <- list.files(file.path(mdir,"scripts"),pattern="[.]R$",full.names=TRUE)
check(check_calls(scripts,reg)$ok,"call registry")
check(check_default_drift(reg)$ok,"container formals")
for(nm in c("check_defaults.py","check_flag_docs.py","lint_r.py")){
 z<-suppressWarnings(system2("python3",shQuote(c(file.path(suite,"tools",nm),if(nm=="lint_r.py")file.path(mdir,"scripts") else mdir)),stdout=TRUE,stderr=TRUE))
 check(is.null(attr(z,"status"))||attr(z,"status")==0L,paste(nm,paste(z,collapse=" | ")))
}
tmp<-Sys.getenv("OMICSTAT_TEST_TMP",file.path(tempdir(),"compare_smoke")); dir.create(tmp,recursive=TRUE,showWarnings=FALSE)
fixture<-cx_make_gcsample(file.path(tmp,"fixture"))
entry<-file.path(mdir,"scripts","run_clusterprofiler_compare.R")
run<-function(args)suppressWarnings(system2("Rscript",shQuote(c(entry,args)),stdout=TRUE,stderr=TRUE))
status<-function(z)attr(z,"status") %||% 0L
den<-function(z)as.integer(vapply(strsplit(as.character(z),"/",fixed=TRUE),`[`,"",2))
key<-function(d)paste(d$Cluster,d$ID)

# ---- (1) Suite enforced-background preset test (ADAPTED fixture, not the original example) ----
# gcSample lists intersected with DOSE geneList, whose 12495 IDs are used as an explicit common
# universe. Independent direct compareCluster call in this session; replay kind: suite preset.
one<-file.path(tmp,"anchor")
z<-run(c("--manifest",fixture$manifest,"--outdir",one));check(status(z)==0L,paste("suite preset (adapted gcSample fixture) run",paste(z,collapse=" | ")))
if(status(z)==0L){
 tab<-read.csv(file.path(one,"tables","enrichment_full.csv"),check.names=FALSE)
 ref<-clusterProfiler::compareCluster(geneClusters=fixture$lists,fun="enrichGO",data="",source_from=NULL,
   OrgDb=org.Hs.eg.db::org.Hs.eg.db,keyType="ENTREZID",ont="BP",pool=FALSE,
   universe=fixture$universe,pvalueCutoff=1,qvalueCutoff=1,pAdjustMethod="BH",
   minGSSize=10,maxGSSize=500,readable=FALSE)
 exp<-as.data.frame(ref)
 check(nrow(tab)==nrow(exp)&&identical(as.character(tab$Cluster),as.character(exp$Cluster))&&
       identical(tab$ID,exp$ID)&&isTRUE(all.equal(tab$p.adjust,exp$p.adjust,tolerance=1e-14)),
       sprintf("suite preset replay (adapted fixture): %d rows, %d BH 0.05 rows",nrow(exp),sum(exp$p.adjust<0.05,na.rm=TRUE)))
 defs<-read.csv(file.path(one,"tables","list_definitions.csv"))
 check(nrow(defs)==8&&all(defs$n_candidate_background==12495)&&all(defs$n_effective_background==11525),"per-list candidate/effective background")
 fam<-read.csv(file.path(one,"tables","test_families.csv"),stringsAsFactors=FALSE)
 check(nrow(fam)==8&&all(fam$test_family=="GO BP")&&all(fam$n_effective_background==11525)&&
       identical(fam$n_effective_input,defs$n_effective_input)&&all(den(tab$GeneRatio)==fam$n_effective_input[match(tab$Cluster,fam$group)]),
       "BP: one testing family per list; denominators per row")
 check(all(c("pvalue","p.adjust","qvalue","significant_bh05","group","population","test_family")%in%names(tab)),"full table and metadata")
 check(file.exists(file.path(one,"figures","compare_dotplot.figure_spec.json")),"figure specification")
 rep<-file.path(tmp,"replay");z<-run(c("--spec",file.path(one,"provenance","resolved_spec.json"),"--outdir",rep))
 check(status(z)==0L,"resolved spec replay")
 if(status(z)==0L)for(p in c("tables/enrichment_full.csv","figures/compare_dotplot.png"))
   check(identical(digest::digest(file=file.path(one,p),algo="sha256"),digest::digest(file=file.path(rep,p),algo="sha256")),paste("byte-identical",p))
 if(identical(Sys.getenv("OMICSTAT_WRITE_GOLDEN"),"1"))
   os_golden_write(mdir,one,c("tables/enrichment_full.csv","tables/list_definitions.csv","tables/test_families.csv",
                              "results/clusterprofiler_compare_results.json","figures/compare_dotplot.figure_spec.json"))
 g<-os_golden_check(mdir,one);check(g$status%in%c("PASS","SKIP"),paste("golden",g$status,paste(g$problems,collapse=",")))
}

# ---- (2) F1 / contract (d): GO ALL with pool FALSE and TRUE on lists X1, X2 ----
fxdir<-dirname(fixture$manifest)
two<-read.csv(fixture$manifest,stringsAsFactors=FALSE)[1:2,]
twofile<-file.path(fxdir,"all_manifest.csv");write.csv(two,twofile,row.names=FALSE)
all_run<-function(pool,want){
 out<-file.path(tmp,paste0("all_pool_",pool))
 z<-run(c("--manifest",twofile,"--ontology","ALL","--pool",pool,"--outdir",out))
 check(status(z)==0L,paste("ALL pool",pool,"run",paste(tail(z,3),collapse=" | ")))
 if(status(z)!=0L)return(invisible(NULL))
 tab<-read.csv(file.path(out,"tables","enrichment_full.csv"),check.names=FALSE,stringsAsFactors=FALSE)
 fam<-read.csv(file.path(out,"tables","test_families.csv"),stringsAsFactors=FALSE)
 defs<-read.csv(file.path(out,"tables","list_definitions.csv"),stringsAsFactors=FALSE)
 check(identical(paste(fam$group,fam$test_family),want$family)&&identical(fam$n_effective_input,want$input)&&
       identical(fam$n_effective_background,want$background),
       sprintf("ALL pool %s: %s input %s background %s",pool,paste(fam$group,sub("GO ","",fam$test_family),collapse="/"),
               paste(fam$n_effective_input,collapse="/"),paste(fam$n_effective_background,collapse="/")))
 k<-match(paste(tab$group,tab$test_family),paste(fam$group,fam$test_family))
 check(!anyNA(k)&&all(den(tab$GeneRatio)==fam$n_effective_input[k])&&all(den(tab$BgRatio)==fam$n_effective_background[k]),
       paste("ALL pool",pool,"every list-term row keeps its own family's denominators"))
 check(identical(defs$effective_input_by_family,want$def_input)&&identical(defs$effective_background_by_family,want$def_bg)&&
       identical(as.integer(defs$n_effective_input),want$def_n_input),
       paste("ALL pool",pool,"list_definitions:",paste(defs$effective_input_by_family,collapse=" | ")))
 d<-as.data.frame(clusterProfiler::compareCluster(geneClusters=fixture$lists[1:2],fun="enrichGO",data="",source_from=NULL,
   OrgDb=org.Hs.eg.db::org.Hs.eg.db,keyType="ENTREZID",ont="ALL",pool=identical(pool,"TRUE"),
   universe=fixture$universe,pvalueCutoff=1,qvalueCutoff=1,pAdjustMethod="BH",minGSSize=10,maxGSSize=500,readable=FALSE))
 check(identical(key(tab),key(d))&&identical(tab$GeneRatio,d$GeneRatio)&&identical(tab$BgRatio,d$BgRatio)&&
       isTRUE(all.equal(tab$p.adjust,d$p.adjust,tolerance=1e-14)),paste("ALL pool",pool,"replay equals direct compareCluster"))
 f<-if(identical(pool,"FALSE"))paste(d$Cluster,d$ONTOLOGY) else as.character(d$Cluster)
 bh<-stats::ave(d$pvalue,f,FUN=function(p)stats::p.adjust(p,method="BH"))
 check(max(abs(bh-d$p.adjust))<1e-14,paste("ALL pool",pool,"p.adjust is BH within",if(identical(pool,"FALSE"))"list x ontology" else "list"))
 draft<-paste(readLines(file.path(out,"draft","methods_results.md"),warn=FALSE),collapse="\n")
 check(grepl(want$text,draft,fixed=TRUE),paste("ALL pool",pool,"Methods state per-family denominators and BH scope"))
}
all_run("FALSE",list(family=paste(rep(c("X1","X2"),each=3),c("GO BP","GO CC","GO MF")),
  input=c(198L,201L,205L,746L,768L,758L),background=rep(c(11525L,11914L,11822L),2),
  def_input=c("BP=198;CC=201;MF=205","BP=746;CC=768;MF=758"),def_bg=rep("BP=11525;CC=11914;MF=11822",2),def_n_input=c(NA_integer_,NA_integer_),
  text="(list: ontology input/background = X1 BP 198/11525, CC 201/11914, MF 205/11822; X2 BP 746/11525, CC 768/11914, MF 758/11822)."))
all_run("TRUE",list(family=c("X1 GO ALL pooled","X2 GO ALL pooled"),input=c(206L,778L),background=c(12112L,12112L),
  def_input=sprintf("ALL pooled=%d",c(206L,778L)),def_bg=rep(sprintf("ALL pooled=%d",12112L),2),def_n_input=c(206L,778L),
  text=sprintf("(list: input/background = X1 ALL pooled %d/%d; X2 ALL pooled %d/%d).",206L,12112L,778L,12112L)))

# ---- (3) F2: replay of the ORIGINAL book example on the UNMODIFIED gcSample lists ----
# Source: clusterProfiler book, comparecluster-analysis.qmd lines 31-42 at commit
# 549613197f7953b97bf1346cc81eb0e1c61b6dbc (sha256 e4c2ea01...a6ab, L2/manifest.tsv).
# The book code is run verbatim below (reference replay); the module is then run on the
# same unmodified lists with enrichGO's implicit default universe made explicit (see
# fixtures/make_gcsample.R). Replay kind: guide code in the same session vs engine.
# The book page source has no printed values (outputs are rendered online from the
# development versions), so there is no printed anchor to assert.
suppressPackageStartupMessages({library(clusterProfiler);library(org.Hs.eg.db)})
book<-local({
 data(gcSample)
 ck <- compareCluster(geneCluster = gcSample, fun = enrichGO,
                     OrgDb = org.Hs.eg.db, ont="BP")
 ck <- setReadable(ck, OrgDb = org.Hs.eg.db, keyType="ENTREZID")
 head(ck)
 as.data.frame(ck)
})
orig<-cx_make_gcsample_original(file.path(tmp,"original"))
check(identical(unname(lengths(orig$lists)),c(216L,805L,392L,838L,929L,585L,582L,237L)),"original gcSample lists unmodified (216/805/392/838/929/585/582/237)")
out<-file.path(tmp,"original_replay")
z<-run(c("--manifest",orig$manifest,"--outdir",out))
check(status(z)==0L,paste("original example replay run",paste(tail(z,3),collapse=" | ")))
if(status(z)==0L){
 tab<-read.csv(file.path(out,"tables","enrichment_full.csv"),check.names=FALSE,stringsAsFactors=FALSE)
 # The book call keeps its default cutoffs; enrichit::get_enriched (locked 0.2.1) reports
 # rows with pvalue <= 0.05, p.adjust <= 0.05 and qvalue <= 0.2. The module keeps the full table.
 sel<-tab$pvalue<=0.05&tab$p.adjust<=0.05&tab$qvalue<=0.2
 m<-match(key(book),key(tab))
 check(nrow(book)==1020&&sum(sel)==nrow(book)&&setequal(key(tab[sel,]),key(book))&&!anyNA(m),
       sprintf("original example: book code reports %d list-term rows; the module's full table (%d rows) contains exactly these under the book cutoffs",nrow(book),nrow(tab)))
 # Module values are read back from its CSV (15 significant digits), hence the 1e-14 relative
 # tolerance used by every table anchor of this suite; ratios must be identical strings.
 check(isTRUE(all.equal(tab$pvalue[m],book$pvalue,tolerance=1e-14))&&isTRUE(all.equal(tab$p.adjust[m],book$p.adjust,tolerance=1e-14))&&
       isTRUE(all.equal(tab$qvalue[m],book$qvalue,tolerance=1e-14))&&
       identical(tab$GeneRatio[m],book$GeneRatio)&&identical(tab$BgRatio[m],book$BgRatio),
       sprintf("original example: pvalue, p.adjust, qvalue equal (rel. 1e-14) and GeneRatio/BgRatio identical to the book code output; first row %s %s padj %.12g",
               book$Cluster[1],book$ID[1],book$p.adjust[1]))
 per<-as.integer(table(factor(book$Cluster,levels=names(orig$lists))))
 check(identical(per,c(6L,149L,71L,69L,68L,99L,274L,284L)),paste("original example rows per list X1..X8:",paste(per,collapse="/")))
 fam<-read.csv(file.path(out,"tables","test_families.csv"),stringsAsFactors=FALSE)
 check(all(fam$n_effective_background==18842)&&identical(fam$n_effective_input,c(198L,761L,351L,793L,884L,544L,558L,234L))&&
       all(unique(den(book$BgRatio))=="18842"),
       "original example: effective background 18842 (all GO BP annotated genes) and inputs 198/761/351/793/884/544/558/234")
}

# ---- (4) Different selectable population: DOSE-ranked IDs with |score| > 0.2 ----
data(geneList,package="DOSE")
other_bg<-names(geneList)[abs(geneList)>0.2]
write.csv(data.frame(feature_id=other_bg),file.path(fxdir,"eligible2.csv"),row.names=FALSE)
write.csv(data.frame(feature_id=intersect(fixture$lists[[2]],other_bg)),file.path(fxdir,"X2_other.csv"),row.names=FALSE)
mix<-read.csv(fixture$manifest,stringsAsFactors=FALSE)[1:2,]
mix$genes[2]<-"X2_other.csv";mix$universe[2]<-"eligible2.csv"
mix$population[2]<-"DOSE abs(score)>0.2 eligible population (fixture only)"
mix$selection_rule[2]<-"gcSample X2 membership restricted to DOSE abs(score)>0.2 IDs"
mixfile<-file.path(fxdir,"mixed_manifest.csv");write.csv(mix,mixfile,row.names=FALSE)
z<-run(c("--manifest",mixfile,"--outdir",file.path(tmp,"mixed")))
check(status(z)==0L,"different backgrounds routed to separate ORA")
if(status(z)==0L){
 rr<-jsonlite::read_json(file.path(tmp,"mixed","results","clusterprofiler_compare_results.json"),simplifyVector=TRUE)
 check(identical(rr$mode,"separate_background_ORA")&&!file.exists(file.path(tmp,"mixed","figures","compare_dotplot.png")),"no pooled comparison figure for different backgrounds")
}
no_pool<-run(c("--manifest",fixture$manifest,"--ontology","ALL","--outdir",file.path(tmp,"all_no_pool")))
check(status(no_pool)!=0L&&any(grepl("OS_MISSING_PARAMETER",no_pool)),"ALL requires explicit pool")
missing_ref<-run(c("--manifest",fixture$manifest,"--database","KEGG","--outdir",file.path(tmp,"kegg")))
check(status(missing_ref)!=0L&&any(grepl("OS_REFDATA_MISSING",missing_ref)),"missing KEGG typed refusal")
invalid<-read.csv(fixture$manifest,stringsAsFactors=FALSE);invalid$universe[1]<-invalid$genes[1]
invalidfile<-file.path(fxdir,"invalid_manifest.csv");write.csv(invalid,invalidfile,row.names=FALSE)
z<-run(c("--manifest",invalidfile,"--outdir",file.path(tmp,"invalid")))
check(status(z)!=0L&&any(grepl("OS_INVALID_UNIVERSE",z)),"selected list cannot be its own universe")
check(!file.exists(file.path(suite,"Rplots.pdf")),"no Rplots.pdf")
if(length(fail))quit(status=1) else cat("SMOKE PASSED\n")

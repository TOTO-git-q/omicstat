here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])))
mod <- dirname(here); shared <- file.path(mod, "..", "_shared", "scripts")
for (f in c("module_kit.R", "basic_stats_io.R", "calls_check.R")) source(file.path(shared, f))
source(file.path(mod, "scripts/omicstat_ddct_core.R"))
check <- function(ok,msg) {if(!isTRUE(ok))stop(paste("FAIL:",msg));cat("PASS:",msg,"\n")}
refuse <- function(expr,code) {msg<-tryCatch({force(expr);"NO_ERROR"},error=conditionMessage);check(grepl(code,msg,fixed=TRUE),paste("refusal",code))}
tmp<-tempfile();dir.create(tmp)
write<-function(d,name){p<-file.path(tmp,name);write.csv(d,p,row.names=FALSE);p}
proof<-list(schema="omicstat.qpcr-assay.v1",target_genes=list("c-myc"),reference_gene="GAPDH",equal_efficiency_confirmed=TRUE,near_two_amplification_confirmed=TRUE,reference_stability_confirmed=TRUE,source="synthetic declared assay fixture",basis="Unit tests; not real laboratory efficiency evidence")
p<-file.path(tmp,"assay.json");jsonlite::write_json(proof,p,auto_unbox=TRUE)
a<-list(input=file.path(here,"livak_table1.csv"),`ct-col`="ct",`gene-col`="gene",`group-col`="group",`unit-col`="unit",`well-col`="well",`well-layout`="separate",`target-genes`="c-myc",`reference-gene`="GAPDH",`reference-group`="Brain",`group-order`="Brain,Kidney",design="independent",inference="descriptive",`ct-max`=40,`assay-validation`=p,adjust="none",`family-size`=1L,`ci-level`=.95,display="bar",journal="nature")
x<-omicstat_ddct_compute(a);u<-x$tables$biological_units;k<-u[u$group=="Kidney",]
check(nrow(u)==2 && all(u$n_target_technical==6) && is.null(x$tables$tests),"24 wells remain two descriptive biological preparations")
check(abs(k$delta_delta_ct+2.495)<1e-12 && abs(k$fold_change-2^2.495)<1e-12,"within-unit Ct arithmetic and exact fold transformation")
b<-a;b$inference<-"welch";refuse(omicstat_ddct_compute(b),"OS_INVALID_DESIGN")
b<-a;b[["well-layout"]]<-"same";refuse(omicstat_ddct_compute(b),"OS_INVALID_DESIGN")
raw<-read.csv(a$input);b<-a;b$input<-write(raw[rev(seq_len(nrow(raw))),],"reverse.csv")
y<-omicstat_ddct_compute(b);check(isTRUE(all.equal(x$tables,y$tables,tolerance=1e-12)),"row-order independent separate-well normalization")
# Four real declared unit identities in each synthetic group; three technical wells.
z<-expand.grid(subject=1:4,group=c("Brain","Kidney"),gene=c("c-myc","GAPDH"),well=1:3,stringsAsFactors=FALSE)
z$unit<-paste(z$group,z$subject,sep="_");z$well<-paste0("w",z$well)
z$ct<-20+z$subject*.2+as.numeric(sub("w","",z$well))*.1+ifelse(z$gene=="c-myc",5+z$subject*.3-ifelse(z$group=="Kidney",1+z$subject*.1,0),0)
b<-a;b$input<-write(z,"bio.csv");b$inference<-"welch";b[["well-layout"]]<-"same"
y<-omicstat_ddct_compute(b);e<-y$tables$effect_table
check(y$tables$tests$n_treatment_biological==4 && y$tables$tests$n_calibrator_biological==4,"biological inference uses four units rather than twelve wells")
check(abs(e$fold_ci_low-2^(-e$ci_high))<1e-12 && abs(e$fold_ci_high-2^(-e$ci_low))<1e-12,"decreasing fold transform reverses CI endpoints")
check(all(y$tables$biological_units$technical_delta_ct_sd<1e-12),"same-well shared Ct shift cancels before technical SD")
c<-b;c[["well-layout"]]<-"separate";yy<-omicstat_ddct_compute(c)
check(all(yy$tables$biological_units$technical_delta_ct_sd>.1),"separate-well technical variance does not assume pairing")
z$unit<-paste0("subject",z$subject);b$input<-write(z,"paired.csv");b$design<-"paired";b$inference<-"paired-t"
y<-omicstat_ddct_compute(b);check(y$tables$tests$df==3 && y$tables$tests$n_treatment_biological==4,"paired delta-Ct tests biological subjects")
z2<-z;z2$gene[z2$gene=="c-myc"]<-"target2";z2<-z2[z2$gene=="target2",];z2$ct<-z2$ct+.5;both<-rbind(z,z2)
c<-b;c$input<-write(both,"two-targets.csv");c[["target-genes"]]<-"c-myc,target2";c[["family-size"]]<-2;c$adjust<-"holm"
proof$target_genes<-list("c-myc","target2");p2<-file.path(tmp,"two-assays.json");jsonlite::write_json(proof,p2,auto_unbox=TRUE);c[["assay-validation"]]<-p2
y<-omicstat_ddct_compute(c);check(nrow(y$tables$tests)==2 && identical(y$tables$tests$p_adjusted,p.adjust(y$tables$tests$p_value,method="holm",n=2)),"one p-adjustment family spans target genes")
c[["family-size"]]<-1;refuse(omicstat_ddct_compute(c),"OS_INVALID_DESIGN")
for (kind in c("missing-ref","missing-target","missing-pair","duplicate-well","undetermined","over-limit","wrong-proof")) {
 zz<-z;cc<-b
 if(kind=="missing-ref")zz<-zz[!(zz$subject==1 & zz$group=="Kidney" & zz$gene=="GAPDH"),]
 if(kind=="missing-target")zz<-zz[!(zz$subject==1 & zz$group=="Kidney" & zz$gene=="c-myc"),]
 if(kind=="missing-pair")zz<-zz[!(zz$subject==1 & zz$group=="Kidney"),]
 if(kind=="duplicate-well")zz<-rbind(zz,zz[1,])
 if(kind=="undetermined")zz$ct[1]<-NA
 if(kind=="over-limit")zz$ct[1]<-41
 if(kind=="wrong-proof")cc[["assay-validation"]]<-p2
 cc$input<-write(zz,paste0(kind,".csv"));refuse(omicstat_ddct_compute(cc),if(kind %in% c("undetermined","over-limit"))"OS_INVALID_INPUT" else "OS_INVALID_DESIGN")
}
check(check_calls(list.files(file.path(mod,"scripts"),pattern="\\.R$",full.names=TRUE),file.path(mod,"scripts/calls_registry.json"))$ok,"call registry")
check(check_default_drift(file.path(mod,"scripts/calls_registry.json"))$ok,"actual native defaults")
check(!file.exists("Rplots.pdf"),"no device leak")
unlink(tmp,recursive=TRUE);cat("SMOKE PASSED: biological-unit delta-delta-Ct\n")

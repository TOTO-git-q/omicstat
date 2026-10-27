# Project-created artificial fixtures. Never load built-in biological data.
a <- commandArgs(trailingOnly=TRUE); root <- normalizePath(a[1]); out <- a[2]
dir.create(out,recursive=TRUE,showWarnings=FALSE)
journal <- Sys.getenv('P012_BASELINE_JOURNAL', 'nature');options(omicstat.journal=journal)
stopifnot(identical(digest::digest(file=file.path(root,"skills/_shared/scripts/fig_heatmap.R"),algo="sha256"),"27ed291ecf6abad456a49019a443132733a99ef888907af9218ee32b7fdb6a49"))
stopifnot(identical(digest::digest(file=file.path(root,"skills/_shared/scripts/fig_mod_models.R"),algo="sha256"),"455d990c3d0ef19edd824257b40c56024cbb2b545912fb44af3aa532834569d3"))
stopifnot(identical(digest::digest(file=file.path(root,"skills/_shared/scripts/fig_mod_sc_seurat.R"),algo="sha256"),"f19408ac8b129b5a69ca4c107b38507f91c9736ade82a3e8bad3f98782604ef0"))
stopifnot(identical(digest::digest(file=file.path(root,"skills/_shared/scripts/fig_mod_calibration.R"),algo="sha256"),"35218d032654804448a49854e0b80bf5ea169d9e3a573319116d50a546b6be68"))
stopifnot(identical(digest::digest(file=file.path(root,"skills/_shared/scripts/fig_evidence.R"),algo="sha256"),"134625f7da21e2ff9d676e2f0750c63f1a5c4dd0aa90dac30adfa5a4b1044b84"))
stopifnot(identical(digest::digest(file=file.path(root,"skills/_shared/scripts/fig_mod_sc_bioc.R"),algo="sha256"),"e9e97a01be7b8d833c0cfc57bcca2ddabefc4ca9d7ed3fd1c29dfd7ab8174661"))
stopifnot(identical(digest::digest(file=file.path(root,"skills/_shared/scripts/fig_mod_cnv.R"),algo="sha256"),"6a8e6228e62d3aeda5ae3ee7f007acb5132f279365cfb2fc604fe665978dc832"))
stopifnot(identical(digest::digest(file=file.path(root,"skills/_shared/scripts/fig_mod_bulk.R"),algo="sha256"),"b41e5c34cdd0918806d21a935659ea4e9b9e953b6c1fab3495f1d2836f0b0542"))
stopifnot(identical(digest::digest(file=file.path(root,"skills/_shared/scripts/fig_mod_groupcomp.R"),algo="sha256"),"ffc87dd559cd92513f2e1d6294f8241d4084b0b4124b2adca7b56f26a82ac7a5"))
stopifnot(identical(digest::digest(file=file.path(root,"skills/_shared/scripts/fig_sc_extra.R"),algo="sha256"),"4ee7b143f092b1520af0e6fb4b1ac7809d6356fb90279f9513365ce306d957dd"))
stopifnot(identical(digest::digest(file=file.path(root,"skills/_shared/scripts/fig_mod_sc_backend.R"),algo="sha256"),"fae00f116899bcd982c9b763396a1bdd7e3e63d568e381ba32fd7def0ee870ce"))
stopifnot(identical(digest::digest(file=file.path(root,"skills/_shared/scripts/fig_sc.R"),algo="sha256"),"4a86981a46790a8b915501d5afc01fcc8cdbe126b74892f071cd75da0c0b2e36"))
stopifnot(identical(digest::digest(file=file.path(root,"skills/_shared/scripts/fig_mod_bulk_limma.R"),algo="sha256"),"ba8247513de31d128b0927167b3efcd549d632c93cc7355e712ecc556fda6553"))
stopifnot(identical(digest::digest(file=file.path(root,"skills/_shared/scripts/fig_mod_methylation.R"),algo="sha256"),"dc92cdfad3ed911a148e222a90cb2a14403a8d3c83e4e5ec2ec28bc64b524224"))
stopifnot(identical(digest::digest(file=file.path(root,"skills/_shared/scripts/fig_enrich.R"),algo="sha256"),"dc1081793cf8a9146733abbb0a27aa34f38912f9eb873854446cab02ea9a0c3f"))
stopifnot(identical(digest::digest(file=file.path(root,"skills/_shared/scripts/fig_mod_survival.R"),algo="sha256"),"7542e4c1d892388c3f2a55114de34decbc6b53840272640d321c38ecd0e95c4a"))
stopifnot(identical(digest::digest(file=file.path(root,"skills/_shared/scripts/fig_style.R"),algo="sha256"),"0df58d9524fa5d1425f8f0b2f3411eb88d46d0dce0094132f678453ead68451f"))
stopifnot(identical(digest::digest(file=file.path(root,"skills/_shared/scripts/fig_mod_m4.R"),algo="sha256"),"5e810d78afbef4dae40e39c8503804f708a378d331a3fedeec92967ee87a0913"))
stopifnot(identical(digest::digest(file=file.path(root,"skills/_shared/scripts/fig_network.R"),algo="sha256"),"f6c5722f21c6543b275d6c28de08b0cca8c152021e9448bacd7e2836fa907482"))
stopifnot(identical(digest::digest(file=file.path(root,"skills/_shared/scripts/fig_mod_chromatin.R"),algo="sha256"),"24ed8ce4c9fb36ad11672e9993e0e4f46c7404ca5e2a63d8e8886d388ec21138"))
stopifnot(identical(digest::digest(file=file.path(root,"skills/_shared/scripts/fig_mod_enrich.R"),algo="sha256"),"ab7ffe1acc7b90993a5903d7a2b170bcdb1fa0ee87932a933d19a93957714966"))
stopifnot(identical(digest::digest(file=file.path(root,"skills/_shared/scripts/fig_mod_enrich_rank.R"),algo="sha256"),"f17721430289a75fc8a0a7664a612778369b55c62e9583b35c31fec7b61b4310"))
stopifnot(identical(digest::digest(file=file.path(root,"skills/_shared/scripts/fig_compose.R"),algo="sha256"),"d468589bba409adb46ebe4af0b727e3fb366bb55bb33cd7be738d4de27fc770e"))
stopifnot(identical(digest::digest(file=file.path(root,"skills/_shared/scripts/fig_bulk.R"),algo="sha256"),"c5051d6b9218aadd2197412d77410b99d9f92a6faddeafccb5ff230b389b4a1f"))
stopifnot(identical(digest::digest(file=file.path(root,"skills/_shared/scripts/fig_all.R"),algo="sha256"),"91ae80a0cfd9b554ec769f1c7eca0fac1e3250b6147419b20ba423fde4e1aedb"))
stopifnot(identical(digest::digest(file=file.path(root,"skills/_shared/scripts/fig_mod_ligand.R"),algo="sha256"),"d50810871d982f6c47a634fa0c2f994c861bf1e6f4fd04bb160dde924de9112b"))
stopifnot(identical(digest::digest(file=file.path(root,"skills/_shared/scripts/fig_spatial.R"),algo="sha256"),"e8a9527471a75b3499a605b886e423ade732d1ce486ebd61461b49395339e085"))
stopifnot(identical(digest::digest(file=file.path(root,"skills/_shared/scripts/fig_enrich_network.R"),algo="sha256"),"12d7ae47e4b4befd4ba2472793b647e87a3c21162b82459da758d186606b73fb"))
source(file.path(root,'skills/_shared/scripts/fig_all.R'))
source(file.path(root,'skills/_shared/scripts/fig_mod_sc_seurat.R'))
write_json <- function(x,p) jsonlite::write_json(x,file.path(out,p),auto_unbox=TRUE,pretty=TRUE,null='null',na='null',digits=17)
write_csv <- function(x,p) utils::write.csv(x,file.path(out,p),row.names=FALSE,na='NA')
plots <- list(); observations <- list(); fixtures <- list()
# FE043: authoritative names are deliberately shuffled relative to coordinates.
emb <- data.frame(cell=c('invented_c1','invented_c2','invented_c3','invented_c4'),x=c(0,1,2,3),y=c(0,2,1,3))
values <- c(invented_c3=30,invented_c1=10,invented_c4=40,invented_c2=20)
p <- os_feature_embedding(emb,values,'Artificial feature'); plots[['FE-043']] <- p
actual <- p$data[,c('cell','x','y','.v')]; actual <- actual[match(emb$cell,actual$cell),]
observations[['FE-043']] <- list(actual=actual,expected=unname(values[emb$cell]),bug_reproduced=!identical(actual$.v,unname(values[emb$cell])))
fixtures$embedding <- emb;fixtures$feature_values <- values;write_csv(actual,'FE-043-positional-values.csv')
# FE018: capture the actual sample-distance caller and compare complete-linkage trees.
mat <- matrix(c(0,0,1,0,1,2,4,3),2,dimnames=list(c('featureA','featureB'),paste0('invented_s',1:4)))
cd <- data.frame(sample=colnames(mat),condition=c('A','A','B','B'))
base_heatmap <- os_heatmap; captured <- NULL
os_heatmap <- function(mat,...) {captured <<- mat;base_heatmap(mat,...)}
p <- os_sample_distance(mat,cd,'condition');plots[['FE-018']] <- p
direct <- stats::hclust(stats::as.dist(captured),method='complete');legacy <- .os_cluster(captured)
observations[['FE-018']] <- list(distance=captured,direct_merge=direct$merge,direct_height=direct$height,actual_merge=legacy$merge,actual_height=legacy$height,bug_reproduced=!isTRUE(all.equal(direct$height,legacy$height)))
fixtures$distance_expression <- mat;fixtures$sample_table <- cd;write_csv(data.frame(step=seq_along(direct$height),direct=direct$height,actual=legacy$height),'FE-018-tree-heights.csv')
# FE019: true0, original NA, Inf and constant-row scale failure are separate inputs.
bad <- matrix(c(0,1,2,3,NA,2,4,8,1,2,Inf,4),3,byrow=TRUE,dimnames=list(c('true_zero','missing','infinite'),colnames(mat)))
legacy_missing <- tryCatch(.os_cluster(bad),error=conditionMessage)
constant <- rbind(constant=c(5,5,5,5),changing=c(0,1,2,3),varying=c(1,4,2,8));colnames(constant)<-colnames(mat)
ft_h <- data.frame(feature_id=rownames(constant),padj=c(.01,.02,.03),log2fc=c(0,1,-1))
p <- os_top_heatmap(constant,ft_h,cd,'condition',n=3);plots[['FE-019']] <- p
observations[['FE-019']] <- list(nonfinite_clustering_accepted=inherits(legacy_missing,'hclust'),display_matrix=captured,bug_reproduced=inherits(legacy_missing,'hclust') && all(captured['constant',]==0))
fixtures$nonfinite_matrix<-bad;fixtures$constant_matrix<-constant;fixtures$heatmap_feature_table<-ft_h;write_csv(data.frame(feature=rownames(captured),captured,check.names=FALSE),'FE-019-filled-values.csv')
# FE041: grouped display cap selects12 of30 samples; z must refer to30.
scores <- rbind(set_A=seq(-15,14),set_B=cos(seq_len(30)),set_C=(seq_len(30)%%7)-3);colnames(scores)<-sprintf('invented_gs%02d',1:30)
scd <- data.frame(sample=colnames(scores),group=rep(c('A','B'),each=15))
p <- os_gsva_score_heatmap(scores,scd,group_col='group');plots[['FE-041']] <- p
expected <- t(scale(t(scores)))[rownames(captured),colnames(captured),drop=FALSE]
observations[['FE-041']]<-list(displayed=colnames(captured),actual=captured,expected=expected,bug_reproduced=!isTRUE(all.equal(unname(captured),unname(expected))))
fixtures$gsva_scores<-scores;fixtures$gsva_samples<-scd;write_csv(data.frame(set=rownames(captured),captured,check.names=FALSE),'FE-041-subset-z.csv')
os_heatmap <- base_heatmap
# FE013: true nonsignificance must differ from missing adjusted P.
ft <- data.frame(feature_id=c('invented_NA','invented_NS','invented_UP','invented_DOWN'),base_mean=c(5,10,20,40),log2fc=c(1,0.2,2,-2),padj=c(NA,.2,.01,.01),pvalue=c(.02,.2,.001,.001),filtered_reason=c('independent_filter',NA,NA,NA))
p<-os_ma(ft,label_n=0);plots[['FE-013']]<-p
observations[['FE-013']]<-list(classes=p$data[,c('feature_id','de_class')],bug_reproduced=p$data$de_class[match('invented_NA',p$data$feature_id)]=='ns')
fixtures$ma_table<-ft;write_csv(observations[['FE-013']]$classes,'FE-013-test-classes.csv')
# FE047: real Seurat object/accessors, artificial counts and explicit noncluster grouping.
counts<-matrix(c(1,2,3,4,5,6,6,4,5,2,3,1,2,6,3,5,4,1),3,byrow=TRUE,dimnames=list(c('invented-geneA','invented-geneB','invented-geneC'),paste0('invented_mc',1:6)))
x<-SeuratObject::CreateSeuratObject(counts=counts,min.cells=0,min.features=0)
x$cluster<-rep(c('cluster0','cluster1'),each=3);x$cell_type<-rep(c('typeA','typeB'),3);x$sample<-rep(c('sample1','sample2'),each=3)
SeuratObject::LayerData(x[['RNA']],layer='data')<-log1p(counts)
SeuratObject::LayerData(x[['RNA']],layer='scale.data')<-t(scale(t(log1p(counts))))
markers<-data.frame(gene=c('invented-geneA','invented-geneB','invented-geneC','invented-geneA','invented-geneB','invented-geneC'),cluster=rep(c('typeA','typeB'),each=3),p_val_adj=c(.001,.01,.02,.003,.02,.01),avg_log2FC=c(.1,2,1,.1,-1,-2))
r<-list(object=x,state=list(marker_assay='RNA'),grouping='cell_type',tables=list(markers_full=markers,markers_display=markers[abs(markers$avg_log2FC)>=1,]),details='Artificial native object; native grouping cell_type; display filter abs(log2FC)>=1.')
saved<-list();os_finalize_figure<-function(p,stem,...) {saved[[basename(stem)]]<<-p;invisible(NULL)}
os_seurat_markers_figures(r,list('top-n'=2,journal=journal),tempdir())
p<-saved$marker_dotplot;plots[['FE-047']]<-p
observations[['FE-047']]<-list(plotted_groups=unique(p$data$cluster),plotted_genes=unique(p$data$gene),expected_groups=sort(unique(x$cell_type)),eligible_genes=unique(r$tables$markers_display$gene),bug_reproduced=!setequal(unique(p$data$cluster),unique(x$cell_type)))
fixtures$marker_counts<-counts;fixtures$marker_table<-markers;fixtures$marker_metadata<-x[[]]
write_csv(p$data,'FE-047-wrong-marker-groups.csv')
write_json(fixtures,'FIXTURES.json');saveRDS(fixtures,file.path(out,'FIXTURES.rds'));write_json(observations,'BASELINE_OBSERVATIONS.json')
stopifnot(length(observations)==6L,all(vapply(observations,function(x)isTRUE(x$bug_reproduced),logical(1))))
for(j in journal) for(id in names(plots)) {
 p<-plots[[id]];os_save_figure(p,file.path(out,id,j,'before'),width='double',height_mm=90,journal=j,formats=c('png','pdf'),root=out)
}
write_json(list(source_local='9299a33d4ca155975ba3915c74f7361ff3e69ff0',source_remote='5c139777aa8034cbfb4fcb63745728c7e1b8572f',source_kind='Frozen original project functions from source local commit; preset-specific rebuild of before figures; artificial fixtures, native Seurat accessors; no fitted scientific model',six_baseline_bugs_reproduced=TRUE,R=R.version.string,packages=lapply(c('ggplot2','SeuratObject','Seurat','ragg'),function(p) list(package=p,version=as.character(utils::packageVersion(p))))),'BASELINE_RUN.json')
cat('Six baseline counterexamples reproduced; original values and before figures frozen.\n')

# 1 locate shared; 2 parse; 3 validate; 4 input; 5 compute; 6 result;
# 7 render; 8 QC; 9 provenance; 10 closing line.
options(error=function(){cat(geterrmessage(),file=stderr());quit(status=1,save="no")})
.this<-normalizePath(sub("^--file=","",grep("^--file=",commandArgs(FALSE),value=TRUE)[1]))
.module<-dirname(dirname(.this));.shared<-normalizePath(file.path(.module,"..","_shared","scripts"))
for(f in c("args.R","engine_run.R","module_kit.R","feature_table.R","handoff.R","fig_all.R","ranked_list.R", "limma_io.R"))source(file.path(.shared,f))
source(file.path(dirname(.this),"limma_dupcor_core.R"))
source(file.path(dirname(.this),"limma_dupcor_qc.R"))
source(file.path(dirname(.this),"limma_dupcor_report.R"))
SPEC<-os_arg_spec(
 usage="Rscript run_limma_dupcor.R --mode array|rna --matrix <csv>|--counts <csv> --samples <csv> --block <column> --block-description <text> --reference <level> --target <level> --outdir <dir>",
 description="Differential expression with duplicateCorrelation for repeated correlated units.",
 flags=list(
  os_flag("mode","enum",required=TRUE,values=c("array","rna"),help="normalized array or raw RNA count input"),
  os_flag("matrix","path",must_exist=TRUE,help="normalized log2 array expression matrix"),
  os_flag("counts","path",must_exist=TRUE,help="uncorrected integer RNA count matrix"),
  os_flag("samples","path",must_exist=TRUE,help="sample table matching matrix columns"),
  os_flag("from-run","path",must_exist=TRUE,help="verified upstream matrix and sample table"),
  os_flag("outdir","path",required=TRUE,help="output directory"),
  os_flag("spec","path",must_exist=TRUE,help="resolved spec replay"),
  os_flag("sample-col","string",default="sample",help="sample identifier column"),
  os_flag("condition","string",default="condition",help="compared group column"),
  os_flag("reference","string",required=TRUE,help="reference group"),
  os_flag("target","string",required=TRUE,help="target group"),
  os_flag("covariates","string",help="comma-separated fixed effects"),
  os_flag("block","string",required=TRUE,help="sample table column identifying correlated units"),
  os_flag("block-description","string",required=TRUE,help="plain-language meaning of correlated unit"),
  os_flag("block-role","enum",default="correlated_unit",values=c("correlated_unit","technical_batch"),help="block role; technical batch needs a rationale"),
  os_flag("block-rationale","string",help="reason for using technical batch as random block"),
  os_flag("platform","enum",values=c("agilent","other"),help="array platform; required in array mode"),
  os_flag("trend","enum",default="auto",values=c("auto","true","false"),help="eBayes trend; auto uses mode/platform preset"),
  os_flag("robust","enum",default="auto",values=c("auto","true","false"),help="eBayes robust; auto uses mode/platform preset"),
  os_flag("min-count","int",default=10L,range=c(0,100000L),help="RNA filterByExpr minimum count"),
  os_flag("alpha","num",default=0.05,range=c(0.000001,0.5),help="BH significance cutoff"),
  os_flag("min-effect-fc","num",default=1,range=c(1,100),help="pre-specified minimum effect, linear fold change; 1 = zero-effect"),
  os_flag("display-lfc-filter","num",default=0,range=c(0,20),help="display-only absolute log2 fold change filter; 0 = off"),
  os_flag("label-n","int",default=5L,range=c(0,30),help="feature labels per direction"),
  os_flag("seed","int",default=20260925L,help="recorded random seed"),
  os_flag("journal","enum",default="nature",values=c("nature","cell","science","generic"),help="figure preset")),
 exclusive=list(c("matrix","counts","from-run")))
a<-os_parse_args(SPEC,os_spec_argv(commandArgs(trailingOnly=TRUE)))
if(isTRUE(a$help)){os_print_help(SPEC);quit(status=0)}
if(is.null(a$matrix)&&is.null(a$counts)&&is.null(a[["from-run"]]))stop("OS_MISSING_PARAMETER: supply input matrix/counts or --from-run.",call.=FALSE)
if((a$mode=="array"&&!is.null(a$counts))||(a$mode=="rna"&&!is.null(a$matrix)))stop("OS_CONFLICTING_PARAMETERS: --mode array uses --matrix; --mode rna uses --counts.",call.=FALSE)
if(is.null(a[["from-run"]])&&is.null(a$samples))stop("OS_MISSING_PARAMETER: direct input needs --samples.",call.=FALSE)
argv<-os_canonical_argv(SPEC,a);set.seed(a$seed);options(omicstat.journal=a$journal)
dir.create(a$outdir,recursive=TRUE,showWarnings=FALSE);outdir<-normalizePath(a$outdir)
elog<-os_engine_log_new(outdir)
input_type<-if(a$mode=="array")"expression_matrix" else "count_matrix"
input_name<-if(a$mode=="array")"expression_matrix" else "count_matrix"
expect<-list(sample_table="sample_table");expect[[input_name]]<-input_type
up<-if(is.null(a[["from-run"]]))NULL else read_handoff(a[["from-run"]],expect=expect)
mp<-if(is.null(up))if(a$mode=="array")a$matrix else a$counts else up$objects[[input_name]]$path
sp<-if(is.null(up))a$samples else up$objects$sample_table$path
mat<-os_read_matrix(mp,if(a$mode=="array")"normalized array expression" else "raw counts")
st<-os_align_samples(mat,os_read_sample_table(sp,a[["sample-col"]]),a[["sample-col"]])
model<-os_limma_design(mat,st,a,block_col=a$block,allow_multilevel=TRUE)
res<-os_engine_capture(limma_dupcor_compute(mat,model,a),"compute",elog)
written<-os_engine_capture(os_limma_write(res,mat,model,a,LD_MODULE,LD_MODULE_VERSION,"LD",outdir,.module,argv,basename(.this),list(input=mp,samples=sp),up),"render",elog)
cat(sprintf("%d of %d rules triggered; read %s first\n",written$qc$n_triggered,written$qc$n_rules,written$qc$read_first))

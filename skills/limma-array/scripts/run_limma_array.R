# 1 locate shared; 2 parse; 3 validate; 4 input; 5 compute; 6 result;
# 7 render; 8 QC; 9 provenance; 10 closing line.
options(error = function() { cat(geterrmessage(), file = stderr()); quit(status = 1, save = "no") })
.this <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))
.module <- dirname(dirname(.this)); .shared <- normalizePath(file.path(.module,"..","_shared","scripts"))
for(f in c("args.R","engine_run.R","module_kit.R","feature_table.R","handoff.R","fig_all.R","ranked_list.R", "limma_io.R")) source(file.path(.shared,f))
source(file.path(dirname(.this),"limma_array_core.R"))
source(file.path(dirname(.this),"limma_array_qc.R"))
source(file.path(dirname(.this),"limma_array_report.R"))
SPEC <- os_arg_spec(
 usage="Rscript run_limma_array.R --matrix <csv> --samples <csv> --platform agilent --reference <level> --target <level> --outdir <dir>",
 description="Differential expression on normalized log2 microarray intensities using limma.",
 flags=list(
  os_flag("matrix","path",must_exist=TRUE,help="normalized log2 probe-by-array matrix"),
  os_flag("samples","path",must_exist=TRUE,help="sample table matching array columns"),
  os_flag("from-run","path",must_exist=TRUE,help="upstream expression_matrix and sample_table handoff"),
  os_flag("outdir","path",required=TRUE,help="output directory"),
  os_flag("spec","path",must_exist=TRUE,help="resolved spec replay"),
  os_flag("sample-col","string",default="sample",help="sample identifier column"),
  os_flag("condition","string",default="condition",help="compared group column"),
  os_flag("reference","string",required=TRUE,help="reference group"),
  os_flag("target","string",required=TRUE,help="target group"),
  os_flag("covariates","string",help="comma-separated fixed-effect factors"),
  os_flag("keep-other-levels","bool",help="keep condition levels other than reference and target in the design (User's Guide 17.4.7); off = exactly two levels required"),
  os_flag("platform","enum",required=TRUE,values=c("agilent","other"),help="normalized array platform"),
  os_flag("trend","enum",default="auto",values=c("auto","true","false"),help="eBayes trend; auto uses Agilent preset only"),
  os_flag("robust","enum",default="auto",values=c("auto","true","false"),help="eBayes robust; auto uses Agilent preset only"),
  os_flag("control-ids","path",must_exist=TRUE,help="CSV of feature_id control probes to remove"),
  os_flag("controls-removed","bool",help="declare input matrix already excludes control probes"),
  os_flag("above-background","path",must_exist=TRUE,help="0/1 probe-by-array detection matrix"),
  os_flag("background-k","int",range=c(1,100000),help="minimum number of above-background arrays; explicit with detection data"),
  os_flag("technical-ids","path",must_exist=TRUE,help="CSV feature_id,technical_id for true technical replicates"),
  os_flag("verified-technical-ids","bool",help="declare technical IDs were validated as identical targets"),
  os_flag("probe-annotation","path",must_exist=TRUE,help="CSV feature_id,symbol,entrez[,...] probe-to-gene mapping; unmapped probes are marked"),
  os_flag("preprocessing","string",help="upstream background correction and normalization as declared by the user; reported verbatim, otherwise 'not stated'"),
  os_flag("alpha","num",default=0.05,range=c(0.000001,0.5),help="BH significance cutoff"),
  os_flag("min-effect-fc","num",default=1,range=c(1,100),help="pre-specified minimum effect, linear fold change; 1 = zero-effect"),
  os_flag("display-lfc-filter","num",default=0,range=c(0,20),help="display-only absolute log2 fold change filter; 0 = off"),
  os_flag("label-n","int",default=5L,range=c(0,30),help="feature labels per direction"),
  os_flag("seed","int",default=20260925L,help="recorded random seed"),
  os_flag("journal","enum",default="nature",values=c("nature","cell","science","generic"),help="figure preset")),
 exclusive=list(c("matrix","from-run")))
a <- os_parse_args(SPEC,os_spec_argv(commandArgs(trailingOnly=TRUE)))
if(isTRUE(a$help)){os_print_help(SPEC);quit(status=0)}
if(is.null(a$matrix) && is.null(a[["from-run"]])) stop("OS_MISSING_PARAMETER: give --matrix and --samples, or --from-run.",call.=FALSE)
if(!is.null(a$matrix) && is.null(a$samples)) stop("OS_MISSING_PARAMETER: --matrix needs --samples.",call.=FALSE)
argv<-os_canonical_argv(SPEC,a);set.seed(a$seed);options(omicstat.journal=a$journal)
dir.create(a$outdir,recursive=TRUE,showWarnings=FALSE);outdir<-normalizePath(a$outdir)
elog<-os_engine_log_new(outdir)
up<-if(is.null(a[["from-run"]])) NULL else read_handoff(a[["from-run"]],expect=list(expression_matrix="expression_matrix",sample_table="sample_table"))
mp<-if(is.null(up))a$matrix else up$objects$expression_matrix$path
sp<-if(is.null(up))a$samples else up$objects$sample_table$path
mat<-os_read_matrix(mp,"normalized array expression")
st<-os_align_samples(mat,os_read_sample_table(sp,a[["sample-col"]]),a[["sample-col"]])
n_levels<-length(unique(st[[a$condition]]))
if(n_levels>2L && !isTRUE(a[["keep-other-levels"]])) stop(sprintf("OS_INVALID_DESIGN: condition has %d levels; pass --keep-other-levels to keep the other levels in the design (their arrays then contribute to the residual variance), or subset the arrays upstream.",n_levels),call.=FALSE)
model<-os_limma_design(mat,st,a,allow_multilevel=isTRUE(a[["keep-other-levels"]]))
# Every file that can change the result is hashed in provenance (S3 F4).
aux<-c(control_ids="control-ids",above_background="above-background",technical_ids="technical-ids",probe_annotation="probe-annotation")
inputs<-c(list(matrix=mp,samples=sp),Filter(Negate(is.null),lapply(aux,function(f)a[[f]])))
res<-os_engine_capture(limma_array_compute(mat,model,a),"compute",elog)
written<-os_engine_capture(os_limma_write(res,mat,model,a,LA_MODULE,LA_MODULE_VERSION,"LA",outdir,.module,argv,basename(.this),inputs,up),"render",elog)
cat(sprintf("%d of %d rules triggered; read %s first\n",written$qc$n_triggered,written$qc$n_rules,written$qc$read_first))

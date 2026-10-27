#!/usr/bin/env Rscript
# Explicit offline export from a fixed OrgDb/EnsDb SQLite file. This never
# downloads data or updates the live registry. Hash the source AND the export.
args <- commandArgs(TRUE)
if (length(args)!=5 || !args[1] %in% c("orgdb","ensdb"))
  stop("Usage: export_idmap_snapshot.R orgdb|ensdb source.sqlite KEYTYPE,COLUMN,... output.tsv refdata_id",call.=FALSE)
kind <- args[1];path <- normalizePath(args[2],mustWork=TRUE);columns <- strsplit(args[3],",",fixed=TRUE)[[1]];out <- args[4]
if (length(columns)<2 || anyDuplicated(columns) || file.exists(out)) stop("OS_INVALID_INPUT: need unique mapping columns and a new output path",call.=FALSE)
if (!requireNamespace("AnnotationDbi",quietly=TRUE) || !requireNamespace("jsonlite",quietly=TRUE) || !requireNamespace("digest",quietly=TRUE)) stop("OS_MISSING_PACKAGE: AnnotationDbi/jsonlite/digest",call.=FALSE)
if (kind=="ensdb") { if(!requireNamespace("ensembldb",quietly=TRUE)) stop("OS_MISSING_PACKAGE: ensembldb",call.=FALSE);db <- ensembldb::EnsDb(path) }
else db <- AnnotationDbi::loadDb(path)
if (!columns[1] %in% AnnotationDbi::keytypes(db) || !all(columns[-1] %in% AnnotationDbi::columns(db))) stop("OS_MISSING_COLUMN: mapping columns absent",call.=FALSE)
d <- AnnotationDbi::select(db,keys=sort(AnnotationDbi::keys(db,keytype=columns[1]),method="radix"),columns=columns[-1],keytype=columns[1])
d <- unique(d[,columns,drop=FALSE]);d[] <- lapply(d,as.character)
d <- d[do.call(order,c(unname(d),list(method="radix",na.last=TRUE))),,drop=FALSE]
dir.create(dirname(out),recursive=TRUE,showWarnings=FALSE)
utils::write.table(d,out,sep="\t",quote=TRUE,row.names=FALSE,na="")
jsonlite::write_json(list(refdata_id=args[5],source_sha256=digest::digest(file=path,algo="sha256"),mapping=list(path=basename(out),format="tsv",sha256=digest::digest(file=out,algo="sha256")),columns=columns,n_rows=nrow(d)),paste0(out,".manifest.json"),auto_unbox=TRUE,pretty=TRUE)

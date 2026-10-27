# requires: jsonlite digest
source('skills/_shared/scripts/handoff.R')
root <- tempfile('handoff-contract-'); dir.create(root)
on.exit <- NULL
p <- file.path(root,'counts.csv'); writeLines('gene,s1\na,1',p)
objs <- list(counts=list(path=p,type='count_matrix'))
write_handoff(root,'unit','omicstat-test','1',objs)
stopifnot(identical(read_handoff(root)$objects$counts$type,'count_matrix'))
types <- vapply(jsonlite::fromJSON(.omicstat_handoff_types_file,simplifyVector=FALSE)$types,`[[`,"","id")
stopifnot("analysis_table" %in% types,!anyDuplicated(types))
for(type in types) {
  objs$counts$type<-type;write_handoff(root,'unit','omicstat-test','1',objs)
  stopifnot(identical(read_handoff(root)$objects$counts$type,type))
}
cat(sprintf('PASS: all %d registered handoff types round-trip, including analysis_table\n',length(types)))
objs$counts$type <- 'invented_type'
e <- tryCatch({write_handoff(root,'unit','omicstat-test','1',objs);NULL},error=identity)
stopifnot(inherits(e,'error'),grepl('OS_HANDOFF_TYPE_UNKNOWN',conditionMessage(e),fixed=TRUE))
x <- jsonlite::fromJSON(file.path(root,'objects','handoff.json'),simplifyVector=FALSE)
x$objects[[1]]$type <- 'invented_type'
jsonlite::write_json(x,file.path(root,'objects','handoff.json'),auto_unbox=TRUE)
e <- tryCatch({read_handoff(root);NULL},error=identity)
stopifnot(inherits(e,'error'),grepl('OS_HANDOFF_TYPE_UNKNOWN',conditionMessage(e),fixed=TRUE))
unlink(root,recursive=TRUE)
cat('PASS: R handoff registry positive and unknown-type write/read refusals\n')

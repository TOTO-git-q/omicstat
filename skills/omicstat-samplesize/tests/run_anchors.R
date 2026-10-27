a <- commandArgs(FALSE);.here <- dirname(normalizePath(sub("^--file=","",a[grepl("^--file=",a)][1])))
source(file.path(.here,"test_helpers.R"));ss_require_native()
x <- commandArgs(TRUE);get <- function(k) {i<-match(k,x);if(is.na(i)||i==length(x))stop(paste("missing",k));x[i+1L]}
run <- get("--run");fixtures <- get("--fixtures");output <- get("--results")
dir.create(dirname(output),recursive=TRUE,showWarnings=FALSE)
result <- ss_oracles(run,fixtures,file.path(dirname(output),"runs","additional-anchors"))
jsonlite::write_json(result,output,auto_unbox=TRUE,pretty=TRUE,na="null",digits=17)
stopifnot(all(unlist(result[c("paired_oracle_delta","anova_oracle_delta","proportions_oracle_delta")])==0))
cat("Fresh seven-anchor results written; original NI anchor intentionally excluded by scope.\n")

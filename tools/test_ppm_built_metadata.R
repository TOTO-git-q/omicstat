# Base-R metadata contracts only. Never source or run the installer body.
file_arg <- grep("^--file=", commandArgs(FALSE), value=TRUE)
stopifnot(length(file_arg)==1L)
root <- dirname(dirname(normalizePath(sub("^--file=", "", file_arg))))
expressions <- parse(file.path(root,"tools/env/install_candidate.R"))
is_helper <- function(e) is.call(e) && identical(e[[1]],as.name("<-")) &&
  identical(e[[2]],as.name("candidate_built_platform_ok"))
definition <- Filter(is_helper,as.list(expressions))
stopifnot(length(definition)==1L)
scope <- new.env(parent=baseenv())
eval(definition[[1]],scope)
ok <- scope$candidate_built_platform_ok
platform <- "x86_64-pc-linux-gnu"
members <- c("toy/DESCRIPTION","toy/Meta/package.rds","toy/R/toy.rdb")
checks <- 0L
check <- function(value) {stopifnot(isTRUE(value));checks <<- checks+1L}
check(ok("",platform,"no",members))
for (flag in list(NULL,"","yes","NO","false")) check(!ok("",platform,flag,members))
for (file in c("toy/libs/library","toy/libs/x64/toy.so","toy/exec/helper.so.1",
               "toy/toy.DLL","toy/toy.dylib","toy/toy.a","toy/toy.o"))
  check(!ok("",platform,"no",c(members,file)))
check(!ok("aarch64-unknown-linux-gnu",platform,"no",members))
check(!ok("x86_64-w64-mingw32",platform,"no",members))
check(ok(platform,platform,"yes",c(members,"toy/libs/toy.so")))
check(ok(platform,platform,"no",members))
# Exact installed Version strings must not be normalized before lock comparison.
check(identical(as.character(package_version("3.0-1")),"3.0.1"))
check(identical(unname(utils::packageDescription("base",fields="Version")),
                as.character(getRversion())))
raw <- textConnection("Package: toy\nVersion: 3.0-1\n")
description <- read.dcf(raw);close(raw)
check(identical(unname(description[1,"Version"]),"3.0-1"))
cat("PASS:",checks,"base-R Built/Version metadata assertions; no install/build executed\n")

# Domain readers preserve units and declare output handoff types.
# Genomics readers (peaks, fragments, IDAT, tximport) are deferred to the
# plug-in lanes that need them.
.os_reader_stop <- function(message) stop(paste0("OS_INVALID_INPUT: ", message), call. = FALSE)
.os_reader_result <- function(data, type, provenance) structure(list(data = data, handoff_type = type, provenance = provenance), class = "omicstat_reader_result")
.os_reader_file <- function(path) {
  if (length(path) != 1 || !file.exists(path) || dir.exists(path)) .os_reader_stop("input file missing")
  normalizePath(path, mustWork = TRUE)
}
.os_reader_hash <- function(path) digest::digest(file = path, algo = "sha256")
.os_reader_numeric <- function(x, name, nonnegative = FALSE, integer = FALSE) {
  y <- suppressWarnings(as.numeric(x))
  if (any(!is.finite(y)) || (nonnegative && any(y < 0)) || (integer && any(y != floor(y)))) .os_reader_stop(paste("invalid",name))
  y
}

os_read_clinical_table <- function(path, id_col, time_col, event_col, time_unit, sep = ",") {
  path <- .os_reader_file(path)
  if (length(time_unit) != 1 || !time_unit %in% c("days","weeks","months","years")) .os_reader_stop("explicit days/weeks/months/years time unit required")
  d <- utils::read.table(path, header=TRUE,sep=sep,quote="\"",comment.char="",check.names=FALSE,stringsAsFactors=FALSE,colClasses="character")
  if (anyDuplicated(names(d)) || !nrow(d) || !all(c(id_col,time_col,event_col) %in% names(d))) .os_reader_stop("clinical ID/time/event columns required")
  if (anyNA(d[[id_col]]) || any(!nzchar(trimws(d[[id_col]]))) || anyDuplicated(d[[id_col]])) .os_reader_stop("clinical IDs must be unique and nonempty")
  d[[time_col]] <- .os_reader_numeric(d[[time_col]],"survival time",TRUE)
  d[[event_col]] <- .os_reader_numeric(d[[event_col]],"event indicator",TRUE,TRUE)
  if (any(!d[[event_col]] %in% c(0,1))) .os_reader_stop("event coding must be explicit 0=censored, 1=event")
  .os_reader_result(d,"clinical_table",list(path=path,sha256=.os_reader_hash(path),id_col=id_col,time_col=time_col,event_col=event_col,time_unit=time_unit,event_coding="0=censored;1=event"))
}

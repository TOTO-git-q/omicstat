# Explicit reusable pasilla canonical fixture; never touches a golden or lock.
a <- commandArgs(TRUE)
stopifnot(length(a) == 2L)
source(file.path(a[2], "skills/_shared/scripts/module_kit.R"))
source(file.path(a[2], "skills/deseq2-wald/tests/fixtures/make_pasilla.R"))
p <- make_pasilla(a[1], a[2])
# make_pasilla verifies these exact package-embedded source bytes before deriving
# the canonical files. The receipt contains hashes only, never raw observations.
raw <- list(counts=os_acceptance_file(a[2], "pasilla", "extdata", "pasilla_gene_counts.tsv"),
            annotation=os_acceptance_file(a[2], "pasilla", "extdata", "pasilla_sample_annotation.csv"))
receipt <- list(schema="omicstat.owner-dataset-receipt.v1",dataset_id="pasilla",kind="registered_real",
  source_files=lapply(names(raw), function(key) list(key=key,sha256=digest::digest(file=raw[[key]],algo="sha256"))),
  prepared_inputs=lapply(p,function(path) list(path=basename(path),sha256=digest::digest(file=path,algo="sha256"),bytes=unname(file.info(path)$size))))
# Arrays retain their array form even when only one item exists in a future fixture.
receipt$prepared_inputs <- unname(receipt$prepared_inputs)
jsonlite::write_json(receipt,file.path(a[1],"owner_dataset.json"),auto_unbox=TRUE,pretty=TRUE)

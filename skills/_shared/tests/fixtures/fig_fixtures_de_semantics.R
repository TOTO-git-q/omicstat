# Entirely project-invented values and labels. These are display-contract
# counterexamples, not biological observations or a scientific benchmark.
os_fixture_de_semantics <- function() {
  ft <- data.frame(feature_id = sprintf("SYN_DE_%02d", 1:16), symbol = paste0("Mock", LETTERS[1:16]),
    log2fc = c(8,-8,4,-4,.5,1.2,.2,0,1.5,-1.5,.3,-.3,.7,-.7,NA,1),
    tested_effect = c(8,-8,4,-4,.7,1.2,.2,0,1.5,-1.5,.3,-.3,.7,-.7,1,1),
    base_mean = c(12,25,80,40,4,100,50,70,0,-2,7,9,30,45,10,20),
    pvalue = c(0,1e-7,.001,.002,.0001,.05,.2,1,NA,.01,NA,NA,.2,.01,.001,.01),
    padj = c(0,1e-6,.01,.02,.001,.2,.8,1,NA,NA,NA,NA,.4,.05,.01,.01),
    filtered_reason = c(rep("",8),"outlier","independent_filtering","failed_model","unknown",rep("",4)),
    prefilter_pass = c(rep(TRUE,15),FALSE),
    annotation = c("Bound","Unbound","Bound","Unbound",NA,"Bound","Unbound","Bound","Bound","Unbound","Bound",NA,"Bound","Unbound","Bound","Bound"),
    stringsAsFactors = FALSE)
  # The final hand row is prefiltered, hence no actual test result is available.
  ft$pvalue[16] <- ft$padj[16] <- NA_real_; ft$filtered_reason[16] <- "prefilter_count_rule"
  effect <- list(plotted_estimator = "supplied display estimate", tested_estimator = "supplied unshrunk estimate",
    tested_effect_col = "tested_effect", software = "project fixture", software_version = "1",
    shrinkage = "display-only illustrative values", prior = "not a fitted model",
    contrast = list(numerator = "Synthetic target", reference = "Synthetic control", expanded_control = "Two explicitly declared synthetic control components"),
    sample_counts = list(reference_subjects = 4, target_subjects = 4), independent_unit = "synthetic subject")
  zero <- os_de_test_contract("zero_effect", 0, "zero_effect", 0, "invented zero-null test table", "SYN_ZERO", TRUE,
    test_method = "supplied illustrative zero-null test", model_id = "SYN_MODEL", software = "project fixture", software_version = "1")
  minimum <- os_de_test_contract("minimum_effect", 1, "minimum_effect", 1, "invented minimum-effect test table", "SYN_MIN", TRUE,
    test_method = "supplied illustrative minimum-effect test", model_id = "SYN_MODEL_MIN", software = "project fixture", software_version = "1")
  small <- os_de_test_contract("small_effect", 1, "small_effect", 1, "separate invented equivalence test table", "SYN_SMALL", TRUE,
    test_method = "supplied illustrative small-effect test", model_id = "SYN_MODEL_SMALL", software = "project fixture", software_version = "1", prior = "none")
  eq <- ft; eq$pvalue <- c(.8,.8,.8,.8,.0005,.04,.0005,.4,NA,.01,NA,NA,.1,.02,.05,NA)
  eq$padj <- c(.9,.9,.9,.9,.001,.2,.001,.8,NA,NA,NA,NA,.3,.06,.2,NA)
  # This is a distinct illustrative source, never a relabelled zero-null P
  # column. Effects inside the minimum margin provide no invented support.
  minimum_table <- ft
  minimum_table$pvalue <- c(0,1e-6,.005,.01,.8,.05,.9,1,NA,.1,NA,NA,.7,.6,.8,NA)
  minimum_table$padj <- c(0,1e-5,.02,.04,.9,.2,1,1,NA,NA,NA,NA,.9,.9,.9,NA)
  points <- expand.grid(feature_id = c("SYN_FEATURE_A","SYN_FEATURE_B"), sample = sprintf("SYN_SAMPLE_%02d",1:8),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  points$group <- rep(rep(c("Reference","Target"),each=4),each=2)
  points$subject <- rep(rep(paste0("SYN_SUBJECT_",1:4),2),each=2)
  points$pair <- points$subject
  points$value <- c(0,2,1,2.5,2,3,3,3.5,4,6,5,7,6,8,7,9)
  list(ft = ft, equivalence = eq, minimum_table = minimum_table, effect = effect,
    zero = zero, minimum = minimum, small = small, points = points)
}

# Options: maftools 2.28.0

| option | locked default / vignette value | required? | S0 extraction parameter key |
|---|---|---|---|
| --capture-regions | NULL; offline native TSV alternative to capture-size | one required | none |
| --capture-regions-source | required source/build/version with region file | conditional | none |
| --input | none | no | none |
| --from-run | none | no | none |
| --upstream-object | maf | no | none |
| --clinical | none | no | none |
| --outdir | none | yes | none |
| --spec | none | no | none |
| --call-source | none | yes | maf_source |
| --use-all | true | no | read_maf_useall |
| --is-tcga | false | no | read_maf_istcga |
| --remove-duplicates | true | no | read_maf_duplicates |
| --rm-flags | false | no | read_maf_rmflags |
| --non-synonymous | none | no | read_maf_nonsyn |
| --cn-table | none | no | none |
| --cn-level | all | no | none |
| --gistic-lesions | none | no | none |
| --gistic-amp | none | no | none |
| --gistic-del | none | no | none |
| --gistic-scores | none | no | none |
| --top | 10 | no | oncoplot_top |
| --capture-size | none; alternative to capture-regions | one required | tmb_capture_size |
| --ignore-cnv | true | no | tmb_ignore_cnv |
| --interaction-top | 25 | no | interaction_gene_set |
| --interaction-genes | none | no | interaction_gene_set |
| --seed | 20260925 | no | none |
| --journal | nature | no | none |

Read.maf options apply to raw MAF input; a native MAF handoff retains its existing filters. Vignette top=10; somaticInteractions top=25 and pvalue=c(0.05,0.1). Function usage returnAll=TRUE agrees with locked formals despite contradictory Rd prose. Capture size 50 Mb is only the vignette example; require actual callable assay territory. No threshold is assigned to TMB.

Supply exactly one of --capture-size (Mb) or --capture-regions (TSV; native first three columns chrom/start/end). Regions subset only the native TMB calculation; complete variants and summaries remain intact. Native territory is sum(end-start)/1e6, including native overlap semantics. Declare region source/build/version; source and SHA-256 appear in Methods/provenance.

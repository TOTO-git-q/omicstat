# Method basis

Primary manual inspected2026-10-15, version1.32.1:
https://bioconductor.org/packages/release/bioc/manuals/DropletUtils/man/DropletUtils.pdf
Primary source inspected for equality and zero-gene mapping:
https://github.com/MarioniLab/DropletUtils/blob/master/R/emptyDrops.R
https://github.com/MarioniLab/DropletUtils/blob/master/R/ambientProfileEmpty.R
Upstream source uses total>=retain, despite prose describing above retain. Explicit boundary checks
must be run in the locked1.32.0 engine before acceptance. Generic emptyDrops dispatches ANY;
niters,ignore,alpha,by.rank and known.empty are forwarded to testEmptyDrops, not generic defaults.

Lun et al2019, Genome Biology20:63, DOI10.1186/s13059-019-1662-y.
Synthetic independent count/BH/raw-preservation anchors are replay oracles. They are not the printed
11100/849 author example, which has a different generator and must not be claimed reproduced here.

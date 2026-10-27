# Method basis

Official release1.56.0: https://bioconductor.org/packages/release/bioc/html/ReactomePA.html
Inspected source archive SHA256 e8c65e31c5725333002c12b630f0d68e5874892bab1f2f3da98ec9228fc0ef72.
R/enrichPathway.R calls enrichit::ora_gson; R/gson.R and get_Reactome_DATA read installed reactome.db
and species OrgDb. Despite an old function docstring saying download latest, inspected1.56.0 uses
these installed resources. Future versions are refused until this offline binding is reviewed.

Hypergeometric definition: https://stat.ethz.ch/R-manual/R-devel/library/stats/html/Hypergeometric.html
Anchors use independent Python exact binomial coefficients from resource memberships and explicit
query/universe, plus an independently implemented BH reverse cumulative minimum. They are replay
oracles, not claimed printed pathway P values stable across annotation releases. The15 input IDs are
from the upstream function's documented example. No biomedical validity is inferred from that example.

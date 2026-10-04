# Method basis — clusterprofiler-gsea

Frozen decisions are in `acceptance/exemplars/clusterprofiler-gsea/PACK.md` S1 P-1 to P-3. Locked evidence: `L1_bioc3.23/clusterProfiler/Rd/gseGO.Rd`, `Rd/GSEA.Rd`; `L1_cran2026-09-15/enrichit/Rd/gsea.Rd`; enrichit 0.2.1 NEWS. The container has clusterProfiler 4.20.0, enrichit 0.2.1 and registered GO annotation. The full result contains testable intersected GO sets; absent sets were not tested. `eps` is a computation floor, never a tolerance. The named, signed ranking follows the common pre-ranked contract with fgsea-prerank.

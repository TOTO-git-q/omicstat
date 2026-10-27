# Method basis and source boundary

ported_from: TOTO-git-q/medstat@12292d0:skills/survival-nonph/scripts/nonph_core.R
ported_from: TOTO-git-q/medstat@12292d0:skills/competing-risks/scripts/cr_core.R

PORT_SOURCE.json pins the complete source commit and raw Git blobs. COPIED_FUNCTIONS.json
binds17 selected original/adapted functions and every change. OmicStat maintains its own copies;
no MedStat imports, environments, container calls or remote runtime are used.

The default per-gene Cox/KM function bodies are retained verbatim under private names. The new
nonph branch reuses those fitted objects for copied Schoenfeld diagnostics. Classification uses
the source fixed significance threshold0.05 and declared engineering log-HR magnitude. Source
0.20 is not a recommendation. No automatic selection, gene filter or missing-slope inference.
Unweighted piecewise Cox follows the original native defaults under explicit acknowledgement;
all period rows, event support, warnings and non-estimable results are retained. Public intervals
correct the source display labels to counting-process (start,stop] without changing the fit.

AJ follows the source survival::survfit multistate primitive. The explicit zero censor level is
an encoding correction for all-event input; we do not claim equality to the defective source
case. Independent product-integral checks are required for that case. The source algorithm has
point estimates only. CI, Gray and adjusted/Fine-Gray results are not fabricated. The diagnostic
1-KM comparison is isolated from the true CIF output. No native science has been executed here.

Original upstream documentation and numerical-anchor history are retained under
../tests/ported_source/original_references_method-basis.md.txt. Its historical clinical fixture
was superseded before this port by the entirely synthetic seed9182 canonical contract. It must
not be described as a newly downloaded or reproduced clinical anchor. Current mathematical
references are in tests/anchors.py; original MedStat case status is in ORIGINAL_ANCHOR_STATUS.json.
The old call registry records survival3.8.3/R4.5.0 history; these bytes/default values are retained
as history, while new source-native call defaults are explicitly unknown until exact R4.6.1 /
survival3.8-9 capture. No substitute installed environment certifies that capture.

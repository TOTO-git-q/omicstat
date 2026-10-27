# QC rules

ROC-01 missingness accounting; 02 disjoint participant flow and class counts;
03 exact binary reference; 04 independent IDs/no clustering; 05 reader labels;
06 declared versus audit-only automatic direction; 07 AUC below one half;
08 zero cells; 09 negative/out-of-review-range Youden J; 10 criterion disagreement;
11 separate continuity correction; 12 exploration companions; 13 cutoff instability;
14 point/interval identity; 15 identical paired sets; 16 indeterminate sensitivity;
17 small samples; 18 endpoint proportions; 19 partial-AUC bootstrap; 20 prevalence
transport assumption; 21 explicit-device/no stray plot; 22 comparison family and
required correction; 23 every skipped subgroup level.

ROC-24 adds SHA256 table/estimand and native value/count verification before finish
and again before display-only rendering. ROC-90 is always a candidate blocker.
Original high severities remain reviewable. The original allow-optimistic-cutpoint
flag applies only to internal-validation=none; it does not erase ROC-12, override
another guard, confer owner approval or make inference-ready handoffs.

All emitted error codes are registered OS_* codes. source code DA identifiers are
mapped to ROC identifiers; the original MedStat exception namespace is not emitted.

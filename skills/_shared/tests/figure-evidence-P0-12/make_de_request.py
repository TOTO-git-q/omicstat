"""Invented typed differential-effect and biological-unit FigureRequest inputs."""
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "py"))
from ospy.figure_request import FigureRequest, frame

out = Path(sys.argv[1])
out.mkdir(parents=True, exist_ok=True)
journal = sys.argv[2] if len(sys.argv) > 2 else "nature"
ids = [f"SYN_BRIDGE_GENE_{i}" for i in range(1, 9)]
ft = dict(feature_id=ids, symbol=[f"Synthetic{i}" for i in range(1, 9)],
          log2fc=[8.0, -8.0, 0.5, 1.2, 0.2, 0.0, 1.0, -1.0],
          tested_effect=[8.0, -8.0, 0.7, 1.2, 0.2, 0.0, 1.0, -1.0],
          base_mean=[5.0, 15.0, 20.0, 30.0, 9.0, 12.0, 0.0, 0.0],
          pvalue=[0.0, 1e-7, 1e-4, 0.05, 0.4, 1.0, None, None],
          padj=[0.0, 1e-6, 0.001, 0.2, 0.8, 1.0, None, None],
          prefilter_pass=[True] * 7 + [False],
          filtered_reason=[""] * 6 + ["outlier", "prefilter_count_rule"],
          annotation=["Bound", "Unbound", None, "Bound", "Unbound", "Bound", "Bound", None])
test = dict(version="omicstat.de-semantics.v1", hypothesis="zero_effect", margin=0,
            effect_unit="log2_fold_change", null="beta = 0", alternative="beta != 0",
            p_value_hypothesis="zero_effect", p_value_margin=0,
            p_value_source="complete project-invented illustrative zero-null P table",
            test_id="SYN_BRIDGE_TEST", prespecified=True, test_method="supplied illustrative test",
            model_id="SYN_BRIDGE_MODEL", software="project fixture", software_version="1",
            prior="not a fitted model", shrinkage="none")
effect = dict(plotted_estimator="supplied display estimate", tested_estimator="supplied tested estimate",
              tested_effect_col="tested_effect", software="project fixture", software_version="1",
              shrinkage="none", prior="not a fitted model",
              contrast=dict(numerator="Target", reference="Reference", expanded_control="unknown"),
              sample_counts=dict(reference_subjects=4, target_subjects=4), independent_unit="invented subject")
common = dict(test_contract=test, effect_provenance=effect, statistic_method="supplied illustrative test",
              adjustment="BH", family_id="SYN_BRIDGE_FAMILY", family_size=6, family_source_ids=ids[:6],
              padj_threshold=0.05, lfc_threshold=1, label_n=0, display_operator=">=")
req = FigureRequest(str(out), "synthetic-de-semantics", "0.0.0", journal=journal)
req.add("volcano", "os_volcano", {"ft": frame(ft)}, args=common)
req.add("ma", "os_ma", {"ft": frame(ft)}, args=dict(common, y_max=4))
req.add("annotation", "os_volcano", {"ft": frame(ft)}, args=dict(common, colour_mode="annotation",
        annotation_col="annotation", annotation_title="Binding annotation",
        annotation_levels=["Bound", "Unbound", "Missing annotation"], annotation_denominator="direction"), width="double")
unknown_ft = dict(ft, padj=[None] * len(ids))
req.add("unavailable", "os_ma", {"ft": frame(unknown_ft, types={"padj": "numeric"})},
        args=dict(label_n=0, test_contract=None, effect_provenance=None, family_size=None,
                  family_source_ids=None, mean_kind="normalized_count_mean", y_max=4))
points = []
for i in range(8):
    for k, feature in enumerate(("SYN_BRIDGE_SELECTED_A", "SYN_BRIDGE_SELECTED_B")):
        points.append(dict(feature_id=feature, sample=f"SYN_SAMPLE_{i+1}",
                           group="Reference" if i < 4 else "Target", subject=f"SYN_SUBJECT_{i % 4+1}",
                           pair=f"SYN_SUBJECT_{i % 4+1}", value=float(i + 2*k)))
req.add("selected", "os_selected_feature_points", {"d": frame(points)},
        args=dict(selected_features=["SYN_BRIDGE_SELECTED_A", "SYN_BRIDGE_SELECTED_B"],
                  selection_reason="Predeclared invented examples", normalization="invented size-factor values",
                  unit="normalized counts", reference="Reference", subject_col="subject", pair_col="pair",
                  group_order=["Reference", "Target"]), width="double")
eligibility = []
states = ["zero_cell", "below_min_cells", "zero_library", "not_fitted"]
for k, subtype in enumerate(("SYN_BRIDGE_TYPE_A", "SYN_BRIDGE_TYPE_B")):
    for i in range(4):
        state = "fitted" if k == 0 else states[i]
        cells = 20 if k == 0 else [0, 1, 20, 20][i]
        library = 120.0 if k == 0 else [0.0, 5.0, 0.0, None][i]
        eligibility.append(dict(sample=f"SYN_PB_SAMPLE_{i+1}", subtype=subtype,
                                condition="Reference" if i < 2 else "Target", donor=f"SYN_PB_DONOR_{i+1}",
                                n_cells=cells, library_size=library, state=state,
                                reason="supplied illustrative eligibility state"))
req.add("pseudobulk", "os_pseudobulk_eligibility", {"d": frame(eligibility)},
        args=dict(conditions=["Reference", "Target"], min_cells=2, donor_col="donor"), width="double")
req.write()
(out / "SOURCE.json").write_text(json.dumps(dict(origin="project-invented values only; no real biological records or paper pixels",
    ft=ft, selected=points, eligibility=eligibility, test_contract=test, effect_provenance=effect),
    indent=2, allow_nan=False) + "\n")

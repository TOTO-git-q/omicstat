"""Check actual Python-to-R figure output, without recalculating any inference.

Usage: check_de_request.py REQUEST_OUT [FIRST_RENDER_SNAPSHOT_JSON]
The optional snapshot is a JSON map of relative paths to SHA256, captured
before a second R render. PDF replay is checked by normalized content hashes
inside the byte-identical figure specs, not by exempt creation timestamps.
"""
import hashlib
import json
from pathlib import Path
import sys

root = Path(sys.argv[1])
source = json.loads((root / "SOURCE.json").read_text())
request = json.loads((root / "figure_data/figure_request.json").read_text())
render = json.loads((root / "provenance/figure_render.json").read_text())
passed = 0


def check(condition, label):
    global passed
    if not condition:
        raise AssertionError(label)
    passed += 1
    print("PASS", label)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


check(len(render["figures"]) == 6, "six requested builders rendered")
check(render["warnings"]["error"] == 0, "renderer reported no error")
check(render["request"]["sha256"] == digest(root / render["request"]["path"]),
      "exact request hash recorded")
specs = {}
for figure in render["figures"]:
    name = figure["id"]
    path = root / figure["spec"]["path"]
    check(digest(path) == figure["spec"]["sha256"], name + " actual spec hash")
    spec = specs[name] = json.loads(path.read_text())
    check(spec["journal"] == render["journal"], name + " actual journal")
    check(not [x for x in spec["lint"] if x["severity"] in ("error", "warning")],
          name + " no warning/error lint (informational grayscale findings retained)")
    check(digest(root / figure["files"]["png"]["path"]) == figure["files"]["png"]["sha256"],
          name + " actual PNG hash")
    check(spec["files"]["pdf"]["content_sha256"] == figure["files"]["pdf"]["content_sha256"],
          name + " normalized PDF hash propagated")
    for descriptor in figure["data"].values():
        check(digest(root / descriptor["path"]) == descriptor["sha256"], name + " actual input bytes")

for name in ("volcano", "ma", "annotation"):
    spec = specs[name]
    contract = spec["definition"]["de_contract"]
    check(spec["data"]["raw_source"] == source["ft"], name + " all original numeric/string/null source values")
    check(contract["test"] == source["test_contract"], name + " exact test contract")
    check(contract["effect"] == source["effect_provenance"], name + " exact effect provenance")
    check(contract["family_source_ids"] == source["ft"]["feature_id"][:6] and
          contract["statistic"]["family_size"] == 6, name + " complete supplied family membership")
    check(spec["counts"]["n_input"] == 8 and spec["counts"]["n_prefilter_pass"] == 7 and
          spec["counts"]["n_finite_raw_p"] == spec["counts"]["n_finite_padj"] == 6,
          name + " distinct input/filter/finite-test denominators")
    decisions = spec["data"]["decision_table"]
    check(decisions["statistical_call"][2] == "supported_positive" and
          decisions["display_selected"][2] is False,
          name + " significant small estimate remains supported outside display gate")
    check(decisions["statistical_call"][3] == "inconclusive" and
          decisions["statistical_call"][6:] == ["not_tested", "not_tested"],
          name + " unsupported large estimate and unavailable tests stay distinct")

unavailable = specs["unavailable"]["definition"]["de_contract"]
for key in ("family_source_ids",):
    check(key in unavailable and unavailable[key] is None, "explicit unknown " + key)
check("family_size" in unavailable["statistic"] and unavailable["statistic"]["family_size"] is None,
      "unknown family size remains explicit null")
check(unavailable["test"]["margin"] is None and unavailable["effect"]["sample_counts"] is None,
      "unknown margin and biological n remain explicit null")
check(all(value is None for value in unavailable["statistic"]["values"].values()),
      "typed all-null statistic column remains unavailable")
check(specs["volcano"]["data"]["decision_table"] == specs["annotation"]["data"]["decision_table"],
      "annotation colors leave statistical decisions unchanged")
for row in specs["annotation"]["data"]["direction_category"]:
    check(row["numerator"] == len(row["numerator_ids"]) and row["denominator"] == len(row["denominator_ids"]),
          "annotation count membership " + row["direction"] + "/" + row["category"])
    check(row["fraction"] == (row["numerator"] / row["denominator"] if row["denominator"] else None),
          "annotation fraction " + row["direction"] + "/" + row["category"])
check(specs["selected"]["counts"]["n_subjects"] == 4 and
      specs["selected"]["counts"]["n_selected_samples"] == 8 and
      specs["selected"]["counts"]["n_visible_points"] == 16,
      "selected feature points do not count features or repeated samples as subjects")
check(specs["pseudobulk"]["counts"]["n_donors"] == 4 and
      specs["pseudobulk"]["counts"]["n_samples"] == 4,
      "pseudobulk donor n is distinct from cell n and repeated subtypes")
check(specs["pseudobulk"]["notes"]["cell_label_contrast_min"] >= 4.5,
      "pseudobulk actual tile text contrast")
if len(sys.argv) > 2:
    snapshot = json.loads(Path(sys.argv[2]).read_text())
    for relative, sha in snapshot.items():
        check(digest(root / relative) == sha, "exact rerender/source replay " + relative)
print("ASSERTIONS", passed, "FAILED 0")

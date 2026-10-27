# Typed scientific display semantics (P0-12 group 1)

`omicstat.figure-semantics.v1` is an opt-in `figure_spec.definition` extension to
`omicstat.figure-spec.v1`; the outer schema and legacy FigureRequest API remain
compatible. New contracts use `fig_semantics.R` and the standard-library-only
`ospy.figure_semantics` module. `fig_all.R` loads the R contract before builders.
The structural schema is `schemas/figure_semantics.v1.schema.json`; runtime
checks additionally enforce source hashes, key sets, counts, interval alignment,
ratio reconstruction, provenance, and display transformations. Neither path fits
an estimator or converts design evidence into numerical validation.

## Source, estimand and population

A definition names quantity, physical unit, observation and independent units,
eligible population, displayed subset and aggregation. Unknown values remain
`unknown`; missing population IDs cannot be replaced with the largest available n.
Each layer has a unique ID, explicit source key(s), raw source table, population ID,
and one data role: observed, aggregate, model_grid, prediction, partial_residual,
simulation_truth, known_annotation, fitted_cluster, draw, reference, or display_only.
String keys are required; composite keys use JSON tuples rather than delimiters.

An observed visit is an observation row, not automatically an independent person.
Independent IDs must be explicitly supplied for every row. Model grids, random
draws and aggregates contribute zero observed rows. Per-population counts deduplicate
shared observation/independent IDs across layers. Per-column missing, finite, zero
and infinite counts remain distinct from row-state counts. A recorded visit with an
unavailable measurement can therefore be an observed record without being a plotted
finite point. The diagnostic builder states finite/nonfinite display counts.

Named ID-set fractions reconstruct their numerator and denominator, enforce subset
membership and preserve zero-denominator undefined values. Event rates use distinct
event/person units. `os_quantity_ratio` separately handles supplied numeric increments
(e.g. 100 EUR / 2 units), retains signed increments, zero denominators and quadrant
counts, and does not summarize ratios across a denominator that crosses zero.

## Identity, serialization and replay

The source checksum is SHA-256 over `omicstat.typed-table.sha256.v1`: bytewise UTF-8
sorted columns and source IDs, length-prefixed typed cells, 17-significant-digit
numeric strings, canonical numeric zero, distinct strings/logicals/null/Inf/-Inf.
Exactly representable integers/doubles have the same numeric hash. Python integers
that cannot be represented exactly as binary64 are rejected before conversion,
including overflow (for example, `2**53 + 1`). Missing is never zero. Infinity
has an explicit cell mask because JSON cannot represent infinity. One-row source
columns stay arrays. Typed/lossless metadata saves binary64 round-trip precision.
A renderer verifies every declared layer against actual input tables by full key
set and raw values before drawing. Additional builder columns are allowed; unmatched
or changed source layers fail. Attaching metadata alone is not estimator validation.

`FigureRequest.add(..., definition=..., evidence_refs=...)` validates typed fields
before recording the request. R replay revalidates them and binds the source tables.
Legacy definitions without `semantic_version` continue to be written unchanged.
A typed contract cannot be removed through metadata merges. A replacement typed
definition must be complete and valid; it is merged atomically, preserving explicit
null numerator/denominator and other unknown fields. Repeated attachment and
`extra_meta` therefore retain the exact canonical definition rather than deleting
nulls or inheriting stale nested fields. Arbitrary unsupported
source formats or nested source cells fail rather than being coerced to numbers.

## Uncertainty and comparisons

Every uncertainty object declares target, kind, method, coverage scope, resampling
unit and availability. CI/CrI/PI/observation-quantile levels are explicit. Distribution,
IQR, SD, SE, baseline ranges and estimator-mapping connectors do not acquire a 95%
confidence label. Unavailable/partial intervals need reasons. Interval summaries
must match keyed source estimates; reversed endpoints or inappropriate enclosing
bounds fail. Domain violations retain raw endpoints and are flagged, never clipped.
Nested masses must enclose smaller supplied intervals for the same target/IDs.

Joint contrasts require supplied covariance or paired draws with parameter/draw IDs
and a pinned source hash. Covariance is checked for symmetry and positive
semidefiniteness. The arithmetic contrast variance retains covariance terms; no CI
is estimated. Simultaneous intervals require that joint source. Pointwise bands do
not become continuous simultaneous coverage. Inner draws, outer repeats and
conditioning remain separate fields. Method-specific bootstrap/MI/HC3/cluster
claims must come from the upstream method, never the renderer.

Comparison annotations materialize actual per-row test, model, endpoint, source
result ID, statistic type, adjustment, family ID/size and paired/cluster unit.
Brackets bind to actual distinct group IDs. Omnibus, interaction, trend or fit tests
cannot appear on a pairwise bracket. Legacy global arguments are preserved but
expanded into explicit rows with unknown provenance where information was absent.
Missing results remain unavailable; P=.053 is not rounded into significance.
Raw P, adjusted P, q value, local FDR and posterior probabilities remain distinct.
`os_p_label` refuses non-P types; comparison q labels retain their actual field.
A reported P=0 with unknown precision does not invent a 1e-300 bound.
No caption infers an interaction, equivalence, safety or causality from separate
significance or overlapping intervals.

The volcano builder supports explicit raw P, adjusted P and q-value source columns;
implicit relabeling of `padj`, local-FDR or posterior inputs is refused. Source values
and full-family provenance are retained. A raw-P FDR boundary can be derived only
from a complete supplied raw/adjusted family whose decisions are reproduced by
one line; no rejection means no line, and incompatible ties/nonmonotone decisions
require explicit glyphs instead. This does not recompute multiplicity correction.

## Display-only transformations and missing states

Raw, model and display scales remain separate. Identity/log/log2/log10/log1p/sqrt,
log-link exponentiation, explicit inverse-logit and folded-ratio transformations
record base, pseudocount, offsets, operation order, raw/display values and exclusions.
Data, ticks and reference lines share the same map. Double logging and arbitrary
latent-score-to-probability conversion fail. Folded ratios explicitly lose direction.
Attached transforms replay against their source column; display-only objects are
refused by the analysis-value guard. Infinite sources remain explicit, untransformed
in attached transforms until a suitable upstream finite representation is supplied.
Fixed-reference standardization accepts supplied center/SD and reference IDs/hash,
never recomputes parameters per visit, retains negative scores and checks inversion.

States distinguish missing, untested, failed, unknown, reference, nonsignificant,
true_zero, nonestimable, unreachable, constant/single-sample/nonfinite-reference
undefined values, infinity, exclusions and display-only placeholders. State IDs
must exactly reconcile to source rows and retain reasons. Family adapters remain
responsible for model-specific estimability and failure states; this shared layer
cannot manufacture native capability or alter scientific filtering thresholds.

## Categories, physical QA and evidence

Persistent category dictionaries distinguish biological class, condition, run-local
cluster, model and role namespaces, with colour, shape and line encodings. Same
cluster number in two runs is not an equivalence claim. Namespace/role/run keys use
canonical JSON tuples, so delimiter-containing labels cannot collide. Registry
serialization retains all colour, shape and line mappings together. Category/legend/label sets
must agree. `os_category_overlap` joins actual common IDs and retains all split/merge
intersections, missing categories, removed/new IDs, row fractions, column fractions
and Jaccard separately. It never forces a one-to-one mapping or declares accuracy.
Embedding metadata missingness is an explicit dark-grey cross category using the
existing reference-grey token; actual scale, category metadata and returned registry
carry the same colour/shape. Category counts
reconcile to all displayed cells, including missing metadata.

Glyph QA checks the actual selected font, including Greek/minus/subscript glyphs.
Text/background contrast has a declared 4.5:1 default warning threshold. Physical
panel/row budgets, pagination with repeated headers, and viewport exclusion IDs
retain all source values. Label suppression changes labels, not observations.
Automatic lint does not prove there is no overlap/clipping at final publication
size: before/after images in both presets still require owner visual review.

Evidence references pin record ID, independent figure key, repository-relative path,
SHA-256, source ref and support type. Resolution can check an available record root.
Companion 0242 and duplicate figure keys do not add independent records. Fewer than
20 verified eligible independent records per family stays pending. Transferable
visual designs are not direct method evidence, estimator verification or permission
to implement any of the 28 prospective families.

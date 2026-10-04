# Publication rules v1

This directory contains the versioned, data-only publication-policy layer for
omicstat (forked from medstat-55692f7).  It deliberately does not select estimators, alter module defaults,
or invoke runners.  A post-run finalizer can load these JSON files with the R
or Python standard library and use them to classify artifacts and create a
publication review.

Files:

- `universal_rules_v1.json` defines the stable schema, categories, severities,
  and rules that apply across modules.
- `module_rules_v1.json` supplies exactly one policy record for each installed
  omicstat module.  At M0 no module is installed and the `modules` list is
  empty; a record is added at each module's S5 install step.  A record maps
  legacy artifact names without moving them.
- `test_publication_rules.py` is a read-only standard-library validation test.

Run the validation from any working directory:

```powershell
python E:\claude workspace\skills-dev\omicstat\skills\_shared\publication\test_publication_rules.py
```

`universal_hard`, `design_conditional`, and `advisory` participate in a
general publication review.  `journal_specific` records differences between
journals and is warning-only until a named journal profile is supplied.

The release gate records one `rule_execution` row for every applicable catalog
rule. Rules the finalizer did not actually check produce a human-reviewable
pending finding; they cannot be treated as a pass merely because no finding
was previously emitted. `journal_specific` remains traceable but warning-only
by default.

Reviewer decisions are a core trust boundary. Accepted/rejected decisions must
use fixed local, non-publication evidence and an exact per-location SHA-256 map;
the finalizer rechecks every hash even when decisions came from an imported
manifest. The reproducibility gate records the Git commit/dirty state, module
entry-script hash, Python and R package inventories, R `sessionInfo()`, and the
immutable container image ID. Missing required provenance blocks readiness.

Modules exposing reportable estimates cannot opt out of canonical validation.
(In the medstat source this rule was introduced for `rcs-analysis`, whose
reportable point contrasts had to be persisted through the canonical effect
table contract.)

# QC rules

| ID | Severity | Trigger | Action | Source |
|---|---|---|---|---|
| LC-01 | info | Registered sets absent after ID overlap | Inspect identifier namespace and retained sets. | PACK T, S1 P-1 |
| LC-02 | warning | Ranked score ties | Inspect rank construction and report count. | Ranked-list contract |
| LC-03 | info | No BH-adjusted P below alpha | Report full table. | PACK D-08 |
| LC-04 | warning | 1999 rotations | Repeat at >=9999 for publication. | PACK S1 P-2 |
| LC-05 | info | camera/cameraPR fixed correlation | State that 0.01 is preset. | PACK S1 P-1 |
| LC-06 | warning | camera on a limma-dupcor upstream whose block is not modelled (`--acknowledge-block-ignored`) | State the unmodelled block; use fry/roast/mroast to model it. | S4 contract b |

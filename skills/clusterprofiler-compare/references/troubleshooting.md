# Troubleshooting — clusterprofiler-compare

- `OS_MISSING_COLUMN` -> include every required manifest field and `feature_id` in each list/background CSV.
- `OS_INVALID_UNIVERSE` -> give every gene eligible for the list's selection rule; selected genes must be a proper subset.
- CX-01 -> lists do not share one selectable population; inspect list_definitions.csv and interpret separate ORA results.
- `OS_REFDATA_MISSING` -> the requested offline collection is not pinned; use registered GO.
- `OS_EMPTY_DATA` -> no list has a testable GO overlap; verify key type and set-size bounds.

# Troubleshooting
- OS_MISSING_PACKAGE: rebuild the suite environment with this package; do not mix-install into the old locked image.
- OS_PACKAGE_VERSION / OS_API_MISMATCH: compare installed formals/schema with official target, review changes and repeat anchors. Do not silently accept a new version.
- OS_PSEUDOREPLICATION: provide genuine biological replication; do not rename technical runs to evade the check.
- OS_INVALID_DESIGN: verify sample IDs, declared conditions and independent/paired design.
- OS_OUTPUT_EXISTS: use a new empty output directory.
- Acceptance QC: a successful development run still has pending numerical/visual acceptance and no seal.

- OS_ZERO_SEMANTICS: current upstream code converts exact zeros to NA when no other NA occurs, even for log2 input. This wrapper refuses that case after normalization, rather than changing valid zeros.

# Relabeling note (2026-10-02)

Model labels and section headings in this folder's reports and CSVs were relabeled after the audit
(e.g. "Bisbee Baseline" -> "Bisbee et al. (2024)", "winner" -> "closer_to_observed"). No numbers changed.
The SHA-256 values in `preserved_input_manifest.json` and `audit_verification.json` refer to the
pre-relabel files.

Files were also moved on 2026-10-02 for the study-package layout: the comparison script is now
`scripts/compare_bisbee_zaller_report.R` and the ANES CSV lives in `external/` (not redistributed). Paths
recorded in the JSON files here are the pre-move paths.

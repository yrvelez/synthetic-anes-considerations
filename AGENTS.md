# AGENTS.md: Considerations-Based Synthetic Respondents and the Bisbee et al. (2024) Baseline

This repository is a study package from [The File Drawer](https://filedrawer.org). If you are an AI coding agent,
you are most likely here to reproduce or reanalyze the study. It is a methods comparison, not a survey
experiment: two ways of generating synthetic ANES 2024 feeling-thermometer ratings with an LLM persona
(direct generation after Bisbee et al. 2024; a considerations-based process after Zaller 1992), scored against
the same respondents' observed ratings. `README.md` has the full layout.

## Reanalyzing this study

**Data in this repository (read and analyze them directly):**
- `data/raw/`: the saved model outputs and consideration banks behind every report. Each row is one synthetic
  rating for one ANES case and target, with the ANES case ID and the persona variables used in the prompt.
- `results/`: the comparison tables for the primary run (`baseline_zaller_true84_n100_*`): individual-level
  error, distribution metrics and summary, truth coverage.
- `data/audit_20260926/`: an audit of the comparison script (target-name join, distribution metrics); read
  `RELABEL_NOTE.md` there before comparing older outputs.

**Not in this repository:** the observed ANES 2024 ratings. Download the CSV release of August 8, 2025 from
[electionstudies.org](https://electionstudies.org/data-center/2024-time-series-study/) and place it at
`external/anes_timeseries_2024_csv_20250808/anes_timeseries_2024_csv_20250808.csv`. Any comparison with the
human ratings needs that file; join on the ANES case ID.

**Reproduce the results** (no API calls; R with readr, dplyr, tidyr, stringr):

```bash
Rscript scripts/02_compare.R
python tests/test_compare_bisbee_evaluator.py
```

`scripts/compare_bisbee_zaller_report.R` holds the metrics. The generation scripts (`scripts/2_API_*`,
`scripts/run_bisbee_baseline_gemini.R`) call a model and need an API key or a local LM Studio server; their
outputs will differ from the saved ones, so reanalyze the saved outputs rather than regenerating them.
`original/bisbee_et_al_2024/` is the Bisbee et al. replication code, for reference.

**Rules for new work:**
1. The respondents in `data/raw/` are synthetic (LLM-generated). Never describe them as people or their ratings
   as survey responses.
2. New metrics or subsets are exploratory relative to `report.md`; label them so and report the run, target set
   and metric next to every number.
3. Do not redistribute the ANES file; point to its download page.
4. Cite the package (see `README.md`) and Bisbee et al. (2024) when you use the baseline.

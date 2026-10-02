# Considerations-Based Synthetic Respondents and the Bisbee et al. (2024) Baseline: ANES 2024 Feeling Thermometers

Study package in the [filedrawer](https://github.com/yrvelez/filedrawer) layout, design type
`methods_comparison`. It compares two ways of generating synthetic ANES 2024 feeling-thermometer ratings
with an LLM persona, direct generation following Bisbee et al. (2024) and a considerations-based
response process after Zaller (1992), against the same respondents' observed ratings. Findings are in
[`report.md`](report.md).

## Layout

- `report.md`: findings, design, limitations, references
- `study.json`: metadata the File Drawer reads; `reproduce` names the script and the outputs it rebuilds
- `scripts/`
  - `02_compare.R`: rebuilds `results/` from saved model outputs (no API calls)
  - `compare_bisbee_zaller_report.R`: the comparison and its metrics
  - `run_bisbee_baseline_gemini.R`: baseline generation (Gemini)
  - `2_API_synth_data_ANES2024_zaller_Gemini.R`: considerations pipeline (Gemini)
  - `2_API_synth_data_ANES2024_RAS_LMStudio.R`: considerations pipeline (local model via LM Studio)
  - `2_API_synth_data_ANES2024.R`: the Bisbee et al. (2024) prompts adapted to ANES 2024 (OpenAI)
  - `merge_csv_chunks.R`: merges chunked generation runs
- `results/`: comparison tables and report for the primary run
- `data/raw/`: saved model outputs and consideration banks for the runs behind every report, plus the
  earlier comparison reports. Each row carries the ANES case ID and the persona variables used in the prompt.
- `data/audit_20260926/`: audit of the comparison script (target-name join, distribution metrics) with
  its outputs; see `RELABEL_NOTE.md` there
- `original/bisbee_et_al_2024/`: scripts from the Bisbee et al. (2024) replication materials, for reference
- `tests/`: integration tests for the comparison script on synthetic fixtures
- `external/`: the ANES source data (**not included**; see below)

## ANES data

The ANES 2024 Time Series Study is not redistributed here. Download the CSV release of August 8, 2025 from
[electionstudies.org](https://electionstudies.org/data-center/2024-time-series-study/) and place it at

```
external/anes_timeseries_2024_csv_20250808/anes_timeseries_2024_csv_20250808.csv
```

## Reproduce

```bash
Rscript scripts/02_compare.R                 # R with readr, dplyr, tidyr, stringr
python tests/test_compare_bisbee_evaluator.py
filedrawer reproduce .                       # optional: re-runs 02_compare.R in a copy, compares results/*.csv byte for byte
```

Regenerating the model outputs requires `GEMINI_API_KEY` (or `OPENAI_API_KEY`, or a local LM Studio
server) and the generation scripts; model outputs will differ from the saved ones.

## Citation

Cite this package as: Velez, Y. R. 2026. "Considerations-Based Synthetic Respondents and the Bisbee et al.
(2024) Baseline: ANES 2024 Feeling Thermometers." Study package, The File Drawer.
https://github.com/yrvelez/synthetic-anes-considerations

The baseline follows Bisbee, J., J. D. Clinton, C. Dorff, B. Kenkel, and J. M. Larson. 2024. "Synthetic
Replacements for Human Survey Data? The Perils of Large Language Models." *Political Analysis* 32 (4):
401–416. https://doi.org/10.1017/pan.2024.5

Code: MIT. Reports, tables and derived data: CC BY 4.0.

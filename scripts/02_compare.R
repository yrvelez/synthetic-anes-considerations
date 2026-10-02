################################################################################
## Rebuilds the primary comparison in results/ from saved model outputs (no API
## calls): the Bisbee et al. (2024) baseline against the Zaller 8->4 pipeline,
## 100 ANES 2024 respondents, two draws each, eight thermometer targets.
##
## Needs the ANES 2024 Time Series CSV in external/ (see README.md).
## Run from the repository root: Rscript scripts/02_compare.R
################################################################################

Sys.setenv(
  BASELINE_FILE = "data/raw/therm_ANES2024_bisbee_Gemini_bisbee_gemini_n300_c1.csv",
  ZALLER_FILE = "data/raw/therm_ANES2024_zaller_Gemini_zaller_gemini_n100_true84.csv",
  OUT_FILE = "results/baseline_zaller_true84_n100.md",
  RUN_LABEL = "zaller_gemini_n100_true84",
  EXPECTED_RESPONDENTS = "100"
)

source("scripts/compare_bisbee_zaller_report.R")

# Considerations-Based Synthetic Respondents and the Bisbee et al. (2024) Baseline: ANES 2024 Feeling Thermometers

> **Provenance: HUMAN REVIEWED — see provenance.human_steps.** Hand-built `methods_comparison` package, filedrawer 0.1.0, 2026-10-02. Human steps recorded: 1. Release status: **draft**.

## Summary

Bisbee et al. (2024) show that LLM personas built from ANES respondents' demographics and political
predispositions recover average feeling thermometers reasonably well but with too little variation and
unstable distributions. This package asks whether a response process modeled on Zaller (1992) and
Zaller and Feldman (1992), in which each answer averages over a small sample of the considerations a
respondent has accepted, changes that picture. For 100 ANES 2024 respondents, 8 targets and 2 draws each,
the two approaches perform similarly. Direct generation following Bisbee et al. (2024) has slightly lower
individual-level error (RMSE 23.5 vs. 24.8; MAE 17.5 vs. 18.1; r = 0.77 vs. 0.74), and the
considerations pipeline has smaller average bias (−0.04 vs. 2.86 points) and smaller gaps between
predicted and observed target means (4.3 vs. 5.1 points). Neither approach recovers RFK Jr. well.

## Design

- **Respondents.** 100 complete-case respondents from the ANES 2024 Time Series Study, each rendered as
  the "full" persona prompt of Bisbee et al. (2024) updated for 2024 (age, marital status, race and
  ethnicity, gender, education, income, ideology, registration, party identification, political interest).
- **Targets.** Feeling thermometers (0–100) for Kamala Harris, Donald Trump, Joe Biden, RFK Jr., JD Vance,
  Tim Walz, the Democratic Party and the Republican Party.
- **Baseline.** Direct generation: the persona is asked for a thermometer rating, an explanation and a
  confidence score, following Bisbee et al. (2024). Script: `scripts/run_bisbee_baseline_gemini.R`.
- **Zaller 8→4.** For each respondent and target the model produces 8 ranked considerations that
  respondent would hold (saved in `data/raw/anes2024_considerations_zaller_zaller_gemini_n100_true84.csv`);
  each response draw samples 4 of them in R and asks for a rating given only those. Script:
  `scripts/2_API_synth_data_ANES2024_zaller_Gemini.R`, whose staged design builds the considerations from a
  shared per-target universe; the universe file for this run is not among the saved outputs.
- **Model and draws.** Gemini Flash through the `generateContent` API, 2 independent draws per respondent
  and target for each method (1,600 rows per method).
- **When.** All model outputs were generated on April 14–15, 2026; the primary comparison uses the
  baseline run of April 14, 15:06–15:22 EDT, and the considerations run of the same day (considerations
  16:23–17:03, responses 20:10–20:33 EDT). The comparison script was audited on September 26, 2026. See
  [When the runs happened](#when-the-runs-happened).
- **Benchmark.** The respondent's observed pre-election thermometer. 798 of 800 respondent-target cells
  have a valid observed rating (one missing for Joe Biden, one for RFK Jr.); predictions are the mean of the
  two draws. Respondents are weighted equally, so nothing here estimates weighted national quantities.

## Results

All numbers come from `results/` (rebuilt by `scripts/02_compare.R`) and match the audited outputs in
`data/audit_20260926/` exactly.

**Individual-level recovery.**

| Method | RMSE | MAE | Bias | r |
| --- | --- | --- | --- | --- |
| Bisbee et al. (2024) baseline | 23.49 | 17.45 | 2.86 | 0.77 |
| Zaller 8→4 | 24.79 | 18.12 | −0.04 | 0.74 |

Cell by cell, the baseline is closer to the observed rating in 381 cells (47.7%), the considerations
pipeline in 364 (45.6%), and 53 (6.6%) are ties. By target, the considerations pipeline has lower RMSE for
the Democratic Party (19.0 vs. 20.3) and roughly equal RMSE for Joe Biden (20.9 vs. 20.8); the baseline is
lower for the other six targets, most clearly Tim Walz (24.3 vs. 28.2).

**Means and spread.** Averaged over targets, the absolute gap between predicted and observed means is 5.05
points for the baseline and 4.28 for the considerations pipeline; the absolute SD gap is 3.40 and 3.81.
The baseline overstates warmth toward the Democratic Party by 8.0 points; the considerations pipeline by
1.9. Both understate RFK Jr. (by 8.8 and 14.1 points) and compress his distribution (predicted SD about 15
against an observed 27.5).

**Distributions of raw draws.** Comparing the empirical distribution of individual draws with observed
ratings, total variation on the native 101-point scale favors the baseline (0.61 vs. 0.72, averaged over
targets), while on 11 fixed bins (0.41 vs. 0.40) and by Wasserstein-1 distance (7.7 vs. 7.6 points) the two
are nearly identical, so the native-scale gap depends on which exact integers each method produces
rather than on where its mass falls on the scale.

**Draw-to-draw variation.** The two draws for the same respondent and target are identical 1.3% of the
time under the baseline and 13.1% under the considerations pipeline; the mean absolute difference between
draws is 4.3 points for both, with a larger maximum for the considerations pipeline (27 vs. 15). Because
the ANES records one rating per respondent and target, these figures describe the generators, not
whether either matches human response instability.

## Earlier runs

`data/raw/` keeps the reports from earlier iterations: a 300-respondent run of both methods
(`bisbee_vs_zaller_n300_report.md`), two earlier variants of the considerations pipeline
(`bisbee_vs_ras_n100_v1_report.md`, `bisbee_vs_ras_n100_v2_blocked_report.md`), and the first
100-respondent run with an earlier sampler (`bisbee_vs_zaller_true84_n100_report_buggy_sampler.md`). Those
reports predate the September 2026 audit of the comparison script, which fixed a target-name join that
dropped every RFK Jr. row (they report 699 rather than 798 cells). Their numbers are not comparable to the
results above; the audit and the corrected script are in `data/audit_20260926/`.

## When the runs happened

Times are US Eastern (EDT) and come from the creation and last-modification times of each run's output
files, which the scripts write as generation proceeds; the scripts do not log timestamps themselves.
Because `gemini-flash-latest` is an alias, these dates are the best record of which Gemini model answered.

| Run | Outputs in `data/raw/` | Generated |
| --- | --- | --- |
| Considerations pipeline on a local model (LM Studio; script default `google/gemma-4-31b`) | `*_RAS_ras_prob.csv` | Apr 14, 2026, 07:05–07:37 |
| Bisbee et al. (2024) baseline, 300 respondents in three chunks (chunk 1 is the primary baseline) | `therm_ANES2024_bisbee_Gemini_bisbee_gemini_n300_{c1,merged}.csv` | Apr 14, 2026, 15:06–15:22 |
| Zaller 8→4, 300 respondents in three chunks | `*_zaller_gemini_n300_merged.csv` | Apr 14, 2026, 15:14–16:15 |
| Zaller 8→4, 100 respondents, earlier sampler | `therm_..._true84_buggy_sampler.csv` | Apr 14, 2026, 17:03–17:24 |
| Zaller 8→4, 100 respondents (primary) | `*_zaller_gemini_n100_true84.csv` | Apr 14, 2026, considerations 16:23–17:03, responses 20:10–20:33 |
| Considerations pipeline variant 1 | `*_ras_n100_v1.csv` | Apr 14, 2026, 22:20 – Apr 15, 2026, 07:58 |
| Considerations pipeline variant 2 | `*_ras_n100_v2_blocked.csv` | Apr 15, 2026, 10:21–10:53 |
| Comparison script audit | `data/audit_20260926/` | Sep 26, 2026 |
| Package assembled; `results/` rebuilt from saved outputs | `results/` | Oct 2, 2026 |

## Limitations

- One model family (Gemini Flash), one survey year, one question format, and 100 respondents. The
  comparison says nothing about transfer to other models, items or populations.
- Two draws per respondent and target are enough to describe draw-to-draw movement but not to estimate a
  respondent-specific response distribution.
- The model string sent to the API is not stored in the saved outputs; the scripts default to
  `gemini-flash-latest`, an alias whose underlying model changes over time. Rerunning the generation
  scripts today may reach a different model than the one that answered in April 2026.
- No uncertainty intervals are reported; differences of a point or two in RMSE between methods should not
  be read as reliable.

## Reproducing

Download the ANES 2024 Time Series CSV (see `README.md`) into `external/`, then run
`Rscript scripts/02_compare.R` or `filedrawer reproduce .`. This re-scores the saved model outputs and
makes no API calls. Regenerating the outputs themselves requires a Gemini API key and the generation
scripts in `scripts/`.

## References

American National Election Studies. 2025. *ANES 2024 Time Series Study Full Release* [dataset and documentation]. August 8, 2025 version. https://electionstudies.org

Bisbee, J., J. D. Clinton, C. Dorff, B. Kenkel, and J. M. Larson. 2024. "Synthetic Replacements for Human Survey Data? The Perils of Large Language Models." *Political Analysis* 32 (4): 401–416. https://doi.org/10.1017/pan.2024.5

Zaller, J. R. 1992. *The Nature and Origins of Mass Opinion*. Cambridge: Cambridge University Press. https://doi.org/10.1017/CBO9780511818691

Zaller, J., and S. Feldman. 1992. "A Simple Theory of the Survey Response: Answering Questions versus Revealing Preferences." *American Journal of Political Science* 36 (3): 579–616. https://doi.org/10.2307/2111583

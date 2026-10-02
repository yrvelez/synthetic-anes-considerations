# Bisbee et al. (2024) Baseline and Zaller 8->4 Pipeline Compared

Run label: `ras_n100_v1`

## Design

- Respondents compared: `100`
- Prompt type: `full`
- Draws per respondent: `2`
- Baseline: direct thermometer generation following Bisbee et al. (2024)
- Zaller: `8` generated considerations per target, `4` sampled into each response draw
- Evaluation target: observed ANES 2024 feeling thermometers for the same respondents

## Completeness

| model | respondents | prompt_types | draws | groups | rows |
| --- | --- | --- | --- | --- | --- |
| Bisbee et al. (2024) | 100 | 1 | 2 | 8 | 1600 |
| Zaller 8->4 | 100 | 1 | 2 | 8 | 1600 |

## Overall Truth Recovery

| model | rows | rmse | mae | bias | cor |
| --- | --- | --- | --- | --- | --- |
| Bisbee et al. (2024) | 699 | 22.81 | 16.82 | 4.52 | 0.80 |
| Zaller 8->4 | 699 | 24.50 | 18.23 | 5.25 | 0.76 |

Lower `rmse` and `mae` are better. Bias is `prediction - observed`. Higher correlation is better.

## Cell-Level Comparison (Smaller Absolute Error)

| closer_to_observed | cells | prop |
| --- | --- | --- |
| Baseline | 356 | 0.509 |
| Tie | 56 | 0.080 |
| Zaller | 287 | 0.411 |

## Within-Respondent Draw Variation

| model | prop_same | mean_abs_diff | median_abs_diff | max_abs_diff |
| --- | --- | --- | --- | --- |
| Bisbee et al. (2024) | 0.013 | 4.27 | 5.00 | 15.00 |
| Zaller 8->4 | 0.088 | 5.80 | 5.00 | 40.00 |

Lower `prop_same` means the two draws collapsed less often. Higher `mean_abs_diff` means more draw-to-draw movement.

## Group-Level Truth Recovery

| model | group | rows | rmse | mae | bias | cor |
| --- | --- | --- | --- | --- | --- | --- |
| Bisbee et al. (2024) | Democratic Party | 100 | 20.25 | 16.57 | 8.04 | 0.85 |
| Bisbee et al. (2024) | Donald Trump | 100 | 22.56 | 14.32 | 3.68 | 0.84 |
| Bisbee et al. (2024) | JD Vance | 100 | 24.32 | 18.21 | 3.23 | 0.74 |
| Bisbee et al. (2024) | Joe Biden | 99 | 20.78 | 15.76 | 4.79 | 0.82 |
| Bisbee et al. (2024) | Kamala Harris | 100 | 20.76 | 15.04 | 4.45 | 0.84 |
| Bisbee et al. (2024) | Republican Party | 100 | 26.03 | 19.55 | 3.68 | 0.71 |
| Bisbee et al. (2024) | Tim Walz | 100 | 24.31 | 18.27 | 3.73 | 0.74 |
| Zaller 8->4 | Democratic Party | 100 | 19.94 | 16.12 | 4.89 | 0.83 |
| Zaller 8->4 | Donald Trump | 100 | 24.27 | 16.32 | 5.95 | 0.81 |
| Zaller 8->4 | JD Vance | 100 | 25.92 | 18.94 | 7.87 | 0.72 |
| Zaller 8->4 | Joe Biden | 99 | 20.10 | 15.14 | -2.84 | 0.81 |
| Zaller 8->4 | Kamala Harris | 100 | 22.35 | 17.21 | 4.22 | 0.81 |
| Zaller 8->4 | Republican Party | 100 | 29.20 | 21.63 | 4.44 | 0.68 |
| Zaller 8->4 | Tim Walz | 100 | 28.03 | 22.20 | 12.11 | 0.69 |

## Mean And SD Recovery

| model | mean_abs_mean_gap | mean_abs_sd_gap |
| --- | --- | --- |
| Bisbee et al. (2024) | 4.51 | 2.14 |
| Zaller 8->4 | 6.05 | 4.72 |

| model | group | actual_mean | pred_mean | mean_gap | actual_sd | pred_sd | sd_gap |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Bisbee et al. (2024) | Democratic Party | 46.77 | 54.81 | 8.04 | 32.05 | 35.28 | 3.23 |
| Bisbee et al. (2024) | Donald Trump | 32.67 | 36.35 | 3.68 | 39.67 | 38.35 | -1.33 |
| Bisbee et al. (2024) | JD Vance | 34.50 | 37.74 | 3.23 | 33.88 | 33.39 | -0.49 |
| Bisbee et al. (2024) | Joe Biden | 48.08 | 52.87 | 4.79 | 34.07 | 33.94 | -0.14 |
| Bisbee et al. (2024) | Kamala Harris | 50.76 | 55.20 | 4.44 | 37.58 | 33.20 | -4.38 |
| Bisbee et al. (2024) | Republican Party | 37.67 | 41.36 | 3.69 | 31.10 | 35.55 | 4.44 |
| Bisbee et al. (2024) | Tim Walz | 54.82 | 58.56 | 3.73 | 33.66 | 32.70 | -0.96 |
| Zaller 8->4 | Democratic Party | 46.77 | 51.66 | 4.89 | 32.05 | 33.78 | 1.73 |
| Zaller 8->4 | Donald Trump | 32.67 | 38.62 | 5.95 | 39.67 | 35.99 | -3.68 |
| Zaller 8->4 | JD Vance | 34.50 | 42.37 | 7.87 | 33.88 | 31.76 | -2.12 |
| Zaller 8->4 | Joe Biden | 48.08 | 45.24 | -2.84 | 34.07 | 28.18 | -5.90 |
| Zaller 8->4 | Kamala Harris | 50.76 | 54.98 | 4.22 | 37.58 | 29.73 | -7.84 |
| Zaller 8->4 | Republican Party | 37.67 | 42.11 | 4.44 | 31.10 | 39.08 | 7.98 |
| Zaller 8->4 | Tim Walz | 54.82 | 66.93 | 12.11 | 33.66 | 29.91 | -3.76 |

## Largest Cell-Level Differences Favoring the Baseline

| respID | group | actual | baseline | zaller | baseline_abs_error | zaller_abs_error | closer_to_observed |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 201896 | Donald Trump | 15.00 | 27.50 | 75.00 | 12.50 | 60.00 | Baseline |
| 201896 | JD Vance | 15.00 | 22.50 | 61.00 | 7.50 | 46.00 | Baseline |
| 200824 | Donald Trump | 0.00 | 17.50 | 52.50 | 17.50 | 52.50 | Baseline |
| 202172 | Tim Walz | 15.00 | 50.00 | 85.00 | 35.00 | 70.00 | Baseline |
| 201575 | Tim Walz | 0.00 | 52.50 | 86.00 | 52.50 | 86.00 | Baseline |
| 200084 | Tim Walz | 0.00 | 53.50 | 82.50 | 53.50 | 82.50 | Baseline |
| 201858 | Joe Biden | 85.00 | 77.50 | 49.00 | 7.50 | 36.00 | Baseline |
| 202356 | Joe Biden | 85.00 | 61.00 | 32.50 | 24.00 | 52.50 | Baseline |

## Largest Cell-Level Differences Favoring the Zaller Pipeline

| respID | group | actual | baseline | zaller | baseline_abs_error | zaller_abs_error | closer_to_observed |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 201575 | Donald Trump | 100.00 | 17.50 | 53.50 | 82.50 | 46.50 | Zaller |
| 200138 | Joe Biden | 40.00 | 82.50 | 52.50 | 42.50 | 12.50 | Zaller |
| 202356 | JD Vance | 50.00 | 23.50 | 47.50 | 26.50 | 2.50 | Zaller |
| 200862 | Joe Biden | 60.00 | 81.00 | 61.00 | 21.00 | 1.00 | Zaller |
| 202172 | Joe Biden | 30.00 | 52.50 | 32.50 | 22.50 | 2.50 | Zaller |
| 200435 | Democratic Party | 0.00 | 32.50 | 13.50 | 32.50 | 13.50 | Zaller |
| 200053 | JD Vance | 70.00 | 52.50 | 70.00 | 17.50 | 0.00 | Zaller |
| 200138 | Republican Party | 40.00 | 22.50 | 40.00 | 17.50 | 0.00 | Zaller |

## Example Zaller Rows

| respID | group | actual | baseline | zaller | closer_to_observed | sampled_considerations | explanation |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 201896 | Donald Trump | 15.00 | 27.50 | 75.00 | Baseline | Everything felt like it was cheaper and the economy was better when he was in charge. \\|\\| He is a strong leader who does not take any cr... | The economy felt much stronger under his leadership and I appreciate his direct approach. |
| 201896 | Democratic Party | 60.00 | 72.50 | 32.50 | Baseline | They are the party that is fighting to protect women's reproductive rights. \\|\\| They are way too obsessed with identity politics and all... | While I support their defense of reproductive rights, their excessive spending and focus on identity politics are major drawbacks. |
| 201896 | JD Vance | 15.00 | 22.50 | 61.00 | Baseline | He is a Marine veteran and I have a lot of respect for his military service. \\|\\| He represents the new and younger face of the MAGA move... | He is an articulate veteran who genuinely seems to understand the struggles of the working class. |
| 201575 | Donald Trump | 100.00 | 17.50 | 53.50 | Zaller | He is a billionaire who only cares about giving tax cuts to his rich friends. \\|\\| He is the former president who wants to get back into ... | He had a better economy, but he is offensive and seems to only care about his rich friends. |
| 200824 | Donald Trump | 0.00 | 17.50 | 52.50 | Baseline | He is a direct threat to democracy and should never be near power again. \\|\\| He is the former president who wants to get back into the W... | He is a strong leader but he is a direct threat to our democracy and his bullying behavior is exhausting. |
| 201209 | Joe Biden | 60.00 | 82.50 | 47.50 | Zaller | Inflation has made my groceries and gas way too expensive while he has been in office. \\|\\| I worry that he no longer has the mental stam... | I trust his foreign policy experience but worry about his age and the high cost of groceries. |

## Interpretation

- Overall RMSE comparison: baseline `22.81` vs Zaller `24.50`.
- The central question is not whether the pipelines differ, but whether either one better tracks observed ANES thermometers and reproduces plausible variation.
- The Zaller 8->4 setup is the first version in this project that actually gives consideration sampling room to matter, so its within-respondent variation numbers are substantively meaningful.
- If the baseline has lower RMSE/MAE while the Zaller pipeline shows more draw variation, then the tradeoff is predictive accuracy versus a richer theory-driven response process.


## References

Bisbee, J., J. D. Clinton, C. Dorff, B. Kenkel, and J. M. Larson. 2024. "Synthetic Replacements for Human Survey Data? The Perils of Large Language Models." *Political Analysis* 32 (4): 401–416. https://doi.org/10.1017/pan.2024.5

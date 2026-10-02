# Bisbee et al. (2024) Baseline and Zaller 8->4 Pipeline Compared

Run label: `ras_n100_v2_blocked`

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
| Zaller 8->4 | 699 | 25.70 | 19.73 | 5.04 | 0.71 |

Lower `rmse` and `mae` are better. Bias is `prediction - observed`. Higher correlation is better.

## Cell-Level Comparison (Smaller Absolute Error)

| closer_to_observed | cells | prop |
| --- | --- | --- |
| Baseline | 401 | 0.574 |
| Tie | 17 | 0.024 |
| Zaller | 281 | 0.402 |

## Within-Respondent Draw Variation

| model | prop_same | mean_abs_diff | median_abs_diff | max_abs_diff |
| --- | --- | --- | --- | --- |
| Bisbee et al. (2024) | 0.013 | 4.27 | 5.00 | 15.00 |
| Zaller 8->4 | 0.069 | 8.16 | 5.00 | 45.00 |

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
| Zaller 8->4 | Democratic Party | 100 | 19.56 | 15.68 | 0.48 | 0.79 |
| Zaller 8->4 | Donald Trump | 100 | 26.14 | 19.86 | 6.70 | 0.77 |
| Zaller 8->4 | JD Vance | 100 | 26.48 | 20.51 | 9.60 | 0.69 |
| Zaller 8->4 | Joe Biden | 99 | 22.62 | 18.37 | -7.16 | 0.79 |
| Zaller 8->4 | Kamala Harris | 100 | 24.77 | 19.70 | 3.51 | 0.76 |
| Zaller 8->4 | Republican Party | 100 | 27.47 | 20.15 | 4.88 | 0.67 |
| Zaller 8->4 | Tim Walz | 100 | 31.24 | 23.84 | 17.19 | 0.63 |

## Mean And SD Recovery

| model | mean_abs_mean_gap | mean_abs_sd_gap |
| --- | --- | --- |
| Bisbee et al. (2024) | 4.51 | 2.14 |
| Zaller 8->4 | 7.07 | 8.48 |

| model | group | actual_mean | pred_mean | mean_gap | actual_sd | pred_sd | sd_gap |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Bisbee et al. (2024) | Democratic Party | 46.77 | 54.81 | 8.04 | 32.05 | 35.28 | 3.23 |
| Bisbee et al. (2024) | Donald Trump | 32.67 | 36.35 | 3.68 | 39.67 | 38.35 | -1.33 |
| Bisbee et al. (2024) | JD Vance | 34.50 | 37.74 | 3.23 | 33.88 | 33.39 | -0.49 |
| Bisbee et al. (2024) | Joe Biden | 48.08 | 52.87 | 4.79 | 34.07 | 33.94 | -0.14 |
| Bisbee et al. (2024) | Kamala Harris | 50.76 | 55.20 | 4.44 | 37.58 | 33.20 | -4.38 |
| Bisbee et al. (2024) | Republican Party | 37.67 | 41.36 | 3.69 | 31.10 | 35.55 | 4.44 |
| Bisbee et al. (2024) | Tim Walz | 54.82 | 58.56 | 3.73 | 33.66 | 32.70 | -0.96 |
| Zaller 8->4 | Democratic Party | 46.77 | 47.24 | 0.48 | 32.05 | 28.00 | -4.05 |
| Zaller 8->4 | Donald Trump | 32.67 | 39.37 | 6.70 | 39.67 | 29.56 | -10.12 |
| Zaller 8->4 | JD Vance | 34.50 | 44.10 | 9.60 | 33.88 | 26.93 | -6.95 |
| Zaller 8->4 | Joe Biden | 48.08 | 40.92 | -7.16 | 34.07 | 22.22 | -11.85 |
| Zaller 8->4 | Kamala Harris | 50.76 | 54.26 | 3.50 | 37.58 | 26.07 | -11.50 |
| Zaller 8->4 | Republican Party | 37.67 | 42.54 | 4.88 | 31.10 | 34.79 | 3.69 |
| Zaller 8->4 | Tim Walz | 54.82 | 72.01 | 17.19 | 33.66 | 22.44 | -11.22 |

## Largest Cell-Level Differences Favoring the Baseline

| respID | group | actual | baseline | zaller | baseline_abs_error | zaller_abs_error | closer_to_observed |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 201896 | Donald Trump | 15.00 | 27.50 | 86.00 | 12.50 | 71.00 | Baseline |
| 201216 | Tim Walz | 0.00 | 17.50 | 65.00 | 17.50 | 65.00 | Baseline |
| 201896 | JD Vance | 15.00 | 22.50 | 66.50 | 7.50 | 51.50 | Baseline |
| 202288 | Tim Walz | 10.00 | 29.00 | 69.50 | 19.00 | 59.50 | Baseline |
| 201001 | Tim Walz | 0.00 | 22.50 | 62.50 | 22.50 | 62.50 | Baseline |
| 200015 | Tim Walz | 0.00 | 10.00 | 48.50 | 10.00 | 48.50 | Baseline |
| 202172 | Tim Walz | 15.00 | 50.00 | 87.50 | 35.00 | 72.50 | Baseline |
| 200985 | Joe Biden | 100.00 | 93.50 | 56.50 | 6.50 | 43.50 | Baseline |

## Largest Cell-Level Differences Favoring the Zaller Pipeline

| respID | group | actual | baseline | zaller | baseline_abs_error | zaller_abs_error | closer_to_observed |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 201322 | Tim Walz | 50.00 | 12.50 | 50.00 | 37.50 | 0.00 | Zaller |
| 201575 | Donald Trump | 100.00 | 17.50 | 55.00 | 82.50 | 45.00 | Zaller |
| 200381 | Tim Walz | 85.00 | 22.50 | 59.00 | 62.50 | 26.00 | Zaller |
| 200138 | Joe Biden | 40.00 | 82.50 | 32.50 | 42.50 | 7.50 | Zaller |
| 201155 | Tim Walz | 60.00 | 23.50 | 55.00 | 36.50 | 5.00 | Zaller |
| 202011 | Tim Walz | 50.00 | 12.50 | 44.00 | 37.50 | 6.00 | Zaller |
| 200510 | Tim Walz | 50.00 | 19.00 | 50.00 | 31.00 | 0.00 | Zaller |
| 201032 | Joe Biden | 50.00 | 83.50 | 52.50 | 33.50 | 2.50 | Zaller |

## Example Zaller Rows

| respID | group | actual | baseline | zaller | closer_to_observed | sampled_considerations | explanation |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 201896 | Donald Trump | 15.00 | 27.50 | 86.00 | Baseline | Everything felt like it was cheaper and the economy was better when he was in charge. \\|\\| He is a strong leader who does not take any cr... | The economy was much better during his presidency and he remains a strong leader who speaks his mind. |
| 201896 | Democratic Party | 60.00 | 72.50 | 22.00 | Baseline | They are the party that is fighting to protect women's reproductive rights. \\|\\| They are way too obsessed with identity politics and all... | They protect reproductive rights, but their spending has caused inflation and they are too focused on identity politics. |
| 200138 | Joe Biden | 40.00 | 82.50 | 32.50 | Zaller | Inflation has made my groceries and gas way too expensive while he has been in office. \\|\\| He is the current president but he looks and ... | High inflation and his visible age outweigh the positives of infrastructure and his honorable exit. |
| 201216 | Tim Walz | 0.00 | 17.50 | 65.00 | Baseline | He is a gun-owning hunter and a veteran who understands rural American life. \\|\\| He is a Midwestern governor who has that friendly and a... | His approachable personality is balanced against criticisms of his handling of civil unrest and his selection process. |
| 201896 | JD Vance | 15.00 | 22.50 | 66.50 | Baseline | He is a Marine veteran and I have a lot of respect for his military service. \\|\\| He represents the new and younger face of the MAGA move... | He is a smart Marine veteran who understands the working class and represents the future of the movement. |
| 201230 | Joe Biden | 60.00 | 83.50 | 42.50 | Zaller | He is the current president but he looks and sounds very old now. \\|\\| I worry that he no longer has the mental stamina to lead the count... | Concerns about his age and the impact of inflation outweigh his institutionalist approach. |

## Interpretation

- Overall RMSE comparison: baseline `22.81` vs Zaller `25.70`.
- The central question is not whether the pipelines differ, but whether either one better tracks observed ANES thermometers and reproduces plausible variation.
- The Zaller 8->4 setup is the first version in this project that actually gives consideration sampling room to matter, so its within-respondent variation numbers are substantively meaningful.
- If the baseline has lower RMSE/MAE while the Zaller pipeline shows more draw variation, then the tradeoff is predictive accuracy versus a richer theory-driven response process.


## References

Bisbee, J., J. D. Clinton, C. Dorff, B. Kenkel, and J. M. Larson. 2024. "Synthetic Replacements for Human Survey Data? The Perils of Large Language Models." *Political Analysis* 32 (4): 401–416. https://doi.org/10.1017/pan.2024.5

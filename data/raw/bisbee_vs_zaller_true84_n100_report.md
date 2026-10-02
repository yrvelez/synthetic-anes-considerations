# Bisbee et al. (2024) Baseline and Zaller 8->4 Pipeline Compared

Run label: `zaller_gemini_n100_true84`

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
| Zaller 8->4 | 699 | 24.08 | 17.44 | 1.95 | 0.77 |

Lower `rmse` and `mae` are better. Bias is `prediction - observed`. Higher correlation is better.

## Cell-Level Comparison (Smaller Absolute Error)

| closer_to_observed | cells | prop |
| --- | --- | --- |
| Baseline | 330 | 0.472 |
| Tie | 46 | 0.066 |
| Zaller | 323 | 0.462 |

## Within-Respondent Draw Variation

| model | prop_same | mean_abs_diff | median_abs_diff | max_abs_diff |
| --- | --- | --- | --- | --- |
| Bisbee et al. (2024) | 0.013 | 4.27 | 5.00 | 15.00 |
| Zaller 8->4 | 0.131 | 4.29 | 3.00 | 27.00 |

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
| Zaller 8->4 | Democratic Party | 100 | 19.03 | 15.07 | 1.91 | 0.82 |
| Zaller 8->4 | Donald Trump | 100 | 23.96 | 15.38 | 4.49 | 0.81 |
| Zaller 8->4 | JD Vance | 100 | 25.54 | 19.01 | 4.17 | 0.73 |
| Zaller 8->4 | Joe Biden | 99 | 20.87 | 15.10 | -2.21 | 0.80 |
| Zaller 8->4 | Kamala Harris | 100 | 22.08 | 15.80 | -0.66 | 0.81 |
| Zaller 8->4 | Republican Party | 100 | 27.42 | 20.41 | -0.36 | 0.66 |
| Zaller 8->4 | Tim Walz | 100 | 28.21 | 21.30 | 6.29 | 0.68 |

## Mean And SD Recovery

| model | mean_abs_mean_gap | mean_abs_sd_gap |
| --- | --- | --- |
| Bisbee et al. (2024) | 4.51 | 2.14 |
| Zaller 8->4 | 2.87 | 2.69 |

| model | group | actual_mean | pred_mean | mean_gap | actual_sd | pred_sd | sd_gap |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Bisbee et al. (2024) | Democratic Party | 46.77 | 54.81 | 8.04 | 32.05 | 35.28 | 3.23 |
| Bisbee et al. (2024) | Donald Trump | 32.67 | 36.35 | 3.68 | 39.67 | 38.35 | -1.33 |
| Bisbee et al. (2024) | JD Vance | 34.50 | 37.74 | 3.23 | 33.88 | 33.39 | -0.49 |
| Bisbee et al. (2024) | Joe Biden | 48.08 | 52.87 | 4.79 | 34.07 | 33.94 | -0.14 |
| Bisbee et al. (2024) | Kamala Harris | 50.76 | 55.20 | 4.44 | 37.58 | 33.20 | -4.38 |
| Bisbee et al. (2024) | Republican Party | 37.67 | 41.36 | 3.69 | 31.10 | 35.55 | 4.44 |
| Bisbee et al. (2024) | Tim Walz | 54.82 | 58.56 | 3.73 | 33.66 | 32.70 | -0.96 |
| Zaller 8->4 | Democratic Party | 46.77 | 48.68 | 1.91 | 32.05 | 32.14 | 0.10 |
| Zaller 8->4 | Donald Trump | 32.67 | 37.16 | 4.50 | 39.67 | 37.19 | -2.48 |
| Zaller 8->4 | JD Vance | 34.50 | 38.67 | 4.17 | 33.88 | 35.03 | 1.15 |
| Zaller 8->4 | Joe Biden | 48.08 | 45.87 | -2.21 | 34.07 | 31.07 | -3.01 |
| Zaller 8->4 | Kamala Harris | 50.76 | 50.10 | -0.66 | 37.58 | 31.88 | -5.70 |
| Zaller 8->4 | Republican Party | 37.67 | 37.31 | -0.36 | 31.10 | 35.45 | 4.35 |
| Zaller 8->4 | Tim Walz | 54.82 | 61.11 | 6.29 | 33.66 | 35.67 | 2.01 |

## Largest Cell-Level Differences Favoring the Baseline

| respID | group | actual | baseline | zaller | baseline_abs_error | zaller_abs_error | closer_to_observed |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 200824 | Donald Trump | 0.00 | 17.50 | 62.50 | 17.50 | 62.50 | Baseline |
| 200824 | Joe Biden | 70.00 | 72.50 | 22.50 | 2.50 | 47.50 | Baseline |
| 200824 | Kamala Harris | 85.00 | 62.50 | 25.00 | 22.50 | 60.00 | Baseline |
| 200152 | Tim Walz | 0.00 | 27.50 | 60.00 | 27.50 | 60.00 | Baseline |
| 201100 | Kamala Harris | 90.00 | 72.50 | 45.00 | 17.50 | 45.00 | Baseline |
| 201858 | Joe Biden | 85.00 | 77.50 | 50.00 | 7.50 | 35.00 | Baseline |
| 201896 | Donald Trump | 15.00 | 27.50 | 53.50 | 12.50 | 38.50 | Baseline |
| 200060 | Joe Biden | 85.00 | 86.50 | 58.00 | 1.50 | 27.00 | Baseline |

## Largest Cell-Level Differences Favoring the Zaller Pipeline

| respID | group | actual | baseline | zaller | baseline_abs_error | zaller_abs_error | closer_to_observed |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 201469 | JD Vance | 0.00 | 57.50 | 25.00 | 57.50 | 25.00 | Zaller |
| 200374 | JD Vance | 50.00 | 82.50 | 61.50 | 32.50 | 11.50 | Zaller |
| 200794 | Joe Biden | 60.00 | 82.50 | 58.50 | 22.50 | 1.50 | Zaller |
| 200886 | Kamala Harris | 50.00 | 80.00 | 60.00 | 30.00 | 10.00 | Zaller |
| 200749 | Democratic Party | 60.00 | 27.50 | 46.50 | 32.50 | 13.50 | Zaller |
| 201407 | Kamala Harris | 0.00 | 32.50 | 13.50 | 32.50 | 13.50 | Zaller |
| 201575 | Donald Trump | 100.00 | 17.50 | 36.50 | 82.50 | 63.50 | Zaller |
| 201247 | Democratic Party | 60.00 | 81.00 | 57.00 | 21.00 | 3.00 | Zaller |

## Example Zaller Rows

| respID | group | actual | baseline | zaller | closer_to_observed | sampled_considerations | explanation |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 200824 | Joe Biden | 70.00 | 72.50 | 22.50 | Baseline | He has a lot of experience but I worry he is just a figurehead for the staffers now. \\|\\| He is a decent man but he is clearly showing hi... | I have been a Democrat my whole life but he is showing his age and has no plan for inflation. |
| 200824 | Donald Trump | 0.00 | 17.50 | 62.50 | Baseline | Inflation would probably come down if he just let people drill for oil again. \\|\\| The guy is a total circus but my 401k and the economy ... | The economy was better when he was in charge and his legal troubles feel like a distraction. |
| 200824 | Kamala Harris | 85.00 | 62.50 | 25.00 | Baseline | Her laugh comes off as forced when she is trying to avoid a hard question. \\|\\| She feels a bit too much like a California elite for a gu... | She feels like an out-of-touch California elite who cares more about social justice than the economy or the border. |
| 200152 | Tim Walz | 0.00 | 27.50 | 60.00 | Baseline | I don't know much about him other than he's from the Midwest and seems friendly. \\|\\| He looks like a normal high school football coach o... | He seems like a friendly guy who understands the Midwest but he's a little too upbeat for how bad things are. |
| 201469 | JD Vance | 0.00 | 57.50 | 25.00 | Zaller | He is very articulate and smart but he comes off as a bit of a phoney. \\|\\| He seems to have changed every single one of his opinions jus... | He comes across as a phoney whose comments about women and social issues are very alienating. |
| 201896 | Kamala Harris | 50.00 | 62.50 | 33.50 | Baseline | Her record as a prosecutor was actually pretty tough and I think the party ignores that. \\|\\| I have not seen her take the lead on anythi... | I value her prosecutor past but worry she lacks the leadership skills to be next in line. |

## Interpretation

- Overall RMSE comparison: baseline `22.81` vs Zaller `24.08`.
- The central question is not whether the pipelines differ, but whether either one better tracks observed ANES thermometers and reproduces plausible variation.
- The Zaller 8->4 setup is the first version in this project that actually gives consideration sampling room to matter, so its within-respondent variation numbers are substantively meaningful.
- If the baseline has lower RMSE/MAE while the Zaller pipeline shows more draw variation, then the tradeoff is predictive accuracy versus a richer theory-driven response process.


## References

Bisbee, J., J. D. Clinton, C. Dorff, B. Kenkel, and J. M. Larson. 2024. "Synthetic Replacements for Human Survey Data? The Perils of Large Language Models." *Political Analysis* 32 (4): 401–416. https://doi.org/10.1017/pan.2024.5

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
| Zaller 8->4 | 699 | 23.92 | 17.38 | 2.24 | 0.77 |

Lower `rmse` and `mae` are better. Bias is `prediction - observed`. Higher correlation is better.

## Cell-Level Comparison (Smaller Absolute Error)

| closer_to_observed | cells | prop |
| --- | --- | --- |
| Baseline | 361 | 0.516 |
| Tie | 8 | 0.011 |
| Zaller | 330 | 0.472 |

## Within-Respondent Draw Variation

| model | prop_same | mean_abs_diff | median_abs_diff | max_abs_diff |
| --- | --- | --- | --- | --- |
| Bisbee et al. (2024) | 0.013 | 4.27 | 5.00 | 15.00 |
| Zaller 8->4 | 0.990 | 0.02 | 0.00 | 3.00 |

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
| Zaller 8->4 | Democratic Party | 100 | 19.97 | 15.56 | 2.90 | 0.81 |
| Zaller 8->4 | Donald Trump | 100 | 23.37 | 14.85 | 4.36 | 0.82 |
| Zaller 8->4 | JD Vance | 100 | 25.61 | 18.75 | 3.87 | 0.73 |
| Zaller 8->4 | Joe Biden | 99 | 21.28 | 15.84 | -0.55 | 0.79 |
| Zaller 8->4 | Kamala Harris | 100 | 21.81 | 15.74 | -0.36 | 0.81 |
| Zaller 8->4 | Republican Party | 100 | 26.97 | 20.17 | -0.49 | 0.68 |
| Zaller 8->4 | Tim Walz | 100 | 27.30 | 20.76 | 5.92 | 0.69 |

## Mean And SD Recovery

| model | mean_abs_mean_gap | mean_abs_sd_gap |
| --- | --- | --- |
| Bisbee et al. (2024) | 4.51 | 2.14 |
| Zaller 8->4 | 2.64 | 2.63 |

| model | group | actual_mean | pred_mean | mean_gap | actual_sd | pred_sd | sd_gap |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Bisbee et al. (2024) | Democratic Party | 46.77 | 54.81 | 8.04 | 32.05 | 35.28 | 3.23 |
| Bisbee et al. (2024) | Donald Trump | 32.67 | 36.35 | 3.68 | 39.67 | 38.35 | -1.33 |
| Bisbee et al. (2024) | JD Vance | 34.50 | 37.74 | 3.23 | 33.88 | 33.39 | -0.49 |
| Bisbee et al. (2024) | Joe Biden | 48.08 | 52.87 | 4.79 | 34.07 | 33.94 | -0.14 |
| Bisbee et al. (2024) | Kamala Harris | 50.76 | 55.20 | 4.44 | 37.58 | 33.20 | -4.38 |
| Bisbee et al. (2024) | Republican Party | 37.67 | 41.36 | 3.69 | 31.10 | 35.55 | 4.44 |
| Bisbee et al. (2024) | Tim Walz | 54.82 | 58.56 | 3.73 | 33.66 | 32.70 | -0.96 |
| Zaller 8->4 | Democratic Party | 46.77 | 49.67 | 2.90 | 32.05 | 32.77 | 0.72 |
| Zaller 8->4 | Donald Trump | 32.67 | 37.04 | 4.37 | 39.67 | 37.31 | -2.36 |
| Zaller 8->4 | JD Vance | 34.50 | 38.37 | 3.87 | 33.88 | 35.23 | 1.35 |
| Zaller 8->4 | Joe Biden | 48.08 | 47.54 | -0.55 | 34.07 | 31.61 | -2.46 |
| Zaller 8->4 | Kamala Harris | 50.76 | 50.40 | -0.36 | 37.58 | 31.73 | -5.84 |
| Zaller 8->4 | Republican Party | 37.67 | 37.18 | -0.49 | 31.10 | 35.60 | 4.50 |
| Zaller 8->4 | Tim Walz | 54.82 | 60.74 | 5.92 | 33.66 | 34.86 | 1.19 |

## Largest Cell-Level Differences Favoring the Baseline

| respID | group | actual | baseline | zaller | baseline_abs_error | zaller_abs_error | closer_to_observed |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 201575 | Donald Trump | 100.00 | 17.50 | 52.00 | 82.50 | 48.00 | Zaller |
| 201469 | JD Vance | 0.00 | 57.50 | 34.00 | 57.50 | 34.00 | Zaller |
| 200695 | Democratic Party | 70.00 | 97.50 | 75.00 | 27.50 | 5.00 | Zaller |
| 200749 | Democratic Party | 60.00 | 27.50 | 50.00 | 32.50 | 10.00 | Zaller |
| 201513 | Democratic Party | 60.00 | 87.50 | 66.00 | 27.50 | 6.00 | Zaller |
| 201247 | Democratic Party | 60.00 | 81.00 | 60.00 | 21.00 | 0.00 | Zaller |
| 201407 | Kamala Harris | 0.00 | 32.50 | 15.00 | 32.50 | 15.00 | Zaller |
| 200862 | Kamala Harris | 70.00 | 89.00 | 72.00 | 19.00 | 2.00 | Zaller |

## Largest Cell-Level Differences Favoring the Zaller Pipeline

| respID | group | actual | baseline | zaller | baseline_abs_error | zaller_abs_error | closer_to_observed |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 201575 | Donald Trump | 100.00 | 17.50 | 52.00 | 82.50 | 48.00 | Zaller |
| 201469 | JD Vance | 0.00 | 57.50 | 34.00 | 57.50 | 34.00 | Zaller |
| 200695 | Democratic Party | 70.00 | 97.50 | 75.00 | 27.50 | 5.00 | Zaller |
| 200749 | Democratic Party | 60.00 | 27.50 | 50.00 | 32.50 | 10.00 | Zaller |
| 201513 | Democratic Party | 60.00 | 87.50 | 66.00 | 27.50 | 6.00 | Zaller |
| 201247 | Democratic Party | 60.00 | 81.00 | 60.00 | 21.00 | 0.00 | Zaller |
| 201407 | Kamala Harris | 0.00 | 32.50 | 15.00 | 32.50 | 15.00 | Zaller |
| 200862 | Kamala Harris | 70.00 | 89.00 | 72.00 | 19.00 | 2.00 | Zaller |

## Example Zaller Rows

| respID | group | actual | baseline | zaller | closer_to_observed | sampled_considerations | explanation |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 201575 | Donald Trump | 100.00 | 17.50 | 52.00 | Zaller | I remember those stimulus checks had his name on them when I really needed the money. \\|\\| The way he talks about people is so disrespect... | I appreciated the stimulus money and lower prices but his behavior makes me uneasy. |
| 200824 | Donald Trump | 0.00 | 17.50 | 48.00 | Baseline | The guy is a total circus but my 401k and the economy felt better when he was in charge. \\|\\| I cannot stand how he handled himself after... | The economy felt better under him and the legal cases are a distraction, but I cannot stand his behavior. |
| 201896 | Donald Trump | 15.00 | 27.50 | 58.00 | Baseline | The economy and my 401k felt much stronger before the world went crazy in 2020. \\|\\| He is his own worst enemy because he cannot stop tal... | The economy was stronger under him and the legal cases feel biased, though I dislike his rhetoric and constant drama. |
| 201896 | Joe Biden | 60.00 | 72.50 | 42.00 | Baseline | I respect him as a person but he is clearly too old to be doing this for another four years. \\|\\| Inflation has really killed the value o... | He is a decent man but inflation is hurting my paycheck and I worry he is too old and influenced by activists. |
| 200824 | Joe Biden | 70.00 | 72.50 | 43.00 | Baseline | He is a decent man but he is clearly showing his age and losing his step. \\|\\| Gas and groceries are eating up my salary and he does not ... | He cares about the middle class, but his age and the cost of groceries make it hard to stay excited. |
| 201100 | Kamala Harris | 90.00 | 72.50 | 45.00 | Baseline | It is nice to see a woman who looks like me in such a high position. \\|\\| I honestly have no idea what she has been doing for the last fo... | I appreciate the representation but she seems stiff and I worry if she is truly ready. |

## Interpretation

- Overall RMSE comparison: baseline `22.81` vs Zaller `23.92`.
- The central question is not whether the pipelines differ, but whether either one better tracks observed ANES thermometers and reproduces plausible variation.
- The Zaller 8->4 setup is the first version in this project that actually gives consideration sampling room to matter, so its within-respondent variation numbers are substantively meaningful.
- If the baseline has lower RMSE/MAE while the Zaller pipeline shows more draw variation, then the tradeoff is predictive accuracy versus a richer theory-driven response process.


## References

Bisbee, J., J. D. Clinton, C. Dorff, B. Kenkel, and J. M. Larson. 2024. "Synthetic Replacements for Human Survey Data? The Perils of Large Language Models." *Political Analysis* 32 (4): 401–416. https://doi.org/10.1017/pan.2024.5

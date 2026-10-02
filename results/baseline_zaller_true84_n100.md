# Bisbee et al. (2024) Baseline and Zaller 8->4 Pipeline Compared

Run label: `zaller_gemini_n100_true84`

## Design

- Respondents compared: `100`
- Prompt type: `full`
- Draws per respondent: `2`
- Baseline: direct thermometer generation following Bisbee et al. (2024)
- Zaller: `8` generated considerations per target, `4` sampled into each response draw
- Evaluation target: observed ANES 2024 feeling thermometers for the same respondents
- Baseline input: `data/raw/therm_ANES2024_bisbee_Gemini_bisbee_gemini_n300_c1.csv`
- Zaller input: `data/raw/therm_ANES2024_zaller_Gemini_zaller_gemini_n100_true84.csv`
- Respondents receive equal weight; these results do not represent weighted national ANES estimates.

## Completeness

| model | respondents | prompt_types | draws | groups | rows |
| --- | --- | --- | --- | --- | --- |
| Bisbee et al. (2024) | 100 | 1 | 2 | 8 | 1600 |
| Zaller 8->4 | 100 | 1 | 2 | 8 | 1600 |

### Truth-join audit

Target names are normalized before joining. Both models must contain the same complete respondent-target-draw grid. Every valid observed outcome must join to both models; invalid/missing ANES ratings are counted explicitly.

| group | expected_respondents | valid_truth | missing_or_invalid_truth | baseline_matched | zaller_matched |
| --- | --- | --- | --- | --- | --- |
| Democratic Party | 100 | 100 | 0 | 100 | 100 |
| Donald Trump | 100 | 100 | 0 | 100 | 100 |
| JD Vance | 100 | 100 | 0 | 100 | 100 |
| Joe Biden | 100 | 99 | 1 | 99 | 99 |
| Kamala Harris | 100 | 100 | 0 | 100 | 100 |
| RFK Jr | 100 | 99 | 1 | 99 | 99 |
| Republican Party | 100 | 100 | 0 | 100 | 100 |
| Tim Walz | 100 | 100 | 0 | 100 | 100 |

## Overall Truth Recovery

| model | rows | rmse | mae | bias | cor |
| --- | --- | --- | --- | --- | --- |
| Bisbee et al. (2024) | 798 | 23.49 | 17.45 | 2.86 | 0.77 |
| Zaller 8->4 | 798 | 24.79 | 18.12 | -0.04 | 0.74 |

Lower `rmse` and `mae` are better. Bias is `prediction - observed`. Higher correlation is better.

## Cell-Level Comparison (Smaller Absolute Error)

| closer_to_observed | cells | prop |
| --- | --- | --- |
| Baseline | 381 | 0.477 |
| Tie | 53 | 0.066 |
| Zaller | 364 | 0.456 |

## Within-Respondent Draw Variation

| model | prop_same | mean_abs_diff | median_abs_diff | max_abs_diff |
| --- | --- | --- | --- | --- |
| Bisbee et al. (2024) | 0.013 | 4.27 | 5.00 | 15.00 |
| Zaller 8->4 | 0.131 | 4.29 | 3.00 | 27.00 |

Lower `prop_same` means the two draws collapsed less often. Higher `mean_abs_diff` means more draw-to-draw movement.

## Target-Level Truth Recovery

| model | group | rows | rmse | mae | bias | cor |
| --- | --- | --- | --- | --- | --- | --- |
| Bisbee et al. (2024) | Democratic Party | 100 | 20.25 | 16.57 | 8.04 | 0.85 |
| Bisbee et al. (2024) | Donald Trump | 100 | 22.56 | 14.32 | 3.68 | 0.84 |
| Bisbee et al. (2024) | JD Vance | 100 | 24.32 | 18.21 | 3.23 | 0.74 |
| Bisbee et al. (2024) | Joe Biden | 99 | 20.78 | 15.76 | 4.79 | 0.82 |
| Bisbee et al. (2024) | Kamala Harris | 100 | 20.76 | 15.04 | 4.45 | 0.84 |
| Bisbee et al. (2024) | RFK Jr | 99 | 27.80 | 21.91 | -8.81 | 0.34 |
| Bisbee et al. (2024) | Republican Party | 100 | 26.03 | 19.55 | 3.68 | 0.71 |
| Bisbee et al. (2024) | Tim Walz | 100 | 24.31 | 18.27 | 3.73 | 0.74 |
| Zaller 8->4 | Democratic Party | 100 | 19.03 | 15.07 | 1.91 | 0.82 |
| Zaller 8->4 | Donald Trump | 100 | 23.96 | 15.38 | 4.49 | 0.81 |
| Zaller 8->4 | JD Vance | 100 | 25.54 | 19.01 | 4.17 | 0.73 |
| Zaller 8->4 | Joe Biden | 99 | 20.87 | 15.10 | -2.21 | 0.80 |
| Zaller 8->4 | Kamala Harris | 100 | 22.08 | 15.80 | -0.66 | 0.81 |
| Zaller 8->4 | RFK Jr | 99 | 29.32 | 22.90 | -14.12 | 0.39 |
| Zaller 8->4 | Republican Party | 100 | 27.42 | 20.41 | -0.36 | 0.66 |
| Zaller 8->4 | Tim Walz | 100 | 28.21 | 21.30 | 6.29 | 0.68 |

## Mean And SD Recovery

| model | mean_abs_mean_gap | mean_abs_sd_gap |
| --- | --- | --- |
| Bisbee et al. (2024) | 5.05 | 3.40 |
| Zaller 8->4 | 4.28 | 3.81 |

| model | group | actual_mean | pred_mean | mean_gap | actual_sd | pred_sd | sd_gap |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Bisbee et al. (2024) | Democratic Party | 46.77 | 54.81 | 8.04 | 32.05 | 35.28 | 3.23 |
| Bisbee et al. (2024) | Donald Trump | 32.67 | 36.35 | 3.68 | 39.67 | 38.35 | -1.33 |
| Bisbee et al. (2024) | JD Vance | 34.50 | 37.74 | 3.23 | 33.88 | 33.39 | -0.49 |
| Bisbee et al. (2024) | Joe Biden | 48.08 | 52.87 | 4.79 | 34.07 | 33.94 | -0.14 |
| Bisbee et al. (2024) | Kamala Harris | 50.76 | 55.20 | 4.44 | 37.58 | 33.20 | -4.38 |
| Bisbee et al. (2024) | RFK Jr | 37.47 | 28.66 | -8.81 | 27.50 | 15.26 | -12.24 |
| Bisbee et al. (2024) | Republican Party | 37.67 | 41.36 | 3.69 | 31.10 | 35.55 | 4.44 |
| Bisbee et al. (2024) | Tim Walz | 54.82 | 58.56 | 3.73 | 33.66 | 32.70 | -0.96 |
| Zaller 8->4 | Democratic Party | 46.77 | 48.68 | 1.91 | 32.05 | 32.14 | 0.10 |
| Zaller 8->4 | Donald Trump | 32.67 | 37.16 | 4.50 | 39.67 | 37.19 | -2.48 |
| Zaller 8->4 | JD Vance | 34.50 | 38.67 | 4.17 | 33.88 | 35.03 | 1.15 |
| Zaller 8->4 | Joe Biden | 48.08 | 45.87 | -2.21 | 34.07 | 31.07 | -3.01 |
| Zaller 8->4 | Kamala Harris | 50.76 | 50.10 | -0.66 | 37.58 | 31.88 | -5.70 |
| Zaller 8->4 | RFK Jr | 37.47 | 23.36 | -14.12 | 27.50 | 15.79 | -11.71 |
| Zaller 8->4 | Republican Party | 37.67 | 37.31 | -0.36 | 31.10 | 35.45 | 4.35 |
| Zaller 8->4 | Tim Walz | 54.82 | 61.11 | 6.29 | 33.66 | 35.67 | 2.01 |

## Distribution Recovery From Raw Draws

Primary TV compares the empirical distribution of raw individual draws with the distribution of valid observed ratings on all 101 integer thermometer categories. Each respondent has equal total mass and their two draws divide that mass equally. Point-prediction means from the earlier sections are not used here.

Sensitivity measures use 11 fixed bins (0-4, 5-14, ..., 85-94, 95-100) and one-dimensional Wasserstein distance (W1) on the native 0-100 scale. W1 scaled divides the distance by 100. Smaller values are better for every measure.

The all-respondent summary gives each of the eight political targets equal weight. The PID summary gives each target-by-party cell equal weight. Party subgroups use saved Democrat/Independent/Republican persona classifications. Political targets and demographic subgroups are distinct dimensions.

| model | subgroup_type | cells | min_respondents | tv_native_101 | tv_fixed_11_bins | w1_thermometer_points | w1_scaled |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Bisbee et al. (2024) | PID | 24 | 4 | 0.7087 | 0.5666 | 15.8166 | 0.1582 |
| Bisbee et al. (2024) | all | 8 | 99 | 0.6070 | 0.4129 | 7.6768 | 0.0768 |
| Zaller 8->4 | PID | 24 | 4 | 0.7986 | 0.5427 | 14.9077 | 0.1491 |
| Zaller 8->4 | all | 8 | 99 | 0.7212 | 0.4004 | 7.5505 | 0.0755 |

### All-respondent results by target

| model | group | n_respondents | n_draws | tv_native_101 | tv_fixed_11_bins | w1_thermometer_points | w1_scaled |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Bisbee et al. (2024) | Kamala Harris | 100 | 200 | 0.6150 | 0.3700 | 6.2750 | 0.0628 |
| Bisbee et al. (2024) | Donald Trump | 100 | 200 | 0.6150 | 0.4000 | 4.6500 | 0.0465 |
| Bisbee et al. (2024) | Joe Biden | 99 | 198 | 0.5303 | 0.3636 | 5.8232 | 0.0582 |
| Bisbee et al. (2024) | RFK Jr | 99 | 198 | 0.5960 | 0.4394 | 13.6111 | 0.1361 |
| Bisbee et al. (2024) | JD Vance | 100 | 200 | 0.6100 | 0.4850 | 6.6750 | 0.0668 |
| Bisbee et al. (2024) | Tim Walz | 100 | 200 | 0.6300 | 0.3800 | 7.7050 | 0.0771 |
| Bisbee et al. (2024) | Democratic Party | 100 | 200 | 0.6300 | 0.5300 | 9.4600 | 0.0946 |
| Bisbee et al. (2024) | Republican Party | 100 | 200 | 0.6300 | 0.3350 | 7.2150 | 0.0721 |
| Zaller 8->4 | Kamala Harris | 100 | 200 | 0.7600 | 0.4250 | 6.1600 | 0.0616 |
| Zaller 8->4 | Donald Trump | 100 | 200 | 0.6850 | 0.3600 | 5.5950 | 0.0560 |
| Zaller 8->4 | Joe Biden | 99 | 198 | 0.7172 | 0.3939 | 4.7020 | 0.0470 |
| Zaller 8->4 | RFK Jr | 99 | 198 | 0.7121 | 0.4545 | 15.7020 | 0.1570 |
| Zaller 8->4 | JD Vance | 100 | 200 | 0.7700 | 0.4250 | 7.0700 | 0.0707 |
| Zaller 8->4 | Tim Walz | 100 | 200 | 0.8150 | 0.3700 | 9.4250 | 0.0942 |
| Zaller 8->4 | Democratic Party | 100 | 200 | 0.7050 | 0.3950 | 4.7900 | 0.0479 |
| Zaller 8->4 | Republican Party | 100 | 200 | 0.6050 | 0.3800 | 6.9600 | 0.0696 |

All target-by-party cells are saved in the distribution_metrics CSV beside this report. With only two draws per person and small party cells, these are descriptive empirical distribution checks, not estimates of a well-resolved person-specific response distribution. No uncertainty intervals or new model calls are included.

## Largest Cell-Level Differences Favoring the Baseline

| respID | group | actual | baseline | zaller | baseline_abs_error | zaller_abs_error | closer_to_observed |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 200824 | Donald Trump | 0.00 | 17.50 | 62.50 | 17.50 | 62.50 | Baseline |
| 200824 | Joe Biden | 70.00 | 72.50 | 22.50 | 2.50 | 47.50 | Baseline |
| 200824 | Kamala Harris | 85.00 | 62.50 | 25.00 | 22.50 | 60.00 | Baseline |
| 200152 | Tim Walz | 0.00 | 27.50 | 60.00 | 27.50 | 60.00 | Baseline |
| 200459 | RFK Jr | 60.00 | 57.50 | 25.00 | 2.50 | 35.00 | Baseline |
| 202172 | RFK Jr | 70.00 | 50.00 | 17.50 | 20.00 | 52.50 | Baseline |
| 201100 | Kamala Harris | 90.00 | 72.50 | 45.00 | 17.50 | 45.00 | Baseline |
| 201506 | RFK Jr | 60.00 | 62.50 | 30.00 | 2.50 | 30.00 | Baseline |

## Largest Cell-Level Differences Favoring the Zaller Pipeline

| respID | group | actual | baseline | zaller | baseline_abs_error | zaller_abs_error | closer_to_observed |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 201469 | JD Vance | 0.00 | 57.50 | 25.00 | 57.50 | 25.00 | Zaller |
| 200541 | RFK Jr | 30.00 | 72.50 | 42.50 | 42.50 | 12.50 | Zaller |
| 201223 | RFK Jr | 30.00 | 52.50 | 30.00 | 22.50 | 0.00 | Zaller |
| 200374 | JD Vance | 50.00 | 82.50 | 61.50 | 32.50 | 11.50 | Zaller |
| 200435 | RFK Jr | 0.00 | 47.50 | 26.50 | 47.50 | 26.50 | Zaller |
| 200794 | Joe Biden | 60.00 | 82.50 | 58.50 | 22.50 | 1.50 | Zaller |
| 201858 | RFK Jr | 60.00 | 22.50 | 43.00 | 37.50 | 17.00 | Zaller |
| 200886 | Kamala Harris | 50.00 | 80.00 | 60.00 | 30.00 | 10.00 | Zaller |

## Example Zaller Rows

| respID | group | actual | baseline | zaller | closer_to_observed | sampled_considerations | explanation |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 200824 | Joe Biden | 70.00 | 72.50 | 22.50 | Baseline | He has a lot of experience but I worry he is just a figurehead for the staffers now. \\|\\| He is a decent man but he is clearly showing hi... | I have been a Democrat my whole life but he is showing his age and has no plan for inflation. |
| 200824 | Donald Trump | 0.00 | 17.50 | 62.50 | Baseline | Inflation would probably come down if he just let people drill for oil again. \\|\\| The guy is a total circus but my 401k and the economy ... | The economy was better when he was in charge and his legal troubles feel like a distraction. |
| 200824 | Kamala Harris | 85.00 | 62.50 | 25.00 | Baseline | Her laugh comes off as forced when she is trying to avoid a hard question. \\|\\| She feels a bit too much like a California elite for a gu... | She feels like an out-of-touch California elite who cares more about social justice than the economy or the border. |
| 201681 | RFK Jr | 50.00 | 67.50 | 32.50 | Tie | I wonder if he's going to pull more votes from Trump or from Biden in November. \\|\\| He is pro-choice which is a big problem for most con... | He is right about government corruption but his pro-choice stance and spoiler potential are problems. |
| 200152 | Tim Walz | 0.00 | 27.50 | 60.00 | Baseline | I don't know much about him other than he's from the Midwest and seems friendly. \\|\\| He looks like a normal high school football coach o... | He seems like a friendly guy who understands the Midwest but he's a little too upbeat for how bad things are. |
| 200459 | RFK Jr | 60.00 | 57.50 | 25.00 | Baseline | He is probably just going to be a spoiler and take away votes from Trump. \\|\\| Some of his conspiracy theories go a bit too far even for ... | He has a few decent points about the deep state but remains a liberal who will just spoil the election. |

## Interpretation

- Overall RMSE comparison: baseline `23.49` vs Zaller `24.79`.
- The central question is not whether the pipelines differ, but whether either one better tracks observed ANES thermometers and reproduces plausible variation.
- More variation between model draws does not establish more realistic human occasion variation; the human data here contain one observed rating per respondent and target.
- These saved predictions concern one ANES year and selected complete-case respondents. They do not establish transfer to unseen datasets or questions.

## References

Bisbee, J., J. D. Clinton, C. Dorff, B. Kenkel, and J. M. Larson. 2024. "Synthetic Replacements for Human Survey Data? The Perils of Large Language Models." *Political Analysis* 32 (4): 401–416. https://doi.org/10.1017/pan.2024.5


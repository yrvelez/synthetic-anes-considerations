# Bisbee et al. (2024) Baseline and Zaller Pipeline Compared

Run label: `n300_full_gemini`
Baseline file: `data/raw/therm_ANES2024_bisbee_Gemini_bisbee_gemini_n300_merged.csv`
Zaller file: `data/raw/therm_ANES2024_zaller_Gemini_zaller_gemini_n300_merged.csv`

## Setup

- Matched respondents: 300
- Prompt type: `full`
- Draws per respondent: `2`
- Backend: Gemini Flash
- Comparison unit: respondent-target-draw rows, with respondent as the substantive sampling unit

## Completeness

| model | rows | respondents | prompts | draws | groups |
| --- | --- | --- | --- | --- | --- |
| baseline | 4800 | 300 | 1 | 2 | 8 |
| zaller | 4800 | 300 | 1 | 2 | 8 |

## Within-Respondent Draw Variation

| model | prop_same | mean_abs_diff | median_abs_diff | max_abs_diff |
| --- | --- | --- | --- | --- |
| baseline | 0.014 | 4.28 | 5 | 15 |
| zaller | 0.999 | 0.00 | 0 | 5 |

Lower `prop_same` means fewer identical draw pairs. Higher `mean_abs_diff` means more draw-to-draw movement in thermometer ratings.

## Target-Level Summary

| model | group | mean_therm | sd_therm |
| --- | --- | --- | --- |
| baseline | Democratic Party | 50.0 | 37.1 |
| zaller | Democratic Party | 44.8 | 34.6 |
| baseline | Donald Trump | 42.5 | 40.3 |
| zaller | Donald Trump | 42.1 | 39.3 |
| baseline | JD Vance | 42.9 | 35.0 |
| zaller | JD Vance | 41.8 | 36.7 |
| baseline | Joe Biden | 48.9 | 35.8 |
| zaller | Joe Biden | 43.8 | 34.4 |
| baseline | Kamala Harris | 50.6 | 34.4 |
| zaller | Kamala Harris | 45.8 | 33.6 |
| baseline | RFK Jr | 31.4 | 16.6 |
| zaller | RFK Jr | 23.6 | 16.1 |
| baseline | Republican Party | 46.0 | 36.7 |
| zaller | Republican Party | 41.0 | 35.8 |
| baseline | Tim Walz | 53.6 | 34.1 |
| zaller | Tim Walz | 54.5 | 37.0 |

## Baseline vs Zaller Deltas

Overall mean delta (`zaller - baseline`): `-3.56`. Mean absolute delta: `6.43`. Max absolute delta: `45`.

| group | mean_delta | mean_abs_delta |
| --- | --- | --- |
| RFK Jr | -7.84 | 10.10 |
| Joe Biden | -5.10 | 6.93 |
| Democratic Party | -5.26 | 6.73 |
| Kamala Harris | -4.72 | 6.45 |
| Republican Party | -4.98 | 6.44 |
| Tim Walz | 0.90 | 5.50 |
| JD Vance | -1.09 | 5.16 |
| Donald Trump | -0.39 | 4.10 |

## Largest Row-Level Differences

| respID | draw | group | base_therm | zaller_therm | delta | sampled_considerations |
| --- | --- | --- | --- | --- | --- | --- |
| 203687 | 1 | RFK Jr | 60 | 15 | -45 | He is still a Democrat at the end of the day and I don't trust that family. \\|\\| He has some interesting ideas about health but he is too... |
| 204130 | 2 | RFK Jr | 70 | 25 | -45 | He is right about the vaccines and the government lying to us but he is still a liberal. \\|\\| I am afraid he will be a spoiler and help t... |
| 205843 | 1 | Kamala Harris | 62 | 20 | -42 | I don't think she is ready to be president and her word salad speeches make me nervous. \\|\\| She is way too liberal for me on things like... |
| 200824 | 1 | Joe Biden | 75 | 35 | -40 | He is just too old and it is embarrassing to watch him stumble through speeches. \\|\\| My groceries and insurance have doubled and I do no... |
| 201506 | 1 | RFK Jr | 65 | 25 | -40 | I agree with some of his points about government corruption and big pharma but he is still a Kennedy liberal at heart. \\|\\| He is a distr... |
| 202707 | 2 | RFK Jr | 25 | 65 | 40 | I like that he is willing to speak out against the big pharmaceutical companies and the way they control the government. \\|\\| He says som... |
| 203687 | 2 | RFK Jr | 55 | 15 | -40 | He is still a Democrat at the end of the day and I don't trust that family. \\|\\| He has some interesting ideas about health but he is too... |
| 204130 | 1 | RFK Jr | 65 | 25 | -40 | He is right about the vaccines and the government lying to us but he is still a liberal. \\|\\| I am afraid he will be a spoiler and help t... |
| 200633 | 1 | Kamala Harris | 70 | 32 | -38 | She is the heartbeat-away insurance policy and I am not entirely confident she is ready for the top job. \\|\\| Her public speaking often f... |
| 205843 | 1 | Democratic Party | 68 | 30 | -38 | This isn't the party of JFK or even Bill Clinton anymore and it makes me feel left behind. \\|\\| I stay a Democrat because I believe in th... |

## Example Zaller Rows

| respID | draw | group | thermometer | explanation | sampled_considerations |
| --- | --- | --- | --- | --- | --- |
| 200015 | 1 | Democratic Party | 8 | They have abandoned American citizens for identity politics and a high-tax socialist agenda. | They care more about illegal immigrants than they do about the citizens who actually pay taxes. \\|\\| Their obsession with identity politi... |
| 200015 | 1 | Donald Trump | 88 | He has the backbone to fix the economy and border though I wish he would talk less on social media. | My business and my 401k were much stronger when he was in the White House. \\|\\| He is the only person with the backbone to actually secur... |
| 200015 | 1 | JD Vance | 82 | He is a sharp veteran and effective communicator who understands the working class and the party's future. | He is a sharp guy who represents the future of the party and understands the working class. \\|\\| I like that he served in the Marines and... |
| 200015 | 1 | Joe Biden | 12 | He is a career politician who is mentally unfit and has let inflation and foreign policy fail. | He is clearly not mentally fit to be running the country for another four years. \\|\\| Inflation under his watch has made everything from ... |
| 200039 | 2 | Democratic Party | 85 | They represent science and progress even if I wish they were a bit more aggressive in their tactics. | They are the only party that actually cares about protecting my rights as a woman. \\|\\| I wish they were a bit more aggressive and didn't... |
| 200039 | 2 | Donald Trump | 2 | He is a threat to the rule of law whose supporters seem to live in an alternate reality. | He is a genuine threat to democracy and I am terrified of him getting back in power. \\|\\| I am so sick of his constant whining and the wa... |
| 200039 | 2 | JD Vance | 3 | His comments about women are offensive and his extremist views on gender and family are very creepy. | He is a total phony who sold his soul and changed his views just to get ahead. \\|\\| His comments about childless cat ladies were so offen... |
| 200039 | 2 | Joe Biden | 78 | He was a steady hand for the country but his debate performance made it clear he needed to step down. | I am so incredibly relieved that he decided to step aside for a younger candidate. \\|\\| He was a steady hand who fixed a lot of the mess ... |
| 200084 | 1 | Democratic Party | 44 | I trust them with reproductive rights but they feel elitist and are too focused on social issues over the economy. | They are the only ones I trust to protect reproductive rights and keep the government out of my healthcare. \\|\\| They seem more focused o... |
| 200084 | 1 | Donald Trump | 52 | I miss the better economy and border security from his term but the constant drama and legal battles are exhausting. | I remember my paycheck going a lot further when he was in office before the pandemic. \\|\\| The way he talks about people is exhausting an... |
| 200084 | 1 | JD Vance | 34 | His offensive comments about women and his status as a MAGA puppet make it hard to trust his intelligence. | His comments about childless women were really offensive and made him seem out of touch with modern life. \\|\\| He seems very smart and ar... |
| 200084 | 1 | Joe Biden | 32 | He is a nice person but he is clearly too old for the job and inflation has hurt my finances significantly. | He is clearly too old for this job and it makes me nervous for the country's safety. \\|\\| Inflation has been out of control under his wat... |

## Interpretation

- Baseline captures broad partisan alignment cleanly but tends to sound more polished and globally reasoned.
- Zaller responses are grounded in sampled considerations, so shifts tend to track whichever cues were accessible in the draw.
- The key empirical questions are whether Zaller changes target means materially, increases realistic heterogeneity, and yields explanations that sound more like contingent survey reasoning than compact political commentary.


## References

Bisbee, J., J. D. Clinton, C. Dorff, B. Kenkel, and J. M. Larson. 2024. "Synthetic Replacements for Human Survey Data? The Perils of Large Language Models." *Political Analysis* 32 (4): 401–416. https://doi.org/10.1017/pan.2024.5

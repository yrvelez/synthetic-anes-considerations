## Compares synthetic thermometer predictions from the baseline design of
## Bisbee et al. (2024) with the Zaller 8->4 considerations pipeline.
##
## Reference: Bisbee, J., J. D. Clinton, C. Dorff, B. Kenkel, and J. M. Larson. 2024. "Synthetic Replacements for Human Survey Data? The Perils of Large Language Models." Political Analysis 32 (4): 401–416. https://doi.org/10.1017/pan.2024.5

library(readr)
library(dplyr)
library(tidyr)
library(stringr)

baseline_file <- Sys.getenv("BASELINE_FILE", "")
zaller_file <- Sys.getenv("ZALLER_FILE", "")
out_file <- Sys.getenv("OUT_FILE", "baseline_zaller_comparison.md")
run_label <- Sys.getenv("RUN_LABEL", "")
expected_respondents <- as.integer(Sys.getenv("EXPECTED_RESPONDENTS", "0"))
anes_file <- Sys.getenv(
  "ANES_FILE",
  "./external/anes_timeseries_2024_csv_20250808/anes_timeseries_2024_csv_20250808.csv"
)

if (!nzchar(baseline_file) || !file.exists(baseline_file)) {
  stop("BASELINE_FILE is missing or does not exist.")
}

if (!nzchar(zaller_file) || !file.exists(zaller_file)) {
  stop("ZALLER_FILE is missing or does not exist.")
}

if (!file.exists(anes_file)) {
  stop("ANES_FILE does not exist.")
}

TARGET_MAP <- c(
  "Kamala Harris" = "V241156",
  "Donald Trump" = "V241157",
  "Joe Biden" = "V241158",
  "RFK Jr" = "V241159",
  "JD Vance" = "V241164",
  "Tim Walz" = "V241165",
  "Democratic Party" = "V241166",
  "Republican Party" = "V241167"
)

normalize_target <- function(x) {
  x <- trimws(x)
  case_when(
    x %in% c("RFK Jr.", "Robert F. Kennedy Jr.", "Robert F Kennedy Jr.") ~ "RFK Jr",
    x == "J.D. Vance" ~ "JD Vance",
    TRUE ~ x
  )
}

validate_predictions <- function(df, model_name) {
  required <- c("respID", "group", "prompt_type", "draw", "thermometer", "confidence")
  if (!all(required %in% names(df))) stop(model_name, ": missing required prediction columns.")
  df <- df %>% mutate(group = normalize_target(group))
  if (any(is.na(df$respID)) || any(is.na(df$group)) ||
      any(!df$group %in% names(TARGET_MAP))) {
    stop(model_name, ": missing respondent ID or unknown target name.")
  }
  if (any(!is.finite(df$thermometer)) || any(df$thermometer < 0 | df$thermometer > 100) ||
      any(df$thermometer != round(df$thermometer))) {
    stop(model_name, ": thermometer predictions must be integers in 0:100.")
  }
  if (n_distinct(df$prompt_type) != 1 || any(is.na(df$prompt_type))) {
    stop(model_name, ": evaluate one prompt type at a time.")
  }
  if (!setequal(unique(df$draw), c(1, 2)) || any(is.na(df$draw))) {
    stop(model_name, ": this comparison requires exactly draws 1 and 2.")
  }
  if (anyDuplicated(df[c("respID", "group", "draw")])) {
    stop(model_name, ": duplicate respondent-target-draw predictions.")
  }
  expected <- expand_grid(respID = unique(df$respID), group = names(TARGET_MAP), draw = c(1, 2))
  if (nrow(anti_join(expected, df, by = c("respID", "group", "draw"))) > 0) {
    stop(model_name, ": incomplete respondent-target-draw grid.")
  }
  if (expected_respondents > 0 && n_distinct(df$respID) != expected_respondents) {
    stop(model_name, ": respondent count differs from EXPECTED_RESPONDENTS.")
  }
  df
}

baseline <- validate_predictions(read_csv(baseline_file, show_col_types = FALSE), "Baseline")
zaller <- validate_predictions(read_csv(zaller_file, show_col_types = FALSE), "Zaller")
if (!setequal(baseline$respID, zaller$respID) ||
    !setequal(baseline$prompt_type, zaller$prompt_type)) {
  stop("Models must cover the same respondents and prompt type.")
}
if ("PID" %in% names(baseline) && "PID" %in% names(zaller)) {
  pid_profiles <- bind_rows(baseline, zaller) %>% distinct(respID, PID)
  if (any(is.na(pid_profiles$PID)) || anyDuplicated(pid_profiles$respID)) {
    stop("Party subgroup profiles must be nonmissing and agree across models and draws.")
  }
}

actual_full <- read_csv(
  anes_file,
  col_select = c("V200001", all_of(unname(TARGET_MAP))),
  show_col_types = FALSE
) %>%
  rename(respID = V200001) %>%
  pivot_longer(
    cols = all_of(unname(TARGET_MAP)),
    names_to = "source_col",
    values_to = "actual"
  ) %>%
  mutate(
    group = recode(source_col, !!!setNames(names(TARGET_MAP), unname(TARGET_MAP))),
    actual = as.numeric(actual)
  ) %>%
  filter(respID %in% baseline$respID) %>%
  select(respID, group, actual)

expected_truth_keys <- expand_grid(respID = unique(baseline$respID), group = names(TARGET_MAP))
if (anyDuplicated(actual_full[c("respID", "group")]) ||
    nrow(anti_join(expected_truth_keys, actual_full, by = c("respID", "group"))) > 0) {
  stop("ANES truth rows do not uniquely cover every expected respondent-target pair.")
}
actual <- actual_full %>% filter(!is.na(actual), actual >= 0, actual <= 100)
if (any(actual$actual != round(actual$actual))) stop("ANES thermometer truths must be integers.")
truth_coverage <- actual_full %>%
  group_by(group) %>%
  summarise(
    expected_respondents = n(),
    valid_truth = sum(!is.na(actual) & actual >= 0 & actual <= 100),
    missing_or_invalid_truth = expected_respondents - valid_truth,
    .groups = "drop"
  )
for (model_name in c("baseline", "zaller")) {
  model_df <- get(model_name)
  if (nrow(anti_join(actual, model_df, by = c("respID", "group"))) > 0) {
    stop(model_name, ": a valid truth has no prediction; refusing a lossy evaluation join.")
  }
}
if (any(truth_coverage$valid_truth == 0)) stop("Every target must have at least one valid truth.")
truth_coverage <- truth_coverage %>%
  mutate(baseline_matched = valid_truth, zaller_matched = valid_truth)

escape_md <- function(x) {
  x <- as.character(x)
  x <- gsub("\\|", "\\\\|", x, perl = TRUE)
  x <- gsub("[\r\n]+", " ", x, perl = TRUE)
  x <- gsub("\\s{2,}", " ", x, perl = TRUE)
  trimws(x)
}

shorten <- function(x, width = 120) {
  x <- escape_md(x)
  ifelse(nchar(x) > width, paste0(substr(x, 1, width - 3), "..."), x)
}

md_table <- function(df) {
  if (nrow(df) == 0 || ncol(df) == 0) {
    return("_No rows._")
  }

  header <- paste0("| ", paste(names(df), collapse = " | "), " |")
  divider <- paste0("| ", paste(rep("---", ncol(df)), collapse = " | "), " |")
  rows <- apply(df, 1, function(row) {
    paste0("| ", paste(vapply(row, escape_md, character(1)), collapse = " | "), " |")
  })

  paste(c(header, divider, rows), collapse = "\n")
}

round_num <- function(x, digits = 2) {
  ifelse(is.na(x), NA_character_, format(round(x, digits), nsmall = digits, trim = TRUE))
}

completion_summary <- function(df, model_name) {
  tibble(
    model = model_name,
    respondents = n_distinct(df$respID),
    prompt_types = n_distinct(df$prompt_type),
    draws = n_distinct(df$draw),
    groups = n_distinct(df$group),
    rows = nrow(df)
  )
}

variation_summary <- function(df, model_name) {
  df %>%
    select(respID, group, draw, thermometer) %>%
    distinct() %>%
    pivot_wider(names_from = draw, values_from = thermometer, names_prefix = "draw_") %>%
    filter(!is.na(draw_1), !is.na(draw_2)) %>%
    mutate(
      abs_diff = abs(draw_1 - draw_2),
      same = draw_1 == draw_2
    ) %>%
    summarise(
      model = model_name,
      prop_same = round_num(mean(same), 3),
      mean_abs_diff = round_num(mean(abs_diff), 2),
      median_abs_diff = round_num(median(abs_diff), 2),
      max_abs_diff = round_num(max(abs_diff), 2)
    )
}

prediction_means <- function(df, model_name) {
  df %>%
    group_by(respID, group) %>%
    summarise(
      pred = mean(thermometer),
      mean_confidence = mean(confidence, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    mutate(model = model_name)
}

recovery_metrics <- function(df, model_name) {
  joined <- df %>%
    inner_join(actual, by = c("respID", "group"))

  overall <- joined %>%
    summarise(
      model = model_name,
      rows = n(),
      rmse = sqrt(mean((pred - actual)^2)),
      mae = mean(abs(pred - actual)),
      bias = mean(pred - actual),
      cor = suppressWarnings(cor(pred, actual))
    ) %>%
    mutate(across(c(rmse, mae, bias, cor), round_num))

  by_group <- joined %>%
    group_by(group) %>%
    summarise(
      rows = n(),
      rmse = sqrt(mean((pred - actual)^2)),
      mae = mean(abs(pred - actual)),
      bias = mean(pred - actual),
      cor = suppressWarnings(cor(pred, actual)),
      .groups = "drop"
    ) %>%
    mutate(
      model = model_name,
      across(c(rmse, mae, bias, cor), round_num)
    ) %>%
    select(model, group, rows, rmse, mae, bias, cor)

  list(overall = overall, by_group = by_group, joined = joined)
}

group_distribution_gaps <- function(pred_df, model_name) {
  pred_df %>%
    inner_join(actual, by = c("respID", "group")) %>%
    group_by(group) %>%
    summarise(
      actual_mean = mean(actual),
      pred_mean = mean(pred),
      mean_gap = pred_mean - actual_mean,
      actual_sd = sd(actual),
      pred_sd = sd(pred),
      sd_gap = pred_sd - actual_sd,
      .groups = "drop"
    ) %>%
    mutate(
      model = model_name,
      across(c(actual_mean, pred_mean, mean_gap, actual_sd, pred_sd, sd_gap), round_num)
    ) %>%
    select(model, group, actual_mean, pred_mean, mean_gap, actual_sd, pred_sd, sd_gap)
}

raw_draw_distribution_metrics <- function(df, model_name) {
  # Each respondent contributes total mass one, split across their raw draws.
  # Do not bin the average of their draws: that creates unobserved middle ratings.
  matched <- df %>%
    inner_join(actual, by = c("respID", "group")) %>%
    group_by(respID, group) %>%
    mutate(draw_weight = 1 / n()) %>%
    ungroup()
  strata <- list(list(type = "all", label = "All respondents", data = matched))
  if ("PID" %in% names(matched)) {
    strata <- c(strata, lapply(sort(unique(matched$PID)), function(pid) {
      list(type = "PID", label = pid, data = filter(matched, PID == pid))
    }))
  }
  rows <- list()
  for (stratum in strata) {
    for (target in names(TARGET_MAP)) {
      cell <- stratum$data %>% filter(group == target)
      if (nrow(cell) == 0) next
      truth <- cell %>% distinct(respID, actual)
      n_people <- nrow(truth)
      p <- vapply(0:100, function(k) {
        sum(cell$draw_weight[cell$thermometer == k]) / n_people
      }, numeric(1))
      q <- tabulate(truth$actual + 1L, nbins = 101) / n_people
      # Prespecified centered ten-point bins: 0-4, 5-14, ..., 85-94, 95-100.
      bin_index <- pmin(10L, (0:100 + 5L) %/% 10L)
      p_bin <- vapply(0:10, function(k) sum(p[bin_index == k]), numeric(1))
      q_bin <- vapply(0:10, function(k) sum(q[bin_index == k]), numeric(1))
      w1 <- sum(abs(cumsum(p - q))[1:100])
      stopifnot(abs(sum(p) - 1) < 1e-10, abs(sum(q) - 1) < 1e-10)
      rows[[length(rows) + 1L]] <- tibble(
        model = model_name, group = target,
        subgroup_type = stratum$type, subgroup = stratum$label,
        n_respondents = n_people, n_draws = nrow(cell),
        tv_native_101 = 0.5 * sum(abs(p - q)),
        tv_fixed_11_bins = 0.5 * sum(abs(p_bin - q_bin)),
        w1_thermometer_points = w1, w1_scaled = w1 / 100
      )
    }
  }
  bind_rows(rows)
}

baseline_completion <- completion_summary(baseline, "Bisbee et al. (2024)")
zaller_completion <- completion_summary(zaller, "Zaller 8->4")

baseline_var <- variation_summary(baseline, "Bisbee et al. (2024)")
zaller_var <- variation_summary(zaller, "Zaller 8->4")
variation_tbl <- bind_rows(baseline_var, zaller_var)

baseline_pred <- prediction_means(baseline, "Bisbee et al. (2024)")
zaller_pred <- prediction_means(zaller, "Zaller 8->4")

baseline_rec <- recovery_metrics(baseline_pred, "Bisbee et al. (2024)")
zaller_rec <- recovery_metrics(zaller_pred, "Zaller 8->4")

overall_recovery_tbl <- bind_rows(baseline_rec$overall, zaller_rec$overall)
group_recovery_tbl <- bind_rows(baseline_rec$by_group, zaller_rec$by_group)

baseline_dist <- group_distribution_gaps(baseline_pred, "Bisbee et al. (2024)")
zaller_dist <- group_distribution_gaps(zaller_pred, "Zaller 8->4")
distribution_tbl <- bind_rows(baseline_dist, zaller_dist)
raw_distribution_tbl <- bind_rows(
  raw_draw_distribution_metrics(baseline, "Bisbee et al. (2024)"),
  raw_draw_distribution_metrics(zaller, "Zaller 8->4")
)
raw_distribution_summary <- raw_distribution_tbl %>%
  group_by(model, subgroup_type) %>%
  summarise(
    cells = n(), min_respondents = min(n_respondents),
    across(c(tv_native_101, tv_fixed_11_bins, w1_thermometer_points, w1_scaled), mean),
    .groups = "drop"
  )

head_to_head <- baseline_rec$joined %>%
  select(respID, group, actual, baseline_pred = pred, baseline_conf = mean_confidence) %>%
  inner_join(
    zaller_rec$joined %>%
      select(respID, group, zaller_pred = pred, zaller_conf = mean_confidence),
    by = c("respID", "group")
  ) %>%
  mutate(
    baseline_abs_error = abs(baseline_pred - actual),
    zaller_abs_error = abs(zaller_pred - actual),
    closer_to_observed = case_when(
      baseline_abs_error < zaller_abs_error ~ "Baseline",
      zaller_abs_error < baseline_abs_error ~ "Zaller",
      TRUE ~ "Tie"
    ),
    zaller_minus_baseline = zaller_pred - baseline_pred
  )

win_tbl <- head_to_head %>%
  count(closer_to_observed, name = "cells") %>%
  mutate(prop = round_num(cells / sum(cells), 3))

overall_gap_tbl <- bind_rows(
  baseline_dist %>%
    summarise(
      model = first(model),
      mean_abs_mean_gap = mean(abs(as.numeric(mean_gap))),
      mean_abs_sd_gap = mean(abs(as.numeric(sd_gap)))
    ),
  zaller_dist %>%
    summarise(
      model = first(model),
      mean_abs_mean_gap = mean(abs(as.numeric(mean_gap))),
      mean_abs_sd_gap = mean(abs(as.numeric(sd_gap)))
    )
) %>%
  mutate(across(c(mean_abs_mean_gap, mean_abs_sd_gap), round_num))

largest_baseline_advantage_tbl <- head_to_head %>%
  mutate(abs_error_gap = zaller_abs_error - baseline_abs_error) %>%
  arrange(desc(abs_error_gap)) %>%
  slice_head(n = 8) %>%
  transmute(
    respID,
    group,
    actual = round_num(actual),
    baseline = round_num(baseline_pred),
    zaller = round_num(zaller_pred),
    baseline_abs_error = round_num(baseline_abs_error),
    zaller_abs_error = round_num(zaller_abs_error),
    closer_to_observed
  )

largest_zaller_advantage_tbl <- head_to_head %>%
  mutate(abs_error_gap = baseline_abs_error - zaller_abs_error) %>%
  arrange(desc(abs_error_gap)) %>%
  slice_head(n = 8) %>%
  transmute(
    respID,
    group,
    actual = round_num(actual),
    baseline = round_num(baseline_pred),
    zaller = round_num(zaller_pred),
    baseline_abs_error = round_num(baseline_abs_error),
    zaller_abs_error = round_num(zaller_abs_error),
    closer_to_observed
  )

zaller_examples <- zaller %>%
  group_by(respID, group) %>%
  slice_head(n = 1) %>%
  ungroup() %>%
  inner_join(
    head_to_head %>%
      select(respID, group, actual, baseline_pred, zaller_pred, closer_to_observed),
    by = c("respID", "group")
  ) %>%
  arrange(desc(abs(zaller_pred - baseline_pred))) %>%
  slice_head(n = 6) %>%
  transmute(
    respID,
    group,
    actual = round_num(actual),
    baseline = round_num(baseline_pred),
    zaller = round_num(zaller_pred),
    closer_to_observed,
    sampled_considerations = shorten(sampled_considerations, 140),
    explanation = shorten(explanation, 140)
  )

baseline_best_rmse <- overall_recovery_tbl %>%
  filter(model == "Bisbee et al. (2024)") %>%
  pull(rmse)

zaller_best_rmse <- overall_recovery_tbl %>%
  filter(model == "Zaller 8->4") %>%
  pull(rmse)

headline <- c(
  "# Bisbee et al. (2024) Baseline and Zaller 8->4 Pipeline Compared",
  "",
  if (nzchar(run_label)) paste0("Run label: `", run_label, "`") else NULL,
  ""
)

methods <- c(
  "## Design",
  "",
  paste0("- Respondents compared: `", if (expected_respondents > 0) expected_respondents else max(baseline_completion$respondents, zaller_completion$respondents), "`"),
  paste0("- Prompt type: `", unique(baseline$prompt_type), "`"),
  "- Draws per respondent: `2`",
  "- Baseline: direct thermometer generation following Bisbee et al. (2024)",
  "- Zaller: `8` generated considerations per target, `4` sampled into each response draw",
  "- Evaluation target: observed ANES 2024 feeling thermometers for the same respondents",
  paste0("- Baseline input: `", baseline_file, "`"),
  paste0("- Zaller input: `", zaller_file, "`"),
  "- Respondents receive equal weight; these results do not represent weighted national ANES estimates.",
  ""
)

completeness <- c(
  "## Completeness",
  "",
  md_table(bind_rows(baseline_completion, zaller_completion)),
  "",
  "### Truth-join audit",
  "",
  "Target names are normalized before joining. Both models must contain the same complete respondent-target-draw grid. Every valid observed outcome must join to both models; invalid/missing ANES ratings are counted explicitly.",
  "",
  md_table(truth_coverage),
  ""
)

recovery <- c(
  "## Overall Truth Recovery",
  "",
  md_table(overall_recovery_tbl),
  "",
  "Lower `rmse` and `mae` are better. Bias is `prediction - observed`. Higher correlation is better.",
  ""
)

cell_comparison <- c(
  "## Cell-Level Comparison (Smaller Absolute Error)",
  "",
  md_table(win_tbl),
  ""
)

variation <- c(
  "## Within-Respondent Draw Variation",
  "",
  md_table(variation_tbl),
  "",
  "Lower `prop_same` means the two draws collapsed less often. Higher `mean_abs_diff` means more draw-to-draw movement.",
  ""
)

group_recovery <- c(
  "## Target-Level Truth Recovery",
  "",
  md_table(group_recovery_tbl),
  ""
)

distribution <- c(
  "## Mean And SD Recovery",
  "",
  md_table(overall_gap_tbl),
  "",
  md_table(distribution_tbl),
  ""
)

raw_distribution <- c(
  "## Distribution Recovery From Raw Draws",
  "",
  "Primary TV compares the empirical distribution of raw individual draws with the distribution of valid observed ratings on all 101 integer thermometer categories. Each respondent has equal total mass and their two draws divide that mass equally. Point-prediction means from the earlier sections are not used here.",
  "",
  "Sensitivity measures use 11 fixed bins (0-4, 5-14, ..., 85-94, 95-100) and one-dimensional Wasserstein distance (W1) on the native 0-100 scale. W1 scaled divides the distance by 100. Smaller values are better for every measure.",
  "",
  "The all-respondent summary gives each of the eight political targets equal weight. The PID summary gives each target-by-party cell equal weight. Party subgroups use saved Democrat/Independent/Republican persona classifications. Political targets and demographic subgroups are distinct dimensions.",
  "",
  md_table(raw_distribution_summary %>%
             mutate(across(c(tv_native_101, tv_fixed_11_bins, w1_thermometer_points, w1_scaled), ~round_num(.x, 4)))),
  "",
  "### All-respondent results by target",
  "",
  md_table(raw_distribution_tbl %>% filter(subgroup_type == "all") %>%
             select(-subgroup_type, -subgroup) %>%
             mutate(across(c(tv_native_101, tv_fixed_11_bins, w1_thermometer_points, w1_scaled), ~round_num(.x, 4)))),
  "",
  "All target-by-party cells are saved in the distribution_metrics CSV beside this report. With only two draws per person and small party cells, these are descriptive empirical distribution checks, not estimates of a well-resolved person-specific response distribution. No uncertainty intervals or new model calls are included.",
  ""
)

examples <- c(
  "## Largest Cell-Level Differences Favoring the Baseline",
  "",
  md_table(largest_baseline_advantage_tbl),
  "",
  "## Largest Cell-Level Differences Favoring the Zaller Pipeline",
  "",
  md_table(largest_zaller_advantage_tbl),
  "",
  "## Example Zaller Rows",
  "",
  md_table(zaller_examples),
  ""
)

interpretation <- c(
  "## Interpretation",
  "",
  paste0(
    "- Overall RMSE comparison: baseline `", baseline_best_rmse,
    "` vs Zaller `", zaller_best_rmse, "`."
  ),
  "- The central question is not whether the pipelines differ, but whether either one better tracks observed ANES thermometers and reproduces plausible variation.",
  "- More variation between model draws does not establish more realistic human occasion variation; the human data here contain one observed rating per respondent and target.",
  "- These saved predictions concern one ANES year and selected complete-case respondents. They do not establish transfer to unseen datasets or questions.",
  ""
)

references <- c(
  "## References",
  "",
  "Bisbee, J., J. D. Clinton, C. Dorff, B. Kenkel, and J. M. Larson. 2024. \"Synthetic Replacements for Human Survey Data? The Perils of Large Language Models.\" *Political Analysis* 32 (4): 401–416. https://doi.org/10.1017/pan.2024.5",
  ""
)

report_lines <- c(
  headline,
  methods,
  completeness,
  recovery,
  cell_comparison,
  variation,
  group_recovery,
  distribution,
  raw_distribution,
  examples,
  interpretation,
  references
)

output_stem <- tools::file_path_sans_ext(out_file)
write_csv(truth_coverage, paste0(output_stem, "_truth_coverage.csv"))
write_csv(overall_recovery_tbl, paste0(output_stem, "_individual_metrics.csv"))
write_csv(raw_distribution_tbl, paste0(output_stem, "_distribution_metrics.csv"))
write_csv(raw_distribution_summary, paste0(output_stem, "_distribution_summary.csv"))
writeLines(report_lines, out_file, useBytes = TRUE)
cat("Wrote report to ", out_file, "\n", sep = "")

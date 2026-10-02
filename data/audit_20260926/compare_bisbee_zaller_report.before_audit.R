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
  "./anes_timeseries_2024_csv_20250808/anes_timeseries_2024_csv_20250808.csv"
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
  "Robert F. Kennedy Jr." = "V241159",
  "JD Vance" = "V241164",
  "Tim Walz" = "V241165",
  "Democratic Party" = "V241166",
  "Republican Party" = "V241167"
)

baseline <- read_csv(baseline_file, show_col_types = FALSE)
zaller <- read_csv(zaller_file, show_col_types = FALSE)

actual <- read_csv(
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
  filter(!is.na(actual), actual >= 0, actual <= 100) %>%
  select(respID, group, actual)

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
  "- Prompt type: `full`",
  "- Draws per respondent: `2`",
  "- Baseline: direct thermometer generation following Bisbee et al. (2024)",
  "- Zaller: `8` generated considerations per target, `4` sampled into each response draw",
  "- Evaluation target: observed ANES 2024 feeling thermometers for the same respondents",
  ""
)

completeness <- c(
  "## Completeness",
  "",
  md_table(bind_rows(baseline_completion, zaller_completion)),
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
  "## Group-Level Truth Recovery",
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
  "- The Zaller 8->4 setup is the first version in this project that actually gives consideration sampling room to matter, so its within-respondent variation numbers are substantively meaningful.",
  "- If the baseline has lower RMSE/MAE while the Zaller pipeline shows more draw variation, then the tradeoff is predictive accuracy versus a richer theory-driven response process.",
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
  examples,
  interpretation
)

writeLines(report_lines, out_file, useBytes = TRUE)
cat("Wrote report to ", out_file, "\n", sep = "")

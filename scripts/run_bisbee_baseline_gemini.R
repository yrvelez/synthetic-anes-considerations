################################################################################
## Bisbee et al. (2024) baseline via Gemini — same prompt as 2_API_synth_data_ANES2024.R
## but hitting Gemini generateContent instead of OpenAI.
## Produces output comparable to the RAS pipeline for RMSE comparison.
##
## Reference: Bisbee, J., J. D. Clinton, C. Dorff, B. Kenkel, and J. M. Larson. 2024.
##   "Synthetic Replacements for Human Survey Data? The Perils of Large Language
##   Models." Political Analysis 32 (4): 401–416. https://doi.org/10.1017/pan.2024.5
################################################################################

rm(list = ls())
gc()

library(tidyverse)
library(httr)
library(jsonlite)

# ---- Config ----
GEMINI_API_BASE <- Sys.getenv("GEMINI_API_BASE", "https://generativelanguage.googleapis.com/v1beta/models")
GEMINI_MODEL    <- Sys.getenv("GEMINI_MODEL", "gemini-flash-latest")
GEMINI_API_KEY  <- Sys.getenv("GEMINI_API_KEY", "")
N_DRAWS         <- as.integer(Sys.getenv("N_DRAWS", "30"))
DRAWS_PER_CALL  <- as.integer(Sys.getenv("DRAWS_PER_CALL", "1"))
RESPONDENT_LIMIT <- as.integer(Sys.getenv("RESPONDENT_LIMIT", "0"))
RESPONDENT_START <- as.integer(Sys.getenv("RESPONDENT_START", "1"))
RESPONDENT_END <- as.integer(Sys.getenv("RESPONDENT_END", "0"))
RUN_LABEL       <- Sys.getenv("RUN_LABEL", "bisbee_baseline")
PAUSE_SECONDS   <- as.numeric(Sys.getenv("PAUSE_SECONDS", "0.5"))
HTTP_TIMEOUT    <- as.integer(Sys.getenv("HTTP_TIMEOUT_SECONDS", "600"))
PROMPT_TYPES    <- strsplit(Sys.getenv("PROMPT_TYPES_OVERRIDE", "full"), ",")[[1]]

run_suffix  <- ifelse(nzchar(RUN_LABEL), paste0("_", RUN_LABEL), "")
OUTPUT_FILE <- paste0("./data/raw/therm_ANES2024_bisbee_Gemini", run_suffix, ".csv")
DEBUG_RAW_FILE <- paste0("./data/raw/bisbee_stage_last_raw", run_suffix, ".txt")
DEBUG_PARSED_FILE <- paste0("./data/raw/bisbee_stage_last_parsed", run_suffix, ".csv")
DEBUG_API_ERROR_FILE <- paste0("./data/raw/bisbee_api_last_error", run_suffix, ".txt")

TARGET_GROUPS <- c("Kamala Harris", "Donald Trump", "Joe Biden", "RFK Jr",
                   "JD Vance", "Tim Walz", "Democratic Party", "Republican Party")

# ---- Load ANES data (same recode as 2_API_synth_data_ANES2024.R) ----
anes <- read_csv("./external/anes_timeseries_2024_csv_20250808/anes_timeseries_2024_csv_20250808.csv",
                 show_col_types = FALSE)

anes_simp <- anes %>%
  select(
    respID = V200001, raceth = V241501x, age = V241458x, gender = V241550,
    ideo = V241177, PID = V241227x, income = V241567x, regis = V241012,
    education = V241465x, interest = V241004, marst = V241461x,
    `therm_Kamala Harris` = V241156, `therm_Donald Trump` = V241157,
    `therm_Joe Biden` = V241158, `therm_RFK Jr` = V241159,
    `therm_JD Vance` = V241164, `therm_Tim Walz` = V241165,
    `therm_Democratic Party` = V241166, `therm_Republican Party` = V241167
  ) %>%
  mutate_at(vars(matches("therm_")), function(x) ifelse(x < 0 | x > 100, NA, x)) %>%
  mutate(
    raceth = case_when(
      raceth == 1 ~ "non-Hispanic white", raceth == 2 ~ "non-Hispanic Black",
      raceth == 3 ~ "Hispanic", raceth == 4 ~ "Asian or Pacific Islander",
      raceth == 5 ~ "Native American", raceth == 6 ~ "multiracial", TRUE ~ NA_character_),
    gender = case_when(gender == 1 ~ "male", gender == 2 ~ "female", TRUE ~ NA_character_),
    PID = case_when(
      PID %in% 1:3 ~ "Democrat", PID == 4 ~ "Independent",
      PID %in% 5:7 ~ "Republican", TRUE ~ NA_character_),
    regis = case_when(regis == 1 ~ "registered", regis == 2 ~ "unregistered", TRUE ~ NA_character_),
    interest = case_when(
      interest == 1 ~ "always", interest == 2 ~ "regularly",
      interest == 3 ~ "frequently", interest == 4 ~ "sometimes",
      interest == 5 ~ "never", TRUE ~ NA_character_),
    ideo = case_when(
      ideo == 1 ~ "an extremely liberal", ideo == 2 ~ "a liberal",
      ideo == 3 ~ "a slightly liberal", ideo == 4 ~ "a moderate",
      ideo == 5 ~ "a slightly conservative", ideo == 6 ~ "a conservative",
      ideo == 7 ~ "an extremely conservative", TRUE ~ NA_character_),
    income = case_when(
      income == 1 ~ "$10,000", income == 2 ~ "$30,000", income == 3 ~ "$60,000",
      income == 4 ~ "$100,000", income == 5 ~ "$175,000",
      income == 6 ~ "more than $250,000", TRUE ~ NA_character_),
    education = case_when(
      education == 1 ~ "less than a high school diploma",
      education == 2 ~ "a high school diploma",
      education == 3 ~ "some college, but no degree",
      education %in% 4:5 ~ "a bachelor's degree or more", TRUE ~ NA_character_),
    marst = case_when(
      marst == 1 ~ "married", marst == 2 ~ "divorced", marst == 3 ~ "separated",
      marst == 4 ~ "widowed", marst == 5 ~ "single", TRUE ~ NA_character_)
  ) %>%
  filter(age > 0) %>%
  drop_na(raceth, age, gender, ideo, PID, income, regis, education, interest, marst)

if (RESPONDENT_LIMIT > 0) {
  anes_simp <- anes_simp %>% slice_head(n = RESPONDENT_LIMIT)
}

if (DRAWS_PER_CALL < 1) {
  stop("DRAWS_PER_CALL must be at least 1.")
}

if (RESPONDENT_START < 1) {
  stop("RESPONDENT_START must be at least 1.")
}

if (RESPONDENT_END > 0) {
  if (RESPONDENT_END < RESPONDENT_START) {
    stop("RESPONDENT_END must be >= RESPONDENT_START.")
  }
  anes_simp <- anes_simp %>% slice(RESPONDENT_START:RESPONDENT_END)
} else if (RESPONDENT_START > 1) {
  anes_simp <- anes_simp %>% slice(RESPONDENT_START:n())
}

# ---- Prompt templates (identical to Bisbee et al. 2024) ----
full <- "It is 2024. You are a [AGE] year-old, [MARST], [RACETH] [GENDER] with [EDUCATION] making [INCOME] per year, living in the United States.
You are [IDEO], [REGIS] [PID] who [INTEREST] pays attention to what's going on in government and politics."

demogFull <- "It is 2024. You are a [AGE] year-old [MARST] [RACETH] [GENDER] with [EDUCATION] making [INCOME] per year, living in the United States."

pol <- "It is 2024. You are [IDEO], [REGIS] [PID] who [INTEREST] pays attention to what's going on in government and politics, living in the United States."

system_prep <- function(frame, lookup) {
  for (col in colnames(lookup)) {
    frame <- gsub(paste0("\\[", toupper(col), "\\]"), lookup[[col]][1], frame)
  }
  frame
}

sanitize_cell <- function(x) {
  x %>%
    gsub("\u2018|\u2019", "'", ., perl = TRUE) %>%
    gsub("\u201C|\u201D", "\"", ., perl = TRUE) %>%
    gsub("\\\\\"", "\"", ., perl = TRUE) %>%
    gsub("\\\\'", "'", ., perl = TRUE) %>%
    gsub("[[:cntrl:]&&[^\r\n\t]]+", " ", ., perl = TRUE) %>%
    gsub("[\r\n\t]+", " ", ., perl = TRUE) %>%
    gsub("\\s{2,}", " ", ., perl = TRUE) %>%
    gsub('^"+', "", ., perl = TRUE) %>%
    gsub('"+$', "", ., perl = TRUE) %>%
    trimws()
}

sanitize_character_cols <- function(df) {
  df %>%
    mutate(across(where(is.character), sanitize_cell))
}

append_csv <- function(df, path) {
  if (is.null(df) || nrow(df) == 0) {
    return(invisible(NULL))
  }

  write_csv(
    sanitize_character_cols(df),
    file = path,
    append = TRUE,
    col_names = FALSE
  )

  invisible(NULL)
}

build_user_prompt <- function(draw_ids) {
  paste0(
    "Provide responses from this person's perspective.\n",
    "Use only knowledge about politics that they would have.\n",
    "Produce independent survey draws for these draw ids: ",
    paste(draw_ids, collapse = ", "),
    ".\n",
    "Format the output as a tsv table with the following format:\n",
    "draw\tgroup\tthermometer\texplanation\tconfidence\n",
    "Return exactly one row for each draw id and each target group.\n",
    "The following questions ask about individuals' feelings toward different groups.\n",
    "Responses should be given on a scale from 0 (meaning cold feelings) to 100 (meaning warm feelings).\n",
    "Ratings between 50 degrees and 100 degrees mean that\n",
    "you feel favorable and warm toward the group. Ratings between 0\n",
    "degrees and 50 degrees mean that you don't feel favorable toward\n",
    "the group and that you don't care too much for that group. You\n",
    "would rate the group at the 50 degree mark if you don't feel\n",
    "particularly warm or cold toward the group.\n",
    "Targets:\n",
    "Kamala Harris\n",
    "Donald Trump\n",
    "Joe Biden\n",
    "Robert F. Kennedy Jr.\n",
    "J.D. Vance\n",
    "Tim Walz\n",
    "The Democratic Party\n",
    "The Republican Party\n"
  )
}

# ---- Gemini submit ----
extract_gemini_text <- function(parsed) {
  if (
    !is.list(parsed) ||
    is.null(parsed$candidates) ||
    length(parsed$candidates) < 1 ||
    !is.list(parsed$candidates[[1]]) ||
    is.null(parsed$candidates[[1]]$content) ||
    !is.list(parsed$candidates[[1]]$content) ||
    is.null(parsed$candidates[[1]]$content$parts)
  ) {
    stop("Could not extract text content from Gemini response.")
  }

  parts <- parsed$candidates[[1]]$content$parts
  text_parts <- vapply(
    parts,
    function(part) {
      if (is.list(part) && is.character(part$text) && length(part$text) >= 1) {
        part$text[[1]]
      } else {
        ""
      }
    },
    character(1)
  )
  text_parts <- text_parts[nzchar(text_parts)]
  if (length(text_parts) == 0) {
    stop("Could not extract text content from Gemini response.")
  }
  paste(text_parts, collapse = "\n")
}

submit_gemini <- function(system_prompt, input, max_attempts = 5) {
  if (!nzchar(GEMINI_API_KEY)) {
    stop("GEMINI_API_KEY is not set.")
  }

  endpoint <- paste0(
    sub("/+$", "", GEMINI_API_BASE),
    "/",
    GEMINI_MODEL,
    ":generateContent"
  )

  body <- list(
    systemInstruction = list(
      parts = list(list(text = system_prompt))
    ),
    contents = list(
      list(
        parts = list(list(text = input))
      )
    )
  )
  for (attempt in seq_len(max_attempts)) {
    response <- try(POST(
      url = endpoint,
      body = body,
      encode = "json",
      add_headers("X-goog-api-key" = GEMINI_API_KEY),
      content_type_json(),
      timeout(HTTP_TIMEOUT)
    ), silent = TRUE)
    if (inherits(response, "try-error")) {
      dir.create("./data/raw", recursive = TRUE, showWarnings = FALSE)
      writeLines(as.character(response), DEBUG_API_ERROR_FILE, useBytes = TRUE)
      Sys.sleep(min(60, 2^attempt))
      next
    }
    sc <- status_code(response)
    if (sc >= 200 && sc < 300) {
      parsed <- content(response, as = "parsed", type = "application/json")
      text_out <- try(extract_gemini_text(parsed), silent = TRUE)
      if (!inherits(text_out, "try-error") && !is.null(text_out)) {
        Sys.sleep(PAUSE_SECONDS)
        return(text_out)
      }
    }
    dir.create("./data/raw", recursive = TRUE, showWarnings = FALSE)
    writeLines(content(response, as = "text", encoding = "UTF-8"), DEBUG_API_ERROR_FILE, useBytes = TRUE)
    Sys.sleep(min(60, 2^attempt))
  }
  stop("Gemini request failed after ", max_attempts, " attempts.")
}

# ---- Normalize group names ----
normalize_group_name <- function(x) {
  x <- trimws(x)
  x <- gsub("^[Tt]he\\s+", "", x)
  x <- case_when(
    grepl("harris|kamala", x, ignore.case = TRUE) ~ "Kamala Harris",
    grepl("trump|donald", x, ignore.case = TRUE) ~ "Donald Trump",
    grepl("biden|joe", x, ignore.case = TRUE) ~ "Joe Biden",
    grepl("kennedy|rfk|robert", x, ignore.case = TRUE) ~ "RFK Jr",
    grepl("vance|j\\.?d", x, ignore.case = TRUE) ~ "JD Vance",
    grepl("walz|tim", x, ignore.case = TRUE) ~ "Tim Walz",
    grepl("democrat", x, ignore.case = TRUE) ~ "Democratic Party",
    grepl("republican", x, ignore.case = TRUE) ~ "Republican Party",
    TRUE ~ x
  )
  x
}

# ---- Initialize output ----
dir.create("./data/raw", recursive = TRUE, showWarnings = FALSE)

n_demog <- 11
empty <- data.frame(
  anes_simp[0, 1:n_demog],
  prompt_type = character(),
  prompt = character(),
  draw = integer(),
  group = character(),
  thermometer = integer(),
  explanation = character(),
  confidence = character(),
  index = integer(),
  stringsAsFactors = FALSE
)
write_csv(empty, OUTPUT_FILE)

# ---- Main loop ----
cat("=== Running Bisbee et al. (2024) (Gemini) ===\n")
cat("Respondents:", nrow(anes_simp), " Draws:", N_DRAWS,
    " Prompt types:", paste(PROMPT_TYPES, collapse = ","), "\n")

for (i in seq_len(nrow(anes_simp))) {
  resp <- anes_simp[i, ]

  for (p in PROMPT_TYPES) {
    sys_prompt <- system_prep(get(p), resp[1, 1:n_demog])

    all_draws <- NULL

    for (draw_start in seq(1, N_DRAWS, by = DRAWS_PER_CALL)) {
      draw_end <- min(draw_start + DRAWS_PER_CALL - 1, N_DRAWS)
      draw_batch <- seq(draw_start, draw_end)
      cat("Respondent", resp$respID, "x", p, "draws", paste(draw_batch, collapse = ","), "/", N_DRAWS, "\n")

      raw_text <- try(submit_gemini(sys_prompt, build_user_prompt(draw_batch)), silent = TRUE)
      if (inherits(raw_text, "try-error")) {
        warning("Failed for draw batch ", paste(draw_batch, collapse = ","), ". Skipping.")
        next
      }

      dir.create("./data/raw", recursive = TRUE, showWarnings = FALSE)
      writeLines(raw_text, DEBUG_RAW_FILE, useBytes = TRUE)

      # Parse TSV (same approach as Bisbee et al. 2024)
      cleaned <- raw_text %>%
        gsub("^```[[:alpha:]]*\\s*\n", "", ., perl = TRUE) %>%
        gsub("\n```\\s*$", "", ., perl = TRUE) %>%
        gsub("\r", "", .) %>%
        gsub(" {2,}", "\t", .) %>%
        gsub("\t{2,}", "\t", .) %>%
        gsub("\n{2,}", "\n", .) %>%
        trimws()

      parsed <- try(read.delim(
        text = cleaned, sep = "\t", header = TRUE,
        quote = "", stringsAsFactors = FALSE, check.names = FALSE
      ), silent = TRUE)

      if (inherits(parsed, "try-error") || ncol(parsed) < 2) next

      # Normalize columns
      if (all(c("draw", "group", "thermometer") %in% names(parsed))) {
        parsed <- parsed %>%
          mutate(
            draw = suppressWarnings(as.integer(draw)),
            group = normalize_group_name(group),
            thermometer = suppressWarnings(as.integer(thermometer)),
            explanation = if ("explanation" %in% names(.)) sanitize_cell(as.character(explanation)) else "",
            confidence = if ("confidence" %in% names(.)) sanitize_cell(as.character(confidence)) else ""
          ) %>%
          filter(!is.na(draw), draw %in% draw_batch) %>%
          filter(group %in% TARGET_GROUPS, !is.na(thermometer),
                 thermometer >= 0, thermometer <= 100) %>%
          select(draw, group, thermometer, explanation, confidence)
        write_csv(parsed, DEBUG_PARSED_FILE)
      } else {
        next
      }

      expected_pairs <- expand_grid(draw = draw_batch, group = TARGET_GROUPS)
      parsed_pairs <- parsed %>% distinct(draw, group)
      if (nrow(inner_join(expected_pairs, parsed_pairs, by = c("draw", "group"))) != nrow(expected_pairs)) {
        next
      }

      if (nrow(parsed) == 0) next

      all_draws <- bind_rows(all_draws, parsed)
    }

    if (!is.null(all_draws) && nrow(all_draws) > 0) {
      to_save <- data.frame(resp[1, 1:n_demog]) %>%
        slice(rep(1, nrow(all_draws))) %>%
        bind_cols(
          tibble(prompt_type = p, prompt = sys_prompt),
          all_draws %>%
            mutate(index = i) %>%
            select(draw, group, thermometer, explanation, confidence, index)
        )

      append_csv(to_save, OUTPUT_FILE)
      cat("  Flushed", nrow(all_draws), "rows for respondent", resp$respID, "x", p, "\n")
    }
  }
}

cat("Bisbee et al. (2024) baseline complete.\n")

################################################################################
##
## Purpose: Generate synthetic ANES 2024 thermometer data using a RAS-style
##          pipeline over Gemini's generateContent API.
##
##          Stage 0 builds a shared 2024 consideration universe for each
##          target group.
##
##          Stage 1 applies respondent predispositions to that shared universe
##          and saves the accepted considerations for each
##          respondent x prompt_type x target combination.
##
##          Stage 2 samples ordered accepted considerations in R and asks the
##          model to produce thermometer responses using only those sampled
##          considerations.
##
## Input Files:
##  - ./external/anes_timeseries_2024_csv_20250808/anes_timeseries_2024_csv_20250808.csv
##
## Output Files:
##  - ./data/raw/anes2024_universe_zaller.csv
##  - ./data/raw/anes2024_considerations_zaller.csv
##  - ./data/raw/therm_ANES2024_zaller_Gemini.csv
##
## Notes:
##  - This script is intentionally split into independent stages. The
##    acceptance and response stages read prior outputs from disk rather than
##    sharing chat state with earlier stages.
##  - Configure execution with environment variables:
##      RUN_STAGE=universe|acceptance|considerations|responses|all
##      GEMINI_API_KEY=...
##      GEMINI_MODEL=gemini-flash-latest
##
################################################################################

rm(list = ls())
gc()

library(tidyverse)
library(httr)
library(jsonlite)
require(readr)

GEMINI_API_BASE <- Sys.getenv("GEMINI_API_BASE", unset = "https://generativelanguage.googleapis.com/v1beta/models")
GEMINI_MODEL <- Sys.getenv("GEMINI_MODEL", unset = "gemini-flash-latest")
GEMINI_API_KEY <- Sys.getenv("GEMINI_API_KEY", unset = "")
RUN_STAGE <- Sys.getenv("RUN_STAGE", unset = "all")
RUN_LABEL <- Sys.getenv("RUN_LABEL", unset = "")
PROMPT_TYPES_OVERRIDE <- Sys.getenv("PROMPT_TYPES_OVERRIDE", unset = "")

N_CONSIDERATIONS_PER_GROUP <- as.integer(Sys.getenv("N_CONSIDERATIONS_PER_GROUP", unset = "6"))
N_UNIVERSE_CONSIDERATIONS_PER_GROUP <- as.integer(Sys.getenv("N_UNIVERSE_CONSIDERATIONS_PER_GROUP", unset = "16"))
N_CONSIDERATIONS_SAMPLED <- as.integer(Sys.getenv("N_CONSIDERATIONS_SAMPLED", unset = "4"))
N_RESPONSE_DRAWS <- as.integer(Sys.getenv("N_RESPONSE_DRAWS", unset = "30"))
RESPONSE_DRAWS_PER_CALL <- as.integer(Sys.getenv("RESPONSE_DRAWS_PER_CALL", unset = "1"))
FLUSH_EVERY <- as.integer(Sys.getenv("FLUSH_EVERY", unset = "10"))
PAUSE_SECONDS <- as.numeric(Sys.getenv("PAUSE_SECONDS", unset = "0.5"))
HTTP_TIMEOUT_SECONDS <- as.numeric(Sys.getenv("HTTP_TIMEOUT_SECONDS", unset = "600"))
RESPONDENT_LIMIT <- as.integer(Sys.getenv("RESPONDENT_LIMIT", unset = "0"))
RESPONDENT_START <- as.integer(Sys.getenv("RESPONDENT_START", unset = "1"))
RESPONDENT_END <- as.integer(Sys.getenv("RESPONDENT_END", unset = "0"))
STAGE_OUTPUT_ATTEMPTS <- as.integer(Sys.getenv("STAGE_OUTPUT_ATTEMPTS", unset = "4"))

run_suffix <- if (nzchar(RUN_LABEL)) paste0("_", RUN_LABEL) else ""

UNIVERSE_FILE <- paste0("./data/raw/anes2024_universe_zaller", run_suffix, ".csv")
CONSIDERATIONS_FILE <- paste0("./data/raw/anes2024_considerations_zaller", run_suffix, ".csv")
RESPONSES_FILE <- paste0("./data/raw/therm_ANES2024_zaller_Gemini", run_suffix, ".csv")
DEBUG_RAW_FILE <- paste0("./data/raw/model_parse_failure_raw", run_suffix, ".txt")
DEBUG_CLEAN_FILE <- paste0("./data/raw/model_parse_failure_clean", run_suffix, ".txt")
DEBUG_UNIVERSE_RAW_FILE <- paste0("./data/raw/model_universe_last_raw", run_suffix, ".txt")
DEBUG_UNIVERSE_PARSED_FILE <- paste0("./data/raw/model_universe_last_parsed", run_suffix, ".csv")
DEBUG_STAGE1_RAW_FILE <- paste0("./data/raw/model_stage1_last_raw", run_suffix, ".txt")
DEBUG_STAGE1_PARSED_FILE <- paste0("./data/raw/model_stage1_last_parsed", run_suffix, ".csv")
DEBUG_STAGE2_RAW_FILE <- paste0("./data/raw/model_stage2_last_raw", run_suffix, ".txt")
DEBUG_STAGE2_PARSED_FILE <- paste0("./data/raw/model_stage2_last_parsed", run_suffix, ".csv")
DEBUG_API_ERROR_FILE <- paste0("./data/raw/model_api_last_error", run_suffix, ".txt")

TARGET_GROUPS <- c(
  "Kamala Harris",
  "Donald Trump",
  "Joe Biden",
  "RFK Jr",
  "JD Vance",
  "Tim Walz",
  "Democratic Party",
  "Republican Party"
)

DEFAULT_PROMPT_TYPES <- c("full", "demogFull", "pol")
PROMPT_TYPES <- if (nzchar(PROMPT_TYPES_OVERRIDE)) {
  trimws(strsplit(PROMPT_TYPES_OVERRIDE, ",", fixed = TRUE)[[1]])
} else {
  DEFAULT_PROMPT_TYPES
}

if (N_CONSIDERATIONS_SAMPLED > N_CONSIDERATIONS_PER_GROUP) {
  stop("N_CONSIDERATIONS_SAMPLED cannot exceed N_CONSIDERATIONS_PER_GROUP.")
}

if (N_CONSIDERATIONS_PER_GROUP > N_UNIVERSE_CONSIDERATIONS_PER_GROUP) {
  stop("N_CONSIDERATIONS_PER_GROUP cannot exceed N_UNIVERSE_CONSIDERATIONS_PER_GROUP.")
}

if (RESPONSE_DRAWS_PER_CALL < 1) {
  stop("RESPONSE_DRAWS_PER_CALL must be at least 1.")
}

# ---- Load and prepare the ANES 2024 data ----

anes <- read_csv("./external/anes_timeseries_2024_csv_20250808/anes_timeseries_2024_csv_20250808.csv")

anes_simp <- anes %>%
  select(
    respID = V200001,
    raceth = V241501x,
    age = V241458x,
    gender = V241550,
    ideo = V241177,
    PID = V241227x,
    income = V241567x,
    regis = V241012,
    education = V241465x,
    interest = V241004,
    marst = V241461x,
    `therm_Kamala Harris` = V241156,
    `therm_Donald Trump` = V241157,
    `therm_Joe Biden` = V241158,
    `therm_RFK Jr` = V241159,
    `therm_JD Vance` = V241164,
    `therm_Tim Walz` = V241165,
    `therm_Democratic Party` = V241166,
    `therm_Republican Party` = V241167
  ) %>%
  mutate(
    across(matches("^therm_"), ~ ifelse(.x < 0 | .x > 100, NA, .x)),
    raceth = case_when(
      raceth == 1 ~ "non-Hispanic white",
      raceth == 2 ~ "non-Hispanic Black",
      raceth == 3 ~ "Hispanic",
      raceth == 4 ~ "Asian or Pacific Islander",
      raceth == 5 ~ "Native American",
      raceth == 6 ~ "multiracial",
      TRUE ~ NA_character_
    ),
    gender = case_when(
      gender == 1 ~ "male",
      gender == 2 ~ "female",
      TRUE ~ NA_character_
    ),
    PID = case_when(
      PID %in% 1:3 ~ "Democrat",
      PID == 4 ~ "Independent",
      PID %in% 5:7 ~ "Republican",
      TRUE ~ NA_character_
    ),
    regis = case_when(
      regis == 1 ~ "registered",
      regis == 2 ~ "unregistered",
      TRUE ~ NA_character_
    ),
    marst = case_when(
      marst == 1 ~ "married",
      marst == 2 ~ "divorced",
      marst == 3 ~ "separated",
      marst == 4 ~ "widowed",
      marst == 5 ~ "single",
      TRUE ~ NA_character_
    ),
    interest = case_when(
      interest == 1 ~ "always",
      interest == 2 ~ "regularly",
      interest == 3 ~ "frequently",
      interest == 4 ~ "sometimes",
      interest == 5 ~ "never",
      TRUE ~ NA_character_
    ),
    ideo = case_when(
      ideo == 1 ~ "an extremely liberal",
      ideo == 2 ~ "a liberal",
      ideo == 3 ~ "a slightly liberal",
      ideo == 4 ~ "a moderate",
      ideo == 5 ~ "a slightly conservative",
      ideo == 6 ~ "a conservative",
      ideo == 7 ~ "an extremely conservative",
      TRUE ~ NA_character_
    ),
    income = case_when(
      income == 1 ~ "$10,000",
      income == 2 ~ "$30,000",
      income == 3 ~ "$60,000",
      income == 4 ~ "$100,000",
      income == 5 ~ "$175,000",
      income == 6 ~ "more than $250,000",
      TRUE ~ NA_character_
    ),
    education = case_when(
      education == 1 ~ "less than a high school diploma",
      education == 2 ~ "a high school diploma",
      education == 3 ~ "some college, but no degree",
      education %in% 4:5 ~ "a bachelor's degree or more",
      TRUE ~ NA_character_
    )
  ) %>%
  filter(age > 0) %>%
  drop_na(raceth, age, gender, ideo, PID, income, regis, education, interest, marst)

if (!is.na(RESPONDENT_LIMIT) && RESPONDENT_LIMIT > 0) {
  anes_simp <- anes_simp %>%
    slice_head(n = RESPONDENT_LIMIT)
}

if (!is.na(RESPONDENT_START) && RESPONDENT_START < 1) {
  stop("RESPONDENT_START must be at least 1.")
}

if (!is.na(RESPONDENT_END) && RESPONDENT_END > 0) {
  if (RESPONDENT_END < RESPONDENT_START) {
    stop("RESPONDENT_END must be >= RESPONDENT_START.")
  }
  anes_simp <- anes_simp %>%
    slice(RESPONDENT_START:RESPONDENT_END)
} else if (!is.na(RESPONDENT_START) && RESPONDENT_START > 1) {
  anes_simp <- anes_simp %>%
    slice(RESPONDENT_START:n())
}

n_demog <- 11

# ---- Prompt templates ----

full <- "It is 2024. You are a [AGE] year-old, [MARST], [RACETH] [GENDER] with [EDUCATION] making [INCOME] per year, living in the United States.
You are [IDEO], [REGIS] [PID] who [INTEREST] pays attention to what's going on in government and politics."

demogFull <- "It is 2024. You are a [AGE] year-old [MARST] [RACETH] [GENDER] with [EDUCATION] making [INCOME] per year, living in the United States."

pol <- "It is 2024. You are [IDEO], [REGIS] [PID] who [INTEREST] pays attention to what's going on in government and politics, living in the United States."

# ---- Helper functions ----

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

normalize_group_name <- function(x) {
  cleaned <- sanitize_cell(x)

  case_when(
    cleaned %in% c("RFK Jr.", "Robert F. Kennedy Jr.", "Robert F Kennedy Jr.") ~ "RFK Jr",
    cleaned %in% c("J.D. Vance", "JD Vance") ~ "JD Vance",
    TRUE ~ cleaned
  )
}

hash_to_unit <- function(key) {
  ints <- utf8ToInt(enc2utf8(key))
  modulus <- 2147483629
  hash <- 17
  for (value in ints) {
    hash <- (hash * 131 + value) %% modulus
  }
  (hash + 0.5) / modulus
}

with_local_seed <- function(seed, expr) {
  had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  if (had_seed) {
    old_seed <- get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  }

  on.exit({
    if (had_seed) {
      assign(".Random.seed", old_seed, envir = .GlobalEnv)
    } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
      rm(".Random.seed", envir = .GlobalEnv)
    }
  }, add = TRUE)

  set.seed(max(1L, as.integer(seed)))
  force(expr)
}

weighted_shuffle <- function(ids, weights, base_key) {
  safe_weights <- pmax(as.numeric(weights), 1e-6)
  seed <- floor(hash_to_unit(base_key) * 1e9)
  with_local_seed(
    seed = seed,
    expr = sample(
      x = ids,
      size = length(ids),
      replace = FALSE,
      prob = safe_weights
    )
  )
}

format_tsv_block <- function(df) {
  header <- paste(colnames(df), collapse = "\t")
  body <- apply(df, 1, function(row) paste(row, collapse = "\t"))
  paste(c(header, body), collapse = "\n")
}

safe_pluck <- function(x, path) {
  value <- x
  for (name in path) {
    if (is.null(value) || length(value) == 0) {
      return(NULL)
    }
    value <- value[[name]]
  }
  value
}

extract_output_message <- function(output_block) {
  if (is.null(output_block) || !is.list(output_block)) {
    return(NULL)
  }

  for (item in output_block) {
    if (
      is.list(item) &&
      identical(item$type, "message") &&
      is.character(item$content) &&
      length(item$content) >= 1 &&
      nzchar(item$content[[1]])
    ) {
      return(item$content[[1]])
    }
  }

  NULL
}

parse_keyed_stage1_lines <- function(cleaned) {
  group_pattern <- paste(
    c(
      "Kamala Harris",
      "Donald Trump",
      "Joe Biden",
      "RFK Jr\\.?",
      "JD Vance",
      "Tim Walz",
      "Democratic Party",
      "Republican Party"
    ),
    collapse = "|"
  )

  cleaned <- cleaned %>%
    gsub(paste0("\n(?=(?:", group_pattern, ")\\tC\\d+\\t)"), "\n", ., perl = TRUE)

  lines <- strsplit(cleaned, "\n", fixed = TRUE)[[1]]
  lines <- trimws(lines)
  lines <- lines[nzchar(lines)]

  if (length(lines) <= 1) {
    return(NULL)
  }

  data_lines <- lines[-1]
  parsed_rows <- list()
  row_idx <- 1

  plain_regex <- paste0(
    "^(",
    group_pattern,
    ")\\t",
    "(C\\d+)\\t",
    "(.*?)$"
  )

  for (line in data_lines) {
    parts <- strsplit(line, "\t", fixed = TRUE)[[1]]

    if (length(parts) >= 3) {
      parsed_rows[[row_idx]] <- tibble(
        group = parts[[1]],
        consideration_id = parts[[2]],
        consideration = paste(parts[3:length(parts)], collapse = " ")
      )
      row_idx <- row_idx + 1
      next
    }

    plain_matches <- regmatches(line, regexec(plain_regex, line, perl = TRUE))[[1]]
    if (length(plain_matches) == 4) {
      parsed_rows[[row_idx]] <- tibble(
        group = plain_matches[[2]],
        consideration_id = plain_matches[[3]],
        consideration = plain_matches[[4]]
      )
      row_idx <- row_idx + 1
    }
  }

  if (length(parsed_rows) == 0) {
    return(NULL)
  }

  bind_rows(parsed_rows)
}

parse_keyed_acceptance_lines <- function(cleaned) {
  group_pattern <- paste(
    c(
      "Kamala Harris",
      "Donald Trump",
      "Joe Biden",
      "RFK Jr\\.?",
      "JD Vance",
      "Tim Walz",
      "Democratic Party",
      "Republican Party"
    ),
    collapse = "|"
  )

  lines <- strsplit(cleaned, "\n", fixed = TRUE)[[1]]
  lines <- trimws(lines)
  lines <- lines[nzchar(lines)]

  if (length(lines) <= 1) {
    return(NULL)
  }

  data_lines <- lines[-1]
  parsed_rows <- list()
  row_idx <- 1
  plain_regex <- paste0("^(", group_pattern, ")\\t(U\\d+)$")

  for (line in data_lines) {
    parts <- strsplit(line, "\t", fixed = TRUE)[[1]]

    if (length(parts) >= 2) {
      parsed_rows[[row_idx]] <- tibble(
        group = parts[[1]],
        consideration_id = parts[[2]]
      )
      row_idx <- row_idx + 1
      next
    }

    plain_matches <- regmatches(line, regexec(plain_regex, line, perl = TRUE))[[1]]
    if (length(plain_matches) == 3) {
      parsed_rows[[row_idx]] <- tibble(
        group = plain_matches[[2]],
        consideration_id = plain_matches[[3]]
      )
      row_idx <- row_idx + 1
    }
  }

  if (length(parsed_rows) == 0) {
    return(NULL)
  }

  bind_rows(parsed_rows)
}

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

  if (is.list(parts) && length(parts) > 0) {
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
    if (length(text_parts) > 0) {
      return(paste(text_parts, collapse = "\n"))
    }
  }

  stop("Could not extract text content from Gemini response.")
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

  payload <- list(
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
    response <- try(
      POST(
        url = endpoint,
        body = payload,
        encode = "json",
        add_headers("X-goog-api-key" = GEMINI_API_KEY),
        content_type_json(),
        timeout(HTTP_TIMEOUT_SECONDS)
      ),
      silent = TRUE
    )

    if (inherits(response, "try-error")) {
      dir.create("./data/raw", recursive = TRUE, showWarnings = FALSE)
      writeLines(as.character(response), DEBUG_API_ERROR_FILE, useBytes = TRUE)
      Sys.sleep(min(60, 2 ^ attempt))
      next
    }

    if (status_code(response) >= 200 && status_code(response) < 300) {
      parsed <- content(response, as = "parsed", type = "application/json")
      text_out <- try(extract_gemini_text(parsed), silent = TRUE)
      if (!inherits(text_out, "try-error")) {
        Sys.sleep(PAUSE_SECONDS)
        return(text_out)
      }
    }

    dir.create("./data/raw", recursive = TRUE, showWarnings = FALSE)
    writeLines(content(response, as = "text", encoding = "UTF-8"), DEBUG_API_ERROR_FILE, useBytes = TRUE)

    Sys.sleep(min(60, 2 ^ attempt))
  }

  stop("Gemini request failed after repeated attempts.")
}

parse_stage_tsv <- function(raw_text, col_names) {
  cleaned <- raw_text %>%
    gsub("^```[[:alpha:]]*\\s*\n", "", ., perl = TRUE) %>%
    gsub("\n```\\s*$", "", ., perl = TRUE) %>%
    gsub("\r", "", ., fixed = TRUE) %>%
    gsub("\\\\t", "\t", ., perl = TRUE) %>%
    gsub("\\\\n", "\n", ., perl = TRUE) %>%
    gsub("\t{2,}", "\t", ., perl = TRUE) %>%
    gsub("\n{2,}", "\n", ., perl = TRUE) %>%
    trimws()

  parsed <- try(
    read.delim(
      text = cleaned,
      sep = "\t",
      header = TRUE,
      quote = "",
      stringsAsFactors = FALSE,
      check.names = FALSE
    ),
    silent = TRUE
  )

  if (inherits(parsed, "try-error")) {
    parsed <- NULL
  }

  if (identical(col_names, c("group", "consideration_id", "consideration"))) {
    fallback_parsed <- parse_keyed_stage1_lines(cleaned)

    if (is.null(parsed) || nrow(parsed) == 0) {
      parsed <- fallback_parsed
    } else if (!is.null(fallback_parsed)) {
      parsed_score <- sum(!is.na(parsed$consideration) & nzchar(trimws(as.character(parsed$consideration))))
      fallback_score <- sum(!is.na(fallback_parsed$consideration) & nzchar(trimws(as.character(fallback_parsed$consideration))))

      if (
        fallback_score > parsed_score ||
        (fallback_score == parsed_score && nrow(fallback_parsed) > nrow(parsed))
      ) {
        parsed <- fallback_parsed
      }
    }
  }

  if (identical(col_names, c("group", "consideration_id"))) {
    fallback_parsed <- parse_keyed_acceptance_lines(cleaned)

    if (is.null(parsed) || nrow(parsed) == 0) {
      parsed <- fallback_parsed
    } else if (!is.null(fallback_parsed)) {
      if (nrow(fallback_parsed) > nrow(parsed)) {
        parsed <- fallback_parsed
      }
    }
  }

  if (is.null(parsed)) {
    dir.create("./data/raw", recursive = TRUE, showWarnings = FALSE)
    writeLines(raw_text, DEBUG_RAW_FILE, useBytes = TRUE)
    writeLines(cleaned, DEBUG_CLEAN_FILE, useBytes = TRUE)
    stop("Could not parse model output as TSV.")
  }

  if (!all(col_names %in% colnames(parsed))) {
    dir.create("./data/raw", recursive = TRUE, showWarnings = FALSE)
    writeLines(raw_text, DEBUG_RAW_FILE, useBytes = TRUE)
    writeLines(cleaned, DEBUG_CLEAN_FILE, useBytes = TRUE)
    stop("Parsed TSV is missing required columns.")
  }

  parsed %>%
    select(all_of(col_names)) %>%
    mutate(across(where(is.character), sanitize_cell))
}

build_universe_input <- function() {
  max_id <- paste0("U", N_UNIVERSE_CONSIDERATIONS_PER_GROUP)

  paste(
    "Construct a shared universe of considerations for each target below.",
    paste0("Return exactly ", N_UNIVERSE_CONSIDERATIONS_PER_GROUP, " considerations per target."),
    "These are messages, impressions, cues, and thoughts available in the 2024 political environment, not thoughts tailored to one respondent.",
    "Include positive, negative, neutral, mundane, unfair, naive, contradictory, and glowing considerations when they plausibly circulate in 2024.",
    "Mix broad media cues, elite cues, group cues, economic cues, symbolic cues, and personal-style impressions.",
    "Think of this as the receive-stage information environment: cues should be broadly available, not custom-written for one stereotype.",
    "Do not sanitize the environment into what should be thought.",
    "Do not use slurs, graphic abuse, or endorse violence.",
    "Write each consideration as a terse first-person thought with no tabs or line breaks.",
    "Order rows within each group from the most broadly available or accessible thought to the least.",
    "Every row must have exactly three tab-separated cells.",
    "Do not prepend field names inside rows.",
    paste0("Use consideration_id values U1 through ", max_id, " within each group."),
    "Return TSV only with these columns:",
    "group\tconsideration_id\tconsideration",
    paste("Targets:", paste(TARGET_GROUPS, collapse = "; ")),
    sep = "\n"
  )
}

stage_reasoning_guidance <- function(stage_name) {
  if (identical(stage_name, "universe")) {
    return(paste(
      "Model the 2024 information environment rather than an idealized civics textbook.",
      "Reason silently about what cues would be broadly receivable in 2024 and allow heterogeneous, cross-pressured, contradictory thoughts.",
      "Do not output your hidden reasoning."
    ))
  }

  if (identical(stage_name, "acceptance")) {
    return(paste(
      "Reason silently in a Zaller-style receive-accept sequence before writing TSV.",
      "First infer which cues this persona would plausibly encounter or notice in 2024.",
      "Then keep the cues that feel believable, usable, or hard to dismiss for this person.",
      "Treat demographics, party, ideology, education, and political interest as soft predispositions and exposure priors, not deterministic stereotypes.",
      "Allow cross-pressures: the same person can retain flattering, hostile, low-information, and contradictory thoughts at once.",
      "Do not output your hidden reasoning."
    ))
  }

  paste(
    "Reason silently in a Zaller-style sample-and-answer sequence before writing TSV.",
    "Start from the sampled accepted considerations only.",
    "Let accessibility order and content determine the directional pull of the response.",
    "Aggregate those pulls into a thermometer score without backfilling the answer from demographics or ideology.",
    "Do not output your hidden reasoning."
  )
}

build_acceptance_input <- function(universe_tsv) {
  paste(
    "Select considerations from the shared universe that this person would accept as plausible enough to keep in mind when rating each target.",
    paste0("Return exactly ", N_CONSIDERATIONS_PER_GROUP, " accepted considerations per target."),
    "Accepted does not mean fully endorsed; it means the thought feels usable, believable, or hard to dismiss for this person.",
    "You may keep contradictory thoughts if this person could genuinely carry both.",
    "A person can accept considerations that cut against their demographics or partisanship if those cues are available and plausible to them.",
    "Do not collapse the task into a stereotype based on race, gender, education, party, ideology, age, or income.",
    "Prefer a realistic, heterogeneous accessible set over a mechanically partisan or demographic one.",
    "Reject considerations that this person would flatly dismiss as implausible, alien, or irrelevant.",
    "Do not invent new considerations, text, or IDs.",
    "Only return IDs that appear in the universe bank below.",
    "Order rows within each group from the most accessible accepted thought to the least accessible accepted thought.",
    "Every row must have exactly two tab-separated cells.",
    "Return TSV only with these columns:",
    "group\tconsideration_id",
    "Universe bank:",
    universe_tsv,
    sep = "\n\n"
  )
}

build_response_input <- function(bank_tsv, schedule_tsv) {
  paste(
    "You are rating political targets using only the sampled accepted considerations.",
    "The demographic profile has already done its causal work through which considerations were accepted.",
    "Do not condition again on demographics, party, ideology, race, gender, age, income, or education.",
    "Only use the sampled accepted considerations listed in the draw schedule.",
    "Reason silently from the sampled thoughts to the final thermometer score; do not reverse-engineer the answer from the persona.",
    "Use consideration_rank as accessibility order and infer the directional pull from the content of each thought.",
    "Do not import new reasons, outside facts, or moral corrections.",
    "If the sampled considerations are shallow, contradictory, unfair, glowing, or boring, keep the response that way.",
    "Translate the sampled considerations into a realistic feeling thermometer rating.",
    "The thermometer runs from 0 (cold) to 100 (warm), with 50 neutral.",
    "Return TSV only with these columns:",
    "draw\tgroup\tthermometer\texplanation\tconfidence",
    "Use thermometer as an integer from 0 to 100.",
    "Use confidence as an integer from 0 to 100.",
    "Keep explanation to one short sentence with no tabs or line breaks.",
    "Accepted consideration bank:",
    bank_tsv,
    "Draw schedule:",
    schedule_tsv,
    sep = "\n\n"
  )
}

stage_system_prompt <- function(persona_prompt, stage_name) {
  prompt_parts <- c(
    if (nzchar(persona_prompt)) {
      paste("You are simulating a survey respondent for the", stage_name, "stage.")
    } else {
      paste("You are simulating the", stage_name, "stage.")
    },
    "Stay faithful to the 2024 political context and the stage instructions.",
    stage_reasoning_guidance(stage_name)
  )

  if (nzchar(persona_prompt)) {
    prompt_parts <- c(
      prompt_parts,
      "Use the persona as a probabilistic predisposition profile, not as a caricature.",
      persona_prompt
    )
  }

  paste(prompt_parts, collapse = "\n\n")
}

init_universe_file <- function() {
  if (file.exists(UNIVERSE_FILE)) {
    return(invisible(NULL))
  }

  dir.create("./data/raw", recursive = TRUE, showWarnings = FALSE)

  empty <- tibble(
    group = character(),
    consideration_id = character(),
    consideration = character(),
    universe_rank = integer()
  )

  write_csv(empty, file = UNIVERSE_FILE)
}

init_considerations_file <- function() {
  if (file.exists(CONSIDERATIONS_FILE)) {
    return(invisible(NULL))
  }

  dir.create("./data/raw", recursive = TRUE, showWarnings = FALSE)

  empty <- data.frame(
    anes_simp[0, 1:n_demog],
    prompt_type = as.character(),
    prompt = as.character(),
    group = as.character(),
    consideration_id = as.character(),
    consideration = as.character(),
    universe_rank = as.integer(),
    consideration_rank = as.integer(),
    index = as.integer(),
    stringsAsFactors = FALSE
  )

  write_csv(empty, file = CONSIDERATIONS_FILE)
}

init_responses_file <- function() {
  if (file.exists(RESPONSES_FILE)) {
    return(invisible(NULL))
  }

  dir.create("./data/raw", recursive = TRUE, showWarnings = FALSE)

  empty <- data.frame(
    anes_simp[0, 1:n_demog],
    prompt_type = as.character(),
    prompt = as.character(),
    draw = as.integer(),
    group = as.character(),
    thermometer = as.integer(),
    explanation = as.character(),
    confidence = as.integer(),
    sampled_consideration_ids = as.character(),
    sampled_considerations = as.character(),
    index = as.integer(),
    stringsAsFactors = FALSE
  )

  write_csv(empty, file = RESPONSES_FILE)
}

complete_universe_ready <- function(df) {
  if (nrow(df) == 0) {
    return(FALSE)
  }

  expected_rows <- length(TARGET_GROUPS) * N_UNIVERSE_CONSIDERATIONS_PER_GROUP

  coverage <- df %>%
    count(group, name = "n_considerations")

  unique_ids <- df %>%
    count(group, consideration_id, name = "n_rows") %>%
    count(group, name = "n_unique_ids")

  nrow(df) >= expected_rows &&
    n_distinct(df$group) == length(TARGET_GROUPS) &&
    nrow(coverage) == length(TARGET_GROUPS) &&
    nrow(unique_ids) == length(TARGET_GROUPS) &&
    all(coverage$n_considerations >= N_UNIVERSE_CONSIDERATIONS_PER_GROUP) &&
    all(unique_ids$n_unique_ids >= N_UNIVERSE_CONSIDERATIONS_PER_GROUP)
}

complete_consideration_keys <- function(df) {
  if (nrow(df) == 0) {
    return(tibble(respID = integer(), prompt_type = character()))
  }

  expected_rows <- length(TARGET_GROUPS) * N_CONSIDERATIONS_PER_GROUP

  df %>%
    count(respID, prompt_type, group, consideration_id, name = "n_rows") %>%
    count(respID, prompt_type, group, name = "unique_ids_present") %>%
    group_by(respID, prompt_type) %>%
    summarise(
      rows_present = sum(unique_ids_present),
      groups_present = n_distinct(group),
      min_unique_ids = min(unique_ids_present),
      .groups = "drop"
    ) %>%
    filter(
      rows_present >= expected_rows,
      groups_present == length(TARGET_GROUPS),
      min_unique_ids >= N_CONSIDERATIONS_PER_GROUP
    ) %>%
    select(respID, prompt_type)
}

complete_response_keys <- function(df) {
  if (nrow(df) == 0) {
    return(tibble(respID = integer(), prompt_type = character()))
  }

  expected_rows <- length(TARGET_GROUPS) * N_RESPONSE_DRAWS

  df %>%
    group_by(respID, prompt_type) %>%
    summarise(
      rows_present = n(),
      draws_present = n_distinct(draw),
      groups_present = n_distinct(group),
      .groups = "drop"
    ) %>%
    filter(
      rows_present >= expected_rows,
      draws_present == N_RESPONSE_DRAWS,
      groups_present == length(TARGET_GROUPS)
    ) %>%
    select(respID, prompt_type)
}

build_draw_schedule <- function(bank_df, respID, prompt_type) {
  schedule_rows <- list()
  row_idx <- 1

  for (draw_id in seq_len(N_RESPONSE_DRAWS)) {
    for (target_group in TARGET_GROUPS) {
      group_bank <- bank_df %>%
        filter(group == target_group) %>%
        arrange(consideration_rank, consideration_id)

      if (nrow(group_bank) < N_CONSIDERATIONS_PER_GROUP) {
        stop("Incomplete consideration bank for response stage.")
      }

      implicit_weights <- rev(seq_len(nrow(group_bank)))

      ordered_ids <- weighted_shuffle(
        ids = group_bank$consideration_id,
        weights = implicit_weights,
        base_key = paste(respID, prompt_type, draw_id, target_group, collapse = "|")
      )

      sampled_ids <- ordered_ids[seq_len(N_CONSIDERATIONS_SAMPLED)]
      sampled_text <- group_bank %>%
        filter(consideration_id %in% sampled_ids) %>%
        mutate(sample_rank = match(consideration_id, sampled_ids)) %>%
        arrange(sample_rank) %>%
        pull(consideration)

      schedule_rows[[row_idx]] <- tibble(
        draw = draw_id,
        group = target_group,
        sampled_consideration_ids = paste(sampled_ids, collapse = ","),
        sampled_considerations = paste(sampled_text, collapse = " || ")
      )
      row_idx <- row_idx + 1
    }
  }

  bind_rows(schedule_rows)
}

run_universe_stage <- function() {
  init_universe_file()
  existing <- read_csv(UNIVERSE_FILE, show_col_types = FALSE)

  if (complete_universe_ready(existing)) {
    return(invisible(NULL))
  }

  parsed <- NULL
  last_stage_error <- NULL

  for (stage_attempt in seq_len(STAGE_OUTPUT_ATTEMPTS)) {
    candidate <- try({
      raw_text <- submit_gemini(
        system_prompt = stage_system_prompt("", "universe"),
        input = build_universe_input()
      )

      dir.create("./data/raw", recursive = TRUE, showWarnings = FALSE)
      writeLines(raw_text, DEBUG_UNIVERSE_RAW_FILE, useBytes = TRUE)

      parsed_candidate <- parse_stage_tsv(
        raw_text,
        c("group", "consideration_id", "consideration")
      ) %>%
        mutate(
          group = normalize_group_name(group),
          consideration_id = sanitize_cell(consideration_id),
          consideration = sanitize_cell(consideration)
        ) %>%
        filter(group %in% TARGET_GROUPS) %>%
        filter(consideration_id %in% paste0("U", seq_len(N_UNIVERSE_CONSIDERATIONS_PER_GROUP))) %>%
        group_by(group) %>%
        arrange(suppressWarnings(as.integer(sub("^U", "", consideration_id))), consideration_id, .by_group = TRUE) %>%
        mutate(universe_rank = row_number()) %>%
        ungroup()

      coverage <- parsed_candidate %>%
        count(group, name = "n_considerations")

      unique_ids <- parsed_candidate %>%
        count(group, consideration_id, name = "n_rows") %>%
        count(group, name = "n_unique_ids")

      if (
        n_distinct(parsed_candidate$group) != length(TARGET_GROUPS) ||
        any(coverage$n_considerations < N_UNIVERSE_CONSIDERATIONS_PER_GROUP) ||
        any(unique_ids$n_unique_ids < N_UNIVERSE_CONSIDERATIONS_PER_GROUP)
      ) {
        stop("Universe output is incomplete for at least one target group.")
      }

      parsed_candidate
    }, silent = TRUE)

    if (!inherits(candidate, "try-error")) {
      parsed <- candidate
      break
    }

    last_stage_error <- as.character(candidate)
    Sys.sleep(min(10, stage_attempt))
  }

  if (is.null(parsed)) {
    stop(if (!is.null(last_stage_error)) last_stage_error else "Universe stage failed after repeated semantic retries.")
  }

  write_csv(parsed, DEBUG_UNIVERSE_PARSED_FILE)
  write_csv(parsed, UNIVERSE_FILE)
}

run_acceptance_stage <- function() {
  init_considerations_file()
  if (!file.exists(UNIVERSE_FILE)) {
    stop("Universe file does not exist. Run RUN_STAGE=universe first.")
  }

  universe_bank <- read_csv(UNIVERSE_FILE, show_col_types = FALSE) %>%
    mutate(
      consideration_id = sanitize_cell(consideration_id),
      consideration = sanitize_cell(consideration),
      group = normalize_group_name(group),
      universe_rank = as.integer(universe_rank)
    )

  existing <- read_csv(CONSIDERATIONS_FILE, show_col_types = FALSE)
  done_keys <- complete_consideration_keys(existing)
  to_save <- NULL
  processed <- 0

  for (i in seq_len(nrow(anes_simp))) {
    respondent <- anes_simp[i, ]

    for (prompt_type in PROMPT_TYPES) {
      key_exists <- done_keys %>%
        filter(.data$respID == respondent$respID, .data$prompt_type == prompt_type) %>%
        nrow()

      if (key_exists > 0) {
        next
      }

      persona_prompt <- system_prep(
        frame = get(prompt_type),
        lookup = respondent[1:n_demog]
      )

      universe_tsv <- universe_bank %>%
        arrange(factor(group, levels = TARGET_GROUPS), universe_rank, consideration_id) %>%
        select(group, consideration_id, consideration, universe_rank) %>%
        format_tsv_block()

      parsed <- NULL
      last_stage_error <- NULL

      for (stage_attempt in seq_len(STAGE_OUTPUT_ATTEMPTS)) {
        candidate <- try({
          raw_text <- submit_gemini(
            system_prompt = stage_system_prompt(persona_prompt, "acceptance"),
            input = build_acceptance_input(universe_tsv)
          )

          dir.create("./data/raw", recursive = TRUE, showWarnings = FALSE)
          writeLines(raw_text, DEBUG_STAGE1_RAW_FILE, useBytes = TRUE)

          parsed_candidate <- parse_stage_tsv(
            raw_text,
            c("group", "consideration_id")
          ) %>%
            mutate(
              group = normalize_group_name(group),
              consideration_id = sanitize_cell(consideration_id)
            ) %>%
            filter(group %in% TARGET_GROUPS) %>%
            filter(consideration_id %in% universe_bank$consideration_id) %>%
            group_by(group) %>%
            arrange(suppressWarnings(as.integer(sub("^U", "", consideration_id))), consideration_id, .by_group = TRUE) %>%
            mutate(consideration_rank = row_number()) %>%
            ungroup() %>%
            left_join(
              universe_bank %>%
                select(group, consideration_id, consideration, universe_rank),
              by = c("group", "consideration_id")
            )

          coverage <- parsed_candidate %>%
            count(group, name = "n_considerations")

          unique_ids <- parsed_candidate %>%
            count(group, consideration_id, name = "n_rows") %>%
            count(group, name = "n_unique_ids")

          if (
            n_distinct(parsed_candidate$group) != length(TARGET_GROUPS) ||
            any(coverage$n_considerations < N_CONSIDERATIONS_PER_GROUP) ||
            any(unique_ids$n_unique_ids < N_CONSIDERATIONS_PER_GROUP) ||
            any(is.na(parsed_candidate$consideration))
          ) {
            stop("Acceptance output is incomplete for at least one target group.")
          }

          parsed_candidate %>%
            select(group, consideration_id, consideration, universe_rank, consideration_rank)
        }, silent = TRUE)

        if (!inherits(candidate, "try-error")) {
          parsed <- candidate
          break
        }

        last_stage_error <- as.character(candidate)
        Sys.sleep(min(10, stage_attempt))
      }

      if (is.null(parsed)) {
        stop(if (!is.null(last_stage_error)) last_stage_error else "Acceptance stage failed after repeated semantic retries.")
      }

      write_csv(parsed, DEBUG_STAGE1_PARSED_FILE)

      enriched <- respondent[rep(1, nrow(parsed)), 1:n_demog] %>%
        bind_cols(
          tibble(
            prompt_type = prompt_type,
            prompt = persona_prompt
          )[rep(1, nrow(parsed)), ]
        ) %>%
        bind_cols(parsed) %>%
        mutate(index = i)

      to_save <- bind_rows(to_save, enriched)
      processed <- processed + 1

      if (processed %% FLUSH_EVERY == 0) {
        append_csv(to_save, CONSIDERATIONS_FILE)
        to_save <- NULL
      }
    }
  }

  if (!is.null(to_save) && nrow(to_save) > 0) {
    append_csv(to_save, CONSIDERATIONS_FILE)
  }
}

run_responses_stage <- function() {
  init_responses_file()

  if (!file.exists(CONSIDERATIONS_FILE)) {
    stop("Accepted considerations file does not exist. Run RUN_STAGE=acceptance first.")
  }

  bank_all <- read_csv(CONSIDERATIONS_FILE, show_col_types = FALSE) %>%
    mutate(
      consideration_id = sanitize_cell(consideration_id),
      consideration = sanitize_cell(consideration),
      group = normalize_group_name(group),
      universe_rank = as.integer(universe_rank),
      consideration_rank = as.integer(consideration_rank)
    )

  existing <- read_csv(RESPONSES_FILE, show_col_types = FALSE)
  done_keys <- complete_response_keys(existing)
  to_save <- NULL
  processed <- 0

  for (i in seq_len(nrow(anes_simp))) {
    respondent <- anes_simp[i, ]

    for (prompt_type in PROMPT_TYPES) {
      key_exists <- done_keys %>%
        filter(.data$respID == respondent$respID, .data$prompt_type == prompt_type) %>%
        nrow()

      if (key_exists > 0) {
        next
      }

      bank_df <- bank_all %>%
        filter(.data$respID == respondent$respID, .data$prompt_type == prompt_type)

      if (nrow(bank_df) == 0) {
        stop("Missing consideration bank rows for response stage.")
      }

      persona_prompt <- system_prep(
        frame = get(prompt_type),
        lookup = respondent[1:n_demog]
      )

      schedule <- build_draw_schedule(
        bank_df = bank_df,
        respID = respondent$respID,
        prompt_type = prompt_type
      )

      bank_tsv <- bank_df %>%
        arrange(factor(group, levels = TARGET_GROUPS), consideration_rank, consideration_id) %>%
        select(group, consideration_id, consideration, universe_rank, consideration_rank) %>%
        format_tsv_block()

      parsed_batches <- list()
      batch_idx <- 1

      for (draw_start in seq(1, N_RESPONSE_DRAWS, by = RESPONSE_DRAWS_PER_CALL)) {
        draw_end <- min(draw_start + RESPONSE_DRAWS_PER_CALL - 1, N_RESPONSE_DRAWS)
        draw_batch <- seq(draw_start, draw_end)

        schedule_batch <- schedule %>%
          filter(draw %in% draw_batch)

        schedule_tsv <- schedule_batch %>%
          select(draw, group, sampled_consideration_ids) %>%
          format_tsv_block()

        parsed_batch <- NULL
        last_stage_error <- NULL

        for (stage_attempt in seq_len(STAGE_OUTPUT_ATTEMPTS)) {
          candidate <- try({
            raw_text <- submit_gemini(
              system_prompt = stage_system_prompt("", "responses"),
              input = build_response_input(bank_tsv, schedule_tsv)
            )

            dir.create("./data/raw", recursive = TRUE, showWarnings = FALSE)
            writeLines(raw_text, DEBUG_STAGE2_RAW_FILE, useBytes = TRUE)

            parsed_candidate <- parse_stage_tsv(
              raw_text,
              c("draw", "group", "thermometer", "explanation", "confidence")
            ) %>%
              mutate(
                draw = as.integer(draw),
                group = normalize_group_name(group),
                thermometer = as.integer(thermometer),
                explanation = sanitize_cell(explanation),
                confidence = as.integer(confidence)
              ) %>%
              filter(group %in% TARGET_GROUPS) %>%
              filter(!is.na(draw), draw %in% draw_batch) %>%
              filter(!is.na(thermometer), thermometer >= 0L, thermometer <= 100L) %>%
              filter(!is.na(confidence), confidence >= 0L, confidence <= 100L)

            expected_pairs <- expand_grid(
              draw = draw_batch,
              group = TARGET_GROUPS
            )

            parsed_pairs <- parsed_candidate %>%
              distinct(draw, group)

            if (nrow(inner_join(expected_pairs, parsed_pairs, by = c("draw", "group"))) != nrow(expected_pairs)) {
              stop("Response output is incomplete for at least one draw x group pair.")
            }

            parsed_candidate
          }, silent = TRUE)

          if (!inherits(candidate, "try-error")) {
            parsed_batch <- candidate
            break
          }

          last_stage_error <- as.character(candidate)
          Sys.sleep(min(10, stage_attempt))
        }

        if (is.null(parsed_batch)) {
          stop(if (!is.null(last_stage_error)) last_stage_error else "Responses stage failed after repeated semantic retries.")
        }

        write_csv(parsed_batch, DEBUG_STAGE2_PARSED_FILE)

        parsed_batches[[batch_idx]] <- parsed_batch
        batch_idx <- batch_idx + 1
      }

      parsed <- bind_rows(parsed_batches)

      enriched <- respondent[rep(1, nrow(parsed)), 1:n_demog] %>%
        bind_cols(
          tibble(
            prompt_type = prompt_type,
            prompt = persona_prompt
          )[rep(1, nrow(parsed)), ]
        ) %>%
        bind_cols(parsed) %>%
        left_join(schedule, by = c("draw", "group")) %>%
        mutate(index = i)

      to_save <- bind_rows(to_save, enriched)
      processed <- processed + 1

      if (processed %% FLUSH_EVERY == 0) {
        append_csv(to_save, RESPONSES_FILE)
        to_save <- NULL
      }
    }
  }

  if (!is.null(to_save) && nrow(to_save) > 0) {
    append_csv(to_save, RESPONSES_FILE)
  }
}

# ---- Run requested stage ----

if (RUN_STAGE %in% c("universe", "all")) {
  run_universe_stage()
}

if (RUN_STAGE %in% c("acceptance", "considerations", "all")) {
  run_acceptance_stage()
}

if (RUN_STAGE %in% c("responses", "all")) {
  run_responses_stage()
}

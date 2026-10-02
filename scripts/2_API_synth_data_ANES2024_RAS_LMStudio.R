################################################################################
##
## Purpose: Generate synthetic ANES 2024 thermometer data using a three-stage
##          Receive-Accept-Sample (RAS) pipeline over LM Studio's native REST
##          API.
##
##          Stage 1 (Universe) builds a universal bank of 30 considerations per
##          target — representing the full information environment, independent
##          of any respondent.
##
##          Stage 2 (Acceptance) predicts, for each respondent x prompt_type x
##          target, which considerations from that shared environment become
##          accessible or acceptable for that person's predispositions.
##
##          Stage 3 (Sampling) stochastically draws N_CONSIDERATIONS_SAMPLED
##          from the respondent-specific accepted set — pure R, no API calls.
##
##          Stage 4 (Responses) generates 0-100 thermometer ratings given the
##          sampled considerations. The response prompt explicitly treats
##          demographics as upstream predispositions rather than direct causes
##          of the final answer, mirroring a Zaller-style RAS flow.
##
## Input Files:
##  - ./external/anes_timeseries_2024_csv_20250808/anes_timeseries_2024_csv_20250808.csv
##
## Output Files:
##  - ./data/raw/anes2024_universe_RAS[suffix].csv
##  - ./data/raw/anes2024_acceptance_RAS[suffix].csv
##  - ./data/raw/therm_ANES2024_RAS_LMStudio[suffix].csv
##
## Notes:
##  - Configure execution with environment variables:
##      RUN_STAGE=universe|acceptance|responses|all
##
################################################################################

rm(list = ls())
gc()

library(tidyverse)
library(httr)
library(jsonlite)
require(readr)

# ---- Configuration ----

LM_STUDIO_URL       <- Sys.getenv("LM_STUDIO_URL",       unset = "http://localhost:1234/api/v1/chat")
LM_STUDIO_MODEL     <- Sys.getenv("LM_STUDIO_MODEL",     unset = "google/gemma-4-31b")
LM_STUDIO_REASONING <- Sys.getenv("LM_STUDIO_REASONING", unset = "")
RUN_STAGE            <- Sys.getenv("RUN_STAGE",            unset = "all")
RUN_LABEL            <- Sys.getenv("RUN_LABEL",            unset = "")
PROMPT_TYPES_OVERRIDE <- Sys.getenv("PROMPT_TYPES_OVERRIDE", unset = "")

N_UNIVERSE_CONSIDERATIONS <- as.integer(Sys.getenv("N_UNIVERSE_CONSIDERATIONS", unset = "30"))
N_CONSIDERATIONS_SAMPLED  <- as.integer(Sys.getenv("N_CONSIDERATIONS_SAMPLED",  unset = "4"))
N_RESPONSE_DRAWS          <- as.integer(Sys.getenv("N_RESPONSE_DRAWS",          unset = "30"))
RESPONSE_DRAWS_PER_CALL   <- as.integer(Sys.getenv("RESPONSE_DRAWS_PER_CALL",   unset = "1"))
FLUSH_EVERY               <- as.integer(Sys.getenv("FLUSH_EVERY",               unset = "10"))
PAUSE_SECONDS             <- as.numeric(Sys.getenv("PAUSE_SECONDS",             unset = "0.5"))
HTTP_TIMEOUT_SECONDS      <- as.numeric(Sys.getenv("HTTP_TIMEOUT_SECONDS",      unset = "600"))
RESPONDENT_LIMIT          <- as.integer(Sys.getenv("RESPONDENT_LIMIT",          unset = "0"))

run_suffix <- if (nzchar(RUN_LABEL)) paste0("_", RUN_LABEL) else ""

UNIVERSE_FILE   <- paste0("./data/raw/anes2024_universe_RAS", run_suffix, ".csv")
ACCEPTANCE_FILE <- paste0("./data/raw/anes2024_acceptance_RAS", run_suffix, ".csv")
RESPONSES_FILE  <- paste0("./data/raw/therm_ANES2024_RAS_LMStudio", run_suffix, ".csv")

ZALLER_RESPONSES_FILE_OVERRIDE <- Sys.getenv("ZALLER_RESPONSES_FILE", unset = "")
ZALLER_RESPONSES_FILE <- if (nzchar(ZALLER_RESPONSES_FILE_OVERRIDE)) {
  ZALLER_RESPONSES_FILE_OVERRIDE
} else {
  paste0("./data/raw/therm_ANES2024_zaller_LMStudio", run_suffix, ".csv")
}

DEBUG_RAW_FILE             <- paste0("./data/raw/lmstudio_ras_parse_failure_raw", run_suffix, ".txt")
DEBUG_CLEAN_FILE           <- paste0("./data/raw/lmstudio_ras_parse_failure_clean", run_suffix, ".txt")
DEBUG_UNIVERSE_RAW_FILE    <- paste0("./data/raw/lmstudio_ras_universe_last_raw", run_suffix, ".txt")
DEBUG_UNIVERSE_PARSED_FILE <- paste0("./data/raw/lmstudio_ras_universe_last_parsed", run_suffix, ".csv")
DEBUG_ACCEPT_RAW_FILE      <- paste0("./data/raw/lmstudio_ras_accept_last_raw", run_suffix, ".txt")
DEBUG_ACCEPT_PARSED_FILE   <- paste0("./data/raw/lmstudio_ras_accept_last_parsed", run_suffix, ".csv")
DEBUG_RESP_RAW_FILE        <- paste0("./data/raw/lmstudio_ras_resp_last_raw", run_suffix, ".txt")
DEBUG_RESP_PARSED_FILE     <- paste0("./data/raw/lmstudio_ras_resp_last_parsed", run_suffix, ".csv")

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

n_demog <- 11

# ---- Prompt templates ----

full <- "It is 2024. You are a [AGE] year-old, [MARST], [RACETH] [GENDER] with [EDUCATION] making [INCOME] per year, living in the United States.
You are [IDEO], [REGIS] [PID] who [INTEREST] pays attention to what's going on in government and politics."

demogFull <- "It is 2024. You are a [AGE] year-old [MARST] [RACETH] [GENDER] with [EDUCATION] making [INCOME] per year, living in the United States."

pol <- "It is 2024. You are [IDEO], [REGIS] [PID] who [INTEREST] pays attention to what's going on in government and politics, living in the United States."

# ---- Helper functions (shared with Zaller script) ----

system_prep <- function(frame, lookup) {
  for (col in colnames(lookup)) {
    frame <- gsub(paste0("\\[", toupper(col), "\\]"), lookup[[col]][1], frame)
  }
  frame
}

sanitize_cell <- function(x) {
  x %>%
    gsub("[\r\n\t]+", " ", ., perl = TRUE) %>%
    gsub("\\s{2,}", " ", ., perl = TRUE) %>%
    gsub('^"+', "", ., perl = TRUE) %>%
    gsub('"+$', "", ., perl = TRUE) %>%
    trimws()
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

weighted_shuffle <- function(ids, weights, base_key) {
  safe_weights <- pmax(as.numeric(weights), 1e-6)
  priorities <- vapply(
    seq_along(ids),
    function(i) {
      u <- hash_to_unit(paste(base_key, ids[i], collapse = "|"))
      -log(u) / safe_weights[i]
    },
    numeric(1)
  )
  ids[order(priorities)]
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

extract_lmstudio_text <- function(parsed) {
  candidates <- list(
    extract_output_message(parsed$output),
    parsed$output,
    parsed$content,
    parsed$response,
    parsed$text,
    parsed$message$content,
    safe_pluck(parsed, c("messages", 1, "content")),
    safe_pluck(parsed, c("choices", 1, "message", "content")),
    safe_pluck(parsed, c("choices", 1, "text"))
  )

  for (candidate in candidates) {
    if (is.null(candidate)) {
      next
    }
    if (is.character(candidate) && length(candidate) >= 1 && nzchar(candidate[[1]])) {
      return(candidate[[1]])
    }
  }

  stop("Could not extract text content from LM Studio response.")
}

submit_lmstudio <- function(system_prompt, input, max_attempts = 5) {
  payload <- list(
    model = LM_STUDIO_MODEL,
    system_prompt = system_prompt,
    input = input
  )

  if (nzchar(LM_STUDIO_REASONING)) {
    payload$reasoning <- LM_STUDIO_REASONING
  }

  for (attempt in seq_len(max_attempts)) {
    cat("  API attempt", attempt, "/ ", max_attempts, "...\n")

    response <- try(
      POST(
        url = LM_STUDIO_URL,
        body = payload,
        encode = "json",
        content_type_json(),
        timeout(HTTP_TIMEOUT_SECONDS)
      ),
      silent = TRUE
    )

    if (inherits(response, "try-error")) {
      cat("  -> try-error:", conditionMessage(attr(response, "condition")), "\n")
      Sys.sleep(min(60, 2 ^ attempt))
      next
    }

    sc <- status_code(response)
    cat("  -> status:", sc, "\n")

    if (sc >= 200 && sc < 300) {
      parsed <- content(response, as = "parsed", type = "application/json")
      text_out <- try(extract_lmstudio_text(parsed), silent = TRUE)
      if (!inherits(text_out, "try-error")) {
        Sys.sleep(PAUSE_SECONDS)
        return(text_out)
      }
      cat("  -> extract_lmstudio_text failed:", conditionMessage(attr(text_out, "condition")), "\n")
    } else {
      cat("  -> body:", rawToChar(content(response, as = "raw")), "\n")
    }

    Sys.sleep(min(60, 2 ^ attempt))
  }

  stop("LM Studio request failed after repeated attempts.")
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

  # Normalize mixed tab/multi-space separators: convert multi-space runs to

  # tabs so that space-aligned or partially-tabbed output parses correctly.
  cleaned <- gsub(" {2,}", "\t", cleaned)
  cleaned <- gsub("\t{2,}", "\t", cleaned)

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

  if (is.null(parsed)) {
    dir.create("./data/raw", recursive = TRUE, showWarnings = FALSE)
    writeLines(raw_text, DEBUG_RAW_FILE, useBytes = TRUE)
    writeLines(cleaned, DEBUG_CLEAN_FILE, useBytes = TRUE)
    stop("Could not parse model output as TSV.")
  }

  if (!all(col_names %in% colnames(parsed))) {
    # Fallback: try parsing without header if column count matches
    headerless <- try(
      read.delim(
        text = cleaned,
        sep = "\t",
        header = FALSE,
        quote = "",
        stringsAsFactors = FALSE,
        check.names = FALSE
      ),
      silent = TRUE
    )

    if (!inherits(headerless, "try-error") && ncol(headerless) == length(col_names)) {
      colnames(headerless) <- col_names
      parsed <- headerless
    } else {
      dir.create("./data/raw", recursive = TRUE, showWarnings = FALSE)
      writeLines(raw_text, DEBUG_RAW_FILE, useBytes = TRUE)
      writeLines(cleaned, DEBUG_CLEAN_FILE, useBytes = TRUE)
      stop("Parsed TSV is missing required columns.")
    }
  }

  parsed %>%
    select(all_of(col_names)) %>%
    mutate(across(where(is.character), sanitize_cell))
}

# ---- Stage 1: Universal Consideration Bank ----

build_universe_input <- function(target) {
  max_id <- paste0("C", sprintf("%02d", N_UNIVERSE_CONSIDERATIONS))

  paste(
    paste0("Generate exactly ", N_UNIVERSE_CONSIDERATIONS, " considerations that American adults might hold about ", target, " in 2024."),
    "Each consideration is a terse first-person thought.",
    "Cover the full spectrum: strong Democrat thoughts, strong Republican thoughts, apathetic moderate thoughts.",
    "Include policy, character, identity, competence, affect, and narrative dimensions.",
    "Mix positive, negative, and mixed valence.",
    "Use realism over politeness: include mundane, biased, unfair, naive, contradictory, or glowing thoughts whenever plausible.",
    "Think of this as a receive-stage information environment: cues should be broadly available, not tailored to one demographic type.",
    "Do not sanitize the worldview into what should be thought.",
    "Do not use slurs, graphic abuse, or endorse violence.",
    "Write each consideration as a terse first-person thought with no tabs or line breaks.",
    paste0("Use consideration_id values C01 through ", max_id, "."),
    "Return TSV only with these columns:",
    "target\tconsideration_id\tvalence\tdimension\tconsideration",
    "Use valence values: positive, negative, or mixed.",
    "Use dimension values: policy, character, identity, competence, affect, or narrative.",
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
      "First infer which cues this person would plausibly encounter or notice in 2024.",
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

run_universe_stage <- function() {
  dir.create("./data/raw", recursive = TRUE, showWarnings = FALSE)

  # Check for existing universe file and load completed targets
  existing <- NULL
  done_targets <- character(0)

  if (file.exists(UNIVERSE_FILE)) {
    existing <- read_csv(UNIVERSE_FILE, show_col_types = FALSE)
    done_targets <- existing %>%
      count(target, name = "n_rows") %>%
      filter(n_rows >= N_UNIVERSE_CONSIDERATIONS) %>%
      pull(target)
  } else {
    # Initialize empty file
    empty <- tibble(
      target = character(),
      consideration_id = character(),
      valence = character(),
      dimension = character(),
      consideration = character()
    )
    write_csv(empty, UNIVERSE_FILE)
  }

  for (target in TARGET_GROUPS) {
    if (target %in% done_targets) {
      cat("Universe: skipping", target, "(already complete)\n")
      next
    }

    cat("Universe: generating considerations for", target, "\n")

    raw_text <- submit_lmstudio(
      system_prompt = stage_system_prompt("", "universe"),
      input = build_universe_input(target)
    )

    writeLines(raw_text, DEBUG_UNIVERSE_RAW_FILE, useBytes = TRUE)

    parsed <- parse_stage_tsv(
      raw_text,
      c("target", "consideration_id", "valence", "dimension", "consideration")
    ) %>%
      mutate(
        target = normalize_group_name(target),
        consideration_id = sanitize_cell(consideration_id),
        valence = tolower(sanitize_cell(valence)),
        dimension = tolower(sanitize_cell(dimension)),
        consideration = sanitize_cell(consideration)
      ) %>%
      # Normalize consideration_id format to C01..C30
      mutate(
        consideration_id = case_when(
          grepl("^C\\d+$", consideration_id) ~
            paste0("C", sprintf("%02d", as.integer(sub("^C", "", consideration_id)))),
          TRUE ~ consideration_id
        )
      ) %>%
      # Force the correct target name (model may echo variants)
      mutate(target = target)

    write_csv(parsed, DEBUG_UNIVERSE_PARSED_FILE)

    # Validate
    valid_ids <- paste0("C", sprintf("%02d", seq_len(N_UNIVERSE_CONSIDERATIONS)))
    parsed <- parsed %>% filter(consideration_id %in% valid_ids)

    if (nrow(parsed) < N_UNIVERSE_CONSIDERATIONS) {
      warning(paste0(
        "Universe: only ", nrow(parsed), " valid rows for ", target,
        " (expected ", N_UNIVERSE_CONSIDERATIONS, "). Proceeding with available rows."
      ))
    }

    if (n_distinct(parsed$consideration_id) < nrow(parsed)) {
      # Deduplicate by consideration_id, keeping first occurrence
      parsed <- parsed %>% distinct(consideration_id, .keep_all = TRUE)
    }

    # Append to file
    write.table(
      parsed,
      file = UNIVERSE_FILE,
      append = TRUE,
      row.names = FALSE,
      col.names = FALSE,
      sep = ","
    )
  }

  # Validation summary
  final <- read_csv(UNIVERSE_FILE, show_col_types = FALSE)
  coverage <- final %>% count(target, name = "n_rows")
  cat("\nUniverse stage complete. Coverage:\n")
  print(as.data.frame(coverage))

  missing <- setdiff(TARGET_GROUPS, coverage$target)
  if (length(missing) > 0) {
    warning("Missing targets in universe file: ", paste(missing, collapse = ", "))
  }

  short <- coverage %>% filter(n_rows < N_UNIVERSE_CONSIDERATIONS)
  if (nrow(short) > 0) {
    warning("Targets with fewer than expected considerations: ",
            paste(short$target, collapse = ", "))
  }
}

# ---- Stage 2: Acceptance Prediction per Respondent ----

build_acceptance_input <- function(target, considerations_tsv) {
  paste(
    paste0("Below is a shared bank of considerations about ", target, "."),
    "For each consideration, predict the probability (0-100) that this person would receive and accept it as plausible enough to keep in mind.",
    "Higher probability means the cue is both plausibly encountered and not immediately rejected.",
    "Accepted does not mean morally endorsed or fully believed; it means cognitively usable for evaluation.",
    "A person can accept considerations that cut against their demographics or partisanship if those cues are available and plausible to them.",
    "Do not collapse the task into a stereotype based on race, gender, education, party, or ideology.",
    "Prefer a realistic, heterogeneous acceptance profile over a mechanically partisan or demographic one.",
    "Use the full 0-100 range. A 0 means the thought would almost never make it into this person's evaluative mix; 100 means it is almost certainly in play.",
    "Return TSV only with these columns:",
    "target\tconsideration_id\tacceptance_prob",
    "Use acceptance_prob as an integer from 0 to 100.",
    "Considerations:",
    considerations_tsv,
    sep = "\n"
  )
}

init_acceptance_file <- function() {
  if (file.exists(ACCEPTANCE_FILE)) {
    return(invisible(NULL))
  }

  dir.create("./data/raw", recursive = TRUE, showWarnings = FALSE)

  empty <- data.frame(
    anes_simp[0, 1:n_demog],
    prompt_type = as.character(),
    prompt = as.character(),
    target = as.character(),
    consideration_id = as.character(),
    acceptance_prob = as.integer(),
    index = as.integer(),
    stringsAsFactors = FALSE
  )

  write_csv(empty, ACCEPTANCE_FILE)
}

complete_acceptance_keys <- function(df, universe_df) {
  if (nrow(df) == 0) {
    return(tibble(respID = integer(), prompt_type = character()))
  }

  expected_by_target <- universe_df %>%
    distinct(target, consideration_id) %>%
    count(target, name = "expected_ids")

  df %>%
    distinct(respID, prompt_type, target, consideration_id) %>%
    count(respID, prompt_type, target, name = "ids_present") %>%
    inner_join(expected_by_target, by = "target") %>%
    group_by(respID, prompt_type) %>%
    summarise(
      targets_present = n_distinct(target),
      min_target_share = min(ids_present / expected_ids),
      .groups = "drop"
    ) %>%
    filter(
      targets_present == length(TARGET_GROUPS),
      min_target_share >= 1
    ) %>%
    select(respID, prompt_type)
}

validate_acceptance_schema <- function(df) {
  required_cols <- c("respID", "prompt_type", "target", "consideration_id", "acceptance_prob")
  missing_cols <- setdiff(required_cols, colnames(df))

  if (length(missing_cols) > 0) {
    stop(
      paste0(
        "Acceptance file schema is from an older pipeline version. Missing columns: ",
        paste(missing_cols, collapse = ", "),
        ". Rebuild ", ACCEPTANCE_FILE, " with RUN_STAGE=acceptance."
      )
    )
  }
}

run_acceptance_stage <- function() {
  init_acceptance_file()

  # Load universe
  if (!file.exists(UNIVERSE_FILE)) {
    stop("Universe file does not exist. Run RUN_STAGE=universe first.")
  }

  universe <- read_csv(UNIVERSE_FILE, show_col_types = FALSE) %>%
    mutate(
      target = normalize_group_name(target),
      consideration_id = sanitize_cell(consideration_id),
      consideration = sanitize_cell(consideration)
    )

  cat("Acceptance: ", nrow(anes_simp), " respondents x ",
      length(PROMPT_TYPES), " prompt types x ",
      length(TARGET_GROUPS), " targets = ",
      nrow(anes_simp) * length(PROMPT_TYPES) * length(TARGET_GROUPS), " API calls\n")

  existing <- read_csv(ACCEPTANCE_FILE, show_col_types = FALSE)
  validate_acceptance_schema(existing)
  done_keys <- complete_acceptance_keys(existing, universe)

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

      for (target in TARGET_GROUPS) {
        target_considerations <- universe %>%
          filter(.data$target == !!target) %>%
          select(target, consideration_id, consideration)

        if (nrow(target_considerations) == 0) {
          warning("No universe considerations for target: ", target, ". Skipping.")
          next
        }

        considerations_tsv <- format_tsv_block(target_considerations)

        cat("Acceptance: respondent ", respondent$respID, " x ", prompt_type,
            " x ", target, " [", i, "/", nrow(anes_simp), "]\n")

        raw_text <- submit_lmstudio(
          system_prompt = stage_system_prompt(persona_prompt, "acceptance"),
          input = build_acceptance_input(target, considerations_tsv)
        )

        writeLines(raw_text, DEBUG_ACCEPT_RAW_FILE, useBytes = TRUE)

        parsed <- parse_stage_tsv(
          raw_text,
          c("target", "consideration_id", "acceptance_prob")
        ) %>%
          mutate(
            target = normalize_group_name(target),
            consideration_id = sanitize_cell(consideration_id),
            acceptance_prob = as.integer(sanitize_cell(acceptance_prob))
          ) %>%
          mutate(target = !!target) %>%
          mutate(
            consideration_id = case_when(
              grepl("^C\\d+$", consideration_id) ~
                paste0("C", sprintf("%02d", as.integer(sub("^C", "", consideration_id)))),
              TRUE ~ consideration_id
            )
          ) %>%
          filter(!is.na(acceptance_prob)) %>%
          mutate(acceptance_prob = pmin(pmax(acceptance_prob, 0L), 100L)) %>%
          filter(consideration_id %in% unique(target_considerations$consideration_id)) %>%
          distinct(consideration_id, .keep_all = TRUE)

        write_csv(parsed, DEBUG_ACCEPT_PARSED_FILE)

        if (nrow(parsed) == 0) {
          warning("No valid acceptance rows parsed for respondent ", respondent$respID,
                  " x ", prompt_type, " x ", target, ". Skipping.")
          next
        }

        mean_prob <- mean(parsed$acceptance_prob)
        if (mean_prob < 10 || mean_prob > 90) {
          warning(paste0(
            "Calibration flag: respondent ", respondent$respID, " x ", prompt_type,
            " x ", target, " mean acceptance_prob = ", round(mean_prob, 1),
            " (", nrow(parsed), " considerations)."
          ))
        }

        enriched <- respondent[rep(1, nrow(parsed)), 1:n_demog] %>%
          bind_cols(
            tibble(
              prompt_type = prompt_type,
              prompt = persona_prompt
            )[rep(1, nrow(parsed)), ]
          ) %>%
          bind_cols(parsed %>% select(target, consideration_id, acceptance_prob)) %>%
          mutate(index = i)

        to_save <- bind_rows(to_save, enriched)
        processed <- processed + 1

        if (processed %% FLUSH_EVERY == 0) {
          write.table(
            to_save,
            file = ACCEPTANCE_FILE,
            append = TRUE,
            row.names = FALSE,
            col.names = FALSE,
            sep = ","
          )
          to_save <- NULL
        }
      }
    }
  }

  if (!is.null(to_save) && nrow(to_save) > 0) {
    write.table(
      to_save,
      file = ACCEPTANCE_FILE,
      append = TRUE,
      row.names = FALSE,
      col.names = FALSE,
      sep = ","
    )
  }

  # Validation summary
  final <- read_csv(ACCEPTANCE_FILE, show_col_types = FALSE)
  cat("\nAcceptance stage complete.",
      nrow(final), "total rows,",
      n_distinct(final$respID), "respondents,",
      n_distinct(final$prompt_type), "prompt types,",
      n_distinct(final$target), "targets\n")
}

# ---- Stage 3: Stochastic Sampling (Pure R) ----

build_ras_draw_schedule <- function(acceptance_df, universe_df, respID, prompt_type) {
  schedule_rows <- list()
  row_idx <- 1

  for (draw_id in seq_len(N_RESPONSE_DRAWS)) {
    for (target_group in TARGET_GROUPS) {
      # Get all considerations and their acceptance probabilities for this respondent x prompt x target
      cell_probs <- acceptance_df %>%
        filter(
          .data$respID == !!respID,
          .data$prompt_type == !!prompt_type,
          .data$target == target_group
        )

      if (nrow(cell_probs) == 0) {
        warning(paste0(
          "No acceptance data for respondent ", respID, " x ", prompt_type,
          " x ", target_group, ". Using uniform weights over all universe considerations."
        ))
        cell_probs <- universe_df %>%
          filter(.data$target == target_group) %>%
          select(consideration_id) %>%
          mutate(acceptance_prob = 50L)
      }

      all_ids <- cell_probs$consideration_id
      prob_weights <- cell_probs$acceptance_prob

      n_sample <- min(N_CONSIDERATIONS_SAMPLED, length(all_ids))

      # Use acceptance probabilities as sampling weights
      ordered_ids <- weighted_shuffle(
        ids = all_ids,
        weights = prob_weights,
        base_key = paste(respID, prompt_type, draw_id, target_group, collapse = "|")
      )

      sampled_ids <- ordered_ids[seq_len(n_sample)]
      sampled_text <- universe_df %>%
        filter(.data$target == target_group,
               .data$consideration_id %in% sampled_ids) %>%
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

# ---- Stage 4: Thermometer Response Generation ----

build_response_input <- function(bank_tsv, schedule_tsv) {
  paste(
    "You are rating political targets using only the sampled accepted considerations.",
    "The respondent's predispositions already did their work upstream by shaping which considerations were accepted and sampled.",
    "Do not condition again on demographics, party, ideology, race, gender, age, income, or education.",
    "Only use the sampled considerations listed in the draw schedule.",
    "Reason silently from the sampled thoughts to the final thermometer score; do not reverse-engineer the answer from the persona.",
    "Use the ID order in each sampled_consideration_ids list as accessibility order and infer the directional pull from the content of each thought.",
    "Do not import new reasons, outside facts, or moral corrections.",
    "If the sampled considerations are shallow, contradictory, unfair, glowing, or boring, keep the response that way.",
    "Translate the sampled considerations into a realistic feeling thermometer rating.",
    "The thermometer runs from 0 (cold) to 100 (warm), with 50 neutral.",
    "Return TSV only with these columns:",
    "draw\tgroup\tthermometer\texplanation\tconfidence",
    "Use thermometer as an integer from 0 to 100.",
    "Use confidence as an integer from 0 to 100.",
    "Keep explanation to one short sentence with no tabs or line breaks.",
    "Consideration bank:",
    bank_tsv,
    "Draw schedule:",
    schedule_tsv,
    sep = "\n\n"
  )
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

  write.table(
    empty,
    file = RESPONSES_FILE,
    append = FALSE,
    row.names = FALSE,
    col.names = TRUE,
    sep = ","
  )
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

validate_responses_schema <- function(df) {
  required_cols <- c(
    "respID", "prompt_type", "draw", "group", "thermometer",
    "explanation", "confidence", "sampled_consideration_ids",
    "sampled_considerations"
  )
  missing_cols <- setdiff(required_cols, colnames(df))

  if (length(missing_cols) > 0 || "cell_id" %in% colnames(df)) {
    stop(
      paste0(
        "Responses file schema is from an older pipeline version. ",
        if (length(missing_cols) > 0) {
          paste0("Missing columns: ", paste(missing_cols, collapse = ", "), ". ")
        } else {
          ""
        },
        if ("cell_id" %in% colnames(df)) {
          "Deprecated column present: cell_id. "
        } else {
          ""
        },
        "Rebuild ", RESPONSES_FILE, " with RUN_STAGE=responses."
      )
    )
  }
}

run_ras_responses_stage <- function() {
  init_responses_file()

  # Load universe and acceptance data
  if (!file.exists(UNIVERSE_FILE)) {
    stop("Universe file does not exist. Run RUN_STAGE=universe first.")
  }
  if (!file.exists(ACCEPTANCE_FILE)) {
    stop("Acceptance file does not exist. Run RUN_STAGE=acceptance first.")
  }

  universe <- read_csv(UNIVERSE_FILE, show_col_types = FALSE) %>%
    mutate(
      target = normalize_group_name(target),
      consideration_id = sanitize_cell(consideration_id),
      consideration = sanitize_cell(consideration)
    )

  acceptance <- read_csv(ACCEPTANCE_FILE, show_col_types = FALSE) %>%
    {
      validate_acceptance_schema(.)
      .
    } %>%
    mutate(
      respID = as.integer(respID),
      prompt_type = sanitize_cell(prompt_type),
      target = normalize_group_name(target),
      consideration_id = sanitize_cell(consideration_id),
      acceptance_prob = as.integer(sanitize_cell(acceptance_prob))
    )

  existing <- read_csv(RESPONSES_FILE, show_col_types = FALSE)
  validate_responses_schema(existing)
  done_keys <- complete_response_keys(existing)
  to_save <- NULL
  processed <- 0

  for (i in seq_len(nrow(anes_simp))) {
    respondent <- anes_simp[i, ]

    for (prompt_type in PROMPT_TYPES) {
      key_exists <- done_keys %>%
        filter(.data$respID == respondent$respID, .data$prompt_type == prompt_type) %>%
        nrow()

      if (key_exists > 0) next

      persona_prompt <- system_prep(
        frame = get(prompt_type),
        lookup = respondent[1:n_demog]
      )

      # Stage 3: build draw schedule (pure R)
      schedule <- build_ras_draw_schedule(
        acceptance_df = acceptance,
        universe_df = universe,
        respID = respondent$respID,
        prompt_type = prompt_type
      )

      # Stage 4: generate thermometer responses
      parsed_batches <- list()
      batch_idx <- 1

      for (draw_start in seq(1, N_RESPONSE_DRAWS, by = RESPONSE_DRAWS_PER_CALL)) {
        draw_end <- min(draw_start + RESPONSE_DRAWS_PER_CALL - 1, N_RESPONSE_DRAWS)
        draw_batch <- seq(draw_start, draw_end)

        schedule_batch <- schedule %>%
          filter(draw %in% draw_batch)

        # Extract sampled consideration IDs from this batch
        batch_cids <- schedule_batch %>%
          pull(sampled_consideration_ids) %>%
          strsplit(",") %>%
          unlist() %>%
          trimws() %>%
          unique()

        # Build bank TSV with only the sampled considerations for this batch
        bank_tsv <- universe %>%
          filter(consideration_id %in% batch_cids) %>%
          arrange(factor(target, levels = TARGET_GROUPS), consideration_id) %>%
          select(target, consideration_id, consideration) %>%
          format_tsv_block()

        schedule_tsv <- schedule_batch %>%
          select(draw, group, sampled_consideration_ids) %>%
          format_tsv_block()

        # Debug: dump the actual prompt to file for inspection
        resp_input <- build_response_input(bank_tsv, schedule_tsv)
        resp_sys <- stage_system_prompt("", "responses")
        writeLines(resp_sys, "./data/raw/debug_resp_system_prompt.txt")
        writeLines(resp_input, "./data/raw/debug_resp_input.txt")
        cat("  Bank rows:", length(batch_cids), "unique CIDs,",
            nrow(universe %>% filter(consideration_id %in% batch_cids)),
            "bank rows. Input chars:", nchar(resp_input), "\n")

        raw_text <- submit_lmstudio(
          system_prompt = resp_sys,
          input = resp_input
        )

        dir.create("./data/raw", recursive = TRUE, showWarnings = FALSE)
        writeLines(raw_text, DEBUG_RESP_RAW_FILE, useBytes = TRUE)

        parsed_batch <- try({
          parse_stage_tsv(
            raw_text,
            c("draw", "group", "thermometer", "explanation", "confidence")
          ) %>%
            mutate(
              draw = as.integer(draw),
              group = normalize_group_name(group),
              thermometer = as.integer(thermometer),
              explanation = sanitize_cell(explanation),
              # Default missing confidence to 50
              confidence = ifelse(is.na(confidence) | confidence == "",
                                  50L, as.integer(confidence))
            ) %>%
            filter(group %in% TARGET_GROUPS) %>%
            filter(!is.na(draw), draw %in% draw_batch) %>%
            filter(!is.na(thermometer), thermometer >= 0L, thermometer <= 100L) %>%
            mutate(confidence = pmin(pmax(confidence, 0L), 100L))
        }, silent = TRUE)

        if (inherits(parsed_batch, "try-error")) {
          warning("Failed to parse response for draws ", draw_start, "-", draw_end,
                  ": ", conditionMessage(attr(parsed_batch, "condition")), " Skipping.")
          next
        }

        write_csv(parsed_batch, DEBUG_RESP_PARSED_FILE)

        expected_pairs <- expand_grid(
          draw = draw_batch,
          group = TARGET_GROUPS
        )

        parsed_pairs <- parsed_batch %>%
          distinct(draw, group)

        missing_count <- nrow(expected_pairs) - nrow(inner_join(expected_pairs, parsed_pairs, by = c("draw", "group")))
        if (missing_count > 0) {
          warning("Response output missing ", missing_count, " draw x group pair(s). Continuing.")
        }

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

      cat("Responses: respondent", respondent$respID,
          "x", prompt_type, "[", i, "/", nrow(anes_simp), "]\n")

      if (processed %% FLUSH_EVERY == 0) {
        write.table(
          to_save,
          file = RESPONSES_FILE,
          append = TRUE,
          row.names = FALSE,
          col.names = FALSE,
          sep = ","
        )
        to_save <- NULL
      }
    }
  }

  if (!is.null(to_save) && nrow(to_save) > 0) {
    write.table(
      to_save,
      file = RESPONSES_FILE,
      append = TRUE,
      row.names = FALSE,
      col.names = FALSE,
      sep = ","
    )
  }

  cat("Response stage complete.\n")
}

# ---- Variance comparison: synthetic vs. real FTs ----

run_variance_comparison <- function() {
  if (!file.exists(RESPONSES_FILE)) {
    stop("RAS responses file does not exist. Run RUN_STAGE=responses first.")
  }

  has_zaller <- file.exists(ZALLER_RESPONSES_FILE)
  if (!has_zaller) {
    cat("Note: Zaller responses file not found at", ZALLER_RESPONSES_FILE, "\n")
    cat("  Set ZALLER_RESPONSES_FILE env var to compare against a different Zaller run.\n")
    cat("  Proceeding with RAS-only comparison.\n\n")
  }

  # --- Load data ---
  ras_raw <- read_csv(RESPONSES_FILE, show_col_types = FALSE)

  real_long <- anes_simp %>%
    pivot_longer(
      starts_with("therm_"),
      names_to = "group",
      values_to = "therm_real",
      names_prefix = "therm_"
    ) %>%
    filter(!is.na(therm_real)) %>%
    select(respID, group, therm_real)

  # Helper: summarise a synthetic responses frame to per-respondent stats
  summarise_synth <- function(df, pipeline_label) {
    df %>%
      group_by(respID, group, prompt_type) %>%
      summarise(
        therm_synth_mean = mean(thermometer, na.rm = TRUE),
        therm_synth_sd = sd(thermometer, na.rm = TRUE),
        n_draws = n(),
        .groups = "drop"
      ) %>%
      mutate(pipeline = pipeline_label)
  }

  ras_by_resp <- summarise_synth(ras_raw, "RAS")

  if (has_zaller) {
    zaller_raw <- read_csv(ZALLER_RESPONSES_FILE, show_col_types = FALSE)
    zaller_by_resp <- summarise_synth(zaller_raw, "Zaller")
    synth_by_resp <- bind_rows(ras_by_resp, zaller_by_resp)
  } else {
    synth_by_resp <- ras_by_resp
  }

  comparison <- synth_by_resp %>%
    inner_join(real_long, by = c("respID", "group"))

  # --- 1. Marginal variance by target x pipeline ---
  marginal <- comparison %>%
    group_by(group, prompt_type, pipeline) %>%
    summarise(
      var_real = var(therm_real, na.rm = TRUE),
      var_synth_mean = var(therm_synth_mean, na.rm = TRUE),
      var_ratio = var_synth_mean / var_real,
      sd_real = sd(therm_real, na.rm = TRUE),
      sd_synth_mean = sd(therm_synth_mean, na.rm = TRUE),
      cor_real_synth = cor(therm_real, therm_synth_mean, use = "complete.obs"),
      mae = mean(abs(therm_real - therm_synth_mean), na.rm = TRUE),
      n = n(),
      .groups = "drop"
    ) %>%
    arrange(group, prompt_type, pipeline)

  cat("\n=== Marginal Variance Comparison (per target x prompt_type x pipeline) ===\n")
  print(as.data.frame(marginal), row.names = FALSE)

  # --- 2. Within-respondent synthetic variance (draw-to-draw spread) ---
  within_resp <- synth_by_resp %>%
    group_by(group, prompt_type, pipeline) %>%
    summarise(
      mean_within_sd = mean(therm_synth_sd, na.rm = TRUE),
      median_within_sd = median(therm_synth_sd, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    arrange(group, prompt_type, pipeline)

  cat("\n=== Within-Respondent Synthetic SD (across draws) ===\n")
  print(as.data.frame(within_resp), row.names = FALSE)

  # --- 3. By PID breakdown ---
  pid_comparison <- comparison %>%
    left_join(anes_simp %>% select(respID, PID), by = "respID") %>%
    group_by(group, prompt_type, pipeline, PID) %>%
    summarise(
      mean_real = mean(therm_real, na.rm = TRUE),
      mean_synth = mean(therm_synth_mean, na.rm = TRUE),
      var_real = var(therm_real, na.rm = TRUE),
      var_synth = var(therm_synth_mean, na.rm = TRUE),
      n = n(),
      .groups = "drop"
    ) %>%
    filter(n >= 10) %>%
    arrange(group, prompt_type, PID, pipeline)

  cat("\n=== Variance by PID (cells with n >= 10) ===\n")
  print(as.data.frame(pid_comparison), row.names = FALSE)

  # --- 4. Head-to-head summary (RAS vs Zaller, collapsed across targets) ---
  if (has_zaller) {
    head_to_head <- marginal %>%
      group_by(prompt_type, pipeline) %>%
      summarise(
        mean_var_ratio = mean(var_ratio, na.rm = TRUE),
        mean_cor = mean(cor_real_synth, na.rm = TRUE),
        mean_mae = mean(mae, na.rm = TRUE),
        .groups = "drop"
      ) %>%
      arrange(prompt_type, pipeline)

    cat("\n=== Head-to-Head Summary (averaged across targets) ===\n")
    print(as.data.frame(head_to_head), row.names = FALSE)

    # Within-respondent SD comparison
    within_h2h <- within_resp %>%
      group_by(prompt_type, pipeline) %>%
      summarise(
        grand_mean_within_sd = mean(mean_within_sd, na.rm = TRUE),
        .groups = "drop"
      ) %>%
      arrange(prompt_type, pipeline)

    cat("\n=== Within-Respondent SD Head-to-Head (averaged across targets) ===\n")
    print(as.data.frame(within_h2h), row.names = FALSE)
  }

  # --- Save comparison tables ---
  comparison_file <- paste0("./data/raw/ras_variance_comparison", run_suffix, ".csv")
  write_csv(marginal, comparison_file)
  cat("\nMarginal comparison saved to:", comparison_file, "\n")

  invisible(list(
    marginal = marginal,
    within_resp = within_resp,
    pid_comparison = pid_comparison,
    respondent_level = comparison
  ))
}

# ---- Stage dispatcher ----

if (RUN_STAGE %in% c("universe", "all")) {
  cat("=== Running Universe Stage ===\n")
  run_universe_stage()
}

if (RUN_STAGE %in% c("acceptance", "all")) {
  cat("=== Running Acceptance Stage ===\n")
  run_acceptance_stage()
}

if (RUN_STAGE %in% c("responses", "all")) {
  cat("=== Running Responses Stage ===\n")
  run_ras_responses_stage()
}

if (RUN_STAGE %in% c("validate", "all")) {
  cat("=== Running Variance Comparison ===\n")
  run_variance_comparison()
}

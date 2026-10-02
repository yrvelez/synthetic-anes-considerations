################################################################################
##
## Purpose: This script queries OpenAI's API to generate synthetic survey data.
##            It adapts the approach of Bisbee et al. (2024) for the ANES 2024 Time Series
##            Study, using candidate/party feeling thermometers instead of social
##            group thermometers.
##
## Reference: Bisbee, J., J. D. Clinton, C. Dorff, B. Kenkel, and J. M. Larson. 2024.
##   "Synthetic Replacements for Human Survey Data? The Perils of Large Language
##   Models." Political Analysis 32 (4): 401–416. https://doi.org/10.1017/pan.2024.5
##
## Input Files:
##  - ./external/anes_timeseries_2024_csv_20250808/anes_timeseries_2024_csv_20250808.csv
##
## Output:
##  - ./data/raw/therm_ANES2024_RR1.csv
##
## Variable Reference (from ANES 2024 codebook):
##  Demographics:
##    V241501x  Race/ethnicity summary (1-6)
##    V241458x  Age (continuous)
##    V241550   Sex (1 Male, 2 Female)
##    V241177   Lib-con self-placement (1-7, 99 Haven't thought)
##    V241227x  7-point Party ID summary (1 Strong Dem ... 7 Strong Rep)
##    V241567x  Income summary 6-cat (1 Under $9,999 ... 6 $250K+)
##    V241012   Registered to vote (1 Yes, 2 No)
##    V241465x  Education summary 5-cat (1 < HS ... 5 Graduate)
##    V241004   Political attention (1 Always ... 5 Never)
##    V241461x  Marital status summary (1-5)
##
##  Feeling Thermometers (0-100):
##    V241156  Kamala Harris
##    V241157  Donald Trump
##    V241158  Joe Biden
##    V241159  RFK Jr
##    V241164  J.D. Vance
##    V241165  Tim Walz
##    V241166  Democratic Party
##    V241167  Republican Party
##
##  Missing codes: -9 Refused, -8 Don't know, -5 Break off, -4 Error,
##                 -3 Restricted, -1 Inapplicable
##
################################################################################

rm(list = ls())
gc()

library(tidyverse)
library(openai)
require(readr)

Sys.setenv(OPENAI_API_KEY = '') # Enter API Key Here

# Function to create a detailed prompt
create_prompt <- function(systemPrompt) {
  res <- list(
    list(
      "role" = "system",
      "content" = systemPrompt
    ),
    list(
      "role" = "user",
      "content" = stringr::str_c(
        "Provide responses from this person's perspective.\n
          Use only knowledge about politics that they would have.\n
          Format the output as a tsv table with the following format:\n
          group\tthermometer\texplanation\tconfidence\n
          The following questions ask about individuals' feelings toward different groups.\n
          Responses should be given on a scale from 0 (meaning cold feelings) to 100 (meaning warm feelings).\n
          Ratings between 50 degrees and 100 degrees mean that\n
          you feel favorable and warm toward the group. Ratings between 0\n
          degrees and 50 degrees mean that you don't feel favorable toward\n
          the group and that you don't care too much for that group. You\n
          would rate the group at the 50 degree mark if you don't feel\n
          particularly warm or cold toward the group.\n
          How do you feel toward the following?\n",
        'Kamala Harris?\n',
        'Donald Trump?\n',
        'Joe Biden?\n',
        'Robert F. Kennedy Jr.?\n',
        'J.D. Vance?\n',
        'Tim Walz?\n',
        'The Democratic Party?\n',
        'The Republican Party?\n')
    )
  )
  return(res)
}


# ---- Load and prepare the ANES 2024 data ----

anes <- read_csv('./external/anes_timeseries_2024_csv_20250808/anes_timeseries_2024_csv_20250808.csv')

# Select and rename variables
anes_simp <- anes %>%
  select(
    respID    = V200001,
    raceth    = V241501x,
    age       = V241458x,
    gender    = V241550,
    ideo      = V241177,
    PID       = V241227x,
    income    = V241567x,
    regis     = V241012,
    education = V241465x,
    interest  = V241004,
    marst     = V241461x,
    `therm_Kamala Harris`     = V241156,
    `therm_Donald Trump`      = V241157,
    `therm_Joe Biden`         = V241158,
    `therm_RFK Jr`            = V241159,
    `therm_JD Vance`          = V241164,
    `therm_Tim Walz`          = V241165,
    `therm_Democratic Party`  = V241166,
    `therm_Republican Party`  = V241167
  )

# ---- Recode to text labels ----

anes_simp <- anes_simp %>%
  # Drop missing/negative codes on thermometers (keep 0-100 only)
  mutate_at(vars(matches('therm_')), function(x) ifelse(x < 0 | x > 100, NA, x)) %>%
  mutate(
    # Race/ethnicity (V241501x: 1-6)
    raceth = case_when(
      raceth == 1 ~ 'non-Hispanic white',
      raceth == 2 ~ 'non-Hispanic Black',
      raceth == 3 ~ 'Hispanic',
      raceth == 4 ~ 'Asian or Pacific Islander',
      raceth == 5 ~ 'Native American',
      raceth == 6 ~ 'multiracial',
      TRUE ~ NA_character_
    ),
    # Gender (V241550: 1 Male, 2 Female)
    gender = case_when(
      gender == 1 ~ 'male',
      gender == 2 ~ 'female',
      TRUE ~ NA_character_
    ),
    # Party ID (V241227x: 1-7)
    PID = case_when(
      PID %in% 1:3 ~ 'Democrat',
      PID == 4     ~ 'Independent',
      PID %in% 5:7 ~ 'Republican',
      TRUE ~ NA_character_
    ),
    # Voter registration (V241012: 1 Yes, 2 No)
    regis = case_when(
      regis == 1 ~ 'registered',
      regis == 2 ~ 'unregistered',
      TRUE ~ NA_character_
    ),
    # Marital status (V241461x: 1-5)
    marst = case_when(
      marst == 1 ~ 'married',
      marst == 2 ~ 'divorced',
      marst == 3 ~ 'separated',
      marst == 4 ~ 'widowed',
      marst == 5 ~ 'single',
      TRUE ~ NA_character_
    ),
    # Political attention (V241004: 1 Always ... 5 Never)
    interest = case_when(
      interest == 1 ~ 'always',
      interest == 2 ~ 'regularly',
      interest == 3 ~ 'frequently',
      interest == 4 ~ 'sometimes',
      interest == 5 ~ 'never',
      TRUE ~ NA_character_
    ),
    # Ideology (V241177: 1-7, 99 Haven't thought)
    ideo = case_when(
      ideo == 1 ~ 'an extremely liberal',
      ideo == 2 ~ 'a liberal',
      ideo == 3 ~ 'a slightly liberal',
      ideo == 4 ~ 'a moderate',
      ideo == 5 ~ 'a slightly conservative',
      ideo == 6 ~ 'a conservative',
      ideo == 7 ~ 'an extremely conservative',
      TRUE ~ NA_character_
    ),
    # Income (V241567x: 1-6)
    income = case_when(
      income == 1 ~ '$10,000',
      income == 2 ~ '$30,000',
      income == 3 ~ '$60,000',
      income == 4 ~ '$100,000',
      income == 5 ~ '$175,000',
      income == 6 ~ 'more than $250,000',
      TRUE ~ NA_character_
    ),
    # Education (V241465x: 1-5)
    education = case_when(
      education == 1 ~ 'less than a high school diploma',
      education == 2 ~ 'a high school diploma',
      education == 3 ~ 'some college, but no degree',
      education %in% 4:5 ~ "a bachelor's degree or more",
      TRUE ~ NA_character_
    )
  ) %>%
  # Drop rows with missing age or negative age codes
  filter(age > 0) %>%
  drop_na(raceth, age, gender, ideo, PID, income, regis, education, interest, marst)

# Number of demographic columns (before thermometers)
n_demog <- 11

# ---- Prompt templates ----
# Mirrors the prompts in Bisbee et al. (2024), updated for 2024

full <- "It is 2024. You are a [AGE] year-old, [MARST], [RACETH] [GENDER] with [EDUCATION] making [INCOME] per year, living in the United States.
You are [IDEO], [REGIS] [PID] who [INTEREST] pays attention to what's going on in government and politics."

demogSimp <- "It is 2024. You are a [AGE] year-old [RACETH] [GENDER], living in the United States."

demogFull <- "It is 2024. You are a [AGE] year-old [MARST] [RACETH] [GENDER] with [EDUCATION] making [INCOME] per year, living in the United States."

pol <- "It is 2024. You are [IDEO], [REGIS] [PID] who [INTEREST] pays attention to what's going on in government and politics, living in the United States."

# ---- Helper functions ----

system_prep <- function(frame, lookup) {
  for (col in colnames(lookup)) {
    frame <- gsub(paste0('\\[', toupper(col), '\\]'), lookup[[col]][1], frame)
  }
  return(frame)
}

submit_openai <- function(prompt, temperature = 0.2, n = 1) {
  res <- openai::create_chat_completion(
    model = "gpt-3.5-turbo",
    messages = prompt,
    temperature = temperature,
    n = n
  )
  Sys.sleep(1)
  res
}

# ---- Initialize output file ----
# Comment this block out after first run to avoid overwriting progress.

df <- data.frame(
  anes_simp[0, 1:n_demog],
  group = as.character(),
  thermometer = as.numeric(),
  explanation = as.character(),
  confidence = as.character(),
  draw = as.numeric(),
  temperature = as.numeric(),
  prompt = as.character(),
  index = as.numeric(),
  stringsAsFactors = FALSE
)

dir.create('./data/raw', recursive = TRUE, showWarnings = FALSE)

write.table(df, file = './data/raw/therm_ANES2024_RR1.csv',
            append = FALSE, row.names = FALSE, col.names = TRUE, sep = ',')

# ---- Resume from checkpoint ----

df <- read_csv('./data/raw/therm_ANES2024_RR1.csv', n_max = Inf)

df <- df %>%
  mutate(index = as.numeric(gsub(',NA', '', index)))

if (nrow(df) == 0) {
  start <- 1
} else {
  start <- max(df$index, na.rm = TRUE) + 1
}

remain <- setdiff(anes_simp$respID, unique(df$respID))
indices <- which(anes_simp$respID %in% remain)

write_csv(anes_simp, file = './data/raw/anes2024_simp.csv')

# ---- Main API loop ----

toSave <- NULL
TPM <- RPM <- NULL
zz <- zzz <- Sys.time()

for (i in indices) {
  for (p in c('full', 'demogFull', 'pol')) {
    prompts <- create_prompt(
      systemPrompt = system_prep(
        frame = get(p),
        lookup = anes_simp[i, 1:n_demog]
      )
    )
    t <- 1

    system.time(
      openai_completions <- try(
        submit_openai(prompt = prompts, temperature = t, n = 30)
      )
    )
    Sys.sleep(2)

    while (class(openai_completions) == 'try-error') {
      Sys.sleep(60)
      cat('issue on\n', 'temp =', t, '\n')
      openai_completions <- try(
        submit_openai(prompt = prompts, temperature = t, n = 30)
      )
    }

    tmp <- NULL
    for (j in 1:length(openai_completions$choices$message.content)) {
      tmp2 <- try(
        read.csv(
          text = gsub(
            '(\\\n|\\\r)\\\t', '\t',
            gsub('\\\r', '',
              gsub('\\\\', '',
                gsub('\\\t{2,}', '\t',
                  gsub('\\\n{2,}', '\n',
                    openai_completions$choices$message.content[j]
                  )
                )
              )
            )
          ),
          sep = '\t',
          row.names = NULL,
          col.names = c('group', 'thermometer', 'explanation', 'confidence'),
          colClasses = rep('character', 4)
        )
      )
      if (class(tmp2) == 'try-error') { next }
      tmp <- bind_rows(
        tmp,
        tmp2 %>%
          mutate(
            draw = j,
            thermometer = as.numeric(thermometer),
            temperature = t,
            prompt = get(p)
          )
      )
    }

    toSave <- toSave %>%
      as_tibble() %>%
      bind_rows(
        data.frame(anes_simp[i, 1:n_demog]) %>%
          bind_cols(
            tmp %>% mutate(index = i)
          )
      )

    TPM <- sum(TPM, openai_completions$usage$total_tokens)
    RPM <- sum(RPM, 1)

    if (difftime(Sys.time(), zzz, units = 'mins') < 1) {
      if (RPM > 3000 | TPM > 85000) {
        cat('RPM = ', RPM, '\nTPM = ', TPM, '\n')
        Sys.sleep(max(0, as.numeric(60 - difftime(Sys.time(), zzz, units = 'secs'))))
        RPM <- TPM <- NULL
        zzz <- Sys.time()
        cat('Approaching rate limit\n')
      }
    } else {
      RPM <- TPM <- NULL
      zzz <- Sys.time()
    }
  }

  if (i %% 10 == 0) {
    access_result <- file.access('./data/raw/therm_ANES2024_RR1.csv')
    while (access_result != 0) {
      Sys.sleep(30)
      access_result <- file.access('./data/raw/therm_ANES2024_RR1.csv')
    }
    write.table(toSave, file = './data/raw/therm_ANES2024_RR1.csv',
                append = TRUE, row.names = FALSE, col.names = FALSE, sep = ',')
    toSave <- NULL

    cat(i, 'in', round(difftime(Sys.time(), zz, units = 'mins'), 2), 'minutes\n')
    zz <- Sys.time()
  }
}

# EOF

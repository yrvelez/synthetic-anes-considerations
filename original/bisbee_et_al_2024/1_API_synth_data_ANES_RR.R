################################################################################
##
## Purpose: This script queries OpenAI's API to ChatGPT. It uses the DETAILED
##            prompt, as described in the paper.
##
## Author: James Bisbee (james.h.bisbee@vanderbilt.edu)
##
## Input Files:
##  - ./data/raw/anes_timeseries_cdf_stata_20220916.dta
##
## Output:  
##  - ./data/raw/therm_ANES_RR1.csv
##
##
## This file is not meant to be run as part of the replication, but is included
##    in the replication materials for reference. It was run in the summer of 
##    2023 on NYU's HPC cluster on a Linux based machine.

rm(list = ls())
gc()

# setwd('/scratch/jhb362/LLMs/')

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
          How do you feel toward the following groups?\n",
        'The Democratic Party?\n',
        'The Republican Party?\n',
        'Democrats?\n',
        'Republicans?\n',
        'Black Americans?\n',
        'White Americans?\n',
        'Hispanic Americans?\n',
        'Asian Americans?\n',
        'Muslims?\n',
        'Christians?\n',
        'Immigrants?\n',
        'Gays and Lesbians?\n',
        'Jews?\n',
        'Liberals?\n',
        'Conservatives?\n',
        'Women?\n')
    )
  )
  return(res)
}


# Preparing the ANES data
anes <- haven::read_dta('./data/raw/anes_timeseries_cdf_stata_20220916.dta')

# Therm:
#   Democratic Party: VCF0218
#   Republican Party: VC0224
#   Blacks: VCF0206
#   Whites: VCF0207
#   Hispanics: VCF0217
#   Muslims: VCF9267
#   Christians: VCF9269
#   Jews: VCF0205
#   Liberals: VCF0211
#   Conservatives: VCF0212
# PID: VCF0302
# Race: VCF0105a
# Gender: VCF0104
# Ideology: VCF0824
# Income: VCF0114 (this is a nightmare of assumptions)
# Education: VCF0140 (need to merge the LLM categories to three by collapsing bachelor's with postgrad)

# Prepare data for ANES
anes_simp <- anes %>%
  filter(VCF0004 %in% c(2016,2020)) %>%
  select(respID = VCF0006a,
         year = VCF0004,
         raceth = VCF0105b,
         age = VCF0101,
         gender = VCF0104,
         ideo = VCF0803,
         PID = VCF0302,
         income = VCF0114,
         regis = VCF0703,
         education = VCF0140,
         interest = VCF9259,
         marst = VCF0147,
         `therm_Democratic Party` = VCF0218,
         `therm_Republican Party` = VCF0224,
         `therm_Black Americans` = VCF0206,
         `therm_White Americans` = VCF0207,
         `therm_Asian Americans` = VCF0227,
         `therm_Gays and Lesbians` = VCF0232,
         `therm_Muslims` = VCF9267,
         `therm_Jews` = VCF0205,
         therm_Liberals = VCF0211,
         therm_Conservatives = VCF0212,
         therm_Christians = VCF9269) %>%
  drop_na()


anes_simp <- anes_simp %>%
  mutate_at(vars(matches('therm_')),function(x) ifelse(x > 97 | x < 0,NA,
                                                       ifelse(x == 97,100,x))) %>%
  mutate(PID = ifelse(PID == 1,'Republican',
                      ifelse(PID == 5,'Democrat',
                             ifelse(PID %in% c(2:4),'Independent',NA))),
         raceth = ifelse(raceth == 1,'non-Hispanic white',
                         ifelse(raceth == 2,'non-Hispanic black',
                                ifelse(raceth == 3,'Hispanic',NA))),
         gender = ifelse(gender == 1,'male',
                         ifelse(gender == 2,'female',NA)),
         regis = ifelse(regis %in% 2:3,'registered','unregistered'),
         marst = ifelse(marst == 1,'married',
                        ifelse(marst == 2,'single', #Never married
                               ifelse(marst == 3,'divorced',
                                      ifelse(marst == 4,'separated',
                                             ifelse(marst == 5,'widowed',NA))))),
         interest = ifelse(interest == 1,'always',
                           ifelse(interest == 2,'regularly', # Most of the time
                                  ifelse(interest == 3,'frequently', #About half the time
                                         ifelse(interest == 4,'sometimes', #Some of the time
                                                ifelse(interest == 5,'never',NA))))),
         ideo = ifelse(ideo == 1,'an extremely liberal',
                       ifelse(ideo == 2,'a liberal',
                              ifelse(ideo == 3,'a slightly liberal',
                                     ifelse(ideo == 4,'a moderate',
                                            ifelse(ideo == 5,'a slightly conservative',
                                                   ifelse(ideo == 6,'a conservative',
                                                          ifelse(ideo == 7,'an extremely conservative',NA))))))),
         income = ifelse(income %in% 1,'$30,000',
                         ifelse(income == 2,'$50,000',
                                ifelse(income == 3,'$80,000',
                                       ifelse(income == 4,'$100,000',
                                              ifelse(income == 5,'more than $150,000',NA))))),
         education = ifelse(education %in% 3:4,'a high school diploma',
                            ifelse(education == 5,'some college, but no degree',
                                   ifelse(education == 6,"a bachelor's degree or more",NA)))) %>%
  filter(age != 0,
         interest > 0,
         !ideo %in% c(0,9)) %>%
  drop_na(raceth,age,gender,ideo,PID,income,regis,education,interest,marst)

# Prompt types
full <- "It is [YEAR]. You are a [AGE] year-old, [MARST], [RACETH] [GENDER] with [EDUCATION] making [INCOME] per year, living in the United States. 
You are [IDEO], [REGIS] [PID] who [INTEREST] pays attention to what's going on in government and politics."

demogSimp <- "It is [YEAR]. You are a [AGE] year-old [RACETH] [GENDER], living in the United States."

demogFull <- "It is [YEAR]. You are a [AGE] year-old [MARST] [RACETH] [GENDER] with [EDUCATION] making [INCOME] per year, living in the United States."

pol <- "It is [YEAR]. You are [IDEO], [REGIS] [PID] who [INTEREST] pays attention to what's going on in government and politics, living in the United States."

# Functions for submitting to OpenAI's API
system_prep <- function(frame,lookup) {
  for(col in colnames(lookup)) {
    frame <- gsub(paste0('\\[',toupper(col),'\\]'),lookup[[col]][1],frame)
  }
  return(frame)
}



submit_openai <- function(prompt, temperature = 0.2, n = 1) {
  res <- openai::create_chat_completion(model = "gpt-3.5-turbo",
                                        messages = prompt,
                                        temperature = temperature,
                                        n = n)
  Sys.sleep(1)
  res
}

## This instantiates an empty csv file which we append to. Comment this out
##    once it is created to not overwrite and restart the work.
df <- data.frame(anes_simp[0,1:12],
                 group = as.character(),
                 thermometer = as.numeric(),
                 explanation = as.character(),
                 confidence = as.character(),
                 draw = as.numeric(),
                 temperature = as.numeric(),
                 prompt = as.character(),
                 index = as.numeric(),
                 stringsAsFactors = F)

write.table(df,file = './data/raw/therm_ANES_RR1.csv',append = F,row.names = F,col.names = T,sep = ',')

# To start, open the results .csv file and see how much progress has already been made.
df <- read_csv('./data/raw/therm_ANES_RR1.csv',n_max = Inf)

df <- df %>%
  mutate(index = as.numeric(gsub(',NA','',index)))

# If there is no progress, start from the beginning
if(nrow(df) == 0) {
  start = 1
} else { # Otherwise, take it up from the subsequent index.
  start = max(df$index,na.rm=T) + 1
}

offset <- 0 # For some future work if we have multiple API keys
# offset <- as.numeric(commandArgs(trailingOnly = T))

remain <- setdiff(anes_simp$respID,unique(df$respID))

indices <- which(anes_simp$respID %in% remain)

write_csv(anes_simp,file = './data/raw/anes_simp.csv')

toSave <- NULL
TPM <- RPM <- NULL
zz <- zzz <- Sys.time()
for(i in indices) {
  for(p in c('full','demogFull','pol')) {
    prompts <- create_prompt(systemPrompt = system_prep(frame = get(p),
                                                        lookup = anes_simp[i,1:12]))
    t = 1
    
    system.time(openai_completions <- try(submit_openai(prompt = prompts,temperature = t,n = 30)))
    Sys.sleep(2)
    while(class(openai_completions) == 'try-error') {
      Sys.sleep(60)
      cat('issue on\n',
          'temp =',t,'\n')
      openai_completions <- try(submit_openai(prompt = prompts,temperature = t,n = 30))
      
    }
    
    tmp <- NULL
    for(j in 1:length(openai_completions$choices$message.content)) {
      tmp2 <- try(read.csv(text = gsub('(\\\n|\\\r)\\\t','\t',gsub('\\\r','',gsub('\\\\','',gsub('\\\t{2,}','\t',gsub('\\\n{2,}','\n',openai_completions$choices$message.content[j]))))),
                           sep = '\t',row.names = NULL,
                           col.names = c('group','thermometer','explanation','confidence'),
                           colClasses = rep('character',4)))
      if(class(tmp2) == 'try-error') { next }
      tmp <- bind_rows(tmp,
                       tmp2 %>%
                         mutate(draw = j,
                                thermometer = as.numeric(thermometer),
                                temperature = t,
                                prompt = get(p)))
    }
    tmp %>%
      count(confidence)
    toSave <- toSave %>%
      as_tibble() %>%
      bind_rows(data.frame(anes_simp[i,1:12]) %>%
                  bind_cols(tmp %>%
                              mutate(index = i)))
    
    TPM <- sum(TPM,openai_completions$usage$total_tokens)
    RPM <- sum(RPM,1)
    
    if(difftime(Sys.time(),zzz,units = 'mins') < 1) {
      if(RPM > 3000 | TPM > 85000) {
        cat('RPM = ',RPM,'\nTPM = ',TPM,'\n')
        Sys.sleep(max(0,as.numeric(60 - difftime(Sys.time(),zzz,units = 'secs'))))
        RPM <- TPM <- NULL
        zzz <- Sys.time()
        cat('Approaching rate limit\n')
      }
    } else {
      RPM <- TPM <- NULL
      zzz <- Sys.time()
    }
  }
  
  if(i %% 10 == 0) {
    # This checks if one of the other coauthors' APIs is running and accessing 
    #   the same .csv file of results.
    access_result <- file.access('./data/raw/therm_ANES_RR1.csv')
    while(access_result != 0) {
      # cat('Open according to',API,'\n')
      Sys.sleep(30)
      access_result <- file.access('./data/raw/therm_ANES_RR1.csv')
    }
    write.table(toSave,file = './data/raw/therm_ANES_RR1.csv',append = T,row.names = F,col.names = F,sep = ',')
    toSave <- NULL
    
    cat(i,'in',round(difftime(Sys.time(),zz,units = 'mins'),2),'minutes\n')
    zz <- Sys.time()
  }
}

# EOF
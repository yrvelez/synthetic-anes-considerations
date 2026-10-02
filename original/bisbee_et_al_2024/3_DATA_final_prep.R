################################################################################
##
## Purpose: This script prepares the raw data from the different vintages of the 
##          simple prompts.
##
## Author: James Bisbee (james.h.bisbee@vanderbilt.edu)
##
## Input Files:
##  - ./data/raw/therm_ANES_RR1_replication_firstperson.csv
##  - ./data/raw/therm_ANES.csv
##  - ./data/raw/therm_ANES_RR1_replication.csv
##  - ./data/raw/therm_ANES_RR1_replication_July.csv
##  - ./data/prepped/ANES_LLM_detailed_june_prepped.rds
##  - ./data/raw/anes_timeseries_cdf_stata_20220916.dta
##
## Output Files:
##  - ./data/prepped/ANES_LLM_simple_raw.rds
##  - ./data/prepped/ANES_LLM_simple_prepped.rds
##
##
## See associated log file for compute environment, package versions, 
##  and date of most recent run.
rm(list = ls())
gc()
set.seed(123)
library("groundhog")
groundhog.library(c("assertr","dplyr", "forcats", "ggplot2", "readr", "stringr", 
                    "tidyr","tidyverse","fixest"),
                  "2023-07-01",tolerate.R.version = paste0(R.version$major,'.',R.version$minor))

# Compute details
print(paste0('Compute environment from ',Sys.Date(),' run by Bisbee'))
if(Sys.info()['sysname'] == 'Windows') {
  ram_size = system("wmic MemoryChip get Capacity", intern = TRUE)[-1]
  model_name = system("wmic cpu get name", intern = TRUE)[2] # nocov
  vendor_id = system("wmic cpu get manufacturer", intern = TRUE)[2] # nocov
  
  print(list(ram = stringr::str_squish(ram_size)[1],
             vendor_id = stringr::str_squish(vendor_id),
             model_name = stringr::str_squish(model_name),
             no_of_cores = parallel::detectCores()))
} else if(Sys.info()['sysname'] == 'Linuxs') {
  splitted <- strsplit(system("ps -C rsession -o %cpu,%mem,pid,cmd", intern = TRUE), " ")
  df <- do.call(rbind, lapply(splitted[-1], 
                              function(x) data.frame(
                                cpu = as.numeric(x[2]),
                                mem = as.numeric(x[4]),
                                pid = as.numeric(x[5]),
                                cmd = paste(x[-c(1:5)], collapse = " "))))
  df
} else {
  cat("If not on Linux or Windows, you'll have to figure out your own solution to seeing the compute environment.")
}

sessionInfo()

# Adjust working directory as needed
# setwd('C:/Users/Jimbo/Dropbox/coauthors/LLMs/replication/PA_replication')
# setwd('D:/Dropbox/coauthors/LLMs/replication/PA_replication')
args <- commandArgs(trailingOnly = T)
setwd(as.character(args[1]))


# Starting with First Person Data
dfFP <- read_csv('./data/raw/therm_ANES_RR1_replication_firstperson.csv')

dfFP <-dfFP %>%
  drop_na(group) %>%
  filter(!grepl('^50$|LGBTQ\\+|Please |(g|G)roup|AI language|so I am|```|You can fill in |Republicans30',group)) %>%
  mutate(group = gsub('Immigranats|Immigrsants','Immigrants',gsub('Democatic Party|Democatric Party|Democrat Party|Demographic Party|the Democratic Party','Democratic Party',gsub('the Republican','Republican',gsub('Ways and Lesbians|LGBTQ\\+','Gays and Lesbians',gsub('Amercians','Americans',gsub('Asia |Asians ','Asian ',gsub('\\s{2,}',' ',gsub('&','and',gsub('Republic ','Republican ',gsub('Reps$','Republicans',gsub('lesbians','Lesbians',gsub('Dems$','Democrats',gsub('party','Party',gsub('AsianAmericans|^Asi$','Asian Americans',gsub('\\?|^The | \\(.*\\)','',group))))))))))))))))

dfFP <- dfFP %>%
  filter(!grepl('\\d{2,3}$',group)) %>%
  bind_rows(dfFP %>%
  filter(grepl('\\d{2,3}$',group)) %>%
  rowwise() %>%
  mutate(thermometer = as.numeric(ifelse(is.na(thermometer) & grepl('\\d{2,3}$',group),
                              str_split(group,pattern = '(?=\\d{2,3})')[[1]][2],
                              thermometer)),
         group = ifelse(grepl('\\d{2,3}$',group),
                              gsub('(, |: | |;|\\.|,)+\\d{2,3}','',group),
                              group))) %>%
  ungroup()

  
dfFP <- dfFP %>% 
  mutate(index = as.numeric(gsub(',.*','',index)))

covs <- dfFP %>%
  select(-thermometer,-draw,-group) %>%
  distinct()

# Then to the original data from April
dfOLD <- read_csv('./data/raw/therm_ANES.csv')

dfOLD <- dfOLD %>%
  filter(!is.na(group)) %>%
  bind_rows(dfOLD %>%
  filter(is.na(group)) %>%
  rowwise() %>%
  mutate(group = gsub('"','',str_split(index,',')[[1]][2]),
         thermometer = as.numeric(str_split(index,',')[[1]][3]),
         index = str_split(index,',')[[1]][1]))

dfOLD <- dfOLD %>% 
  drop_na(group) %>%
  mutate(group = gsub('LGBTQ\\+','Gays and Lesbians',gsub('&','and',gsub('Republic ','Republican ',gsub('Reps$','Republicans',gsub('lesbians','Lesbians',gsub('Dems$','Democrats',gsub('party','Party',gsub('AsianAmericans','Asian Americans',gsub('\\?|^The ','',group))))))))))

dfOLD <- dfOLD %>% 
  filter(!grepl('\\d{2,3}$',group)) %>%
  bind_rows(dfOLD %>%
              filter(grepl('\\d{2,3}$',group)) %>%
              rowwise() %>%
              mutate(thermometer = as.numeric(ifelse(is.na(thermometer) & grepl('\\d{2,3}$',group),
                                                     str_split(group,pattern = '(?=\\d{2,3})')[[1]][2],
                                                     thermometer)),
                     group = ifelse(grepl('\\d{2,3}$',group),
                                    gsub('(, |: | |;|\\.|,)+\\d{2,3}','',group),
                                    group))) %>%
  ungroup()

dfOLD <- dfOLD %>% 
  mutate(index = as.numeric(gsub(',.*','',index)))


# June version of the original prompt
dfNEW <- read_csv('./data/raw/therm_ANES_RR1_replication.csv')

dfNEW <- dfNEW %>%
  drop_na(group) %>%
  mutate(group = gsub('LGBTQ','Gays and Lesbians',gsub('&','and',gsub('Republic ','Republican ',gsub('Reps$|Republican$','Republicans',gsub('lesbians','Lesbians',gsub('Dems$','Democrats',gsub('party','Party',gsub('AsianAmericans|Asian Americas','Asian Americans',gsub('\\?|^The |\\+','',group))))))))))

dfNEW <- dfNEW %>% 
  filter(!grepl('\\d{2,3}$',group)) %>%
  bind_rows(dfNEW %>%
              filter(grepl('\\d{2,3}$',group)) %>%
              rowwise() %>%
              mutate(thermometer = as.numeric(ifelse(is.na(thermometer) & grepl('\\d{2,3}$',group),
                                                     str_split(group,pattern = '(?=\\d{2,3})')[[1]][2],
                                                     thermometer)),
                     group = ifelse(grepl('\\d{2,3}$',group),
                                    gsub('(, |: | |;|\\.|,)+\\d{2,3}','',group),
                                    group))) %>%
  ungroup()

dfNEW <- dfNEW %>% 
  mutate(index = as.numeric(gsub(',.*','',index)))

# July version of the original prompt
dfJULY <- read_csv('./data/raw/therm_ANES_RR1_replication_July.csv')

dfJULY <- dfJULY %>%
  drop_na(group) %>%
  filter(group != '65') %>%
  filter(!grepl('```|(g|G)roup|response|I ',group)) %>%
  mutate(group = gsub('lesbians','Lesbians',gsub('HispanicAmericans','Hispanic Americans',gsub('Muslim$','Muslims',gsub('Amerians','Americans',gsub('Republic Party|Republican party','Republican Party',gsub('Democrat Party','Democratic Party',gsub('Christian$','Christians',gsub('\\?| \\(as a group\\)|The ','',gsub('-|<U\\+FF0C>',' ',group))))))))))

dfJULY <- dfJULY %>% 
  filter(!grepl('\\d{2,3}$',group)) %>%
  bind_rows(dfJULY %>%
              filter(grepl('\\d{2,3}$',group)) %>%
              rowwise() %>%
              mutate(thermometer = as.numeric(ifelse(is.na(thermometer) & grepl('\\d{2,3}$',group),
                                                     str_split(group,pattern = '(?=\\d{2,3})')[[1]][2],
                                                     thermometer)),
                     group = ifelse(grepl('\\d{2,3}$',group),
                                    gsub('(, |: | |;|\\.|,)+\\d{2,3}','',group),
                                    group))) %>%
  ungroup()

dfJULY <- dfJULY %>% 
  mutate(index = as.numeric(gsub(',.*','',index)))

# Fixing some weirdness with the draws
dfFP <- dfFP %>%
  group_by(index,group,pid) %>%
  mutate(draw = row_number()) %>%
  ungroup() %>%
  mutate(draw = ifelse(draw > 20,20,draw)) %>%
  group_by(index,group,draw,pid) %>%
  summarise(thermometer = mean(thermometer,na.rm=T),.groups = 'drop')

dfOLD <- dfOLD %>%
  group_by(index,group,pid) %>%
  mutate(draw = row_number()) %>%
  ungroup() %>%
  mutate(draw = ifelse(draw > 20,20,draw)) %>%
  group_by(index,group,draw,pid) %>%
  summarise(thermometer = mean(thermometer,na.rm=T),.groups = 'drop')

dfNEW <- dfNEW %>%
  group_by(index,group,pid) %>%
  mutate(draw = row_number()) %>%
  ungroup() %>%
  mutate(draw = ifelse(draw > 20,20,draw)) %>%
  group_by(index,group,draw,pid) %>%
  summarise(thermometer = mean(thermometer,na.rm=T),.groups = 'drop')

dfJULY <- dfJULY %>%
  group_by(index,group,pid) %>%
  mutate(draw = row_number()) %>%
  ungroup() %>%
  mutate(draw = ifelse(draw > 20,20,draw)) %>%
  group_by(index,group,draw,pid) %>%
  summarise(thermometer = mean(thermometer,na.rm=T),.groups = 'drop')


# Ok good enough for government work I guess. Let's just do it, Nike.
df <- expand.grid(index = 1:1440,
                  draw = 1:20,
                  group = unique(dfFP$group)) %>%
  as_tibble() %>% 
  left_join(dfJULY %>% select(-pid) %>% rename(LLM_JULY_therm = thermometer)) %>%
  left_join(dfFP %>% select(-pid) %>% rename(LLM_FP_therm = thermometer)) %>%
  left_join(dfOLD %>% select(-pid) %>% rename(LLM_OG_therm = thermometer)) %>%
  left_join(dfNEW %>% select(-pid) %>% rename(LLM_REP_therm = thermometer)) %>%
  left_join(covs)

write_rds(df,file = './data/prepped/ANES_LLM_simple_raw.rds')

# Now building the full data, incorporating the rich prompt from July
detailed <- read_rds('./data/prepped/ANES_LLM_detailed_june_prepped.rds')

# ANES data only has three education categories
covs <- covs %>%
  mutate(educ = ifelse(educ %in% c("bachelor's degree","postgraduate degree"),"bachelor's degree or more",educ))

df <- df %>%
  left_join(covs)

# Create two version of the rich data, one with a mean of the 30 synthetic samples
#   and the other with just the first (should be as good as random).
detailed_simp <- detailed %>%
  group_by(respID,group,prompt_simple) %>%
  mutate(LLM_RICH_therm_m = mean(LLM_therm,na.rm = T),.groups = 'drop') %>%
  slice(1) %>%
  ungroup() %>%
  select(respID,group,prompt_simple,LLM_RICH_therm_m,LLM_therm,thermometer_ANES = thermometer) %>%
  pivot_wider(names_from = 'prompt_simple',values_from = c('LLM_RICH_therm_m','LLM_therm')) %>%
  rename(LLM_RICH_demogsonly_therm = LLM_therm_demogs,
         LLM_RICH_demogsonly_therm_m = LLM_RICH_therm_m_demogs,
         LLM_RICH_polonly_therm = LLM_therm_pol,
         LLM_RICH_polonly_therm_m = LLM_RICH_therm_m_pol,
         LLM_RICH_full_therm = LLM_therm_full,
         LLM_RICH_full_therm_m = LLM_RICH_therm_m_full)

# Bring back in the covariates
detailed_simp <- detailed_simp %>%
  left_join(detailed %>%
              select(respID,age,race = raceth,gender,inc = income,educ = education,
                     pid = PID,ideo,regis,interest,marst) %>%
              distinct()) %>%
  mutate(age = as.numeric(labelled::to_character(age)))

print(lapply(detailed_simp,class))

# Standardizing age into same bins as the profiles
detailed_simp <- detailed_simp %>%
  mutate(age = ifelse(age %in% 17:25,20,
                      ifelse(age %in% 26:40,35,
                             ifelse(age %in% 41:59,50,
                                    ifelse(age %in% 60:90,65,NA)))))


# Small tweak to income for merge
df <- df %>%
  mutate(inc = ifelse(grepl('^\\d',inc),paste0('$',inc),inc))

# Small tweak to education for merge
detailed_simp <- detailed_simp %>%
  mutate(educ = gsub('^a ','',educ))

# Okay let's put this all together for once and for all
set.seed(123)
detailed_july <- detailed_simp %>%
  left_join(dfJULY %>% 
              left_join(covs %>% mutate(inc = ifelse(grepl('^\\d',inc),
                                                     paste0('$',inc),
                                                     inc))) %>%
              select(pid,age,race,gender,inc,educ,group,thermometer)) %>%
  drop_na(thermometer) %>%
  group_by(respID,group) %>%
  sample_n(size = 1) %>%
  ungroup() %>%
  rename(LLM_JULY_therm = thermometer)

detailed_july %>%
  count(respID)

detailed_og <- detailed_simp %>%
  left_join(dfOLD %>% 
              left_join(covs %>% mutate(inc = ifelse(grepl('^\\d',inc),
                                                     paste0('$',inc),
                                                     inc))) %>%
              select(pid,age,race,gender,inc,educ,group,thermometer)) %>%
  drop_na(thermometer) %>%
  group_by(respID,group) %>%
  sample_n(size = 1) %>%
  ungroup() %>%
  rename(LLM_OG_therm = thermometer)

detailed_og %>%
  count(respID)

detailed_june <- detailed_simp %>%
  left_join(dfNEW %>% 
              left_join(covs %>% mutate(inc = ifelse(grepl('^\\d',inc),
                                                     paste0('$',inc),
                                                     inc))) %>%
              select(pid,age,race,gender,inc,educ,group,thermometer)) %>%
  drop_na(thermometer) %>%
  group_by(respID,group) %>%
  sample_n(size = 1) %>%
  ungroup() %>%
  rename(LLM_JUNE_therm = thermometer)

detailed_june %>%
  count(respID)

detailed_fp <- detailed_simp %>%
  left_join(dfFP %>% 
              left_join(covs %>% mutate(inc = ifelse(grepl('^\\d',inc),
                                                     paste0('$',inc),
                                                     inc))) %>%
              select(pid,age,race,gender,inc,educ,group,thermometer)) %>%
  drop_na(thermometer) %>%
  group_by(respID,group) %>%
  sample_n(size = 1) %>%
  ungroup() %>%
  rename(LLM_FP_therm = thermometer)

detailed_fp %>%
  count(respID)


final <- detailed_og %>%
  left_join(detailed_july) %>%
  left_join(detailed_fp) %>%
  left_join(detailed_june)

final <- final %>%
  relocate(respID,age,race,gender,inc,educ,pid,ideo,regis,interest,marst,group)

write_rds(final,file = './data/prepped/ANES_LLM_combined.rds')

# EOF
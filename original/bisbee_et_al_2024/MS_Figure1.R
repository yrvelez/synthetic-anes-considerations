################################################################################
##
## Purpose: This script creates Figure 1
##
## Author: James Bisbee (james.h.bisbee@vanderbilt.edu)
##
## Input Files:
##  - ./data/prepped/ANES_LLM_detailed_june_prepped.rds
##
## Output Files:
##  - ./output/figures/figure_1.pdf
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

# Adjust working directory as needed
# setwd('C:/Users/Jimbo/Dropbox/coauthors/LLMs/replication/PA_replication')
# setwd('D:/Dropbox/coauthors/LLMs/replication/PA_replication')
args <- commandArgs(trailingOnly = T)
setwd(as.character(args[1]))

# Load prepared data
toanal <- read_rds('./data/prepped/ANES_LLM_detailed_june_prepped.rds')


pdf('./output/figures/figure_1.pdf',width = 7,height = 5)
toanal %>%
  filter(prompt_simple == 'full') %>%
  select(respID,group,PID,ANES_therm = thermometer,LLM_RICH_full_therm = LLM_therm) %>%
  group_by(respID,group) %>% # Using only first synthetic response per human as per reviewer comment
  slice(1) %>% # Using only first synthetic response per human as per reviewer comment
  ungroup() %>%
  group_by(group) %>%
  summarise(ANES_therm_SD = sd(ANES_therm,na.rm=T),
            ANES_therm_m = mean(ANES_therm,na.rm=T),
            LLM_therm_SD = sd(LLM_RICH_full_therm,na.rm=T),
            LLM_therm_m = mean(LLM_RICH_full_therm,na.rm=T)) %>%
  ungroup() %>%
  gather(measure,value,-group) %>%
  mutate(metric = ifelse(grepl('_SD',measure),'SD','Mean'),
         measure = gsub('_SD|_m$','',measure)) %>%
  spread(metric,value) %>%
  mutate(group = factor(group,levels = rev(c('Jews','White Americans','Black Americans',
                                             'Asian Americans','Christians','Gays and Lesbians',
                                             'Muslims','Conservatives','Liberals',
                                             'Democratic Party','Republican Party')))) %>%
  ggplot(aes(x = Mean,y = group,color = measure,size = measure,shape = measure,alpha = measure)) + 
  geom_point(alpha = 1,size = 2) + 
  geom_errorbarh(aes(xmin = Mean - SD,xmax = Mean + SD),height = 0) + 
  scale_color_manual(values = c('red','black'),labels = c('ANES','ChatGPT 3.5')) + 
  scale_shape_manual(values = c(17,19),labels = c('ANES','ChatGPT 3.5')) +
  scale_size_manual(values = c(3,.5),labels = c('ANES','ChatGPT 3.5')) + 
  scale_alpha_manual(values = c(.3,1),labels = c('ANES','ChatGPT 3.5')) + 
  theme_bw() + 
  labs(x = 'Feeling Thermometer Score',
       y= 'Target Group',
       title = 'LLM and ANES thermometer comparison',
       color = 'Data',
       shape = 'Data',
       size = 'Data',
       alpha = 'Data') + 
  theme(legend.position = 'bottom')
dev.off()

# EOF
#install.packages("EDIutils")
#install.packages("xml2")
#install.packages("here")
library(tidyverse)
library(EDIutils)
library(xml2)
library(lubridate)

#home_directory <- here::here()
home_directory <- getwd()
setwd(home_directory)

### pull in QAQC function directly from EDI -- keep for now, but will need to update the function
#source('https://portal.edirepository.org/nis/dataviewer?packageid=edi.271.7&entityid=1e853e00adc8e1f986a3a4b1586a231f')

## pull in QAQC function from script stored on Github -- use for now, but want to use EDI pull eventually
source('R/edi_qaqc_function.R')

## identify latest date for data on EDI (need to add one (+1) to both dates because we want to exclude all possible start_day data and include all possible data for end_day)
package_ID <- 'edi.499.2'
eml <- read_metadata(package_ID)
date_attribute <- xml_find_all(eml, xpath = ".//temporalCoverage/rangeOfDates/endDate/calendarDate")
last_edi_date <- as.Date(xml_text(date_attribute)) + lubridate::days(1)

day_of_run <- Sys.Date() + lubridate::days(1)

## assign data files 
wq_data <- 'SUNP_buoy_wq.csv'
#manual_data_url <- 'https://raw.githubusercontent.com/CareyLabVT/ManualDownloadsSCCData/master/CR6_Files/FCRcatwalk_manual_2022.csv'
maintenance_url = "https://docs.google.com/spreadsheets/d/1IfVUlxOjG85S55vhmrorzF5FQfpmCN2MROA_ttEEiws/edit?usp=sharing"
outfile <-'SUNP_buoy_wq_L1.csv'

## run QAQC on the data within github
insitu_qaqc(realtime_file = wq_data, maintenance_url = maintenance_url, cleaned_insitu_file = outfile, start_date = last_edi_date,  end_date = day_of_run)

#wq_qaqc <- read_csv('fcre-waterquality_L1.csv')

## convert all flag columns from numeric to factor data type -- this is also done inside of the function. Needs to be called at FLARE run time in the future, unless the flag columns are changed
# wq_qaqc <- wq_qaqc %>%
#   mutate(across(starts_with("Flag"),
#                 ~ as.factor(as.character(.))))

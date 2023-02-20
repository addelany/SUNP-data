insitu_qaqc <- function(realtime_file,
                        maintenance_url,
                        cleaned_insitu_file,
                        start_date = NULL, 
                        end_date = NULL){
  
  # now combine the historical manual + buoy data with the realtime file
  d_head<-read.csv(realtime_file, skip=1, as.is=T) #get header minus wonky Campbell rows
  d <-read.csv(realtime_file, skip=4, header=F) #get data minus wonky Campbell rows
  names(d)<-names(d_head) #combine the names to deal with Campbell logger formatting
  
  #Removes row if the TIMESTAMP column is blank
  d <- d[complete.cases(d$TIMESTAMP),]
  
  #Removes row if the RECORD column has an NA or blank
  d <- d[!(is.na(d$RECORD) | d$RECORD==""), ]
  
  
  # convert to UTC
  #d$TIMESTAMP <- as.POSIXct(d$TIMESTAMP)
  attr(d$TIMESTAMP, "tzone") <- "UTC"
  
  # remove data from before buoy was deployed
  d <- d[d$TIMESTAMP > '2021-06-07 00:00:00',]
  
  
  # remove days where maintenance occurred
  maint_read <- gsheet::gsheet2tbl(maintenance_url)
  maint_read$colnumber <- NA
  maint_read$TIMESTAMP_start <- as.POSIXct(maint_read$TIMESTAMP_start)
  maint_read$TIMESTAMP_end <- as.POSIXct(maint_read$TIMESTAMP_end)
  attr(maint_read$TIMESTAMP_start, "tzone") <- "UTC"
  attr(maint_read$TIMESTAMP_end, "tzone") <- "UTC"
  
  maint <- maint_read
  
  ### identify the date subsetting for the data
  if (!is.null(start_date)){
    d <- d %>% 
      filter(TIMESTAMP >= start_date)
    maint <- maint %>% 
      filter(TIMESTAMP_start >= start_date)
  }
  
  if(!is.null(end_date)){
    d <- d %>% 
      filter(TIMESTAMP <= end_date)
    maint <- maint %>% 
      filter(TIMESTAMP_end <= end_date)
  }
  
  if (nrow(maint) == 0){
    maint <-  maint_read
  }
  
  for(i in 1:nrow(maint)){
    # get start and end time of one maintenance event
    start <- maint$TIMESTAMP_start[i]
    end <- maint$TIMESTAMP_end[i]
    if(is.na(end)){
      end <- as.POSIXct(Sys.time())
      attr(end, "tzone") <- "UTC"
    }
    
    # set colnumbers for maintenance events
    if(maint$instrument[i]=='ALL'){
      maint$colnumber[i] <- 'c(6:38)'
    }
    if(maint$instrument[i]=='EXO'){
      maint$colnumber[i] <- 'c(17:35)'
    }  
    if(maint$instrument[i]=='temp'){
      maint$colnumber[i] <- 'c(6:16)'
    }
    if(maint$instrument[i]=='do'){
      maint$colnumber[i] <- 'c(36:38)'
    }
    
    if(grepl("^\\d+$", maint$colnumber[i])) # single num
    {
      maintenance_cols <- intersect(c(2:38), as.integer(maint$colnumber[i]))
    }
    else if(grepl("^c\\(\\s*\\d+\\s*(;\\s*\\d+\\s*)*\\)$", maint$colnumber[i])) # c(x;y;...)
    {
      maintenance_cols <- intersect(c(2:38), as.integer(unlist(regmatches(maint$colnumber[i],
                                                                          gregexpr("\\d+", maint$colnumber[i])))))
    }
    else if(grepl("^c\\(\\s*\\d+\\s*:\\s*\\d+\\s*\\)$", maint$colnumber[i])) # c(x:y)
    {
      bounds <- as.integer(unlist(regmatches(maint$colnumber[i], gregexpr("\\d+", maint$colnumber[i]))))
      maintenance_cols <- intersect(c(2:38), c(bounds[1]:bounds[2]))
    }
    
    else
    {
      warning(paste("Could not parse column colnumber in row", i, "of the maintenance log. Skipping maintenance for",
                    "that row. The value of colnumber should be in one of three formats: a single number (\"47\"), a",
                    "semicolon-separated list of numbers in c() (\"c(47;48;49)\"), or a range of numbers in c() (\"c(47:74)\").",
                    "Other values (even valid calls to c()) will not be parsed properly."))
      next
    }
    
    # remove EXO_Date and EXO_Time columns from the list of maintenance columns, because they will be deleted later
    maintenance_cols <- setdiff(maintenance_cols, c(17, 18))
    
    if(length(maintenance_cols) == 0)
    {
      warning(paste("Did not parse any valid data columns in row", i, "of the maintenance log. Valid columns have",
                    "indices 2 through 38, excluding 17 and 18, which are EXO Date and time columns and are deleted by this script. 
                    Skipping maintenance for that row."))
      next
    }
    # replace relevant data with NAs and set "all" flag while maintenance was in effect
    d[d$TIMESTAMP >= start & d$TIMESTAMP <= end, maintenance_cols] <- NA
  }
  
  write_csv(d,cleaned_insitu_file)
  return(cleaned_insitu_file)
}
  
  
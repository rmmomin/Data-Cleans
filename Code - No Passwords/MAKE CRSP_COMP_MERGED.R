library(tidyverse)
library(lubridate)
library(RPostgres)
library(data.table)

# Connect to WRDS Server --------------------------------------------------
wrds <- dbConnect(Postgres(),
                  host = 'wrds-pgdata.wharton.upenn.edu',
                  port = 9737,
                  user = '',
                  password = '',
                  dbname = 'wrds',
                  sslmode = 'require')

# download compustat data
comp <- tbl(wrds, sql("SELECT * FROM comp.funda")) %>%
  # filter the bullshit as per usual
  filter(indfmt == 'INDL' & datafmt == 'STD' & popsrc == 'D' & consol == 'C') %>% 
  collect()

# download the link file from wrds
# get the CRSP - Compustat link file
link <- tbl(wrds, sql("SELECT * FROM crsp.ccmxpf_lnkhist")) %>%
  filter(linktype %in% c("LC", "LU", "LS")) %>% 
  collect()

# fix two date errors which generate a very small number of duplicates at the 
# permno-date level
link$linkenddt[which(link$gvkey == "177446" & link$lpermno == 86812)] <- '2019-07-28'
link$linkenddt[which(link$gvkey == "021998" & link$lpermno == 15075)] <- '2018-01-17'

# expand dates from start to end date in linking file
link <- link %>% 
  # if linkeendt is missing set to today
  mutate(linkenddt = if_else(is.na(linkenddt), 
                             lubridate::today(), linkenddt)) %>% 
  # expand date by row
  rowwise() %>% 
  do(tibble(gvkey = .$gvkey, permno = .$lpermno, permco = .$lpermco,
            linkprim = .$linkprim, liid = .$liid,
            datadate = seq.Date(.$linkdt, .$linkenddt, by = "day"))) %>% 
  ungroup() %>% 
  setDT()

# set key in data table to make this go faster
setkey(link, gvkey, datadate)

link <- link %>% 
  .[, count := .N, by = list(gvkey, datadate)] %>% 
  .[count == 1 | linkprim == "P"] %>% 
  .[, count := NULL]

# bring in link variable to compustat
comp <- left_join(comp, link %>% as_tibble(), by = c("gvkey", "datadate"))

# bring in names and ticker
names <- tbl(wrds, sql("SELECT * FROM crsp.dsenames")) %>% 
  collect()

# expand dates from start to end date in linking file
names <- names %>% 
  # expand date by row
  rowwise() %>% 
  do(tibble(permno = .$permno, cusip = .$ncusip, 
            ticker = .$ticker, comnam = .$comnam,
            datadate = seq.Date(.$namedt, .$nameendt, by = "day"))) %>% 
  ungroup() %>% 
  setDT()

setkey(names, permno, datadate)

# merge in info to link file
link <- merge(link, names, by = c("permno", "datadate"), all.x = TRUE) %>% 
  # save it as a tibble
  as_tibble()

# save the two datasets - one a day by gvkey/permno combo file for any stock based method
# and the other the full compustat universe with permno matched.
saveRDS(link, here::here("Cleaned_Data", "gvkey_day_to_permno.rds"))
saveRDS(comp, here::here("Cleaned_Data", "crsp_compustat_merged.rds"))
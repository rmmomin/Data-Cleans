# Data-Cleans
This repo has code to do primary data cleaning for Compustat / Crsp from WRDS.
The included codes do the following data cleaning steps:

1. MAKE CRSP_COMP_MERGED

This code takes the universe of annual compustat financial information and matches to CRSP with the CRSP-specific unique security identifier (permno). In addition, it creates a file that has the associated primary permno for each gvkey/date combination. 

2. MAKE PERMNO_TO_GVKEY

This creates a file that has the associated compustat identifier (gvkey) for each permno/date combination. Because one firm might have multiple issued securities, this file should be longer than the unique gvkey/date combination file from CRSP_COMP_MERGED. In addition, there may be observations where there is a name and ticker associated with a permno, but where there is no compustat identifier (gvkey). These observations are retained, with gvkey being blank. 




* Author: Timothy Dobbins
  Purpose: Create code to identify transfers, including nested transfers
  Date: June, 2012
  Updated June 2014 to create stayseq, and to populate final length of stay to all records within a stay
  Updated June 2016 to reflect name changes in APDC;

DATA testtrans;
   INPUT ppn episode_start_date ddmmyy9. episode_end_date ddmmyy9. mode_of_separation_recode;
   FORMAT episode_start_date episode_end_date ddmmyy10.;
   DATALINES;
1 02012004 04012004 1
1 06012004 20012004 1
1 08012004 08012004 1
1 10012004 12012004 1
1 14012004 15012004 1
1 20012004 20012004 1
1 23012004 25012004 1
2 02012004 02012004 1
2 05012004 06012004 5
2 06012004 07012004 9
2 07012004 18012004 1
2 10012004 11012004 1
2 13012004 13012004 1
3 31102004 13112004 5
3 04112004 04112004 1
3 07112004 07112004 5
3 13112004 14112004 1
;

PROC SORT DATA=testtrans;
   BY ppn episode_start_date episode_end_date;
RUN;


DATA testtrans_seq;
   SET testtrans;
   BY ppn;

   RETAIN morbseq stayseq;

   * Generate FILESEQ and MORBSEQ;
   fileseq=_n_;
   IF first.ppn THEN morbseq=0;
   morbseq=morbseq+1;

   * Identify nested transfers and populate the start date, end date and final mode_of_separation_recode of nested transfers;
   RETAIN nest_start nest_end nest_mode nested;
   IF morbseq=1 THEN DO;
      nest_start=episode_start_date;
      nest_end=episode_end_date;
      nest_mode=mode_of_separation_recode;
      nested=0;
      stayseq=0;
   END;
   IF morbseq>1 AND (episode_start_date <= nest_end & episode_end_date <= nest_end) THEN nested=nested+1;
   ELSE DO;
      nest_start=episode_start_date;
      nest_end=episode_end_date;
      nest_mode=mode_of_separation_recode;
      nested=0;
   END;

   * Create lag variables;
   lagsep = LAG(nest_end);
   lagmode = LAG(nest_mode);
   IF morbseq=1 THEN DO;
      lagsep=.; lagmode=.;
   END;

   * Identify transfers as those with multiple records
        (i.e. morbseq>1)
     AND admission date before previous separation date
        (i.e. overlapping transfer)
     OR admission date before the initial record's separation date
        (i.e. nested transfer)
     OR transferred to another hospital (mode_of_separation_recode=5) AND
        episode_start_date=previous episode_end_date (i.e. serial transfer)
     OR type-change separation (mode_of_separation_recode=9) AND
        episode_start_date = previous episode_end_date (i.e. type-change);

   IF morbseq>1 AND (episode_start_date < lagsep)
      OR (lagmode IN (5,9) and (episode_start_date = lagsep))
   THEN transseq+1;
   ELSE DO;
      transseq=0;
      stayseq=stayseq+1;
   END;

   DROP nest_start nest_end lagsep lagmode nest_mode;
RUN;

PROC FREQ DATA=testtrans_seq;
   TABLE transseq;
RUN;

* Populate sepdate_fin to all records within a stay using PROC SQL;
PROC SQL;
   CREATE TABLE los AS
   SELECT *,
      MAX(episode_end_date) AS sepdate_fin FORMAT=DDMMYY8.,
      MAX(1, CALCULATED sepdate_fin - episode_start_date) AS totlos,
      MAX(1, episode_end_date - episode_start_date) AS losd
   FROM testtrans_seq
   GROUP BY ppn, stayseq
   ORDER BY ppn, episode_start_date, episode_end_date;
QUIT;

* Examine data;
PROC PRINT DATA=los NOOBS;
   BY ppn;
RUN;


%macro profile(ds,
			   report=1,    /*PDF report? 1=yes, 0 = no*/
         outname =,   /*name of output report - default is <dataset>_profile.pdf*/
			   outds = ,    /*destination for output dataset (optional) */
			   limobs=100000,     /*limits the observations randomly pulled from dataset*/
         totlim=100000,
			   order=1,	     /*Order by variable order 1=yes, 0=no (order by variable name) */
			   numlevel=5,     /*The maximum number of distinct values to show*/
			   dictionary=0,    /*Export as a data dictionary csv file 1=yes, 0 = no*/
			   format=1,          /*Show the variable format in the output table 1=yes: landscape report, 0 = no: portrait*/
			   label=0 ,            /*Show the variable label in the output table 1=yes, 0 = no*/
         debug=0 ,     /*1 to print intermediate steps to list, 0 to not print*/
         sample_select= ,  /*Default is blank: use middle value for the sample. 
                            Can add a where phrase like mrn = 'AABBCCDDEE' to choose a record*/
        dropvar =    /*use this to drop variables you don't want to profile, like known problematic variables */
               );
 ***********************************************************************;
 *MACRO:    profile.sas                                                *;
 *LOCATION: //ghcmaster/ghri/Warehouse/sas/sasautos                    *;
 *AUTHOR:   J Stofel                                                   *;
 *DATE:     20 July 2016                                               *;
 *INPUT:    Any SAS dataset                                            *;
 *OUTPUT:   Summary report listing variables and variable definitions  *;
 *          and summary counts for values                              *;
 *          Optional profile SAS dataset and csv dataset output        *;  
 ***********************************************************************;
 * 01NoV2016 : J Stofel. Updating to have rows not drop out of the proc*;
 *          report when all values missing (was being dropped by group  *;
 *          by and order by, solution is to make them not missing, using *
 *          formats, and making missing counts be zero counts)          *;
 *START*                                                               *;
 ***********************************************************************;

  %if (%length(&limobs) = 0 ) %then %do;
    %PUT LIMOBS MUST BE SET TO A POSITIVE INTEGER;
    %let limobs = 1000;
  %end;

 ** Create formats to control how missing values are displayed;
  *    Make the no format option very wide so it does not cut off real format names;
   proc format;
     value NoDot
         . = ' ';
     value NoPrint
         1 = ' '
         0 = ' ';
      value $NoFormat
            'no format' = '                                           '; 

      value $MissValue
             '.' = '(missing)'
             '' = '(missing)'
             ' ' = '(blank)'
        ;
      value MissValue
            . = '(missing)';

   run;
 

*Process input vars;
  *Separate the library from the dsname 
     %let inlib = work; %let dotloc = %sysfunc(index(&ds,.));
       %if (&dotloc > 0 ) %then %do;
       %let inlib = %substr(&ds,1, &dotloc - 1 );
       %let ds = %substr(&ds, &dotloc + 1);
     %end;
     %PUT INLIB is &inlib and ds is &ds;
     %let libpath = %sysfunc(pathname(&inlib));
    
 **Set the name for the pdf report;
  %let supplied_name = &outname;
  %if (%length(&outname) = 0 ) %then %do;
    %let outname = &libpath./&ds._profile.pdf;
  %end;



*Set system options;
  *Get user option set for orientation. This report is wide and must be landscape, but we want to 
    return to the original orientation before exiting, so save that information to use on exit ;
      %let orig_orientation = %sysfunc(getoption(ORIENTATION));
      %let orig_fmterr = %sysfunc(getoption(nofmterr));

  *Set options for this report;
  options mlogic mprint linesize = max pagesize=max orientation = landscape
   noquotelenmax nofmterr
  ;


  *Create a macro to check if a variable exists in a dataset**;
   %macro varchk(varname, dsname);
     %global exists;
     %let dsid = %sysfunc(open(&dsname));
     %if (&dsid) %then %let exists = %sysfunc(varnum(&dsid, &varname));
     %else %let exists = 0;
     %let rc = %sysfunc(close(&dsid)); 
   %mend varchk;

*Count the number of records ;
%let totobs = 0;
proc sql noprint;
    select count(*) into :totobs from &inlib..&ds;
quit;
%let totobs = %eval(&totobs * 1) ;
%let limset = ;
%if (&totobs > &totlim)  %then %do;
  %let limset = obs = &totlim;
%end;

%if %eval(&totobs = 0) %then %do;
ods pdf file = "&outname" ;
  data _null_;
     file print;
     put "There are no records in &ds" ;
   run;
ods pdf close;
 %return;
%end;

*Load into work directory: use a dummy name. If source has long name, intermediate datasets may exceed 32 characters.;
%if (%length(&dropvar) > 0 ) %then %do;
   data _dummy; set &inlib..&ds (&limset drop = &dropvar); run;
%end;
%else %do;
   data _dummy; set &inlib..&ds (&limset); run;
%end;
*Store original name;
%let dsname = &ds;
*Set ds variable to dummy;
%let ds = _dummy;


*Rename "disallowed" variables;
 %varchk(name, &ds);
 %if (&exists) %then %do;
   data &ds; set &ds (rename = (name = _name)); run;
 %end;

*Get dataset definition (contents: list of variables and variable definitions);
  %let srcds = &ds;
  proc contents noprint data = &srcds out=&ds.c (keep = varnum name type length format rename = (name = varname)); run;
  *Reorder variables.... ;
  data &ds.c; retain varnum varname type length format; set &ds.c; run;

%if (&debug) %then %do;
  title "ALL EXPECTED VARS";
  proc print data = &ds.c; run;
%end;

*Get Information about the Variables;
 %let nvlist = ; %let fvlist = ; %let flist = ; %let cvlist = ;
 proc sql noprint; 
  select count(*) format = BEST32. into :num_&ds from &srcds; 
  select count(*) format = BEST32. into :num_var_&ds from &ds.c;
  select varname into :vlist separated by ' ' from &ds.c;
  select varname into :cvlist separated by ' ' from &ds.c where type = 2;
  select varname into :nvlist separated by ' ' from &ds.c where type = 1 and missing(format);
  select varname into :fvlist separated by ' ' from &ds.c where type = 1 and ^missing(format);
  select format||'.' into :flist separated by ' ' from &ds.c where type = 1 and ^missing(format); 
 quit;


*Count the number of records in the dataset;
%let num_&ds = %eval(&&num_&ds + 0);
*Count the number of variables in the dataset;
%let num_var_&ds = %eval(&&num_var_&ds + 0);

*Obtain the middle observation number, and make a formatted record number;
data _null_;
  middle_obs = floor(&&num_&ds/2);
  numrec = &&num_&ds;
  totobs = &totobs;
  show_nobs = trim(left(put(numrec, COMMA15.0)));
  show_totobs = trim(left(put(totobs, COMMA15.0)));
  limobs = &limobs;
  show_limobs = trim(left(put(limobs, COMMA15.0)));
  call symputx('middle_obs', middle_obs);
  call symputx('show_nobs', show_nobs);
  call symputx('show_totobs', show_totobs);
   call symputx('show_limobs', show_limobs);
run;
%PUT there are &&num_&ds records and &&num_var_&ds variables in &ds. The middle obs is &middle_obs ;


 **Get a sample record;

 *Retrieve a sample record, and convert all variables to text representations;

  %let sample_middle = &middle_obs; 
 
  %if (%length(&sample_select) > 0 ) %then %do;  
     data &ds._sample;
         set &srcds (where = (&sample_select));
     run;
     proc sql noprint;
        select round(count(*)/2) into :sample_middle from &ds._sample;
        select count(*) into :sample_obs from &ds._sample;
     quit;
     %let sample_middle = %eval(&sample_middle * 1);
     %let sample_obs = %eval(&sample_obs * 1) ;
  %end;
  %else %do;
     data &ds._sample; set &srcds; run;
  %end;

 %let where = firstobs=&sample_middle obs=&sample_middle;


  data &ds._sample (keep = varname parameter &vlist);
    varname = 'varname'; parameter = 'sample';
    set &ds._sample (&where
            rename = ( 
             %do mip = 1 %to %sysfunc(countw(&vlist)) ;
                  %scan(&vlist, &mip) = s%scan(&vlist,&mip)
             %end;
                      )
                    );
  *Convert formatted numeric variables to character variables by applying the variable-specific format;
  * If the value is missing, use the format for missing;
  %if (%length(&fvlist) > 0) %then %do;
   %do miq = 1 %to %sysfunc(countw(&fvlist)) ;
      if (missing(s%scan(&fvlist, &miq))) then do;
            %scan(&fvlist, &miq) = trim(left(put(s%scan(&fvlist, &miq), MissValue.)));
      end;
      else do;
          %scan(&fvlist, &miq) = trim(left(put(s%scan(&fvlist, &miq), %scan(&flist, &miq). )));
      end;
   %end;
  %end;
  *Convert unformatted numeric varables to character variables by applying the generic BEST. format;
  %if (%length(&nvlist) > 0 ) %then %do;
   %do mir = 1 %to %sysfunc(countw(&nvlist)) ;
       if (missing(s%scan(&nvlist, &mir))) then do;
            %scan(&nvlist, &mir) = trim(left(put(s%scan(&nvlist, &mir), MissValue.)));
       end;
       else do;
          %scan(&nvlist, &mir) = trim(left(put(s%scan(&nvlist, &mir), BEST.)));
       end;
    %end;
  %end;

  *Rename character variables back from s<variable name> to variable name;
    *Applying missing value format to add a label if character variable is missing;

    %if (%length(&cvlist) > 0 ) %then %do;
       %do mis = 1 %to %sysfunc(countw(&cvlist)) ;
          %scan(&cvlist, &mis) = trim(left(put(s%scan(&cvlist, &mis), $MissValue.)));
       %end;
    %end;

  run;

%if (&debug) %then %do;
title7 "Sample";
 proc print data = &ds._sample; run;
%end; 

 *Transpose the results so they can be merged with the dataset definition information;
  proc transpose data = &ds._sample name = varname out = &ds._sample_t; id parameter; var _all_; run;
  proc sort data = &ds._sample_t; by varname; run;
  proc sort data = &ds.c ; by varname; run;

%if (&debug) %then %do;
  title7 "Transposed Sample";
  proc print data = &ds._sample_t; run;
  title7;
%end;

*Merge to contents table;
 data &ds.d;
    merge &ds.c (in = c) 
          &ds._sample_t
          ;
    by varname; if c;
 run;
 


%if (&debug) %then %do;
 title7 "FIRST MERGE - SHOULD HAVE ALL";
 proc print data = &ds.d; run;
  title7;
%end;

 *add diagnostics;

  %let srcds = &ds.src;
 %if  (%eval(&&num_&ds < &limobs)) %then %do;
   *Use the whole dataset;
    %let denom = &&num_&ds;
    data &srcds;
     set &ds;
    run;
 %end;
 %else %do;
   *Get a random sample of &limobs records;
   %let denom = &limobs;

    proc sql nowarn OUTOBS=&limobs ;
    create table &srcds as  
       select d.* from &ds d
       order by RANUNI(2782);
    quit;
 
%end;


   *Check for problematic variable names (All and Name) and rename them in working dataset;

      %let renamestr = ;
      %varchk(All, &srcds)
      %if (&exists) %then %do;
        %let renamestr = &renamestr All = tmpAll;
      %end;
      %varchk(Name, &srcds)
      %if (&exists) %then %do;
        %let renamestr = &renamestr Name = tmpName;
      %end;
      %if (%length(&renamestr) > 0) %then %do;
        data &srcds;
         set &srcds (rename = (&renamestr));
        run;
      %end;

 *Get variable-level information : number of unique values, number missing values; 
  proc sql noprint;
  *Count the number of unique values;
   create table &ds._unique as 
     select 'varname' as varname, 'unique' as parameter 
     %do mit = 1 %to %sysfunc(countw(&vlist));
       %let mvname = %scan(&vlist,&mit);
          , max(0, count(distinct &mvname))  as &mvname
      %end;
     from &srcds ; 

  *Count the number of missing values;
   create table &ds._missing as 
     select 'varname' as varname length = 32 , 'nmiss' as parameter 
     %do miu = 1 %to %sysfunc(countw(&vlist)); 
      %let mvname = %scan(&vlist,&miu);
          , nmiss(&mvname) as &mvname
     %end;
     from &srcds ; 
 quit;

*Transpose the results so they can be merged with the dataset definition information;
  proc transpose data = &ds._missing name = varname out = &ds._missing_t; id parameter; run;
  proc transpose data = &ds._unique name = varname out = &ds._unique_t; id parameter; run;
*Set the varname length to standard 32, to help with merges;
  data &ds._missing_t (drop = tvarname); set &ds._missing_t (rename = (varname = tvarname)); length varname $32; varname = trim(left(tvarname)); run;
  data &ds._unique_t  (drop = tvarname); set &ds._unique_t  (rename = (varname = tvarname)); length varname $32; varname = trim(left(tvarname)); run;
    

*6* GET VALUE-LEVEL SUMMARIES;
 *Get the values and counts -- calculate separately for variables that are "factored" ( <= numlevel values) from 
   variables that are not (lots of values);

 
 *Find the variables of interest;
   proc sort data = &ds._unique_t; by varname; run;
   proc sort data = &ds.c; by varname; run;

   data &ds._factor_n &ds._factor_c &ds._stat_n &ds._stat_c;
    merge &ds._unique_t (in = u)
          &ds.c (in = c keep = varname type);
    by varname; 
    if u and c;
    if type = 1 then do;
        if unique <= &numlevel then output &ds._factor_n;
        else output &ds._stat_n;
    end;
    else if type = 2 then do;
        if unique <= &numlevel then output &ds._factor_c;
        else output &ds._stat_c;
    end;

   run;

%if (&debug) %then %do;
  title7 "Factor N";
  proc print data = &ds._factor_n; run;
  title7 "Factor C";
  proc print data = &ds._factor_c; run;
  title7 "STAT N";
  proc print data = &ds._stat_n; run;
  title7 "STAT C";
  proc print data = &ds._stat_c; run;
%end;    

  *Get the lists of variables by type (factor, numeric, or character);
   *initialize lists; %let vfnlist = ; %let vfclist = ; %let vnlist = ; %let vclist = ;
   proc sql noprint; 
     select varname into :vfnlist separated by ' ' from &ds._factor_n; 
     select varname into :vfclist separated by ' ' from &ds._factor_c; 
     select varname into :vnlist separated by ' ' from &ds._stat_n; 
     select varname into :vclist separated by ' ' from &ds._stat_c; 
   run;

 *Start with a Clean Slate, since you will be appending records;
   proc datasets nolist lib = work; delete &ds._fnfreq &ds._fcfreq &ds._nfreq &ds._cfreq; run;
 *Initialize set list;
  %let setlist = ;

  *Process Numeric and Character Factor type separately, because you want to format the Numeric to Strings, 
     but not process the Characters;
  *Numeric Factor Variables: Get the frequency of each value, and append to overall dataset of value freqs;  
   %if (%length(&vfnlist) > 0 ) %then %do;
    %do i = 1 %to %sysfunc(countw(&vfnlist)) ;
    proc freq noprint data = &srcds; 
      table %scan(&vfnlist, &i) / out=%scan(&vfnlist, &i)_freq missing norow nocol nopercent ; run;
    data %scan(&vfnlist, &i)_freq (keep = varname var_value COUNT PERCENT rename = (count = record_count percent = record_percent));
      length varname $32; varname = "%scan(&vfnlist, &i)";
      set %scan(&vfnlist, &i)_freq (rename = (%scan(&vfnlist, &i) = Value));
      length var_value $300; var_value = trim(left(put(Value, best.)));
    run;
    proc append base = &ds._fnfreq data = %scan(&vfnlist, &i)_freq ; run;
    %end;
    *Add a variable that orders the values from smallest to largest (var_value_level)
    and identifies what kind of information this is (var_value_type = "Value List");
    proc sort data = &ds._fnfreq; by varname var_value; run;
    data &ds._fnfreq; 
     set &ds._fnfreq; 
      by varname var_value; 
      retain var_value_level;
      if first.varname then var_value_level = 1; else var_value_level = var_value_level + 1; 
      length var_value_type $32; var_value_type = "List" ;
    run;
    %let setlist = &setlist &ds._fnfreq;
  %end; *end of if there is a vflist;

 *Character Factor Variables: Get the frequency of each value, and append to overall dataset of value freqs;  
   %if (%length(&vfclist) > 0 ) %then %do;
    %do i = 1 %to %sysfunc(countw(&vfclist)) ;
    proc freq noprint data = &srcds; 
      table %scan(&vfclist, &i) / out=%scan(&vfclist, &i)_freq missing norow nocol nopercent ; run;
    data %scan(&vfclist, &i)_freq (keep = varname var_value COUNT PERCENT rename = (count = record_count percent = record_percent));
      length varname $32; varname = "%scan(&vfclist, &i)";
      set %scan(&vfclist, &i)_freq (rename = (%scan(&vfclist, &i) = Value));
      length var_value $300; var_value = trim(left(Value));
    run;
    proc append base = &ds._fcfreq data = %scan(&vfclist, &i)_freq ; run;
    %end;
    *Add a variable that orders the values from smallest to largest (var_value_level)
    and identifies what kind of information this is (var_value_type = "Value List");
    proc sort data = &ds._fcfreq; by varname var_value; run;
    data &ds._fcfreq; 
     set &ds._fcfreq; 
      by varname var_value; 
      retain var_value_level;
      if first.varname then var_value_level = 1; else var_value_level = var_value_level + 1; 
      length var_value_type $32; var_value_type = "List" ;
    run;
    %let setlist = &setlist &ds._fcfreq;
  %end; *end of if there is a vflist;



  *Numeric Variables: Get Min and Max;
   %if (%length(&vnlist) > 0 ) %then %do;
    %do i = 1 %to %sysfunc(countw(&vnlist)) ;
    proc sql noprint;
       %let mvname = %scan(&vnlist, &i);
           %let fmt = BEST.;
           select trim(left(format))||'.' into :fmt from &ds.c where varname = "&mvname" and format IS NOT NULL;
           %let fmt = %sysfunc(strip(&fmt));

           %PUT NAME IS &mvname and format is &fmt;
           *Note: this selection method returns the numeric value of the variable;        
           select min(&mvname) format BEST32. into :minvalue from &srcds ;
           select max(&mvname) format BEST32. into :maxvalue from &srcds ; 

          /*NOTE:  WE WANT TO MAKE A FORMATTED AS WELL AS UNFORMATTED TEXT STRING OUT OF NUMBERS*/

           create table max as select 
             "&mvname" as varname length=32, 
             'Max' as var_value_type length = 32, 
             trim(left(put(&maxvalue, BEST.))) as var_value length = 300, 
             %if (%length(&fmt) > 2) %then %do;
               case when ( trim(left(put(&maxvalue, &fmt))) ^= trim(left(put(&maxvalue, BEST.))) )
                then trim(left(put(&maxvalue, &fmt))) else trim(left(put(&maxvalue, BEST.))) end 
                 as var_value_fmt length = 300,
             %end;
             %else %do;
                trim(left(put(&maxvalue, BEST.))) as var_value_fmt length = 300,
             %end;
             count(*) as record_count 
             from &srcds where  &mvname  = &maxvalue;

           create table min as select 
             "&mvname" as varname length=32, 
             'Min' as var_value_type length = 32, 
             trim(left(put(&minvalue, BEST.))) as var_value length = 300, 
             %if (%length(&fmt) > 2) %then %do;
              case when ( trim(left(put(&minvalue, &fmt))) ^= trim(left(put(&minvalue, BEST.))) )
               then trim(left(put(&minvalue, &fmt))) else trim(left(put(&minvalue, BEST.)))  end 
                 as var_value_fmt length = 300,
             %end;
             %else %do;
               trim(left(put(&minvalue, BEST.))) as var_value_fmt length = 300,
             %end;
             count(*) as record_count 
             from &srcds where  &mvname  = &minvalue;
     quit;
     proc append base = &ds._nfreq data = min; run;
     proc append base = &ds._nfreq data = max; run;
    %end; *end of do loop through list;
    %let setlist = &setlist &ds._nfreq;
   %end; *end of if the list exists;
 
   *Character Variables: Get Min and Max - tricky with all the wierd characters possible;
    
   %if (%length(&vclist) > 0 ) %then %do;
    %do i = 1 %to %sysfunc(countw(&vclist)) ;
    proc sql nowarn noprint;
       %let mvname = %scan(&vclist, &i);
       %Put Looking for min and max of &mvname; 
        select min(trim(left(&mvname))) into :minvalue from &srcds ;
        select max(trim(left(&mvname))) into :maxvalue from &srcds ; 

/**
        %Put MIN:  %nrquote("&minvalue") MAX: %nrquote("&maxvalue"); 

         %if (%length(&minvalue) > 0 ) %then %do; 
            %let minvalue = %sysfunc(trim(%sysfunc(left(%nrquote(&minvalue)))));
         %end;
     %if (%length(&maxvalue) > 0 ) %then %do;
        %let maxvalue = %sysfunc(trim(%sysfunc(left(%nrquote(&maxvalue)))));
     %end;

        %Put MIN:  %nrquote("&minvalue") MAX: %nrquote("&maxvalue"); 
**/
   
        create table max as select 
          "&mvname" as varname length=32, 
          'Max' as var_value_type length = 32, 
           trim(left(%nrquote("&maxvalue"))) as var_value length=300,
          /*"&maxvalue" as var_value_fmt length = 300,*/
           count(*) as record_count 
           from &srcds where /*trim(left(&mvname))*/ &mvname = %nrquote("&maxvalue");


        create table min as select 
           "&mvname" as varname length=32, 
           'Min' as var_value_type length = 32, 
            trim(left(%nrquote("&minvalue"))) as var_value length=300,
          /* "&minvalue" as var_value_fmt length=300,*/
            count(*) as record_count 
            from &srcds where /*trim(left(&mvname))*/ &mvname = %nrquote("&minvalue"); 
     quit;

     proc append base = &ds._cfreq data = min; run;
     proc append base = &ds._cfreq data = max; run;
    %end; *end of loop through list;
    %let setlist = &setlist &ds._cfreq;
   %end; *end of if the list exists;

   *Combine results from factor, character and numeric variables;
   data &ds._value;
      set &setlist;
   run;


*7* COMBINE ALL DESCRIPTIVE SUMMARIES;

 proc sort data = &ds._unique_t; by varname; run;
 proc sort data = &ds._missing_t; by varname; run;

 proc sort data = &ds._value; by varname; run;

%if (&debug) %then %do;
  title7 "PRE SECOND MERGE";
  proc print data = &ds.d; var varnum varname type length ; run;
  title7;
%end;

 data &ds.d;
    merge &ds.d (in = d) 
          &ds._unique_t 
          &ds._missing_t 
          &ds._value
          ;
    by varname; if d;
       if missing(unique) then unique = 0;
       if missing(nmiss) then nmiss = 0;
    pct_miss = round( (100 * nmiss/&denom), 0.001);
    pct_uniq = round( (100 * unique/(&denom - nmiss)), 0.001);
    if missing(pct_uniq) then pct_uniq = 0;
    if missing(pct_miss) then pct_miss = 0;

    if ^(missing(record_count)) then 
       record_percent = round( (100 * record_count/(&denom - nmiss)), 0.001);
    else record_percent = 0;
 run;

%if (&debug) %then %do;
title7 "SECOND MERGE";
proc print data = &ds.d; var varnum varname type length ; run;
  title7;
%end;

  data &ds.d;
  set &ds.d;   
   *Add a variable that combines length and variable type into one field for display;
     if type = 1 then do;
        show_type = trim(left(put(length, best.)))||".";
     end;
     else do;
        show_type = "$"||trim(left(put(length, best.)));
     end;
   
   *Add a value to the Format field in cases where it is missing;
    if (missing(format)) then format = "no format";
   run;
  
 *Add flag on the even-numbered variables to use for zebra striping;
   proc sort data = &ds.d; by varnum ; run;
   data &ds.d;
     set &ds.d;

     *Flag the even numbered rows;
     if mod(varnum,2) = 0 then even = 1; else even = 0; 
    run;



 **Define the ods template;
  ods path(prepend) work.templat(update);
  proc template;
  define style Styles.myrtf;
  parent= styles.rtf;
  replace fonts /
      'TitleFont2' = ("Arial",9.5 pt,Bold Italic)   /* Procedure titles ("The _____ Procedure")*/
      'TitleFont' = ("Arial",8pt,Bold /*Italic*/ )   /* Titles from TITLE statements */
      'StrongFont' = ("Arial",8pt,Bold)             /* Strong (more emphasized) table headings and
                                                                        footers, page numbers */
      'EmphasisFont' = ("Arial",8pt)                /* Titles for table of contents and table of
                                                                            pages, emphasized table headings and footers */
      'FixedEmphasisFont' = ("Arial",8pt)
      'FixedStrongFont' = ("Arial",8pt,Bold)
      'FixedHeadingFont' = ("Courier",8pt,Bold)
      'BatchFixedFont' = ("SAS Monospace, Courier",6.7pt)
      'FixedFont' = ("Courier",8pt)
      'headingEmphasisFont' = ("Arial",9pt,Bold)
      'headingFont' = ("Arial",9pt)                        /* Table column and row headings */
      'docFont' = ("Arial",8pt)                            /* Data in table cells */
      'footFont'= ("Arial", 7.5pt);                    /* Footnotes from FOOTNOTE statements */
   replace Body from Document /
        leftmargin=1.0in
        rightmargin=1.0in
        topmargin=0.75in
        bottommargin=0.5in;
   replace Table from Output /
      frame=below              /* outside borders: void, box, above/below, vsides/hsides, lhs/rhs */
      rules = groups            /* internal borders: none, all, cols, rows, groups */
      cellpadding = 0pt      /* was: 0.75pt the space between table cell contents and the cell border */
      cellspacing = 0pt       /* the space between table cells, allows background to show THIS IS ACTUALLY VERTICAL LINEWIDTH SPEC*/
      borderwidth = 0.75pt;     /* the width of the borders and rules */
   replace color_list/
      'link' = blue             /* links */
      'bgH' = white             /* row and column header background */
      'fg'=black                /* text color */
      'bg'=white;               /* page background color */;
      style SystemFooter from SystemFooter /
       font = fonts("footFont");
   end;
  run;



 *8* OUTPUT THE ONE-PROC-AWAY DATASET;

proc sort data = &ds.d; by varnum descending var_value_type descending var_value_type; run;

%if (&debug) %then %do;
title7 "Before Proc Report";
proc print data = &ds.d; run;
%end;


 %if (%length(&outds) > 0 ) %then %do;
    data &outds;
    	set &ds.d;
    run;
 %end;

*9* CREATE THE FORMATTED REPORT;


*9c* Check for variables, to help choose what can be displayed;
  %varchk(var_value_fmt);
  %let has_fmt_value = &exists;

*10*CREATE THE REPORT;
  
  %let label_width = 1in; 
  %if (&format) %then %do;
   options orientation=landscape;
  %let label_width = 1.5in; 
  %end;



ods listing close;
%if (%length(&supplied_name) = 0) %then %do;
  %PUT You did not supply a name or location for the report.  ;
  %PUT You can control the name and location by setting the outname parameter;
%end;

ods pdf file = "&outname" style=myrtf;

%let title3 = ;

   %if  (%eval(&&num_&ds > &limobs)) %then %do;
    %let title3 = &title3 SHOWING DATA STATS LIMITED TO &limobs. RANDOMLY SELECTED OBSERVATIONS OUT OF THE FULL SET OF &&num_&ds OBSERVATIONS. ;
   %end;

   %if  (%eval(&totobs > &totlim)) %then %do;
    %let title3 = &title3 SHOWING DATA LIMITED TO FIRST &totlim. OBSERVATIONS OUT OF THE FULL SET OF &totobs OBSERVATIONS. ;
   %end;

   %if (%length(&renamestr) > 0) %then %do;
%let title3 = &title3 Variables using reserved SQL words were renamed for processing: &renamestr. ;
   %end;



 title1 "Data Profile for &inlib..&dsname., showing variables and a representative (sample) value for each variable."; 
   %let title2 = There are &&num_var_&ds variables and &show_totobs records.;
   %if %eval(&&num_&ds < &totobs) %then %do;
     %let title2 = &title2 DATA CUT TO FIRST &show_nobs RECORDS. Use options in PROFILE macro to control data shown.;
   %end;
    %if %eval(&&num_&ds > &limobs) %then %do;
    %let title2 = &title2 STATISTICS PERTAIN TO &show_limobs. RANDOMLY SELECTED OBSERVATIONS.;
   %end;
   title2 "&title2";
   title3 "For variables with &numlevel or fewer unique values, all values are shown as a list, with the corresponding record counts.";
   title4 "For variables with > &numlevel unique values, the maximum and minimum values are shown with their corresponding record counts.";

  %let title5 = ;
   %if (%length(&renamestr) > 0) %then %do;
      %let title5 = Variables using reserved SQL words were renamed for processing: &renamestr. ;
   %end;

   %if (%length(&title5) > 0) %then %do;
     title5 "&title5";
   %end;


   proc report data = &ds.d nowindows spanrows;
 
 columns varnum varname 
 %if (&label) %then %do;
 label 
 %end;
   type 
   length
 %if (&format) %then %do;
   format 
 %end;
 %if  (%eval(&&num_&ds <= &limobs)) %then %do;
 unique nmiss 
 %end;
 pct_uniq 
 pct_miss  


 sample


  var_value_type 
  var_value

 %if ( (&format) & (&has_fmt_value) ) %then %do;
  var_value_fmt
 %end;
  record_count
  even ;

  DEFINE varnum     / ORDER center width=8  'Num'                style(column)={cellwidth=0.3in};	             
  DEFINE varname     / GROUP  left width=35  'Name'                style(column)={cellwidth=1.15in};	 

 %if (&label) %then %do;
  DEFINE label     / GROUP left width=35 FLOW                 style(column)={cellwidth=&label_width};	    
 %end;
  DEFINE type    / GROUP center width=8  'Type'       style(column)={cellwidth=0.5in};	 
  DEFINE length    / GROUP center width=8  'Length'       style(column)={cellwidth=0.5in};	 
             
  %if (&format) %then %do;
       DEFINE format     /  GROUP  'Variable Format' center width=10    style(column)={cellwidth=0.5in};
  %end;

 %if  (%eval(&&num_&ds <= &limobs)) %then %do;
  DEFINE unique     / GROUP 'Num Unique Values' center width=10    style(column)={cellwidth=0.5in};
  DEFINE nmiss     /  GROUP  'Num Missing Values' center width=10    style(column)={cellwidth=0.5in};
  %end;


  DEFINE pct_miss     /  GROUP  'Percent Missing Values' center width=10    style(column)={cellwidth=0.5in};
  DEFINE pct_uniq     / GROUP 'Percent Unique Values' center width=10    style(column)={cellwidth=0.5in};
 
  %if %eval(&sample_middle = &middle_obs) %then %do;
     DEFINE sample     /  GROUP "Values by Variable For Sample Record (Record &middle_obs)" format = $MissValue.  center width=250 FLOW  style(column)={cellwidth=1.0in};
  %end;
  %else %do;
   DEFINE sample     /  GROUP "Values by Variable For %upcase(&sample_select) (Record &sample_middle of &sample_obs) " format = $MissValue.  center width=250 FLOW  style(column)={cellwidth=1.0in};
  %end;

  DEFINE var_value_type / GROUP 'Type of Value Shown' center width=250 FLOW     style(column)={cellwidth=0.75in};

  DEFINE var_value     /  DISPLAY 'Variable Value'    center width=250 FLOW     style(column)={cellwidth=0.75in};
  
  

%if ((&format) & (&has_fmt_value)) %then %do;
  DEFINE var_value_fmt / DISPLAY 'Formatted Value' left width=250 FLOW     style(column)={cellwidth=0.65in};
%end;


  DEFINE record_count     / DISPLAY 'Number Records with this Value' right  style(column)={cellwidth=0.5in};
  

  DEFINE even / DISPLAY ' '  format = NoPrint. style(column)={cellwidth=0.01in};

   compute even;
      if even=0 then call define(_ROW_, 'style', 'style={background=grayaa}');
      else call define(_ROW_, 'style', 'style={background=white}');
   endcomp;


 run; title1; 

ods pdf close;
ods listing;

*11* CLEANUP;

*Return to original options;
   options orientation=&orig_orientation &orig_fmterr;


*Export a dictionary if requested;
   %if (&dictionary) %then %do;
   %let vlist = VARNUM NAME	TYPE LENGTH	LABEL FORMAT SAMPLE;
   proc sort nodupkey data = &ds.d out = &ds.d (keep = &vlist) ; by &vlist; run;
       proc export
    	    data = &ds.d
       	    file = "&dsname._dictionary.csv"
	    dbms = csv
	    REPLACE;
       run;
   %end;

 *Cleanup;

 
 
 proc datasets nolist lib = work;
    delete delete _dummy &ds.d  &ds.c &ds._unique &ds._unique_t &ds._missing &ds._missing_t &ds._sample &ds._sample_t ;
  run;


%mend profile;

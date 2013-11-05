/*********************************************
* Roy Pardee
* Group Health Research Institute
* (206) 287-2078
* pardee.r@ghc.org
*
* \\ghrisas\warehouse\management\Programs\utilities\transition.sas
*
* Proposed macro for doing final updates to GHRI DW production jobs.
*********************************************/

%macro transition(dset            =     /* One-part name of the dset we are transitioning (e.g., encounters). */
                , lib             =     /* Name of the lib where the dsets to be transitioned live.  There should be a &lib..&dset and a &lib..&dset._next versions */
                , backdir         =     /* Folder spec for where archives of current-prod dsets go. */
                , count_tolerance = 99  /* New dset must have at least this percent of the n(recs) as the old in order to proceed. */
                , ignore_vardiffs = 0   /* Set to 1 to override the abort-if-any-vars-are-missing check. */
                , leave_last      = 1   /* Set to 0 to have the macro remove the _last version of the replaced dset. USE WITH CAUTION! */
                ) ;

  %** Do we have a new candidate file? ;
  %if %sysfunc(exist(&lib..&dset._next)) = 0 %then %do ;
    %do i = 1 %to 10 ;
      %put ERROR: Not finding the replacement dset &lib..&dset._next--nothing to do here! ;
    %end ;
    %return ;
  %end ;

  %** Is there a dset we are replacing? ;
  %if %sysfunc(exist(&lib..&dset)) %then %do ;
    %** Blunt quality check--does the new file have at least &count_tolerance % of the records in the old file? ;
    proc contents noprint data = &lib..&dset._next  out = newfile(keep = nobs name) ;
    run ;
    proc contents noprint data = &lib..&dset        out = oldfile(keep = nobs name) ;
    run ;

    proc sql noprint ;
      select distinct round((n.nobs / o.nobs) * 100, 1) as percent_covered
              into :percent_covered
      from  newfile as n CROSS JOIN
            oldfile as o
      ;

      select count(*) as n_missing_vars
              into :n_missing_vars
      from  oldfile as o LEFT JOIN
            newfile as n
      on    o.name = n.name
      where n.name IS NULL
      ;

      drop table newfile ;
      drop table oldfile ;
    quit ;

    %if (&ignore_vardiffs = 0 and &n_missing_vars > 0) %then %do ;
      %do i = 1 %to 10 ;
        %put ERROR: WOULD-BE REPLACEMENT DSET &lib..&dset._next IS MISSING &n_missing_vars VARIABLES RELATIVE TO &lib..&dset.  ABORTING THE TRANSITION. ;
      %end ;
      %return ;
    %end ;

    %if &percent_covered < &count_tolerance %then %do ;
      %do i = 1 %to 10 ;
        %put ERROR: WOULD-BE REPLACEMENT DATASET &lib..&dset._next CONTAINS ONLY &percent_covered PERCENT OF THE RECORDS THAT ARE IN &lib..&dset..  ABORTING THE TRANSITION. ;
      %end ;
      %return ;
    %end ;

    %* If we get this far, we are good. ;
    %** Ditch the last _last, if it exists. ;
    %removedset(dset = &lib..&dset._last) ;

    %if %sysfunc(fileexist(&backdir)) %then %do ;
      %WriteComp(&sysdate._previous_prod_&dset._backup.zip , &lib, &dset, includeindex=1, output_dir = &backdir) ;
    %end ;
    %else %do ;
      %do i = 1 %to 10 ;
        %put WARNING: BACKUP DIRECTORY SPEC GIVEN DOES NOT EXIST--NOT BACKING UP CURRENT PRODUCTION DSET. ;
      %end ;
    %end ;

    proc datasets nolist library = &lib ;
      change &dset = &dset._last ;
      change &dset._next = &dset ;
    quit ;

    %if &leave_last = 0 %then %do ;
      %removedset(dset = &lib..&dset._last) ;
    %end ;

  %end ;
  %else %do ;
    %* No original dset--just do the rename. ;
    proc datasets nolist library = &lib ;
      change &dset._next = &dset ;
    quit ;
  %end ;
%mend transition ;

/*********************************************
* Roy Pardee
* Group Health Research Institute
* (206) 287-2078
* pardee.r@ghc.org
*
* C:\Documents and Settings/pardre1/Desktop/transition.sas
*
* Proposed macro for doing final updates to GHRI DW production jobs.
*********************************************/

%macro transition(dset, stagelib, prodlib, backdir, count_tolerance = 99) ;

  %** Blunt quality check--does the new file have at least &count_tolerance % of the records in the old file? ;
  proc contents noprint data = &stagelib..&dset out = newfile ;
  run ;
  proc contents noprint data = &prodlib..&dset out = oldfile ;
  run ;

  proc sql noprint ;
    select distinct round((n.nobs / o.nobs) * 100, 1) as percent_covered
            into :percent_covered
    from  newfile as n CROSS JOIN
          oldfile as o
    ;
    drop table newfile ;
    drop table oldfile ;
  quit ;

  %if &percent_covered >= &count_tolerance %then %do ;
    %** If there is a leftover copy of the 'next' version, ditch it ;
    %removedset(dset = &prodlib..&dset._next) ;

    %** Rename the staged next copy to _next and then copy it to prod. ;
    proc datasets nolist library = &stagelib ;
      change &dset = &dset._next ;
      copy out = &prodlib clone index = yes constraint = yes move ;
      select &dset._next ;
    quit ;

    %** Ditch the last _last, if it exists. ;
    %removedset(dset = &prodlib..&dset._last) ;

    %** Rename current prod to _last. ;
    %if %sysfunc(exist(&prodlib..&dset)) %then %do ;
      %WriteComp(&sysdate._previous_prod_&dset._backup.zip , &prodlib, &dset, includeindex=1, output_dir = &backdir);
      proc datasets nolist library = &prodlib ;
        change &dset = &dset._last ;
      quit ;
    %end ;

    proc datasets nolist library = &prodlib ;
      change &dset._next = &dset ;
    quit ;
  %end ;
  %else %do i = 1 %to 10 ;
    %put ERROR: WOULD-BE REPLACEMENT DATASET &stagelib..&dset CONTAINS ONLY &percent_covered PERCENT OF THE RECORDS THAT ARE IN &prodlib..&dset..  ABORTING THE TRANSITION. ;
  %end

%mend transition ;
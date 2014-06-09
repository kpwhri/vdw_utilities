/*********************************************
* Roy Pardee
* Group Health Research Institute
* (206) 287-2078
* pardee.r@ghc.org
*
* //ghrisas/warehouse/management/Programs/utilities/tests/test_transition.sas
*
* purpose
*********************************************/

%include "\\home\pardre1\SAS\Scripts\remoteactivate.sas" ;

options
  linesize  = 150
  msglevel  = i
  formchar  = '|-++++++++++=|-/|<>*'
  dsoptions = note2err
  nocenter
  noovp
  nosqlremerge
;

* %include "\\ghrisas\warehouse\management\Programs\utilities\transition.sas" ;
%include "\\mlt1q0\C$\Users\pardre1\documents\vdw\utilities\transition.sas" ;


%let dir = //ghrisas/SASUser/pardre1/utilities ;
libname t "&dir" ;

%macro clear_out ;
  proc datasets nolist lib = t kill memtype = data;
  run;
  quit;
%mend clear_out ;

%macro fail_no_next ;
  %clear_out ;
  %transition(dset          = cmd   /* One-part name of the dset we are transitioning (e.g., encounters). */
          , lib             = t     /* Name of the lib where the dsets to be transitioned live.  There should be a &lib..&dset and a &lib..&dset._next versions */
          , backdir         = &dir  /* Folder spec for where archives of current-prod dsets go. */
          ) ;
%mend fail_no_next ;

%macro fail_toofew_recs(args) ;
  %clear_out ;
  data t.cmd ;
    set sashelp.class ;
  run ;
  data t.cmd_next ;
    set sashelp.class ;
    where sex = 'F' ;
  run ;

  %transition(dset          = cmd   /* One-part name of the dset we are transitioning (e.g., encounters). */
          , lib             = t     /* Name of the lib where the dsets to be transitioned live.  There should be a &lib..&dset and a &lib..&dset._next versions */
          , backdir         = &dir  /* Folder spec for where archives of current-prod dsets go. */
          , count_tolerance = 99    /* New dset must have at least this percent of the n(recs) as the old in order to proceed. */
          ) ;
%mend fail_toofew_recs ;

%macro fail_missing_vars(args) ;
  %clear_out ;
  data t.cmd ;
    set sashelp.class ;
  run ;
  data t.cmd_next ;
    set sashelp.class (drop = Height) ;
  run ;

  %transition(dset          = cmd   /* One-part name of the dset we are transitioning (e.g., encounters). */
          , lib             = t     /* Name of the lib where the dsets to be transitioned live.  There should be a &lib..&dset and a &lib..&dset._next versions */
          , backdir         = &dir  /* Folder spec for where archives of current-prod dsets go. */
          , ignore_vardiffs = 0     /* Set to 1 to override the abort-if-any-vars-are-missing check. */
          ) ;
%mend fail_missing_vars ;

%macro succeed_missing_vars(args) ;
  %clear_out ;
  data t.cmd ;
    set sashelp.class ;
  run ;
  data t.cmd_next ;
    set sashelp.class (drop = Height) ;
  run ;

  %transition(dset          = cmd   /* One-part name of the dset we are transitioning (e.g., encounters). */
          , lib             = t     /* Name of the lib where the dsets to be transitioned live.  There should be a &lib..&dset and a &lib..&dset._next versions */
          , backdir         = &dir  /* Folder spec for where archives of current-prod dsets go. */
          , ignore_vardiffs = 1     /* Set to 1 to override the abort-if-any-vars-are-missing check. */
          ) ;

%mend succeed_missing_vars ;

%macro succeed_no_current(args) ;
  %clear_out ;
  data t.cmd_next ;
    set sashelp.class ;
  run ;
  %transition(dset          = cmd   /* One-part name of the dset we are transitioning (e.g., encounters). */
          , lib             = t     /* Name of the lib where the dsets to be transitioned live.  There should be a &lib..&dset and a &lib..&dset._next versions */
          , backdir         = &dir  /* Folder spec for where archives of current-prod dsets go. */
          ) ;
%mend succeed_no_current ;

%macro succeed_leave_last(args) ;
  %clear_out ;
  data t.cmd ;
    set sashelp.class ;
  run ;
  data t.cmd_next ;
    set sashelp.class ;
  run ;

  %transition(dset          = cmd   /* One-part name of the dset we are transitioning (e.g., encounters). */
          , lib             = t     /* Name of the lib where the dsets to be transitioned live.  There should be a &lib..&dset and a &lib..&dset._next versions */
          , backdir         = &dir  /* Folder spec for where archives of current-prod dsets go. */
          /* , leave_last = 0 */
          ) ;

  %if %sysfunc(exist(t.cmd_last)) = 0 %then %do i = 1 %to 10 ;
    %put ERROR: The _last dataset should be here and isnt!!!! ;
  %end ;

%mend succeed_leave_last ;

%macro succeed_remove_last(args) ;
  %clear_out ;
  data t.cmd ;
    set sashelp.class ;
  run ;
  data t.cmd_next ;
    set sashelp.class ;
  run ;

  %transition(dset          = cmd   /* One-part name of the dset we are transitioning (e.g., encounters). */
          , lib             = t     /* Name of the lib where the dsets to be transitioned live.  There should be a &lib..&dset and a &lib..&dset._next versions */
          , backdir         = &dir  /* Folder spec for where archives of current-prod dsets go. */
          , leave_last      = 0
          ) ;

  %if %sysfunc(exist(t.cmd_last)) %then %do i = 1 %to 10 ;
    %put ERROR: The _last dataset should be removed but wasnt!!!! ;
  %end ;

%mend succeed_remove_last ;

%macro succeed_leftover_last(args) ;
  %clear_out ;
  data t.cmd_last t.cmd t.cmd_next ;
    set sashelp.class ;
  run ;

  %transition(dset          = cmd   /* One-part name of the dset we are transitioning (e.g., encounters). */
          , lib             = t     /* Name of the lib where the dsets to be transitioned live.  There should be a &lib..&dset and a &lib..&dset._next versions */
          , backdir         = &dir  /* Folder spec for where archives of current-prod dsets go. */
          ) ;
%mend succeed_leftover_last ;


%macro test_lock1 ;
  * Sets up a prod dataset for me to open in an interactive instance of SAS.  Then we run one of the success macros ;
  data t.cmd ;
    set sashelp.class ;
    where sex = 'F' ;
  run ;
  data t.cmd_next ;
    set sashelp.class ;
  run ;

%mend test_lock1 ;

%macro test_lock2 ;
  %transition(dset        = cmd   /* One-part name of the dset we are transitioning (e.g., encounters). */
        , lib             = t     /* Name of the lib where the dsets to be transitioned live.  There should be a &lib..&dset and a &lib..&dset._next versions */
        , backdir         = &dir  /* Folder spec for where archives of current-prod dsets go. */
        /* , leave_last = 0 */
        ) ;

  %if %sysfunc(exist(t.cmd_last)) = 0 %then %do i = 1 %to 10 ;
    %put ERROR: The _last dataset should be here and isnt!!!! ;
  %end ;

%mend test_lock2 ;


options mprint mlogic ;


* %fail_no_next ;
* %fail_toofew_recs ;
* %fail_missing_vars ;
* %succeed_missing_vars ;
* %succeed_no_current ;
* %succeed_remove_last ;
%succeed_leave_last ;
%succeed_leftover_last ;
* %test_lock1 ;
* %test_lock2 ;


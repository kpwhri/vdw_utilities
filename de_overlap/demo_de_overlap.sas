/*********************************************
* Roy Pardee
* Group Health Research Institute
* (206) 287-2078
* pardee.r@ghc.org
*
* C:\Users/pardre1/Documents/vdw/Enrollment/supporting_files/demo_de_overlap.sas
*
* Demonstrates cleaning/knitting disparate dsets together with
* the %de_overlap macro.
*********************************************/
options
  linesize  = 150
  pagesize  = 80
  msglevel  = i
  formchar  = '|-++++++++++=|-/|<>*'
  dsoptions = note2err
  nocenter
  noovp
  nosqlremerge
  extendobscounter = no
;

%include "c:\users\pardre1\desktop\mid_year_2017\de_overlap.sas" ;

%macro dummy_out_other_vars ;
  incomplete_emr       = 'N' ;
  incomplete_inpt_enc  = 'N' ;
  incomplete_lab       = 'N' ;
  incomplete_outpt_enc = 'N' ;
  incomplete_outpt_rx  = 'N' ;
  incomplete_tumor     = 'N' ;
  ins_aca              = 'N' ;
  ins_commercial       = 'N' ;
  ins_basichealth      = 'N' ;
  ins_highdeductible   = 'N' ;
  ins_medicaid         = 'N' ;
  ins_medicare         = 'N' ;
  ins_medicare_a       = 'N' ;
  ins_medicare_b       = 'N' ;
  ins_medicare_c       = 'N' ;
  ins_medicare_d       = 'N' ;
  ins_other            = 'N' ;
  ins_privatepay       = 'N' ;
  ins_selffunded       = 'N' ;
  ins_statesubsidized  = 'N' ;
  pcc                  = 'downtown' ;
  pcp                  = 'dr. bob' ;
  plan_hmo             = 'N' ;
  plan_indemnity       = 'N' ;
  plan_pos             = 'N' ;
  plan_ppo             = 'N' ;
%mend dummy_out_other_vars ;

ods listing close ;

ods html path = "c:\users\pardre1\desktop\mid_year_2017\" (URL=NONE)
         body = "demo_de_overlap.html"
          ;

/* Scenario 1: a single file w/overlaps (and collapsibles!) */
data insureds ;
  input
    @1   mrn            $char5.
    @7   enr_start      date11.
    @21  enr_end        date11.
    @35  drugcov        $char1.
  ;
  format enr_: mmddyy10. ;
  enrollment_basis = 'I' ;
  %dummy_out_other_vars ;
datalines ;
roy   01-nov-2006   28-feb-2007   Y  <-- overlaps w/below
roy   01-jan-2007   30-dec-2009   N  <-- overlaps w/below
roy   01-jul-2009   30-jun-2011   N
roy   01-jul-2014   30-jun-2015   Y
roy   01-jul-2013   30-aug-2015   N  <-- completely encompasses above
roy   01-oct-2011   31-may-2012   Y
roy   01-jun-2012   30-nov-2012   Y  <-- collapsible w/above
;
run ;

proc sort data = insureds ;
  by mrn enr_start ;
run ;

%de_overlap(inset = insureds, outset = insureds_improved) ;

title1 "SCENARIO 1 - SINGLE FILE: BEFORE" ;
proc print data = insureds ;
  var mrn enr_: drugcov ;
run ;

title1 "SCENARIO 1 - SINGLE FILE: AFTER" ;
proc print data = insureds_improved ;
  var mrn enr_: drugcov ;
run ;

/* Scenario 2: Two disparate files, w/some people in common, and overlaps across files. */
data patients ;
  input
    @1   mrn            $char5.
    @7   enr_start      date11.
    @21  enr_end        date11.
    @35  drugcov        $char1.
  ;
  format enr_: mmddyy10. ;
  enrollment_basis = 'P' ;
  %dummy_out_other_vars ;
datalines ;
roy   01-aug-2012   28-feb-2015   U   <-- overlaps last period in insureds
bill  01-jul-2009   30-jun-2011   U
bill  01-oct-2011   31-may-2012   U
bill  01-jun-2012   30-nov-2012   U   <-- collapsible w/above
;
run ;

data mishmash ;
  set
    insureds
    patients
  ;
run ;

%de_overlap(inset = mishmash, outset = deoverlapped_mishmash) ;

title1 "SCENARIO 2 - TWO FILES WITH OVERLAPS: BEFORE" ;
proc print data = mishmash ;
  var mrn enr_: drugcov ;
run ;

title1 "SCENARIO 2 - TWO FILES WITH OVERLAPS: AFTER" ;
proc print data = deoverlapped_mishmash ;
  var mrn enr_: drugcov ;
run ;

/* Scenario 3: Tons of dupes, each w/overlaps. */
data crazytown ;
  set
    mishmash
    mishmash
    mishmash
    mishmash
    insureds
    patients
    patients
    patients
    mishmash
    mishmash
    mishmash
  ;
run ;

%de_overlap(inset = crazytown, outset = normaltown) ;

title1 "SCENARIO 3 - CRAZYTOWN - > NORMALTOWN: AFTER" ;
proc print data = normaltown ;
  var mrn enr_: drugcov ;
run ;

/* Scenario 4: Site-specific variable. */
/* Var is cascade_side--a E/W/U indicating that the person gets care at a location West of the Cascades */

data insureds2 ;
  set insureds ;
  if drugcov = 'Y' then cascade_side = 'W' ;
  else cascade_side = 'E' ;
run ;

* endsas ;

%include "c:\users\pardre1\desktop\mid_year_2017\de_overlap_with_ew.sas" ;

%de_overlap(inset = insureds2, outset = insureds2_improved) ;

title1 "SCENARIO 4 - NEW VAR: BEFORE" ;
proc print data = insureds2 ;
  var mrn enr_: drugcov cascade_side ;
run ;

title1 "SCENARIO 4 - NEW VAR: AFTER" ;
proc print data = insureds2_improved ;
  var mrn enr_: drugcov cascade_side ;
run ;

ods _all_ close ;


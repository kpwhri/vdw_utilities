/********************************************
* Roy Pardee
* Group Health Research Institute
* (206) 287-2078
* pardee.r@ghc.org
*
* C:\Users/pardre1/Downloads/get_enroll_demog_descriptives.sas
*
* Creates dset/plots of enrollment retention for a cohort of people enrolled
* on a user-specified date.
*
* TODO: Add the ability to supply a cohort dst w/a per-person
* index_date we can use to count months-to-disenrollment.
*********************************************/

%include "h:/SAS/Scripts/remoteactivate.sas" ;

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

* ==================== begin edit section ============================ ;
* Where do you want datasets/output? ;
libname out "\\home\pardre1\workingdata\enrollment_retention" ;

%include "&GHRIDW_ROOT/Sasdata/CRN_VDW/lib/StdVars.sas" ;
* ===================== end edit section ============================= ;

%include vdw_macs ;

proc format ;
   value age1f
      low -< 10 = '0: Younger than 10'
      10 -< 20 =  '1: Between 10 and 20'
      20 -< 30 =  '2: 20s'
      30 -< 40 =  '3: 30s'
      40 -< 50 =  '4: 40s'
      50 -< 60 =  '5: 50s'
      60 -< 70 =  '6: 60s'
      70 -< 80 =  '7: 70s'
      80 -< 90 =  '8: 80s'
      90 - high = '9: 90 or older'
   ;
   value age2f
      low -< 25 = '0: <=24'
      25 -< 45  = '1: 25-44'
      45 -< 65  = '2: 45-64'
      65 -< 75  = '3: 65-74'
      75 - high = '4: >=75'
   ;
   value $gen
      'M' = 'Men'
      'F' = 'Women'
   ;
quit ;

%macro get_retention(RefDate = 01Jun2010, OutSet = out.&_SiteAbbr._enrollment_retention) ;

   proc sql ;
      * Create a cohort of ppl enrolled on &refdate ;
      create table _cohort as
      select distinct e.mrn
            , put(%CalcAge(RefDate = "&RefDate"d, bdtvar = birth_date), age2f.) as age_cat label = "Age on &RefDate"
            , d.gender
      from &_vdw_enroll as e INNER JOIN
           &_vdw_demographic as d
      on    e.mrn = d.mrn
      where "&RefDate"d between enr_start and enr_end AND
            birth_date is not null AND
            d.gender in ('M', 'F')
      ;

      %let total_n = &SQLOBS ;

      * Grab out all their enrollment periods. ;
      create table _cohort_enroll as
      select c.mrn, enr_start, enr_end
      from &_vdw_enroll as e INNER JOIN
            _cohort as c
      on    e.mrn = c.mrn
      order by c.mrn, enr_start
      ;
   quit ;

   * Reduce to contiguous periods. ;
   %CollapsePeriods(lib      = work
                  , dset     = _cohort_enroll
                  , recstart = enr_start
                  , recend   = enr_end
                  , daystol  = 90
                  ) ;

   proc sql ;
      * Just keep the periods that embrace &refdate. ;
      create table out._relevant_enroll as
      select e.mrn
            , enr_end label = "End of continuous enrollment period embracing &RefDate"
            , c.gender
            , c.age_cat
      from _cohort_enroll as e INNER JOIN
           _cohort as c
      on  e.mrn = c.mrn
      where "&RefDate"d between enr_start and enr_end
      order by gender, age_cat
      ;

      * This should give us back the same # of recs as above ;

      %put &total_n should be the same as &SQLOBS ;
      %put &total_n should be the same as &SQLOBS ;
      %put &total_n should be the same as &SQLOBS ;
      %put &total_n should be the same as &SQLOBS ;
      %put &total_n should be the same as &SQLOBS ;

   quit ;

   proc freq noprint data = out._relevant_enroll noprint ;
      tables enr_end / out = enrollment_ends outcum ;
      by gender age_cat ;
   run ;

   proc sort data = enrollment_ends ;
      by enr_end ;
   run ;

   data &outset ;
      set enrollment_ends ;
      proportion_enrolled = (100 - cum_pct)/100 ;
      site = "&_SiteAbbr (N = &total_n)" ;
      label
         proportion_enrolled = "Proportion still enrolled (of original N = &total_n)"
      ;
   run ;

%mend get_retention ;

options mprint ;

%get_retention(RefDate = 01Jun2010, OutSet = out.&_SiteAbbr._enrollment_retention) ;

options orientation = landscape ;
ods graphics / height = 8in width = 10in ;

%let out_folder = %sysfunc(pathname(out)) ;

ods html path = "&out_folder" (URL=NONE)
          body   = "get_enroll_demog_descriptives.html"
          (title = "get_enroll_demog_descriptives output")
         style = magnify
         nogfootnote
               ;

   * %create_plots(InRetention = out.&_SiteAbbr._enrollment_retention) ;
   proc sgpanel data = out.&_SiteAbbr._enrollment_retention ;
      panelby gender age_cat / layout = lattice novarname rows = 5 ;
      loess x = enr_end y = proportion_enrolled ;
      rowaxis grid ;
      colaxis grid ;
      where cum_pct < 98 ;
      format gender $gen. proportion_enrolled percent10. ;
   run ;

   proc sgpanel data = out.&_SiteAbbr._enrollment_retention ;
      panelby gender / novarname ;
      series x = enr_end y = proportion_enrolled / group = age_cat lineattrs = (pattern = solid) markers ;
      rowaxis grid ;
      colaxis grid ;
      where cum_pct < 98 ;
      format gender $gen. proportion_enrolled percent10. ;
   run ;

   proc sgpanel data = out.&_SiteAbbr._enrollment_retention ;
      panelby age_cat / novarname rows = 5 ;
      loess x = enr_end y = proportion_enrolled / group = gender lineattrs = (pattern = solid) ;
      rowaxis grid ;
      colaxis grid ;
      where cum_pct < 98 ;
      format gender $gen. proportion_enrolled percent10. ;
   run ;


run ;

ods _all_ close ;




/*********************************************
* Roy Pardee
* Group Health Research Institute
* (206) 287-2078
* pardee.r@ghc.org
*
* Takes an input dataset of VDW-enrollment data (which may have overlapping
* periods) and resolves/merges any overlaps into a single set of records
* without overlaps.
*
* Note that this does not take account of any site-specific-enhancement
* variables you may have on your file.  If you have any such vars, you will
* need to:
*
*     - (probably) add formats to translate those vars values into-and-back-
*       out-of numeric values so the max() calls in the select starting on
*       line 151 will properly encode the values in those vars.
*
*     - (definitely) add input(max()) lines to that select starting on line 151
*       so those vars make it into the output dataset.
*
*     - (definitely) add those var names to the BY statement starting on line
*       208.
*
* This code comes mostly from: Mike Rhoads SUGI 29 paper: Starts and Stops:
* Processing Episode Data With Beginning and Ending Dates
*
* http://www2.sas.com/proceedings/sugi29/260-29.pdf
*
*********************************************/

%macro de_overlap(inset = unholy_union, outset = molina_merged) ;

  * Formats ranking the values of enrollment vars from most-favored (information-preserving) ;
  * to least, and back again. ;
  * For any off-spec character vars you want to add, unless their values  ;
  proc format ;
    * Enrollment basis ;
    value $eb
      "P" = "0" /* non-member patient */
      "G" = "1" /* geographic monopoly */
      "I" = "2" /* insurance */
      "B" = "3" /* both geog & insurance */
    ;
    value $d_eb
      "0" = "P" /* non-member patient */
      "1" = "G" /* geographic monopoly */
      "2" = "I" /* insurance */
      "3" = "B" /* both geog & insurance */
    ;
    * Insurance, plan type, drugcov flags ;
    value $yenu
      'U' = '0'
      'N' = '1'
      'E' = '2'
      'Y' = '3'
    ;
    * Insurance, plan type, drugcov flags ;
    value $d_yenu
      '0' = 'U'
      '1' = 'N'
      '2' = 'E'
      '3' = 'Y'
    ;
    * incomplete_ vars ;
    value $incm
      'X' = '0'
      'K' = '1'
      'N' = '2'
    ;
    * incomplete_ vars ;
    value $d_incm
      '0' = 'X'
      '1' = 'K'
      '2' = 'N'
    ;
  quit ;

  options varlenchk = nowarn ;
  * Step 1: dset of all possible period start dates. ;
  data startstops ;
    length enr_start enr_end 4 ;
    set &inset (keep = mrn enr_start enr_end) ;
  run ;

  proc sort nodupkey data = startstops ;
    by mrn enr_start enr_end ;
  run ;

  proc sql ;
    create table status_change_dates as
    select mrn, enr_start as status_change_date format = mmddyy10.
    from startstops
    union
    select mrn, enr_end + 1 as status_change_date format = mmddyy10.
    from startstops
    order by mrn, status_change_date
    ;
    drop table startstops ;
  quit ;

  ** Step 2: Use the set of all possible change dates to make a dset ;
  ** of all contiguous time periods for each person. ;
  ** Note that this includes periods for gaps between coverages--those are necessary ;
  ** for the period-collapsing step below. ;
  options mergenoby = nowarn ;
  data timeline_dates ;
    merge status_change_dates(rename = (status_change_date = period_start))
          status_change_dates(rename = (status_change_date = next_period_start MRN = next_mrn) firstobs = 2)
          ;
    if mrn = next_mrn then period_end = next_period_start -1 ;
    format period_start period_end mmddyy10. ;
    keep MRN period_start period_end ;
  run ;

  options mergenoby = error ;

  /*

  Step 3: Relate each time segment to the actual coverage
  periods.  Because there may well be > 1 coverage period
  embracing the same time segment, we have to use aggregate
  functions to bring the complete set of coverages onto a
  single record.

  Note that we also include a flag for whether the time
  period really signifies coverage, or rather a gap.  After
  merging contiguous identical coverage periods we will use
  that var to chuck the gap segments.

  The tricky part here is deciding how to resolve
  potentially different information from multiple source
  records that apply to the same time period.  The ins_:
  vars are easy, because there isnt any real conflict-- its
  perfectly valid to have >1 type of coverage in effect at
  a given time. So those can be set to Y if there are *any*
  records signifying that coverage during the period. Those
  are numerics in my source data, so the max() function
  works just fine to bring this information onto the output
  time period record.

  But the value-added vars are tougher--you can really only
  have one primary care physician at a time, for example.
  So we have to pick a winner any time there is a conflict.
  Here too, we can use SQLs max and min functions (I wrap
  those around calls to coalesce(), so as to control what
  happens with null values).  Those work fine on text, but
  note that which values sort high/low will depend on the
  collating sequence of your platform (e.g. ASCII vs.
  EBCDIC).  So consider which sorts of values you want to
  favor when you pick winners for your sites data.

  */
  proc sql ;

    drop table status_change_dates ;

    create table penultimate as
    select td.mrn
          , td.period_start                                         as enr_start  length = 4 label = "Start of this enrollment period"
          , td.period_end                                           as enr_end    length = 4 label = "End of this enrollment period"
          , max(coalesce(pcp, '000000'))                            as pcp label = "Primary Care Physician"
          , max(coalesce(pcc, '000')   )                            as pcc label = "Primary Care Clinic"
          , put(max(put(ins_commercial, $yenu.)), $d_yenu.)         as ins_commercial label = "Any Commercial coverage during this period?"
          , put(max(put(ins_privatepay, $yenu.)), $d_yenu.)         as ins_privatepay label = "Any Private Pay (e.g., individual/family) coverage during this period?"
          , put(max(put(ins_statesubsidized, $yenu.)), $d_yenu.)    as ins_statesubsidized label = "Any State-subsidized coverage during this period?"
          , put(max(put(ins_selffunded, $yenu.)), $d_yenu.)         as ins_selffunded label = "Any Self-funded coverage during this period?"
          , put(max(put(ins_highdeductible, $yenu.)), $d_yenu.)     as ins_highdeductible label = "Any High-deductible coverage during this"
          , put(max(put(ins_medicaid, $yenu.)), $d_yenu.)           as ins_medicaid label = "Any Medicaid coverage during this period?"
          , put(max(put(ins_medicare, $yenu.)), $d_yenu.)           as ins_medicare label = "Any Medicare coverage (any type) during this period?"
          , put(max(put(ins_medicare_a, $yenu.)), $d_yenu.)         as ins_medicare_a label = "Any Medicare Part A coverage during this period?"
          , put(max(put(ins_medicare_b, $yenu.)), $d_yenu.)         as ins_medicare_b label = "Any Medicare Part B coverage during this period?"
          , put(max(put(ins_medicare_c, $yenu.)), $d_yenu.)         as ins_medicare_c label = "Any Medicare Part C coverage during this period?"
          , put(max(put(ins_medicare_d, $yenu.)), $d_yenu.)         as ins_medicare_d label = "Any Medicare Part D coverage during this period?"
          , put(max(put(ins_basichealth, $yenu.)), $d_yenu.)        as ins_basichealth label = "Any Basic Health coverage during this period?"
          , put(max(put(ins_aca, $yenu.)), $d_yenu.)        as ins_aca label = "Any Basic Health coverage during this period?"
          , put(max(put(ins_other, $yenu.)), $d_yenu.)              as ins_other label = "Any Other insurance coverage during this period?"
          , put(max(put(plan_hmo, $yenu.)), $d_yenu.)               as plan_hmo label = "Any HMO-plan coverage during this period?"
          , put(max(put(plan_pos, $yenu.)), $d_yenu.)               as plan_pos label = "Any Point Of Service-plan coverage during this period?"
          , put(max(put(plan_ppo, $yenu.)), $d_yenu.)               as plan_ppo label = "Any Preferred Provider Organization-plan coverage during this period?"
          , put(max(put(plan_indemnity, $yenu.)), $d_yenu.)         as plan_indemnity label = "Any Indemnity-plan coverage during this period?"
          , put(max(put(drugcov, $yenu.)), $d_yenu.)                as drugcov label = "Any drug coverage during this period?"
          , put(max(put(enrollment_basis, $eb.)), $d_eb.)           as enrollment_basis label = "Basis for including this person/period in the file ([I]nsurance, [G]eography, or [B]oth I & G)"
          , put(max(put(incomplete_outpt_enc, $incm.)), $d_incm.)   as incomplete_outpt_enc label = "Do we know of a reason why complete capture of outpatient encounters is suspect?"
          , put(max(put(incomplete_tumor, $incm.)), $d_incm.)       as incomplete_tumor label = "Do we know of a reason why complete capture of tumor data is suspect?"
          , put(max(put(incomplete_emr, $incm.)), $d_incm.)         as incomplete_emr label = "Do we know of a reason why complete capture of EMR data is suspect?"
          , put(max(put(incomplete_lab, $incm.)), $d_incm.)         as incomplete_lab label = "Do we know of a reason why complete capture of lab data is suspect?"
          , put(max(put(incomplete_inpt_enc, $incm.)), $d_incm.)    as incomplete_inpt_enc label = "Do we know of a reason why complete capture of inpatient stays is suspect?"
          , put(max(put(incomplete_outpt_rx, $incm.)), $d_incm.)    as incomplete_outpt_rx label = "Do we know of a reason why complete capture of outpatient rx fills is suspect?"
          , max(case when h.mrn is null then 0 else 1 end)          as actual_coverage  length = 3
    from  timeline_dates as td LEFT JOIN
          &inset as h
    on    td.mrn = h.mrn AND
          NOT (period_start > enr_end OR enr_start > period_end)
    group by td.mrn
            , td.period_start
            , td.period_end
    order by td.mrn
          , td.period_start
          , td.period_end
    ;

  quit ;

  data &outset ;
    set penultimate ;
    * This by-list needs to list every var other than enr_start/stop and actual_coverage. ;
    * The order of the vars in the list is not important except that the last-listed var
    * is the one that should be used in the last-dot and first-dot if statements. ;
    by mrn
      pcp
      pcc
      ins_commercial
      ins_privatepay
      ins_statesubsidized
      ins_selffunded
      ins_highdeductible
      ins_medicaid
      ins_medicare
      ins_medicare_a
      ins_medicare_b
      ins_medicare_c
      ins_medicare_d
      ins_basichealth
      ins_aca
      ins_other
      plan_hmo
      plan_pos
      plan_ppo
      plan_indemnity
      enrollment_basis
      incomplete_outpt_enc
      incomplete_tumor
      incomplete_emr
      incomplete_lab
      incomplete_inpt_enc
      incomplete_outpt_rx
      drugcov
      NOTSORTED
    ;
    retain hold_period_start ;
    if first.drugcov then do ;
      hold_period_start = enr_start ;
    end ;
    if last.drugcov then do ;
      enr_start = hold_period_start ;
      if actual_coverage then output ;
    end ;
    drop hold_period_start actual_coverage ;
    format hold_period_start mmddyy10. ;
  run ;
%mend de_overlap ;

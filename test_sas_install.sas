* include "\\ghcmaster\ghri\Warehouse\sas\Includes\globals.sas" ;
/*********************************************
* Roy Pardee
* Group Health Research Institute
* (206) 287-2078
* pardee.r@ghc.org
*
* //ghcmaster/ghri/Warehouse/management/Programs/utilities/test_sas_install.sas
*
* Tests various esoteric & normal ops to do a minimal vetting of a
* new SAS install.
*********************************************/

libname _all_ clear ;

libname s "&GHRIDW_ROOT\management\OfflineData\Scratch" ;

options
  linesize  = 150
  msglevel  = i
  formchar  = '|-++++++++++=|-/|<>*'
  dsoptions = note2err
  nocenter
  noovp
  nosqlremerge
  mprint
;

%include "h:/SAS/login.sas" ;
* %include "h:/SAS/Scripts/remoteactivate.sas" ;

%let ghridwip=10.1.179.59;
%let ghridwip=10.1.179.29;

* options COMAMID=TCP REMOTE=GHRIDWIP;
* %include "h:/SAS/login.sas" ;
* filename GHRIDWIP '\\ghcmaster\ghri\warehouse\remote\tcpwinbatch.scr';
* signon GHRIDWIP;


%macro test_pc_files ;

  /*

    access, import, and export popular PC files data such as Microsoft Access,
    Microsoft Excel, JMP, Paradox, SPSS, Stata, DBF, Lotus 1-2-3, and delimited
    files. Provides details about SAS/ACCESS statements, options, and environment
    variables, as well as the IMPORT and EXPORT procedures

  */

  * excel ;
  libname xl excel "\\ghcmaster\ghri\Warehouse\management\Programs\utilities\tests\products_classified.xlsx" ;

  proc print data = xl.'products_classified$'n ;
  run ;

  libname xl_old "\\ghcmaster\ghri\Warehouse\management\Programs\utilities\tests\addep_depression_dx_codes.xls" ;

  proc datasets library = xl_old ;
  quit ;

  proc print data = xl_old.'sheet1$'n ;
  run ;

  * msaccess ;
  %let mdb_file = &GHRIDW_ROOT\management\programs\crn_vdw\utilization\supporting_files\enctype_subtypes_v3.mdb ;

  libname msac access "&mdb_file" ;

  proc print data = msac.enctypes (drop = longdesc) ;
  run ;

  proc datasets library = msac ;
  quit ;

  * generated from file -> import ;
  PROC IMPORT OUT= WORK.blah
      DATATABLE= "enctypes"
      DBMS=ACCESS REPLACE;
    DATABASE="&mdb_file";
    SCANMEMO=YES;
    USEDATE=NO;
    SCANTIME=YES;
  RUN;

  * generated from file -> export ;


  PROC EXPORT DATA= WORK.BLAH
              OUTFILE= "\\ghcmaster\ghri\Warehouse\management\Programs\utilities\tests\test_xport.xls"
              DBMS=EXCEL REPLACE;
       SHEET="bloob";
       NEWFILE=YES;
  RUN;


%mend test_pc_files ;

* %test_pc_files ;

* ENDSAS ;

proc print data = sashelp.class ;
run ;


* read and write to an access db ;
%let mdb_file = &GHRIDW_ROOT\management\programs\crn_vdw\utilization\supporting_files\enctype_subtypes_v3.mdb ;

* libname mdb OLEDB Provider=Jet DataSource="&mdb_file" ;
libname mdb ODBC required="Driver={Microsoft Access Driver (*.mdb, *.accdb)}; DBQ=&mdb_file" ;

proc print data = mdb.enctypes ;
  var enctype shortdesc ;
run ;

libname mylib teradata
  user              = "&username@LDAP"
  password          = "&password"
  server            = "&td_prod"
  schema            = "%sysget(username)"
  multi_datasrc_opt = in_clause
  connection        = global
;


* endsas ;

goptions reset=all border;
proc format;
   value mmm_fmt
   1='Jan'
   2='Feb'
   3='Mar'
   4='Apr'
   5='May'
   6='Jun'
   7='Jul'
   8='Aug'
   9='Sep'
   10='Oct'
   11='Nov'
   12='Dec'
   ;
run;
data citytemp;
   input  month faren city $ @@;
   datalines;
   1      40.5    Raleigh     1      12.2    Minn
   1      52.1    Phoenix     2      42.2    Raleigh
   2      16.5    Minn        2      55.1    Phoenix
   3      49.2    Raleigh     3      28.3    Minn
   3      59.7    Phoenix     4      59.5    Raleigh
   4      45.1    Minn        4      67.7    Phoenix
   5      67.4    Raleigh     5      57.1    Minn
   5      76.3    Phoenix     6      74.4    Raleigh
   6      66.9    Minn        6      84.6    Phoenix
   7      77.5    Raleigh     7      71.9    Minn
   7      91.2    Phoenix     8      76.5    Raleigh
   8      70.2    Minn        8      89.1    Phoenix
   9      70.6    Raleigh     9      60.0    Minn
   9      83.8    Phoenix    10      60.2    Raleigh
  10      50.0    Minn       10      72.2    Phoenix
  11      50.0    Raleigh    11      32.4    Minn
  11      59.8    Phoenix    12      41.2    Raleigh
  12      18.6    Minn       12      52.5    Phoenix
;



libname clarity ODBC required = &clarity_odbc ;

proc print data = clarity.clarity_eap(obs = 10) ;
  var name ;
run ;


* %include "&GHRIDW_ROOT/Sasdata/CRN_VDW/lib/standard_macros.sas" ;


libname rw "\\groups\data\CTRHS\Crn\voc\enrollment\programs\qa_results\raw" ;

* %stack_datasets(inlib = rw, nom = enroll_duration_stats , outlib = s) ;

  ** All input datasets live in inlib.
  ** All input dataset names begin with <<site abbreviation>>_ and end with the text passed in the nom parameter. ;
  ** This guy creates a big old UNION query against them all and then executes it to create a dataset named <<nom>> in the outlib library. ;


data gnu ;
  input
    @1    adate date9.
    @11   source_count 3.0
    @17   source $char4.
  ;
  format adate mmddyy10. ;
datalines ;
01jan2015 344   west
01feb2015 399   west
01mar2015 399   west
01apr2015 523   west
01jan2015 444   east
01feb2015 499   east
01mar2015 369   east
run ;

* proc print ;



options orientation = landscape ;

* %let out_folder = /C/Users/pardre1/Desktop/ ;
%let out_folder = %sysfunc(pathname(s)) ;

ods html path = "&out_folder" (URL=NONE)
         body   = "deleteme.html"
         (title = "deleteme output")
         style = magnify
          ;

ods rtf file = "&out_folder/deleteme.rtf" ;
ods pdf file = "&out_folder/deleteme.pdf" ;


  title1 "Average Monthly Temperature";
  footnote1 j=l " Source: 1984 American Express";
  footnote2 j=l "         Appointment Book";
  symbol1 interpol=join  value=dot ;
  proc gplot data= citytemp;
     plot faren*month=city / hminor=0;
  run;
  symbol1 interpol=spline width=2 value=triangle c=steelblue;
  symbol2 interpol=spline width=2 value=circle c=indigo;
  symbol3 interpol=spline width=2 value=square c=orchid;
  axis1 label=none
        order = 1 to 12 by 1
        offset=(2);

  axis2 label=("Degrees" justify=right  "Fahrenheit")
        order=(0 to 100 by 10);
  legend1 label=none value=(tick=1 "Minneapolis");
  format month mmm_fmt.;
  plot faren*month=city /
          haxis=axis1 hminor=0
          vaxis=axis2 vminor=1
          legend=legend1;
  run;
  quit;


  ods graphics / height = 6in width = 10in ;
  ods listing gpath="&out_folder";

  proc sgplot data = gnu ;
    loess x = adate y = source_count / group = source lineattrs = (pattern = solid) ;
    xaxis grid ; * values = (&earliest to "31dec2010"d by month ) ;
    yaxis grid ;
  run ;

  proc javainfo ;
  run ;


run ;

ods _all_ close ;


** log on to unix and rsubmit ;
%include 'h:/SAS/Scripts/sasunxlogon.sas' ;
%include "&GHRIDW_ROOT/remote/RemoteStartUnix.sas" ;
rsubmit ;

  %cmd_lib_con(dm, cmd) ;

  data gnu ;
    set cmd.ip_detail(obs = 10) ;
    keep drgkey ;
  run ;

  proc download data = gnu out = test ;
  run ;

** log off unix ;
endrsubmit ;
signoff sasunix.spawner ;


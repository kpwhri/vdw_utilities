DEMOGRAPHICS
============
Version 4.0 StdVar = &\_vdw\_demographic

Subject Area Description
------------------------
The DEMOGRAPHICS table contains patient/enrollee level descriptives for the people found in VDW tables.  It serves as a lookup dataset for MRNs.  Every MRN appearing in any other VDW file should appear in the Demographics table, even if demographics information on the person is unknown.

|Variable Name|Definition|Type(Len)|Values|Implementation Guidelines|
|-------------|----------|---------|------|-------------------------|
|mrn |Medical record number is the unique patient identifier within a site and should never leave the site |char(*)|Unique to each patient at each site|Sites should do their best to maintain a 1:1 correspondence between people and MRNs. Fictitious/test numbers should be removed from the VDW. People with > 1 assigned MRN should be merged into a single number (in all files)|
|birth_date|The person's date of birth.|num(4)|SAS date| |
|gender|The person's gender identity as subjectively experienced, on last ascertainment|char(1)|M = Male<br>F = Female<br>O = Other including transgendered<br>U = Unknown| |
|natal_sex|The person's physical sex at birth|char(1)|M = Male<br>F = Female<br>U = Unknown<br>O = Other| |
|race1-race5|The person's race. Preference is for self-reported; please see Note 1 below for recording multiple race values|char(1)|HP = Native Hawaiian / Pacific Islander<br>IN = American Indian / Alaskan Native<br>AS = Asian<br>BA = Black or African American<br>WH = White<br>MU = Multiple races with particular unknown<br>OT = Other, values that do not fit well in any other value<br>UN = Unknown or Not Reported| |
|hispanic|Whether the person is of Hispanic origin / ethnicity|char(1)|Y = Yes<br>N = No<br>U = Unknown| |
|needs_interpreter|Whether the person needs an interpreter to communicate with an English-only speaker|char(1)|Y = Yes<br>N = No<br>U = Unknown| This variable is capable of changing over time. Populate with only the most recently known interpreter status.|

Primary Key
-----------
MRN

Foreign Keys
------------
|Source Variable|Target Table|Target Field|Orphans Allowed?|
|--|--|--|--|
| [none defined] |  |  |  |

Notes
--------
#Note 1: Race

Our goal is to have the most complete, reliable, and detailed race and ethnicity information in the demographics file. SDMs should gather race information from all sources permitted at your site—for example, tumor registry data; state birth & death data; and regular large-scale social surveys. If there is more than one source of race information for a set of individuals, SDMs should give preference to self-reported sources.

Please see appendix A for guidelines on mapping local race values to the permissible value set in the VDW.

Where multiple sources (or multiple measures from a single source) conflict as to the race of a given person, and the SDM does not have a reason to prefer one source to another (e.g., no one source is known to be most trustworthy, etc.) code all races indicated by any source.

For data sources that treat Hispanic ethnicity as a value of race (so e.g., you know the person is Hispanic, but you don’t know their race) code the person’s race as "Unknown".

When more than one race is known for a given person, assign values to the race variables in the order listed above RACE values and fill in any unused race variables with the value UN for unknown / not reported. Examples of coding RACE1 through RACE5 are illustrated here:

|Example Race Coding                        |Race1|Race2|Race3|Race4|Race5|
|-------------------                        |-----|-----|-----|-----|-----|
|White only                                 |WH   |UN   |UN   |UN   |UN   |
|White and Pacific-Islander                 |HP   |WH   |UN   |UN   |UN   |
|No race known                              |UN   |UN   |UN   |UN   |UN   |
|African-American and Native-American       |IN   |BA   |UN   |UN   |UN   |
|Multi-racial, particular races not reported|MU   |UN   |UN   |UN   |UN   |


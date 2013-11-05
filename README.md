prod_utilities
==============
Conceivably a collection of code useful for maintaining a SAS-based data warehouse (though right now it only holds %transition).

%Transition
-----------
Smoothly and (I hope) safely replaces a production dataset with an updated version.  The joy here is:
1. Makes the actual update just a file rename so as to avoid locking the dset (or worse, being thwarted by others' locks).
2. Refuses the update if the new file doesn't contain at least &count_tolerance percent of the records in the old.
3. Refuses the update if the new file doesn't have all the same variables as the old.

The down-side is that you need disk space enough to hold 2 copies of your data (including index files if any).

Signature:

```
%transition(dset            =     /* One-part name of the dset we are transitioning (e.g., encounters). */
          , lib             =     /* Name of the lib where the dsets to be transitioned live.  There should be a &lib..&dset and a &lib..&dset._next versions */
          , backdir         =     /* Folder spec for where archives of current-prod dsets go. */
          , count_tolerance = 99  /* New dset must have at least this percent of the n(recs) as the old in order to proceed. */
          , ignore_vardiffs = 0   /* Set to 1 to override the abort-if-any-vars-are-missing check. */
          , leave_last      = 1   /* Set to 0 to have the macro remove the _last version of the replaced dset. USE WITH CAUTION! */
          ) ;
```
To use it:
1.	Create a new dset with a _next suffix on it in the production library (so e.g., //server/warehouse/folder/encounters_next.sas7bdat).
2.	Create whatever indexes, integrity constraints, etc. on that _next dset. 
3.	Call %transition w/those first two args specified at least (if backdir is null you’ll get a warning, but the code will run).

The macro will put ERROR:s and WARNING:s as necessary, but should keep quiet if its expectations are met & it can do its thing w/out error.

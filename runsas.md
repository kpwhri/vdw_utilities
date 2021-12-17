# runsas.ps1 SAS Scheduled Task Helper

The attached powershell script, runsas.ps1 helps with scheduling SAS jobs via windows Task Scheduler. It
1. takes parameters, including:
    1. the path of the SAS program you want to run
    2. the path of a folder to which log and lst files should be written, and
    3. a 'friendly name' for the job
2. runs that SAS program
3. Checks the resulting log file for errors
4. Regardless of the result, sends an e-mail to an address you specify to inform that person that a run has been attempted & what the result was.


# Usage

## 1. Choose a computer to run the job

Any computer with a SAS install and a persistent connection to the network will do (so--pool VMs, your in-met-park-east PC, etc.).

## 2. Copy runsas.ps1 to a local drive of that computer

This is necessary because of powershell security policy configuration on KP machines. I tend to put it in c:\tools\powershell\runsas.ps1, but most anywhere should be fine.

## 3. Edit your copy of runsas.ps1 to tailor it to your job(s)

Specifically, edit the log_loc parameter on line 23 to divert the log & lst files to some location you have permission to write to:

![Basic configuration lines](images\scheduling_sas_with_runsas2_html_6a57e723.png)

Then edit the from, to and cc entries to control who gets the e-mail reports on lines 30-32:

![e-mail configuration lines](images\scheduling_sas_with_runsas2_html_m55fbc527.png)

## 4. Optionally, do a test run

Open a powershell prompt on your selected computer and `cd` into the directory you've copied runsas.ps1 into. Then type or paste:

``.\runsas.ps1 -sasprog "g:\ctrhs\YOUR\FOLDERS\HERE\myprog.sas" -friendly_name "Just Testing"``

(Of course you're substituting in the actual path to your program for that `-sasprog` parameter.)

You should see some basic messages come back in the powershell window, and the e-mail results should be sent to the people you configured on to/cc in step 3 above.

## 5. Schedule The Task

Open windows' Task Scheduler on the machine where you are scheduling the job.

Consider creating a folder of your own so you can quickly jump to the tasks you've created (right-click on the 'Task Scheduler Library' folder on the left and choose 'New Folder'.

Select the folder where you want to put the task, and click the 'Create Task...' action on the right side of the Task Scheduler window.

![the windows task scheduler](images\scheduling_sas_with_runsas2_html_m7032900b.png)

In the resulting dialog, give your job a name, select 'Run whether user is logged on or not', 'Run with the highest privileges' and select 'Windows 10' on the configure for: dropdown.

![an individual scheduled task](images\scheduling_sas_with_runsas2_html_70ecb11c.png)

Click the ‘Actions’ tab and then the ‘New’ button. Fill out the resulting dialog like so:

![task action dialog](images\scheduling_sas_with_runsas2_html_24fb7490.png)

The arguments should name your copy of runsas.ps1, the path to SAS program you want to run, and it’s friendly name, like so:

``-file "C:\tools\powershell\runsas.ps1" -sasprog "\\groups.ghc.org\data\CTRHS\LHS\Programming\royland\programs\integrated_pain_mgmt\eval_data.sas" -friendly_name "Opioid SmartData Refresh"``

Naturally again subbing in the path to your own SAS program & some meaningful friendly name.

Finally, click the ‘Triggers’ tab and then the ‘New’ button to set a schedule for when the job should run.

![task trigger dialog](images\scheduling_sas_with_runsas2_html_36830008.png)

When you’re done click OK on the trigger dialog, and then OK on the main job dialog. You’ll be prompted for your CS/NUID password.

## 6. Optionally, test the task as scheduled

Find your saved task in its folder, right-click on it, and select ‘Run’ from the context menu. You should see it’s ‘Status’ change to ‘Running’ and when the job finishes, get the same e-mail you got on your step 4 test run.

![manually kicking off a scheduled task](images\scheduling_sas_with_runsas2_html_1a690bf6.png)
<#
  runsas.ps1: a script for running scheduled SAS jobs.
  Roy Pardee
  12-apr-2021
#>

<#
  sample call:
  program/script: powershell.exe
  args:
  -file "C:\tools\powershell\runsas.ps1" -sasprog "\\groups\data\CTRHS\LHS\Programming\royland\programs\integrated_pain_mgmt\eval_data.sas" -friendly_name "Opioid SmartData Refresh"
#>

# Script input parameters--both required.
param (
  [Parameter(Mandatory)][string]$sasprog,
  [Parameter(Mandatory)][string]$friendly_name
  )

# Basic config
$config = @{
  "sas_exe"  = "C:\Program Files\SASHome\SASFoundation\9.4\sas.exe"
  "log_loc"  = "\\groups\data\CTRHS\LHS\Programming\royland\programs\integrated_pain_mgmt\logs_lsts"
  "sas_args" = "-nologo", "-unbuflog"
  "err_regx" = "(^(error|warning:)|uninitialized|[^l]remerge|Invalid data for)(?! (the .{4,15} product with which|your system is scheduled|will be expiring soon, and|this upcoming expiration.|expiring soon|upcoming expiration.|information on your warning period.))"
  "inf_regx" = "^(info|dig it):"
  "ignorable_err_regx"  = "(Unable to copy SASUSER registry|Multiple lengths were specified|Fastload summary follows|expir(e|ing|ation)|warning period|product with which)"
}
# The outline of the e-mail this run will generate.
$mail_params = @{
  from       = "RunSas Script <roy.e.pardee@kp.org>"
  to         = "jessica.m.mogk@kp.org"
  cc         = "roy.e.pardee@kp.org"
  # to         = "roy.e.pardee@kp.org"
  subject    = $friendly_name
  SmtpServer = "mta-dmz.kp.org"
  port       = 25
  priority   = "Normal"
}
function getOutPath {
  param($inItem)
  $today = get-date -format "yyyy-MM-dd"
  return $config.log_loc + "\" + $inItem.basename + "_$today"
}

function clearOldOutputs {
  param($baseOut)
  remove-item "$baseOut.prior.run.log" -erroraction ignore
  remove-item "$baseOut.prior.run.lst" -erroraction ignore
  if (test-path "$baseOut.log" -pathtype leaf) {
    move-item -path "$baseOut.log" -destination "$baseOut.prior.run.log"
  }
  if (test-path "$baseOut.lst" -pathtype leaf) {
    move-item -path "$baseOut.lst" -destination "$baseOut.prior.run.lst"
  }
}

function checkLog {
  param($logfile)
  $ret = ""
  $errs = select-string -path $logfile -pattern $config.err_regx -context 1 | where-object {$_.line -NotMatch $config.ignorable_err_regx} | select-object linenumber, line <#, context#>
  $infs = select-string -path $logfile -pattern $config.inf_regx -context 1 | select-object linenumber, line <#, context#>
  if ($errs.count -gt 0) {
    $ret += $errs | convertto-html -fragment -precontent "<h2>Errors And Warnings</h2>"
    write-host "Found some errors"
    $mail_params.priority = 'High'
    $mail_params.subject += " RAN WITH ERRORS!!!"
  }
  else {
    $mail_params.subject += " Ran Successfully"
    $mail_params.priority = 'Low'
  }
  $ret += $infs | convertto-html -fragment -precontent "<h2>Information Lines</h2>"
  $mail_params.body += $ret
}
<#
#>
try {
  $start_time = get-date
  $mail_params.body = "Source Program: $sasprog"
  # Does the file exist?
  $sasprog_item = get-item -path $sasprog -erroraction stop
  $baseOut = getOutPath($sasprog_item)
  $log_file = $baseOut + ".log"
  $lst_file = $baseOut + ".lst"
  $mail_params.body += "<br/>"
  $mail_params.body += "Log: $log_file"
  $mail_params.body += "<br/>"
  $mail_params.body += "List: $lst_file"
  # write-host $log_file
  clearOldOutputs($baseOut)
  $todays_args = $config.sas_args + @("-sysin", $sasprog, "-log", $log_file, "-print", $lst_file)
  write-host "Running $sasprog"
  $out = start-process $config.sas_exe -argumentlist $todays_args -wait -workingdirectory $config.log_loc
  $end_time = get-date
  $run_time = $end_time - $start_time
  $db_run_time = $run_time.TotalSeconds
  $mail_params.body += "<br/>Run time: " + $run_time.ToString("dd' days 'hh' hours 'mm' minutes 'ss' seconds'")
  checkLog($log_file)
  if ($mail_params.priority -eq 'High') {
    $rslt = 'failure'
  }
  else {
    $rslt = 'success'
  }
}
catch [System.Management.Automation.ItemNotFoundException] {
  write-host "No such file as $sasprog. I'm telling mom"
  $mail_params.body += "Could not find any such file as $sasprog. Doing nothing."
  $mail_params.subject += " FILE NOT FOUND!!!"
  $mail_params.priority = "High"
}
catch {
  $mail_params.subject += " UNEXPECTED ERROR!!!"
  $mail_params.body += "<br/> $_ <br/>" + $_.ScriptStackTrace
  $mail_params.priority = "High"
}
finally {
  write-host $mail_params.to
  Send-MailMessage @mail_params -BodyAsHtml <#-body ($body | out-string)  -subject $subject -priority $priority#>
  write-host "done!"
}



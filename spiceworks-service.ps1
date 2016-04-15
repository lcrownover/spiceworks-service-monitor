$date = get-date
$log_file = "<LOG FILE PATH>"
$smtp_server = "<YOUR SMTP SERVER>"
$hostname = hostname
$service = "spiceworks"                     # service name
$service_check = get-service $service       # get the service object
$try_counter = 1                            # counter for retry
$fail_threshold = 2                         # number of times it will try to restart the service if it fails the first time
$fail_sleep = 1                             # sleep counter that will increase to give service more time to start if it fails multiple times

$Success_Mail = @{      # mail sent when script successfully restarts service 
    to          = "TargetUser <TargetUser@domain.org>"
    from        = "Spiceworks Status Monitor <spiceworksdiag@domain.org>"
    subject     = "Spiceworks Service Restarted Successfully"
    body        = "Spiceworks service failed on $date and was restarted successfully. `nLog file at: $log_file on $hostname `nNo action necessary." 
    SmtpServer  = $smtp_server
}

$Failure_Mail = @{      # mail sent when script fails to restart the service 
to              = "TargetUser <TargetUser@domain.org>"
from            = "Spiceworks Status Monitor <spiceworksdiag@domain.org>"
subject         = "Spiceworks Service Failure"
body            = "Spiceworks service failed on $date and could not be restarted. `nLog file at: $log_file on $hostname"
SmtpServer      = $smtp_server
}

# main check to see if service has stopped, if so, date stamp the log file and continue
if ($service_check.Status -ne "Running") {
    add-content $log_file "`r`nService stopped running as of $date"
}

# main loop to keep trying to restart service
while ($service_check.Status -ne "Running" -and $try_counter -le $fail_threshold) {
    start-service $service
    $service_check.WaitForStatus("Running","00:00:30")  # waits until service is running or times out after 30sec
    $service_check = get-service $service               # refresh $service_check object
    if ($service_check.Status -eq "Running") {          # check again to verify that it's running
        add-content $log_file "Service restart successful!"
        Send-MailMessage @Success_Mail                
    }
    elseif ($service_check.Status -ne "Running") {
        add-content $log_file "Service restart failed, retrying..."
        start-service $service
	    start-sleep -m $fail_sleep                     # sets sleep timer for 1min to try and give the service more time to start
	    $service_check = get-service $service          # refresh service object again
        $try_counter++                              
        $fail_sleep++
        if ($try_counter -gt $fail_threshold) {        # if it tries more than the fail threshold than stop trying and send failure email
            add-content $log_file "Critical failure, fix me pl0x!"
            Send-MailMessage @Failure_Mail
        }
    }
}

$date = get-date
$log_file = "<LOG FILE PATH>"
$service = "spiceworks"
$service_check = get-service $service
$counter = 1
$fail_threshold = 2
$fail_sleep = 1
$smtp_server = "<YOUR SMTP SERVER>"
$hostname = hostname

if (!(Test-Path $log_file)) {
    New-Item $log_file -type file | out-null
}

if ($service_check.Status -ne "Running") {
    add-content $log_file "`r`nService stopped running as of $date"
}

while ($service_check.Status -ne "Running" -and $counter -le $fail_threshold) {
    start-service $service
    start-sleep -s 30
    $service_check = get-service $service
    if ($service_check.Status -eq "Running") {
        add-content $log_file "Service restart successful!"
        Send-MailMessage -to "TargetUser <TargetUser@domain.org>" `
                         -from "Spiceworks Status Monitor <spiceworksdiag@domain.org>" `
                         -subject "Spiceworks Service Restarted Successfully" `
                         -body "Spiceworks service failed on $date and was restarted successfully. `nLog file at: $log_file on $hostname `nNo action necessary." `
                         -SmtpServer $smtp_server
        break
    }
    elseif ($service_check.Status -ne "Running") {
        add-content $log_file "Service restart failed, retrying..."
        start-service $service
	start-sleep -m $fail_sleep
	$service_check = get-service $service
        $fail_sleep = $fail_sleep + 1
        $counter = $counter + 1
        if ($counter -gt $fail_threshold) {
            add-content $log_file "Critical failure, fix me pl0x!"
            Send-MailMessage -to "TargetUser <TargetUser@domain.org>" `
                             -from "Spiceworks Status Monitor <spiceworksdiag@domain.org>" `
                             -subject "Spiceworks Service Failure" `
                             -body "Spiceworks service failed on $date and could not be restarted. `nLog file at: $log_file on $hostname" `
                             -SmtpServer $smtp_server
        }
        start-sleep -s 30
    }
}

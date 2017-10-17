# Powershell
# Script to modify configuration files
# Pablo Estigarribia
# last modified time: 20171016
#
#Examples:
# burp_clientconfig3.ps1 pre
# burp_clientconfig3.ps1 post 0
# burp_clientconfig3.ps1 initialchange
# Function required to manipulate config file, hardcoded, not imported.

param (
    $saction = 'update',
    [string]$level = 0
)

function get_config( $file ) {
  $content = Get-Content $file
  #$content = $content -replace " ",""
  $ConfigKeys = @{}
  
  $content | Foreach-object {
    $keys = $_ -split "="
    $key = $keys[0].Trim()
    $value = $keys[1].Trim()
    # Exclude exclude_regex
    if ($key -ne 'exclude_regex') { 
        $ConfigKeys += @{$key=$value}
    }
  }
  return $ConfigKeys
}

function setConfig( $file, $key, $value ) {
  ## Function to modify configuration files
  ## http://stackoverflow.com/questions/15662799/powershell-function-to-replace-or-add-lines-in-text-files
  $content = Get-Content $file
  if ( $content -match "^$key\s*=" ) {
      $content -replace "^$key\s*=.*", "$key = $value" |
      Set-Content $file
      Add-Content $LOG_FILE "Replacing $key with $value"
  } else {
      Add-Content $file "$key = $value"
      Add-Content $LOG_FILE "Adding $key = $value"
  }
}

Write-host "saction: $saction"
Write-host "exit level: $level"

$burp_client_dir =  Join-Path "$env:programfiles" "burp"
$burp_config_client_file = Join-Path "$burp_client_dir" "burp.conf"
# Set temp file if the original file will be modified
$destination_file =  Join-Path "$env:temp" "burp.conf"
#Set location code if needed
$DeviceLocation = "$env:Locationcode"
#Set burp_log to work on client while operating backups and backup_script_post
$burp_log =  Join-Path "$burp_client_dir" "log.txt"
$burp_autom_log =  Join-Path "$burp_client_dir" "log_autom.txt"
$log_level = "1"
$status_dir = Join-Path "$env:allusersprofile" "burp"
$status_file = Join-Path $status_dir "burp.latest.txt"
$outdated = 19
$SERVERPORT = '4971'
$SERVERSTATUSPORT = '4972'


if ( ($saction -eq "initialchange") -or ($saction -eq "uninstall") ) {
    $Locationcode = "$env:Locationcode"
	Write-host "Device Location = $Locationcode"
}
else {
    # It actually uses Active Directory to get current location, and location code
    $NetlogonParameters = Get-ItemProperty "hklm:\SYSTEM\CurrentControlSet\services\Netlogon\Parameters"
    $Locationcode = $NetlogonParameters.DynamicSiteName.split("-")[0]
	Write-host "Current Location = $Locationcode"
}

$CLIENTNAME = "$env:computername"

# ----- SETTING variables for package builders
$PackageName = "burp_installer"

if (!$env:SystemRoot) {
    $LOG_FOLDER = "C:\Windows\Logs"
}
else {
    $LOG_FOLDER = "$($env:SystemRoot)\Logs"
}

$LOG_FILE="$LOG_FOLDER\$PackageName" + "_package_.log"

# Used standard to define bandwith:
# For all locations with 2mbps or less, default: 2mbps
# For all locations between 4mbps and 9mbps, default: 2mbps
# For all locations with more than 10mbps, default: 5mbps
# For locations with local burp server (100mbps or more), default: 20mbps
# After first successful backup, it will change to CurrentLocation automatically for all.
# Just example with different locations codes set from AD and their defaults
$burp_servers = @{"L01" = "192.168.1.10";
                  "L02" = "192.168.2.10";
                  "L03" = "192.168.3.10";
                  "L04" = "192.168.4.10";
                  "default" = "192.168.1.11"}
                  
$burp_ratelimits = @{"L01" = "25";
                     "L02" = "20";
                     "L03" = "20";
                     "L04" = "10";
                     "default" = "5"}

if ($burp_servers.ContainsKey($Locationcode)) {
  $SERVERADDRESS = $burp_servers.$Locationcode
} else {
  $SERVERADDRESS = $burp_servers.default
}

if ($burp_ratelimits.ContainsKey($Locationcode)) {
  $RATEFORLOCATION = $burp_ratelimits.$Locationcode
} else {
  $RATEFORLOCATION = $burp_ratelimits.default
}

# Change rate if not in device location. 

if ( test-path $burp_config_client_file ) {
  $ConfigKeys = get_config $burp_config_client_file
  $BSERVERADDRESS = $ConfigKeys.server
}

if ( $Locationcode -eq $DeviceLocation ) {
       Write-host "Does nothing, device and location are equal"
}
else {
  if (( $Locationcode -ne "L50" ) -and ( $SERVERADDRESS -ne $BSERVERADDRESS )){
      $RATEFORLOCATION = $burp_ratelimits.default # Some special location for vpn connections
      Write-host "ratelimit changed to default"
  } else {
    Write-host "does nothing, it's on correct config'"
  }
}

# Increase RATE during out of office hours
[int]$hour = get-date -format HH
If ($hour -lt 8 -or $hour -gt 17) {
  $RATEFORLOCATION = "50"
}

function logging ($msg) {
  $logtime = Get-Date -Format u
  if ( $log_level -eq "1" ) {
      Add-Content $burp_autom_log "$logtime : $msg"
  }
}

#Function to DownloadFile from burp server.
#Fix tried to copy form temp download.
function update_script {
    $ConfigKeys = get_config $burp_config_client_file
    $BSERVERADDRESS = $ConfigKeys.server
    $url = "http://$BSERVERADDRESS/burp_clientconfig3.ps1"
    $temp = "$env:temp"
    $burpfolder = $burp_client_dir
	  $path =  Join-Path "$temp" burp_clientconfig3.ps1
    $webclient = new-object System.Net.WebClient
    $webclient.DownloadFile( $url, $path )
    robocopy $temp $burpfolder burp_clientconfig3.ps1  /R:1 /W:1 /COPY:D /LOG:"c:\program files\burp\update_script.txt"
}

function automation_fixes( $file, $type ) {
    #WARNING! don't use this function before running burp, it will change the $SERVERADDRESS readed from burp config.
    $content = Get-Content $file
    $ConfigKeys = get_config $burp_config_client_file
    $BSERVERADDRESS = $ConfigKeys.server
    logging "$file Entering to automation_fixes function"
    switch ($type)
    {
      "ssl_fixes" {
        logging "$file Testing ssl_fixes"
        if ( $content | where-object {($_ -like "*SSL alert number 51*" -or 
             $_ -like "*SSL3_READ_BYTES:tlsv1 alert decrypt error:s3_pkt.c*" -or 
             $_ -like "*Error with certificate signing request*" -or 
             $_ -like "*check cert failed*" -or
             ($_ -like "*e:Will not accept a client certificate request for*" -and $_ -like "*already exists*") )} )  {
            
            logging "$file contains ssl alerts, removing certs and fixing"
            Remove-Item "$burp_client_dir\ssl_cert_ca.pem"
            Remove-Item "$burp_client_dir\ssl_cert-client.key"
            Remove-Item "$burp_client_dir\ssl_cert-client.pem"
            Remove-Item "$burp_client_dir\CA\$env:computername.csr"
            logging "sending TYPE=FixSSL to server, try again in a minute"
            send_file fixssl automation_fixes
        } else {
          logging "$file Not found SSL problems"
        }
      }
      "auth_fixes" {
        logging "$file looking for unathorise on server: $BSERVERADDRESS"
        if ( $content | where-object {($_ -like "*unable to authorise on server*")} )  {
            logging "$file contains unable to authorise, sending request as new client"
            Remove-Item "$burp_client_dir\ssl_cert_ca.pem"
            Remove-Item "$burp_client_dir\ssl_cert-client.key"
            Remove-Item "$burp_client_dir\ssl_cert-client.pem"
            Remove-Item "$burp_client_dir\CA\$env:computername.csr"
            send_file initialchange automation_fixes
        }
      }
      "failed_backups" {
        logging "$file looking for failed backups on server: $BSERVERADDRESS"
        if ( $content | where-object {($_ -like "*Error when reading counters from server*")} ) {
            logging "$file contains Error when reading counters from server"
            send_file uninstall automation_fixes
        }
      }
      default {
        logging "Going out with no Parameters"
      }
    }
}


function removeConfig( $Path, $key ) {
     $content = Get-Content $Path | Where-Object {$_ -notmatch "$key"}
     $content | Set-Content $Path -Force
}


# Call with post 0 for post backup script
# it will not change the file if backup was not successful
function post ($x)
{
    logging "Entering post actions"
    if($x -eq 0) {
        setConfig $burp_config_client_file "ratelimit" "$RATEFORLOCATION"
        logging "burp finished successful"
        logging "Copying log to status_file"
        vssadmin resize shadowstorage /For=C: /On=C: /MaxSize=6%
        # Create a vss snapshot for local restore
        (Get-WmiObject -list win32_shadowcopy).Create("C:\","ClientAccessible")
        if ( test-path $status_dir ) {
            Copy-Item $burp_log -Destination $status_file -Force
            if ( test-path $status_dir\notify.txt ) {
              msg * "Your backup is up to date!"
            }
        } else {
            New-Item -Path $status_dir -ItemType directory
            Copy-Item $burp_log -Destination $status_file -Force
        }
    } else {
      logging "burp finished with errors"
      automation_fixes $burp_log ssl_fixes
    }
}

function check_backup_status{
  $date = (Get-Date).Adddays(-$outdated) # Get date outdated 
  $date = $date.ToString("yyyy-MM-dd") # Format to compare
  $temp = "$env:temp"
  $notifier_file = Join-Path "$temp" "burp_notifier_$date.txt"
    
  if ( test-path $status_file ) {
    $date_backup = (Get-Item $status_file).LastWriteTime.ToString("yyyy-MM-dd")
    $message_outdated = "El respaldo de su computadora no es actualizado!!!
                        Fecha de backup: $date_backup
                        Favor dejar la computadora conectada a la red y encendida durante la noche o contactar a helpdesk"
    if ( $date -gt $date_backup ) {
      if (-Not (test-path $notifier_file )) {
        msg * $message_outdated
        Add-Content $notifier_file "Notified user about old backup"
        logging "Notified user about old backup"
      }
    }
  } else {
    $message_nobackup = "Su computadora no tiene respaldo!!
                        Favor dejar la computadora conectada a la red y encendida  durante la noche o contactar a helpdesk"
      if (-Not (test-path $notifier_file )) {
        msg * $message_nobackup
        Add-Content $notifier_file "Notified user about no backup"
        logging "Notified user about no backup"
      }
  }
  
}

# Call with pre for pre backup script
function pre{
    logging "Entering pre actions"
    setConfig $burp_config_client_file "ratelimit" "$RATEFORLOCATION"
    Start-Sleep 5
}

function backup{
  pre
  $prog = "C:\Program Files\burp\bin\burp.exe"
  
  # Only run burp if not running
  $ProcessActive = Get-Process burp -ErrorAction SilentlyContinue
  if($ProcessActive -eq $null) {
    logging "running burp"
    cmd /c "$prog" -a t > $burp_log
  } else {
    logging "burp is already running, it will not run"
  }
  logging "burp execution finished, sleep 5s"
  Start-Sleep 5
  automation_fixes $burp_log ssl_fixes
  automation_fixes $burp_log auth_fixes
  # update_script
  check_backup_status
}

function send_file ($type, $saction){
    switch ( $saction ) {
      "automation_fixes" {
        $ConfigKeys = get_config $burp_config_client_file
        $Global:SERVERADDRESS = $ConfigKeys.server
      }
    }
    $CENTRALBURPPASS='SMBPASSWORD'
    $TEMPCFGFOLDER=$env:temp
    $TEMPCFGFORCENTRAL="$TEMPCFGFOLDER\$CLIENTNAME"
   
    if ( test-path "C:\programData") {
      Set-Content $TEMPCFGFORCENTRAL "PROFILE=win6x"
    }
    else {
      Set-Content $TEMPCFGFORCENTRAL "PROFILE=win5x"
    }
    switch ($type) {
        initialchange {
            if ( test-path "$env:programfiles\burp\CA\$CLIENTNAME.csr") {
              Add-Content $TEMPCFGFORCENTRAL "TYPE=Update"
              } else {
              Add-Content $TEMPCFGFORCENTRAL "TYPE=New"
              }
        }
        uninstall { 
          Add-Content $TEMPCFGFORCENTRAL "TYPE=Archive"
          if ( test-path $burp_config_client_file ) {
              $ConfigKeys = get_config $burp_config_client_file
              $Global:SERVERADDRESS = $ConfigKeys.server
            } 
        }
        fixssl { Add-Content $TEMPCFGFORCENTRAL "TYPE=FixSSL" }
    }
    $PROCESSCLIENTSHARE="\\$SERVERADDRESS\process_clients"
    Add-Content $TEMPCFGFORCENTRAL "LOCATION=$Locationcode"
    net use /user:$SERVERADDRESS\burp $PROCESSCLIENTSHARE $CENTRALBURPPASS
    if ( test-path $PROCESSCLIENTSHARE ) {
      robocopy "$TEMPCFGFOLDER" "$PROCESSCLIENTSHARE" $CLIENTNAME /R:1 /W:1 /COPY:D /LOG:"$LOG_FILE.sendfile.log.txt"
    } else {
      Add-Content $LOG_FILE "Could not connect to $PROCESSCLIENTSHARE"
    }
    if ( test-path "$PROCESSCLIENTSHARE\$CLIENTNAME" ) {
      Add-Content $LOG_FILE "File $CLIENTNAME sent to $PROCESSCLIENTSHARE"
    } else {
      Add-Content $LOG_FILE "Could not send $TEMPCFGFOLDER\$CLIENTNAME to $PROCESSCLIENTSHARE\$CLIENTNAME"
    }
    net use /delete $PROCESSCLIENTSHARE
}

#Call with initialchange if you are working with initial installation.
function initialchange {
    setConfig $burp_config_client_file "ratelimit" "$RATEFORLOCATION"
    setConfig $burp_config_client_file "server" "$SERVERADDRESS"
    setConfig $burp_config_client_file "status_port" "$SERVERSTATUSPORT"
    setConfig $burp_config_client_file "cname" "$CLIENTNAME"
    setConfig $burp_config_client_file "backup_script_post" "C:/Program Files/Burp/burp_clientconfig3.bat"
    vssadmin resize shadowstorage /For=C: /On=C: /MaxSize=6%
	  schtasks /Change /TN "burp cron" /TR "%systemroot%\system32\WindowsPowershell\v1.0\powershell.exe -ExecutionPolicy Bypass -File '%programfiles%\burp\burp_clientconfig3.ps1' backup"
    schtasks /query /TN "burp cron"
    if ($LASTEXITCODE -match "1" ) {
        Add-Content $LOG_FILE "schedule task could not be set"
    } else {
        Add-Content $LOG_FILE "schedule task burp cron was set"
    }
    removeConfig $burp_config_client_file "include"
    send_file initialchange
}

function uninstall {
    send_file uninstall
}


Write-host "Checking $saction to perform"
# Actions to perform when running the script:
switch ($saction) {
    
    pre { pre }
    post { post $level }
    initialchange { initialchange }
	
    backup {
            Write-host "Executing backup option"
            backup }
    
    uninstall { uninstall }
}

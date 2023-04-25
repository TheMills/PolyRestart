# Restart Poly devices
# Using XML file for devices
# Logging to txt file

# Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

 #Add logging function
.\LogFunction.ps1

LogMessage "----Script started----"

# get the XML file with the devices
$xmlFile = $PSScriptRoot+"\PolyDevices.xml"
try {
    [xml]$polyDevices = Get-Content $xmlFile
    LogMessage "Devicefile '$xmlFile' found"
}
catch {
    LogMessage "Devicefile '$xmlFile' error: $($_.Exception)"
}

if($polyDevices.HasChildNodes -and $polyDevices.PolyDevices.HasChildNodes) { 

    #Check if we can use -SkipCertificateCheck on webrequest to ignore SSL error
    [bool]$skipSSLHack = $false;
    [string]$SkipCertificateCheck = $null
    [double]$PSVer = $PSVersionTable.PSVersion.Major.ToString() + "." + $PSVersionTable.PSVersion.Minor.ToString()
    if($PSVer -ge [double]"6.0") {
        LogMessage "PS version greater than 6, skipping SSL hack"
        $skipSSLHack = $true
        $SkipCertificateCheck = "-SkipCertificateCheck"
    }

    # If running Powershell earlier than version 6, then we need this to prevent SSL Cert error
    if(-not $skipSSLHack) {
        LogMessage "PS version earlier than 6, doing SSL hack"
        Add-Type @"
        using System.Net;
        using System.Security.Cryptography.X509Certificates;
        public class TrustAllCertsPolicy : ICertificatePolicy {
            public bool CheckValidationResult(
                ServicePoint srvPoint, X509Certificate certificate,
                WebRequest request, int certificateProblem) {
                    return true;
                }
        }
"@
        [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
    }

    # starting splat parameters for login and reboot webrequests
    $loginParams = @{
        Method='POST'
        ContentType='application/json'
    }

    $rebootParams = @{
        Method      = 'POST'
        Body        = "{`"action`" : `"reboot`"}"
        ContentType = 'application/json'
    }

    # If running PS ver. 6 or above, we just use -SkipCertificateCheck in the request
    if($skipSSLHack) {
        $loginParams.Add("SkipCertificateCheck",$null)
        $rebootParams.Add("SkipCertificateCheck",$null)
    }

    # Call each device in xml file and first login, then reboot
    foreach($device in $polyDevices.PolyDevices.device) {

        # set login parameters
        $jsonLogin = 
        '{
            "user" : "' + $device.user + '",
            "password" : "' + $device.pass + '"
        }'

        # add to login and reboot splat parameters
        $loginParams.Uri = "https://" + $device.ip + "/rest/session";
        $loginParams.Body = $jsonLogin;
        $rebootParams.Uri = "https://" + $device.ip + "/rest/system/reboot";
        
        try {
            # login to the REST API
            # $logonResp = Invoke-RestMethod @loginParams -SessionVariable sessVar
            # $logonResp = Invoke-WebRequest @loginParams -SessionVariable sessVar
            $logonResp = Invoke-RestMethod @loginParams -SessionVariable sessVar

            try {
                # reboot device
                $rebootResp = Invoke-WebRequest @rebootParams -WebSession $sessVar
                LogMessage "$($device.name) restarted with status: $($rebootResp.Content)"
            }
            catch {
                # if theres errors in the reboot request, they'll end here
                LogMessage "Couldn't restart $($device.name) on $($device.ip): Error: $($_.Exception.Message)"
            }
        }
        catch {
            # if theres errors in the login request, they'll end here
            LogMessage "Couldn't login to $($device.name) on $($device.ip): Error: $($_.Exception.Message)"
        }
    }
}

LogMessage "Script done!`n"
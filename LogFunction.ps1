Function LogMessage() 
{
 param
    (
    [Parameter(Mandatory=$true)] [string] $Message
    )
 
    Try {
        #Get the current date
        $LogDate = (Get-Date).tostring("yyyyMMdd")
 
        #Get the Location of the script
        If ($psise) {
            $CurrentDir = Split-Path $psise.CurrentFile.FullPath
        }
        Else {
            $CurrentDir = $Global:PSScriptRoot
        }
 
        #Frame Log File with Current Directory and date
        $LogFile = $CurrentDir+ "\" + $LogDate + ".txt"
 
        #Add Content to the Log File
        $TimeStamp = (Get-Date).toString("dd/MM/yyyy HH:mm:ss:fff tt")
        $Line = "$TimeStamp - $Message"
        Add-content -Path $Logfile -Value $Line
    }
    Catch {
        Write-host -f Red "Error:" $_.Exception.Message
    }
}
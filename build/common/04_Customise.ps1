<# 
    .SYNOPSIS
        Customise a Windows image for use as an WVD/XenApp VM in Azure.
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $False)]
    [System.String] $LogPath = "$env:SystemRoot\Logs\Packer",

    [Parameter(Mandatory = $False)]
    [System.String] $Path = "$env:SystemDrive\Apps\image-customise",

    [Parameter(Mandatory = $False)]
    [System.String] $InvokeScript = "Invoke-Scripts.ps1"
)

# Set $VerbosePreference so full details are sent to the log; Make Invoke-WebRequest faster
$VerbosePreference = "Continue"
$ProgressPreference = "SilentlyContinue"

#region Script logic
Write-Host " Start: Customise."
$Script = Get-ChildItem -Path $Path -Filter $InvokeScript -Recurse | Select-Object -First 1

# Validate customisation scripts; Run scripts
If ($Null -ne $Script) {
    try {
        Push-Location -Path $Script.DirectoryName
        Write-Host " Running script: $($Script.FullName)."
        . $Script.FullName -Path $Path
        Pop-Location
    }
    catch {
        Write-Warning -Message " ERR: $($Script.FullName) error with: $($_.Exception.Message)."
    }
}
Else {
    Write-Warning -Message " ERR: Could not find $InvokeScript in $Path."
}

Write-Host " Complete: Customise."
#endregion

<#
    .SYNOPSIS
        Customise a Windows image for use as an WVD/XenApp VM in Azure.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $False)]
    [System.String] $Path = "$env:SystemDrive\Apps\image-customise\src",

    [Parameter(Mandatory = $False)]
    [System.String] $InvokeScript = "Install-Defaults.ps1"
)

# Make Invoke-WebRequest faster
$ProgressPreference = "SilentlyContinue"

#region Script logic
Write-Host " Start: Customise."
Get-ChildItem -Path $Path
$Script = Get-ChildItem -Path $Path -Filter $InvokeScript -Recurse | Select-Object -First 1

# Validate customisation scripts; Run scripts
If ($Null -ne $Script) {
    try {
        Push-Location -Path $Path
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

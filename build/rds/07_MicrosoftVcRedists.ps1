#Requires -Modules VcRedist
<#
    .SYNOPSIS
        Install evergreen core applications.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $False)]
    [System.String] $Path = "$env:SystemDrive\Apps\Microsoft\VcRedist"
)

#region Script logic
# Set $VerbosePreference so full details are sent to the log; Make Invoke-WebRequest faster
$VerbosePreference = "Continue"
$ProgressPreference = "SilentlyContinue"

# Run tasks/install apps
Write-Host " Microsoft Visual C++ Redistributables"
New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null

Write-Host " Downloading Microsoft Visual C++ Redistributables"
Save-VcRedist -VcList (Get-VcList) -Path $Path > $Null

Write-Host " Installing Microsoft Visual C++ Redistributables"
Install-VcRedist -VcList (Get-VcList) -Path $Path -Silent -Verbose | Out-Null

# If (Test-Path -Path $Path) { Remove-Item -Path $Path -Recurse -Confirm:$False -ErrorAction "SilentlyContinue" }
Write-Host " Complete: VcRedists."
#endregion

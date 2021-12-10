<# 
    .SYNOPSIS
        Preps a RDS/WVD image for customisation.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $False)]
    [System.String] $LogPath = "$env:SystemRoot\Logs\Packer",

    [Parameter(Mandatory = $False)]
    [System.String] $Path = "$env:SystemDrive\Apps\Prep"
)

# Ready image
Write-Output " Disable Windows Defender real time scan"
Set-MpPreference -DisableRealtimeMonitoring $true

# Create target folder
New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null
New-Item -Path $LogPath -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null

Write-Output " Disable Windows Store updates"
REG add HKLM\Software\Policies\Microsoft\Windows\CloudContent /v "DisableWindowsConsumerFeatures" /d 1 /t "REG_DWORD" /f
REG add HKLM\Software\Policies\Microsoft\WindowsStore /v "AutoDownload" /d 2 /t "REG_DWORD" /f

Write-Host " Complete: PrepImage."

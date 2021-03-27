<# 
    .SYNOPSIS
        Sysprep image.
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $False)]
    [System.String] $Path = "$env:SystemDrive\Apps"
)

# Re-enable Defender
Write-Output " Enable Windows Defender real time scan"
Set-MpPreference -DisableRealtimeMonitoring $false
Write-Output " Enable Windows Store updates"
reg delete HKLM\Software\Policies\Microsoft\Windows\CloudContent /v DisableWindowsConsumerFeatures /f
reg delete HKLM\Software\Policies\Microsoft\WindowsStore /v AutoDownload /f

# Remove C:\Apps folder
try {
    Remove-Item -Path $Path -Recurse -Force
}
catch {
    Write-Warning "Failed to remove $Path with: $($_.Exception.Message)."
}

# Sysprep
#region Prepare
Write-Output " Run Sysprep"
If (Get-Service -Name "RdAgent" -ErrorAction "SilentlyContinue") { Set-Service -Name "RdAgent" -StartupType "Disabled" }
If (Get-Service -Name "WindowsAzureTelemetryService" -ErrorAction "SilentlyContinue") { Set-Service -Name "WindowsAzureTelemetryService" -StartupType "Disabled" }
If (Get-Service -Name "WindowsAzureGuestAgent" -ErrorAction "SilentlyContinue") { Set-Service -Name "WindowsAzureGuestAgent" -StartupType "Disabled" }
Remove-ItemProperty -Path 'HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Setup\\SysPrepExternal\\Generalize' -Name '*'
#endregion

#region Sysprep
$RegPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State"
& $env:SystemRoot\System32\Sysprep\Sysprep.exe /oobe /generalize /quiet /quit
While ($True) {
    $imageState = Get-ItemProperty $RegPath | Select-Object ImageState
    If ($imageState.ImageState -ne 'IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE') {
        Write-Output $imageState.ImageState
        Start-Sleep -s 10 
    }
    Else {
        Break
    }
}
$imageState = Get-ItemProperty $RegPath | Select-Object ImageState
Write-Output $imageState.ImageState
#endregion
Write-Host " Complete: Sysprep."

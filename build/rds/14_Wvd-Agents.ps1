<# 
    .SYNOPSIS
        Downloads / installs the Windows Virtual Desktop agents and services
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $False)]
    [System.String] $LogPath = "$env:SystemRoot\Logs\Packer",

    [Parameter(Mandatory = $False)]
    [System.String] $Path = "$env:SystemDrive\App\Microsoft\Wvd"
)


#region Script logic
# Set $VerbosePreference so full details are sent to the log; Make Invoke-WebRequest faster
$VerbosePreference = "Continue"
$ProgressPreference = "SilentlyContinue"

# Create target folder
New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null

# Run tasks/install apps
#region RTC service
$App = Get-EvergreenApp -Name "MicrosoftWvdRtcService" | Where-Object { $_.Architecture -eq "x64"} | Select-Object -First 1
If ($App) {
    
    # Download
    Write-Host " Downloading Microsoft Remote Desktop WebRTC Redirector Service"
    $OutFile = Save-EvergreenApp -InputObject $App -Path $Path -WarningAction "SilentlyContinue"

    # Install RTC
    try {
        Write-Host " Installing Microsoft Remote Desktop WebRTC Redirector Service"
        $params = @{
            FilePath     = "$env:SystemRoot\System32\msiexec.exe"
            ArgumentList = "/package $($OutFile.FullName) ALLUSERS=1 /quiet"
            WindowStyle  = "Hidden"
            Wait         = $True
            Verbose      = $True
        }
        Start-Process @params
    }
    catch {
        Write-Warning -Message " ERR: Failed to install Microsoft Remote Desktop WebRTC Redirector Service."
    }
    Write-Host " Done"
}
Else {
    Write-Warning -Message " ERR: Failed to retrieve Microsoft Remote Desktop WebRTC Redirector Service"
}
#endregion

#region Boot Loader
Write-Host " Microsoft Windows Virtual Desktop Agent Bootloader"
$App = Get-EvergreenApp -Name "MicrosoftWvdBootLoader" | Where-Object { $_.Architecture -eq "x64"} | Select-Object -First 1
If ($App) {
    If (!(Test-Path $Path)) { New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null }

    # Download
    Write-Host " Downloading Microsoft Windows Virtual Desktop Agent Bootloader"
    $OutFile = Save-EvergreenApp -InputObject $App -Path $Path -WarningAction "SilentlyContinue"

    # Install
    Write-Host " Installing Microsoft Windows Virtual Desktop Agent Bootloader"
    try {
        $params = @{
            FilePath     = "$env:SystemRoot\System32\msiexec.exe"
            ArgumentList = "/package $($OutFile.FullName) ALLUSERS=1 /quiet"
            WindowStyle  = "Hidden"
            Wait         = $True
            Verbose      = $True
        }
        Start-Process @params
    }
    catch {
        Write-Warning -Message " ERR: Failed to install Microsoft Windows Virtual Desktop Agent Bootloader"
    }
    Write-Host " Done"
}
Else {
    Write-Warning -Message " ERR: Failed to Microsoft Windows Virtual Desktop Agent Bootloader"
}
#endregion

#region Infra agent
Write-Host " Microsoft WVD Infrastructure Agent"
$App = Get-EvergreenApp -Name "MicrosoftWvdInfraAgent" | Where-Object { $_.Architecture -eq "x64"}
If ($App) {

    # Download
    Write-Host " Downloading Microsoft WVD Infrastructure Agent"
    $OutFile = Save-EvergreenApp -InputObject $App -Path $Path -WarningAction "SilentlyContinue"

    # Install
    <#
    Write-Host " Installing Microsoft WVD Infrastructure Agent"
    try {
        $params = @{
            FilePath     = "$env:SystemRoot\System32\msiexec.exe"
            ArgumentList = "/package $($OutFile.FullName) ALLUSERS=1 /quiet"
            WindowStyle  = "Hidden"
            Wait         = $True
            PassThru     = $True
            Verbose      = $True
        }
        $process = Start-Process @params
    }
    catch {
        Throw "Failed to install Microsoft WVD Infrastructure Agent."
    }
    Write-Host " Done"
    #>
}
Else {
    Write-Warning -Message " ERR: Failed to retrieve Microsoft WVD Infrastructure Agent"
}
#endregion

# If (Test-Path -Path $Path) { Remove-Item -Path $Path -Recurse -Confirm:$False -ErrorAction "SilentlyContinue" }
Write-Host " Complete: WvdAgents."
#endregion

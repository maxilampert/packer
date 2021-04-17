<# 
    .SYNOPSIS
        Downloads / installs the Windows Virtual Desktop agents and services
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $False)]
    [System.String] $Log = "$env:SystemRoot\Logs\PackerImagePrep.log",

    [Parameter(Mandatory = $False)]
    [System.String] $Path = "$env:SystemDrive\App\Microsoft\Wvd"
)

#region Functions
Function Global:Invoke-Process {
    <#PSScriptInfo 
    .VERSION 1.4 
    .GUID b787dc5d-8d11-45e9-aeef-5cf3a1f690de 
    .AUTHOR Adam Bertram 
    .COMPANYNAME Adam the Automator, LLC 
    .TAGS Processes 
    #>

    <# 
    .DESCRIPTION 
    Invoke-Process is a simple wrapper function that aims to "PowerShellyify" launching typical external processes. There 
    are lots of ways to invoke processes in PowerShell with Invoke-Process, Invoke-Expression, & and others but none account 
    well for the various streams and exit codes that an external process returns. Also, it's hard to write good tests 
    when launching external proceses. 
 
    This function ensures any errors are sent to the error stream, standard output is sent via the Output stream and any 
    time the process returns an exit code other than 0, treat it as an error. 
    #> 
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $FilePath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String] $ArgumentList
    )

    $ErrorActionPreference = 'Stop'

    try {
        $stdOutTempFile = "$env:TEMP\$((New-Guid).Guid)"
        $stdErrTempFile = "$env:TEMP\$((New-Guid).Guid)"

        $startProcessParams = @{
            FilePath               = $FilePath
            ArgumentList           = $ArgumentList
            RedirectStandardError  = $stdErrTempFile
            RedirectStandardOutput = $stdOutTempFile
            Wait                   = $true
            PassThru               = $true
            NoNewWindow            = $true
        }
        if ($PSCmdlet.ShouldProcess("Process [$($FilePath)]", "Run with args: [$($ArgumentList)]")) {
            $cmd = Start-Process @startProcessParams
            $cmdOutput = Get-Content -Path $stdOutTempFile -Raw
            $cmdError = Get-Content -Path $stdErrTempFile -Raw
            if ($cmd.ExitCode -ne 0) {
                if ($cmdError) {
                    throw $cmdError.Trim()
                }
                if ($cmdOutput) {
                    throw $cmdOutput.Trim()
                }
            }
            else {
                if ([System.String]::IsNullOrEmpty($cmdOutput) -eq $false) {
                    Write-Output -InputObject $cmdOutput
                }
            }
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
    finally {
        Remove-Item -Path $stdOutTempFile, $stdErrTempFile -Force -ErrorAction Ignore
    }
}
#endregion

#region Script logic
# Set $VerbosePreference so full details are sent to the log; Make Invoke-WebRequest faster
$VerbosePreference = "Continue"
$ProgressPreference = "SilentlyContinue"

# Create target folder
New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null

# Run tasks/install apps
#region RTC service
$App = Get-EvergreenApp -Name "MicrosoftWvdRtcService" | Where-Object { $_.Architecture -eq "x64"}
If ($App) {
    
    # Download
    $OutFile = Save-EvergreenApp -InputObject $App -Path $Path

    # Install RTC
    Write-Host " Installing Microsoft Remote Desktop WebRTC Redirector Service"
    try {
        $params = @{
            FilePath     = "$env:SystemRoot\System32\msiexec.exe"
            ArgumentList = "/package $($OutFile.Path) ALLUSERS=1 /quiet"
            Verbose      = $True
        }
        Invoke-Process @params
    }
    catch {
        Throw "Failed to install Microsoft Remote Desktop WebRTC Redirector Service."
    }
    Write-Host " Done"
}
Else {
    Write-Host " Failed to retrieve Microsoft Remote Desktop WebRTC Redirector Service"
}
#endregion

#region Boot Loader
Write-Host " Microsoft Windows Virtual Desktop Agent Bootloader"
Write-Host " Downloading Microsoft Windows Virtual Desktop Agent Bootloader"
$App = Get-EvergreenApp -Name "MicrosoftWvdBootLoader" | Where-Object { $_.Architecture -eq "x64"}
If ($App) {
    If (!(Test-Path $Path)) { New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null }

    # Download
    $OutFile = Save-EvergreenApp -InputObject $App -Path $Path

    # Install
    Write-Host " Installing Microsoft Windows Virtual Desktop Agent Bootloader"
    try {
        $params = @{
            FilePath     = "$env:SystemRoot\System32\msiexec.exe"
            ArgumentList = "/package $($OutFile.Path) ALLUSERS=1 /quiet"
            Verbose      = $True
        }
        Invoke-Process @params
    }
    catch {
        Throw "Failed to install Microsoft Windows Virtual Desktop Agent Bootloader"
    }
    Write-Host " Done"
}
Else {
    Write-Host " Failed to Microsoft Windows Virtual Desktop Agent Bootloader"
}
#endregion

#region Infra agent
Write-Host " Microsoft WVD Infrastructure Agent"
Write-Host " Downloading Microsoft WVD Infrastructure Agent"
$Agent = Get-EvergreenApp -Name "MicrosoftWvdInfraAgent" | Where-Object { $_.Architecture -eq "x64"}
If ($Agent) {

    # Download
    $OutFile = Save-EvergreenApp -InputObject $Agent -Path $Path

    # Install
    <#
    Write-Host " Installing Microsoft WVD Infrastructure Agent"
    try {
        $ArgumentList = "/package $OutFile ALLUSERS=1 /quiet"
        Invoke-Process -FilePath "$env:SystemRoot\System32\msiexec.exe" -ArgumentList $ArgumentList -Verbose
    }
    catch {
        Throw "Failed to install Microsoft WVD Infrastructure Agent."
    }
    Write-Host " Done"
    #>
}
Else {
    Write-Host " Failed to retrieve Microsoft WVD Infrastructure Agent"
}
#endregion

If (Test-Path -Path $Path) { Remove-Item -Path $Path -Recurse -Confirm:$False -ErrorAction "SilentlyContinue" }
Write-Host " Complete: WvdAgents."
#endregion

<# 
    .SYNOPSIS
        Downloads / installs the Windows Virtual Desktop agents and services
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $False)]
    [System.String] $Log = "$env:SystemRoot\Logs\PackerImagePrep.log",

    [Parameter(Mandatory = $False)]
    [System.String] $Target = "$env:SystemDrive\Apps"
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

Function Install-MicrosoftWvdRtcService ($Path) {
    Write-Host "================ Microsoft Remote Desktop WebRTC Redirector Service"
    Write-Host "================ Downloading Microsoft Remote Desktop WebRTC Redirector Service"
    $Rtc = Get-MicrosoftWvdRtcService | Where-Object { $_.Architecture -eq "x64" }
    
    If ($Rtc) {
        If (!(Test-Path $Path)) { New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null }

        # Download
        $OutFile = Join-Path -Path $Path -ChildPath $Rtc.Filename
        Write-Host "================ Downloading to: $OutFile"
        try {
            Invoke-WebRequest -Uri $Rtc.URI -OutFile $OutFile -UseBasicParsing
            If (Test-Path -Path $OutFile) { Write-Host "================ Downloaded: $OutFile." }
        }
        catch {
            Throw "Failed to download Microsoft Remote Desktop WebRTC Redirector Service."
        }

        # Install
        Write-Host "================ Installing Microsoft Remote Desktop WebRTC Redirector Service"
        try {
            $ArgumentList = "/package $OutFile ALLUSERS=1 /quiet"
            Invoke-Process -FilePath "$env:SystemRoot\System32\msiexec.exe" -ArgumentList $ArgumentList -Verbose
        }
        catch {
            Throw "Failed to install Microsoft Remote Desktop WebRTC Redirector Service."
        }
        Write-Host "================ Done"
    }
    Else {
        Write-Host "================ Failed to retreive Microsoft Remote Desktop WebRTC Redirector Service"
    }
}

Function Install-MicrosoftWvdBootLoader ($Path) {
    Write-Host "================ Microsoft Windows Virtual Desktop Agent Bootloader"
    Write-Host "================ Downloading Microsoft Windows Virtual Desktop Agent Bootloader"
    $Rtc = Get-MicrosoftWvdBootLoader | Where-Object { $_.Architecture -eq "x64" }
    
    If ($Rtc) {
        If (!(Test-Path $Path)) { New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null }

        # Download
        $OutFile = Join-Path -Path $Path -ChildPath $Rtc.Filename
        Write-Host "================ Downloading to: $OutFile"
        try {
            Invoke-WebRequest -Uri $Rtc.URI -OutFile $OutFile -UseBasicParsing
            If (Test-Path -Path $OutFile) { Write-Host "================ Downloaded: $OutFile." }
        }
        catch {
            Throw "Failed to download Microsoft Windows Virtual Desktop Agent Bootloader"
        }

        # Install
        Write-Host "================ Installing Microsoft Windows Virtual Desktop Agent Bootloader"
        try {
            $ArgumentList = "/package $OutFile ALLUSERS=1 /quiet"
            Invoke-Process -FilePath "$env:SystemRoot\System32\msiexec.exe" -ArgumentList $ArgumentList -Verbose
        }
        catch {
            Throw "Failed to install Microsoft Windows Virtual Desktop Agent Bootloader"
        }
        Write-Host "================ Done"
    }
    Else {
        Write-Host "================ Failed to Microsoft Windows Virtual Desktop Agent Bootloader"
    }
}

Function Install-MicrosoftWvdInfraAgent ($Path) {
    Write-Host "================ Microsoft WVD Infrastructure Agent"
    Write-Host "================ Downloading Microsoft WVD Infrastructure Agent"
    $Agent = Get-MicrosoftWvdInfraAgent | Where-Object { $_.Architecture -eq "x64" }
    
    If ($Agent) {
        If (!(Test-Path $Path)) { New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null }

        # Download
        $OutFile = Join-Path -Path $Path -ChildPath $Agent.Filename
        Write-Host "================ Downloading to: $OutFile"
        try {
            Invoke-WebRequest -Uri $Agent.URI -OutFile $OutFile -UseBasicParsing
            If (Test-Path -Path $OutFile) { Write-Host "================ Downloaded: $OutFile." }
        }
        catch {
            Throw "Failed to download Microsoft WVD Infrastructure Agent."
        }

        # Install
        <#
        Write-Host "================ Installing Microsoft WVD Infrastructure Agent"
        try {
            $ArgumentList = "/package $OutFile ALLUSERS=1 /quiet"
            Invoke-Process -FilePath "$env:SystemRoot\System32\msiexec.exe" -ArgumentList $ArgumentList -Verbose
        }
        catch {
            Throw "Failed to install Microsoft WVD Infrastructure Agent."
        }
        Write-Host "================ Done"
        #>
    }
    Else {
        Write-Host "================ Failed to retreive Microsoft WVD Infrastructure Agent"
    }
}

Function Install-ConnectionExperienceIndicator ($Path) {

    Write-Host "================ Connection Experience Indicator"
    Write-Host "================ Downloading Connection Experience Indicator"

    # Parameters
    $Url = "https://bit.ly/2RrQTd3"
    $OutFile = Join-Path -Path $Path -ChildPath "ConnectionExperienceIndicator.zip"
    If (!(Test-Path $Path)) { New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null }

    # Download the file
    try {
        Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing
    }
    catch {
        Throw "Failed to download Connection Experience Indicator."
        Break
    }

    # Extract the zip file
    Expand-Archive -Path $OutFile -DestinationPath $Path -Verbose
    Write-Host "================ Done"
}
#endregion

#region Script logic
# Set $VerbosePreference so full details are sent to the log; Make Invoke-WebRequest faster
$VerbosePreference = "Continue"
$ProgressPreference = "SilentlyContinue"

# Set TLS to 1.2; Create target folder
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
New-Item -Path $Target -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null

# Run tasks/install apps
Install-MicrosoftWvdRtcService -Path "$Target\Wvd"
Install-MicrosoftWvdBootLoader -Path "$Target\Wvd"
#Install-MicrosoftWvdInfraAgent -Path "$Target\Wvd"
Install-ConnectionExperienceIndicator -Path "$Target\ConnectionExperienceIndicator"
Write-Host "================ Complete: WvdAgents."
#endregion

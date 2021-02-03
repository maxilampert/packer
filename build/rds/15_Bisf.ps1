<# 
    .SYSOPSIS
        Optimise and seal a Windows image.
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

Function Invoke-WindowsDefender {
    # Run Windows Defender quick scan
    Write-Host "=============== Running Windows Defender"
    Start-Process -FilePath "$env:ProgramFiles\Windows Defender\MpCmdRun.exe" -ArgumentList "-SignatureUpdate -MMPC" -Wait
    Start-Process -FilePath "$env:ProgramFiles\Windows Defender\MpCmdRun.exe" -ArgumentList "-Scan -ScanType 1" -Wait
    # Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\RemovalTools\MRT" -Name "GUID" -Value ""
}

Function Invoke-Bisf ($Path) {
    Write-Host "========== Base Image Script Framework"
    If (!(Test-Path $Path)) { New-Item -Path $Path -ItemType Directory -Force -ErrorAction SilentlyContinue > $Null }

    Write-Host "=============== Downloading BIS-F"
    #$url = (Get-BISF).URI
    $url = "https://github.com/EUCweb/BIS-F/archive/master.zip"
    Invoke-WebRequest -Uri $url -OutFile "$Path\$(Split-Path $url -Leaf)" -UseBasicParsing
    Expand-Archive -Path "$Path\$(Split-Path $url -Leaf)" -DestinationPath "$Path" -Force -Verbose

    $url = "https://raw.githubusercontent.com/aaronparker/packer/main/tools/rds/bisf/BisfConfig.zip"
    Invoke-WebRequest -Uri $url -OutFile "$Path\$(Split-Path $url -Leaf)" -UseBasicParsing
    Expand-Archive -Path "$Path\$(Split-Path $url -Leaf)" -DestinationPath "$Path" -Force -Verbose

    Write-Host "=============== Installing BIS-F"
    #Start-Process -FilePath "$Path\$(Split-Path $url -Leaf)" -ArgumentList "/SILENT" -Wait
    Remove-Item -Path "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Base Image Script Framework (BIS-F).lnk" -Force -ErrorAction SilentlyContinue
    New-Item -Path "${env:ProgramFiles(x86)}\Base Image Script Framework (BIS-F)" -ItemType Directory -Force -ErrorAction SilentlyContinue > $Null
    Copy-Item -Path "$Path\BISFSharedConfig.json" -Destination "${env:ProgramFiles(x86)}\Base Image Script Framework (BIS-F)\BISFSharedConfig.json"

    Write-Host "=============== Running BIS-F"
    & "$Path\BIS-F-master\Framework\PrepBISF_Start.ps1"
    & "${env:ProgramFiles(x86)}\Base Image Script Framework (BIS-F)\Framework\PrepBISF_Start.ps1"
}
#endregion

#region Script logic
# Set $VerbosePreference so full details are sent to the log; Make Invoke-WebRequest faster
$VerbosePreference = "Continue"
$ProgressPreference = "SilentlyContinue"

# Set TLS to 1.2; Create target folder
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
New-Item -Path $Target -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null

# Seal image tasks
Invoke-WindowsDefender
# Invoke-Bisf -Path "$Target\Bisf"

Write-Host "================ Complete: Bisf."
#endregion

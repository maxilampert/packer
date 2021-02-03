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

Function Invoke-CitrixOptimizer ($Path) {
    Write-Host "========== Citrix Optimizer"
    If (!(Test-Path $Path)) { New-Item -Path $Path -ItemType Directory -Force -ErrorAction SilentlyContinue > $Null }

    Write-Host "=============== Downloading Citrix Optimizer"
    $url = "https://raw.githubusercontent.com/aaronparker/packer/main/tools/rds/optimizer/CitrixOptimizer.zip"
    Invoke-WebRequest -Uri $url -OutFile "$Path\$(Split-Path $url -Leaf)" -UseBasicParsing
    Expand-Archive -Path "$Path\$(Split-Path $url -Leaf)" -DestinationPath $Path -Force -Verbose

    # Download templates
    Write-Host "=============== Downloading Citrix Optimizer template"
    If (!(Test-Path $Path)) { New-Item -Path "$Path\Templates" -ItemType Directory -Force -ErrorAction SilentlyContinue > $Null }
    Switch -Regex ((Get-WmiObject Win32_OperatingSystem).Caption) {
        "Microsoft Windows Server*" {
            $url = "https://raw.githubusercontent.com/aaronparker/packer/main/tools/rds/optimizer/WindowsServer2019-Defender-Azure.xml"
        }
        "Microsoft Windows 10 Enterprise for Virtual Desktops" {
            $url = "https://raw.githubusercontent.com/aaronparker/packer/main/tools/rds/optimizer/Windows101909-Defender-Azure.xml"
        }
        "Microsoft Windows 10*" {
            $url = "https://raw.githubusercontent.com/aaronparker/packer/main/tools/rds/optimizer/Windows101909-Defender-Azure.xml"
        }
    }
    Invoke-WebRequest -Uri $url -OutFile "$Path\Templates\$(Split-Path $url -Leaf)" -UseBasicParsing

    Write-Host "=============== Running Citrix Optimizer"
    & "$Path\CtxOptimizerEngine.ps1" -Source "$Path\Templates\$(Split-Path $url -Leaf)" -Mode execute -OutputHtml "$Path\CitrixOptimizer.html"
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
# Invoke-CitrixOptimizer -Path "$Target\CitrixOptimizer"

Write-Host "================ Complete: CitrixOptimizer."
#endregion

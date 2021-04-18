<# 
    .SYNOPSIS
        Optimise and seal a Windows image.
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $False)]
    [System.String] $LogPath = "$env:SystemRoot\Logs\Packer",

    [Parameter(Mandatory = $False)]
    [System.String] $Path = "$env:SystemDrive\Apps\Tools",

    [Parameter(Mandatory = $False)]
    [System.String] $OptimizerTemplate = "Custom-Windows10-20H2.xml"
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

# Set TLS to 1.2; Create target folder
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null

#region Citrix Optimizer
$CtxPath = "CitrixOptimizer"
Write-Host "Using path: $Path."
$Installer = Get-ChildItem -Path $Path -Filter "$CtxPath.zip" -Recurse -ErrorAction "SilentlyContinue"
If ($Null -eq $Installer) {
    try {
        $params = @{
            Uri             = "https://raw.githubusercontent.com/aaronparker/packer/main/tools/rds/citrixoptimizer/CitrixOptimizer.zip"
            OutFile         = (Join-Path -Path $Path -ChildPath "$CtxPath.zip")
            UseBasicParsing = $True
            ErrorAction     = "SilentlyContinue"
        }
        Invoke-WebRequest @params
    }
    catch {
        Write-Warning -Message "Invoke-WebRequest exited with: $($_.Exception.Message)."
    }
    $Installer = Get-ChildItem -Path $Path -Filter "$CtxPath.zip" -Recurse -ErrorAction "SilentlyContinue"
}
If ($Installer) {
    Write-Host "Found zip file: $($Installer.FullName)."
    Expand-Archive -Path $Installer.FullName -DestinationPath $Path -Force -Verbose

    $Template = Get-ChildItem -Path $Path -Recurse -Filter $OptimizerTemplate
    If ($Template) {
        Write-Host "Found template file: $($Template.FullName)."
        try {
            $OptimizerBin = Get-ChildItem -Path $Path -Recurse -Filter "CtxOptimizerEngine.ps1"
            Push-Location -Path $OptimizerBin.Directory
            Write-Host "Running: $($OptimizerBin.FullName) -Source $($Template.FullName) -Mode execute"
            Write-Host "Output will be saved to: $Path\$CtxPath.html."
            & $OptimizerBin.FullName -Source $Template.FullName -Mode execute -OutputHtml "$Path\$CtxPath.html"
            Pop-Location
        }
        catch {
            Write-Warning -Message "ERROR: Citrix Optimizer exited with: $($_.Exception.Message)."
        }
    }
    Else {
        Write-Warning -Message "ERROR: Failed to find Citrix Optimizer template: $OptimizerTemplate in $Path."
    }
}
Else {
    Write-Warning -Message "ERROR: Failed to find Citrix Optimizer in: $Path."
}
#endregion

# If (Test-Path -Path $Path) { Remove-Item -Path $Path -Recurse -Confirm:$False -ErrorAction "SilentlyContinue" }
Write-Host " Complete: Optimise."
#endregion

<# 
    .SYNOPSIS
        Install evergreen core applications.
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $False)]
    [System.String] $Log = "$env:SystemRoot\Logs\PackerImagePrep.log",

    [Parameter(Mandatory = $False)]
    [System.String] $Target = "$env:SystemDrive\Apps\Adobe\AcrobatReaderDC"
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
#endregion Functions


#region Script logic
# Set $VerbosePreference so full details are sent to the log; Make Invoke-WebRequest faster
$VerbosePreference = "Continue"
$ProgressPreference = "SilentlyContinue"

# Create target folder
New-Item -Path $Target -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null

# Run tasks/install apps
# Enforce settings with GPO: https://www.adobe.com/devnet-docs/acrobatetk/tools/AdminGuide/gpo.html
# Download Reader installer and updater
Write-Host " Adobe Acrobat Reader DC"
$Reader = Get-EvergreenApp -Name "AdobeAcrobatReaderDC" | Where-Object { $_.Language -eq "English" -and $_.Architecture -eq $env:PROCESS_ARCHITECTURE }
If ($Reader) {
        
    # Download Adobe Acrobat Reader
    $OutFile = Save-EvergreenApp -InputObject $Reader -Path $Path

    # Install Adobe Acrobat Reader
    try {
        Write-Host " Installing Reader"
        $ArgumentList = "-sfx_nu /sALL /rps /l /msi EULA_ACCEPT=YES ENABLE_CHROMEEXT=0 DISABLE_BROWSER_INTEGRATION=1 ENABLE_OPTIMIZATION=YES ADD_THUMBNAILPREVIEW=0 DISABLEDESKTOPSHORTCUT=1"
        $params = @{
            FilePath     = $OutFile.Path
            ArgumentList = $ArgumentList
            Verbose      = $True
        }
        Invoke-Process @params
    }
    catch {
        Throw "Failed to install Adobe Acrobat Reader."
    }

    
    # Get the latest update; Download the updater if the updater version is greater than the installer
    $Updater = Get-EvergreenApp -Name "AdobeAcrobat" | Where-Object { $_.Product -eq "Reader" -and $_.Track -eq "DC" -and $_.Language -eq "Neutral" } | Select-Object -First 1
    If ($Updater.Version -gt $Reader.Version) {
        $UpdateOutFile = Save-EvergreenApp -InputObject $Updater -Path $Path
    }

    # Run post install actions
    Write-Host " Post install configuration Reader"
    $Executables = "$env:ProgramFiles\Adobe\Acrobat DC\Acrobat\Acrobat.exe", `
        "${env:ProgramFiles(x86)}\Adobe\Acrobat DC\Acrobat\Acrobat.exe", `
        "${env:ProgramFiles(x86)}\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe"
    If (Test-Path -Path $Executables) {

        # Update Adobe Acrobat Reader
        try {
            Write-Host " Installing update: $($msp.FullName)."
            $params = @{
                FilePath     = "$env:SystemRoot\System32\msiexec.exe"
                ArgumentList = "/update $($UpdateOutFile.Path) /quiet /qn"
                Verbose      = $True
            }
            Invoke-Process @params
        }
        catch {
            Throw "Failed to update Adobe Acrobat Reader."
        }

        # Configure update tasks
        Write-Host " Configure Reader services"
        Get-Service -Name "AdobeARMservice" -ErrorAction "SilentlyContinue" | Set-Service -StartupType "Disabled" -ErrorAction "SilentlyContinue"
        Get-ScheduledTask "Adobe Acrobat Update Task*" | Unregister-ScheduledTask -Confirm:$False -ErrorAction "SilentlyContinue"
    }
    Else {
        Write-Warning -Message " Cannot find Adobe Acrobat Reader install"
    }
}
Else {
    Write-Host " Failed to retrieve Adobe Acrobat Reader"
}

If (Test-Path -Path $Path) { Remove-Item -Path $Path -Recurse -Confirm:$False -ErrorAction "SilentlyContinue" }
Write-Host " Complete: AdobeAcrobatReaderDC."
#endregion

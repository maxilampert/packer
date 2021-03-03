<# 
    .SYNOPSIS
        Install evergreen core applications.
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

Function Install-AdobeReaderDC ($Path) {
    # Enforce settings with GPO: https://www.adobe.com/devnet-docs/acrobatetk/tools/AdminGuide/gpo.html
    # Download Reader installer and updater
    Write-Host "================ Adobe Acrobat Reader DC"
    Write-Host "================ Downloading Reader"
    $Reader = Get-AdobeAcrobatReaderDC | Where-Object { $_.Language -eq "English" -or $_.Language -eq "Neutral" }

    If ($Reader) {
        If (!(Test-Path $Path)) { New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null }

        $Installer = ($Reader | Where-Object { $_.Type -eq "Installer" | Sort-Object -Property "Version" -Descending })[-1]
        $Updater = ($Reader | Where-Object { $_.Type -eq "Updater" | Sort-Object -Property "Version" -Descending })[-1]
        
        # Download Adobe Acrobat Reader
        ForEach ($File in $Installer) {
            $OutFile = Join-Path -Path $Path -ChildPath (Split-Path -Path $File.Uri -Leaf)
            Write-Host "================ Downloading to: $OutFile."
            try {
                Invoke-WebRequest -Uri $File.Uri -OutFile $OutFile -UseBasicParsing
                If (Test-Path -Path $OutFile) { Write-Host "================ Downloaded: $OutFile." }
            }
            catch {
                Throw "Failed to download Adobe Acrobat Reader installer."
                Break
            }
        }
    
        # Download the updater if the updater version is greater than the installer
        If ($Updater.Version -gt $Installer.Version) {
            ForEach ($File in $Updater) {
                $OutFile = Join-Path -Path $Path -ChildPath (Split-Path -Path $File.Uri -Leaf)
                Write-Host "================ Downloading to: $OutFile."
                try {
                    Invoke-WebRequest -Uri $File.Uri -OutFile $OutFile -UseBasicParsing
                    If (Test-Path -Path $OutFile) { Write-Host "================ Downloaded: $OutFile." }
                }
                catch {
                    Throw "Failed to download Adobe Acrobat Reader update patch."
                    Break
                }
            }
        }
        Else {
            Write-Host "================ Installer already up to date, skipping patch file."
        }


        # Install Adobe Acrobat Reader
        Write-Host "================ Installing Reader"
        try {
            $ArgumentList = "-sfx_nu /sALL /rps /l /msi EULA_ACCEPT=YES ENABLE_CHROMEEXT=0 DISABLE_BROWSER_INTEGRATION=1 ENABLE_OPTIMIZATION=YES ADD_THUMBNAILPREVIEW=0 DISABLEDESKTOPSHORTCUT=1"
            $Installers = Get-ChildItem -Path $Path -Filter "*.exe"
            ForEach ($exe in $Installers) {
                $params = @{
                    FilePath     = $exe.FullName
                    ArgumentList = $ArgumentList
                    Verbose      = $True
                }
                Invoke-Process @params
            }
        }
        catch {
            Throw "Failed to install Adobe Acrobat Reader."
        }

        # Run post install actions
        Write-Host "================ Post install configuration Reader"
        $Paths = "$env:ProgramFiles\Adobe\Acrobat DC\Acrobat\Acrobat.exe", `
            "${env:ProgramFiles(x86)}\Adobe\Acrobat DC\Acrobat\Acrobat.exe", `
            "${env:ProgramFiles(x86)}\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe"
        If (Test-Path -Path $Paths) {

            # Update Adobe Acrobat Reader
            Write-Host "================ Update Reader"
            try {
                $Updates = Get-ChildItem -Path $Path -Filter "*.msp"
                ForEach ($msp in $Updates) {
                    Write-Host "================ Installing update: $($msp.FullName)."
                    Invoke-Process -FilePath "$env:SystemRoot\System32\msiexec.exe" -ArgumentList "/update $($msp.FullName) /quiet /qn" -Verbose
                }
            }
            catch {
                Throw "Failed to update Adobe Acrobat Reader."
            }

            # Configure update tasks
            Write-Host "================ Configure Reader services"
            Get-Service -Name "AdobeARMservice" -ErrorAction "SilentlyContinue" | Set-Service -StartupType "Disabled" -ErrorAction "SilentlyContinue"
            Get-ScheduledTask "Adobe Acrobat Update Task*" | Unregister-ScheduledTask -Confirm:$False -ErrorAction "SilentlyContinue"
        }
        Else {
            Write-Warning -Message "================ Cannot find Adobe Acrobat Reader install"
        }
        Write-Host "================ Done"
    }
    Else {
        Write-Host "================ Failed to retrieve Adobe Acrobat Reader"
    }
}
#endregion Functions


#region Script logic
# Set $VerbosePreference so full details are sent to the log; Make Invoke-WebRequest faster
$VerbosePreference = "Continue"
$ProgressPreference = "SilentlyContinue"

# Set TLS to 1.2; Create target folder
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
New-Item -Path $Target -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null

# Run tasks/install apps
Install-AdobeReaderDC -Path "$Target\AdobeReader"
Write-Host "================ Complete: AdobeAcrobatReaderDC."
#endregion

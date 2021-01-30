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
        
        # Download Adobe Reader
        ForEach ($File in $Installer) {
            $OutFile = Join-Path -Path $Path -ChildPath (Split-Path -Path $File.Uri -Leaf)
            Write-Host "================ Downloading to: $OutFile."
            try {
                Invoke-WebRequest -Uri $File.Uri -OutFile $OutFile -UseBasicParsing
                If (Test-Path -Path $OutFile) { Write-Host "================ Downloaded: $OutFile." }
            }
            catch {
                Throw "Failed to download Adobe Reader installer."
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
                    Throw "Failed to download Adobe Reader update patch."
                    Break
                }
            }
        }
        Else {
            Write-Host "================ Installer already up to date, skipping patch file."
        }

        # Get resource strings
        $res = Export-EvergreenFunctionStrings -AppName "AdobeAcrobatReaderDC"

        # Install Adobe Reader
        Write-Host "================ Installing Reader"
        try {
            $Installers = Get-ChildItem -Path $Path -Filter "*.exe"
            ForEach ($exe in $Installers) {
                Invoke-Process -FilePath $exe.FullName -ArgumentList $res.Install.Virtual.Arguments -Verbose
            }
        }
        catch {
            "Throw failed to install Adobe Reader."
        }

        # Run post install actions
        Write-Host "================ Post install configuration Reader"
        ForEach ($command in $res.Install.Virtual.PostInstall) {
            Invoke-Command -ScriptBlock ($executioncontext.invokecommand.NewScriptBlock($command))
        }

        # Update Adobe Reader
        Write-Host "================ Update Reader"
        try {
            $Updates = Get-ChildItem -Path $Path -Filter "*.msp"
            ForEach ($msp in $Updates) {
                Write-Host "================ Installing update: $($msp.FullName)."
                Invoke-Process -FilePath "$env:SystemRoot\System32\msiexec.exe" -ArgumentList "/update $($msp.FullName) /quiet /qn" -Verbose
            }
        }
        catch {
            "Throw failed to update Adobe Reader."
        }
        Write-Host "================ Done"
    }
    Else {
        Write-Host "================ Failed to retreive Adobe Reader"
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

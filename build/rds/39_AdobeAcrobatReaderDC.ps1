#Requires -Modules Evergreen
<#
    .SYNOPSIS
        Install evergreen core applications.
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $False)]
    [System.String] $LogPath = "$env:SystemRoot\Logs\Packer",

    [Parameter(Mandatory = $False)]
    [System.String] $Path = "$env:SystemDrive\Apps\Adobe\AcrobatReaderDC",

    [Parameter(Mandatory = $False)]
    [System.String] $Architecture = "x64",

    [Parameter(Mandatory = $False)]
    [System.String] $Language = "English"
)

#region Script logic
# Set $VerbosePreference so full details are sent to the log; Make Invoke-WebRequest faster
$VerbosePreference = "Continue"
$ProgressPreference = "SilentlyContinue"

# Create target folder
New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null

# Run tasks/install apps
# Enforce settings with GPO: https://www.adobe.com/devnet-docs/acrobatetk/tools/AdminGuide/gpo.html
# Download Reader installer and updater
Write-Host " Adobe Acrobat Reader DC"
$Reader = Get-EvergreenApp -Name "AdobeAcrobatReaderDC" | Where-Object { $_.Language -eq $Language -and $_.Architecture -eq $Architecture } | `
    Select-Object -First 1
If ($Reader) {
        
    # Download Adobe Acrobat Reader
    Write-Host " Download Adobe Acrobat Reader DC"
    $OutFile = Save-EvergreenApp -InputObject $Reader -Path $Path -WarningAction "SilentlyContinue"

    # Install Adobe Acrobat Reader
    try {
        Write-Host " Installing Adobe Acrobat Reader DC"
        $ArgumentList = "-sfx_nu /sALL /rps /l /msi EULA_ACCEPT=YES ENABLE_CHROMEEXT=0 DISABLE_BROWSER_INTEGRATION=1 ENABLE_OPTIMIZATION=YES ADD_THUMBNAILPREVIEW=0 DISABLEDESKTOPSHORTCUT=1"
        $params = @{
            FilePath     = $OutFile.FullName
            ArgumentList = $ArgumentList
            WindowStyle  = "Hidden"
            Wait         = $True
            PassThru     = $True
            Verbose      = $True
        }
        $process = Start-Process @params
    }
    catch {
        Write-Warning -Message " ERR: Failed to install Adobe Acrobat Reader."
    }

    
    # Get the latest update; Download the updater if the updater version is greater than the installer
    $Updater = Get-EvergreenApp -Name "AdobeAcrobat" | `
        Where-Object { $_.Product -eq "Reader" -and $_.Track -eq "DC" -and $_.Language -eq "Neutral" -and $_.Architecture -eq $Architecture } | `
        Select-Object -First 1
    If ($Updater.Version -gt $Reader.Version) {
        $UpdateOutFile = Save-EvergreenApp -InputObject $Updater -Path $Path -WarningAction "SilentlyContinue"
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
                ArgumentList = "/update $($UpdateOutFile.FullName) /quiet /qn"
                WindowStyle  = "Hidden"
                Wait         = $True
                Verbose      = $True
            }
            Start-Process @params
        }
        catch {
            Write-Warning -Message " ERR: Failed to update Adobe Acrobat Reader."
        }

        # Configure update tasks
        Write-Host " Configure Reader services"
        Get-Service -Name "AdobeARMservice" -ErrorAction "SilentlyContinue" | Set-Service -StartupType "Disabled" -ErrorAction "SilentlyContinue"
        Get-ScheduledTask "Adobe Acrobat Update Task*" | Unregister-ScheduledTask -Confirm:$False -ErrorAction "SilentlyContinue"
    }
    Else {
        Write-Warning -Message " ERR: Cannot find Adobe Acrobat Reader install"
    }
}
Else {
    Write-Warning -Message " ERR: Failed to retrieve Adobe Acrobat Reader"
}

# If (Test-Path -Path $Path) { Remove-Item -Path $Path -Recurse -Confirm:$False -ErrorAction "SilentlyContinue" }
Write-Host " Complete: AdobeAcrobatReaderDC."
#endregion

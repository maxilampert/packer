#Requires -Modules Evergreen
<#
    .SYNOPSIS
        Install evergreen core applications.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "")]
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $False)]
    [System.String] $Path = "$env:SystemDrive\Apps\Adobe\AcrobatReaderDC",

    [Parameter(Mandatory = $False)]
    [System.String] $Architecture = "x64",

    [Parameter(Mandatory = $False)]
    [System.String] $Language = "English"
)

#region Script logic
# Make Invoke-WebRequest faster
$ProgressPreference = "SilentlyContinue"

# Create target folder
New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null

# Run tasks/install apps
# Enforce settings with GPO: https://www.adobe.com/devnet-docs/acrobatetk/tools/AdminGuide/gpo.html
# Download Reader installer and updater
Write-Host "Adobe Acrobat Reader DC"
$Reader = Get-EvergreenApp -Name "AdobeAcrobatReaderDC" | Where-Object { $_.Language -eq $Language -and $_.Architecture -eq $Architecture } | `
    Select-Object -First 1
If ($Reader) {

    # Download Adobe Acrobat Reader
    Write-Host "`tDownload Adobe Acrobat Reader DC: $($Reader.Version)."
    $OutFile = Save-EvergreenApp -InputObject $Reader -Path $Path -WarningAction "SilentlyContinue"

    # Install Adobe Acrobat Reader
    try {
        Write-Host "`tInstalling Adobe Acrobat Reader DC"
        $ArgumentList = "-sfx_nu /sALL /rps /l /msi EULA_ACCEPT=YES ENABLE_CHROMEEXT=0 DISABLE_BROWSER_INTEGRATION=1 ENABLE_OPTIMIZATION=YES ADD_THUMBNAILPREVIEW=0 DISABLEDESKTOPSHORTCUT=1"
        $params = @{
            FilePath     = $OutFile.FullName
            ArgumentList = $ArgumentList
            WindowStyle  = "Hidden"
            Wait         = $True
            PassThru     = $True
            Verbose      = $True
        }
        $Result = Start-Process @params
    }
    catch {
        Write-Warning -Message "`tERR: Failed to install Adobe Acrobat Reader with: $($Result.ExitCode)."
    }


    # Get the latest update; Download the updater if the updater version is greater than the installer
    $Updater = Get-EvergreenApp -Name "AdobeAcrobat" | `
        Where-Object { $_.Product -eq "Reader" -and $_.Track -eq "DC" -and $_.Language -eq "Neutral" -and $_.Architecture -eq $Architecture } | `
        Select-Object -First 1

    # Run post install actions
    Write-Host "`tPost install configuration Reader"
    Write-Host "`tGetting Acrobat updates"
    $Executables = "$env:ProgramFiles\Adobe\Acrobat DC\Acrobat\Acrobat.exe", `
        "${env:ProgramFiles(x86)}\Adobe\Acrobat DC\Acrobat\Acrobat.exe", `
        "${env:ProgramFiles(x86)}\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe"
    If (Test-Path -Path $Executables) {

        # Update
        If ([System.Version]$Updater.Version -gt [System.Version]$Reader.Version) {
            $UpdateOutFile = Save-EvergreenApp -InputObject $Updater -Path $Path -WarningAction "SilentlyContinue"

            # Update Adobe Acrobat Reader
            try {
                Write-Host "`tInstalling update: $($UpdateOutFile.FullName)."
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
                Write-Warning -Message "`tERR: Failed to update Adobe Acrobat Reader."
            }
        }

        # Configure update tasks
        Write-Host "`tConfigure Adobe Acrobat Reader services"
        try {
            Get-Service -Name "AdobeARMservice" -ErrorAction "SilentlyContinue" | Set-Service -StartupType "Disabled" -ErrorAction "SilentlyContinue"
            Get-ScheduledTask "Adobe Acrobat Update Task*" | Unregister-ScheduledTask -Confirm:$False -ErrorAction "SilentlyContinue"
        }
        catch {
            Write-Warning -Message "`tERR: $($_.Exception.Message)."
        }
    }
    Else {
        Write-Warning -Message "`tERR: Cannot find Adobe Acrobat Reader install"
    }
}
Else {
    Write-Warning -Message "`tERR: Failed to retrieve Adobe Acrobat Reader"
}

# If (Test-Path -Path $Path) { Remove-Item -Path $Path -Recurse -Confirm:$False -ErrorAction "SilentlyContinue" }
Write-Host "Complete: Adobe Acrobat Reader DC."
#endregion

#Requires -RunAsAdministrator
<#PSScriptInfo

.VERSION 1.0.0

.GUID c231f42e-5bf7-4ea3-bf47-d0a0f8254ff1

.AUTHOR Aaron Parker, @stealthpuppy

.COMPANYNAME stealthpuppy

.COPYRIGHT

.TAGS

.LICENSEURI

.PROJECTURI

.ICONURI

.EXTERNALMODULEDEPENDENCIES

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES

.PRIVATEDATA

#>

<#
    .DESCRIPTION
    Install language support on Windows 10.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "")]
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $False)]
    [System.String] $Path = "$env:SystemRoot\Temp",

    [Parameter(Mandatory = $False)]
    [System.String[]] $Language = @("ar-SA", "bg-BG", "cs-CZ", "da-DK", "de-DE", "el-GR", "en-GB", "en-US", "es-ES", "es-MX",
        "et-EE", "fi-FI", "fr-CA", "fr-FR", "he-IL", "hr-HR", "hu-HU", "it-IT", "ja-JP", "ko-KR", "lt-LT", "lv-LV", "nb-NO", "nl-NL",
        "pl-PL", "pt-BR", "pt-PT", "ro-RO", "ru-RU", "sk-SK", "sl-SI", "sr-Cyrl-CS", "sv-SE", "th-TH", "tr-TR", "uk-UA", "zh-CN", "zh-TW"),

    [Parameter(Mandatory = $False)]
    [System.String[]] $LanguageDescription = @("Arabic (Saudi Arabia)", "Bulgarian (Bulgaria)", "Czech (Czech Republic)", "Danish (Denmark)",
        "German (Germany)", "Greek (Greece)", "English (United Kingdom)", "English (United States)", "Spanish (Spain)",
        "Spanish (Mexico)", "Estonian (Estonia)", "Finnish (Finland)", "French (Canada)", "French (France)", "Hebrew (Israel)",
        "Croatian (Croatia)", "Hungarian (Hungary)", "Italian (Italy)", "Japanese (Japan)", "Korean (Korea)", "Lithuanian (Lithuania)",
        "Latvian (Latvia)", "Norwegian (Bokmål) (Norway)", "Dutch (Netherlands)", "Polish (Poland)", "Portuguese (Brazil)",
        "Portuguese (Portugal)", "Romanian (Romania)", "Russian (Russia)", "Slovak (Slovakia)", "Slovenian (Slovenia)",
        "Serbian (Latin, Serbia)", "Swedish (Sweden)", "Thai (Thailand)", "Turkish (Turkey)", "Ukrainian (Ukraine)", "Chinese (Simplified)",
        "Chinese (Traditional)")
)

#region Resources
$LanguageFiles = @{
    "1903" = @{
        "LanguagePack" = "https://software-download.microsoft.com/download/pr/18362.1.190318-1202.19h1_release_CLIENTLANGPACKDVD_OEM_MULTI.iso"
        "FOD"          = "https://software-download.microsoft.com/download/pr/18362.1.190318-1202.19h1_release_amd64fre_FOD-PACKAGES_OEM_PT1_amd64fre_MULTI.iso"
        "InboxApps"    = "https://software-download.microsoft.com/download/pr/18362.1.190318-1202.19h1_release_amd64fre_InboxApps.iso"
    }
    "1909" = @{
        "LanguagePack" = "https://software-download.microsoft.com/download/pr/18362.1.190318-1202.19h1_release_CLIENTLANGPACKDVD_OEM_MULTI.iso"
        "FOD"          = "https://software-download.microsoft.com/download/pr/18362.1.190318-1202.19h1_release_amd64fre_FOD-PACKAGES_OEM_PT1_amd64fre_MULTI.iso"
        "InboxApps"    = "https://software-download.microsoft.com/download/pr/18362.1.190318-1202.19h1_release_amd64fre_InboxApps.iso"
    }
    "2004" = @{
        "LanguagePack" = "https://software-download.microsoft.com/download/pr/19041.1.191206-1406.vb_release_CLIENTLANGPACKDVD_OEM_MULTI.iso"
        "FOD"          = "https://software-download.microsoft.com/download/pr/19041.1.191206-1406.vb_release_amd64fre_FOD-PACKAGES_OEM_PT1_amd64fre_MULTI.iso"
        "InboxApps"    = "https://software-download.microsoft.com/download/pr/19041.1.191206-1406.vb_release_amd64fre_InboxApps.iso"
    }
    "20H2" = @{
        "LanguagePack" = "https://software-download.microsoft.com/download/pr/19041.1.191206-1406.vb_release_CLIENTLANGPACKDVD_OEM_MULTI.iso"
        "FOD"          = "https://software-download.microsoft.com/download/pr/19041.1.191206-1406.vb_release_amd64fre_FOD-PACKAGES_OEM_PT1_amd64fre_MULTI.iso"
        "InboxApps"    = "https://software-download.microsoft.com/download/pr/19041.508.200905-1327.vb_release_svc_prod1_amd64fre_InboxApps.iso"
    }
    "21H1" = @{
        "LanguagePack" = "https://software-download.microsoft.com/download/pr/19041.1.191206-1406.vb_release_CLIENTLANGPACKDVD_OEM_MULTI.iso"
        "FOD"          = "https://software-download.microsoft.com/download/pr/19041.1.191206-1406.vb_release_amd64fre_FOD-PACKAGES_OEM_PT1_amd64fre_MULTI.iso"
        "InboxApps"    = "https://software-download.microsoft.com/download/sg/19041.928.210407-2138.vb_release_svc_prod1_amd64fre_InboxApps.iso"
    }
}
#region


#region Functions
Function Show-SupportedLanguage () {
    #ListSupportedLanguages
    foreach ($num in 1..$Language.Count) {
        Write-Host "`n[$num] $($LanguageDescription[$num-1])"
    }
}

Function Save-File ($FileName, $Url, $OutFile) {
    #DownloadFile
    $ProgressPreference = "SilentlyContinue"
    try {
        $params = @{
            Uri             = $Url
            OutFile         = $OutFile
            UseBasicParsing = $True
            ErrorAction     = "Continue"
        }
        Invoke-WebRequest @params
    }
    catch [System.Exception] {
        Write-Warning "Download $Url failed with: $($_.Exception.Message)."
    }
}

Function Get-WinVer {
    try {
        $DisplayVersion = (Get-Item -Path "HKLM:SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction "SilentlyContinue").GetValue("DisplayVersion")
    }
    catch {
        $DisplayVersion = $Null
    }
    If ((![System.String]::IsNullOrWhiteSpace($DisplayVersion))) {
        $WinVer = (Get-Item -Path "HKLM:SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction "SilentlyContinue").GetValue("ReleaseId")
    }
    Return $WinVer
}

Function Save-LanguageFile () {
    #DownloadLanguageFiles
    $Files = $languageFiles[(Get-WinVer)]
    $Space = 20 #Total space required to download and install

    # Test whether the ISO has been downloaded already
    ForEach ($FileName in $Files.Keys) {
        $OutFile = Join-Path -Path $Path -ChildPath (Split-Path -Path $Files[$FileName] -Leaf)
        If (Test-Path -Path $OutFile) { $Space -= 5 }
    }

    # Download each ISO
    $CDrive = Get-CimInstance -Class "Win32_LogicalDisk" -Filter "DeviceID='C:'"
    If ([System.Math]::Round($CDrive.FreeSpace / 1GB) -lt $Space) {
        Write-Warning -Message "Not enough capacity on $($env:SystemDrive) to install language support. $Space GB of free space required."
        Break Script
    }

    ForEach ($FileName in $Files.Keys) {
        $FileUrl = $Files[$FileName]
        $OutFile = Join-Path -Path $Path -ChildPath (Split-Path -Path $Files[$FileName] -Leaf)

        If (Test-Path -Path $OutFile) {
            # File exists
        }
        Else {
            Save-File -FileName $FileName -Url $FileUrl -OutFile $OutFile
        }
    }
}

Function Get-OutputFilePath ($FileName) { #GetOutputFilePath
    #GetOutputFilePath
    Return $(Join-Path -Path $Path -ChildPath (Split-Path -Path $LanguageFiles[$WinVer][$FileName] -Leaf))
}

Function Mount-File ($FilePath) { #MountFile
    try {
        $Result = Mount-DiskImage -ImagePath $FilePath -PassThru
        Return ($Result | Get-Volume).DriveLetter
    }
    catch {
        Return $False
    }
}

Function Dismount-File ($FilePath) { #DismountFile
    Dismount-DiskImage -ImagePath $FilePath | Out-Null
}

Function Remove-LanguageFile () {
    #CleanupLanguageFiles
    try { Remove-Item -Path $(Get-OutputFilePath -FileName "LanguagePack") -Force }
    catch { Write-Warning -Message "Failed to remove: $(Get-OutputFilePath -FileName "LanguagePack")." }

    try { Remove-Item -Path $(Get-OutputFilePath -FileName "FOD") -Force }
    catch { Write-Warning -Message "Failed to remove: $(Get-OutputFilePath -FileName "FOD")." }

    try { Remove-Item -Path $(Get-OutputFilePath -FileName "InboxApps") -Force }
    catch { Write-Warning -Message "Failed to remove: $(Get-OutputFilePath -FileName "InboxApps")." }
}

Function Install-LanguagePackage ($LanguageCode, $DriveLetter) { #InstallLanguagePackage
    Write-Host "Installing language pack for: $languageCode."

    try {
        $params = @{
            Online      = $True
            PackagePath = [System.IO.Path]::Combine("$($DriveLetter):", "LocalExperiencePack", $LanguageCode, "LanguageExperiencePack.$LanguageCode.Neutral.appx")
            LicensePath = [System.IO.Path]::Combine("$($DriveLetter):", "LocalExperiencePack", $LanguageCode, "License.xml")
            ErrorAction = "SilentlyContinue"
        }
        Add-AppProvisionedPackage @params
    }
    catch [System.Exception] {
        Write-Warning -Message "Add-AppProvisionedPackage failed with: $($_.Exception.Message)."
    }

    try {
        $params = @{
            Online      = $True
            PackagePath = [System.IO.Path]::Combine("$($DriveLetter):", "x64", "langpacks", "Microsoft-Windows-Client-Language-Pack_x64_$($LanguageCode).cab")
            ErrorAction = "SilentlyContinue"
        }
        Add-WindowsPackage @params
    }
    catch [System.Exception] {
        Write-Warning -Message "Add-WindowsPackage failed with: $($_.Exception.Message)."
    }
}

Function Add-ValidWindowsPackage ($FilePath) {
    #Add-ValidWindowsPackage
    If (Test-Path -Path $FilePath) {
        Write-Host "Installing: $FilePath."
        try {
            $params = @{
                Online      = $True
                PackagePath = $FilePath
                ErrorAction = "SilentlyContinue"
            }
            Add-WindowsPackage @params
        }
        catch [System.Exception] {
            Write-Warning -Message "Add-WindowsPackage failed with: $($_.Exception.Message)."
        }
    }
}

Function Install-FeaturesOnDemand ($LanguageCode, $DriveLetter) { #InstallFOD
    Write-Host "Installing features on demand for: $LanguageCode."
    If ($LanguageCode -eq "zh-CN") {
        Add-ValidWindowsPackage -FilePath $([System.IO.Path]::Combine("$($DriveLetter):", "Microsoft-Windows-LanguageFeatures-Fonts-Hans-Package~31bf3856ad364e35~amd64~~.cab"))
    }

    $Packages = @("Microsoft-Windows-LanguageFeatures-Basic-$LanguageCode-Package~31bf3856ad364e35~amd64~~.cab",
        "Microsoft-Windows-LanguageFeatures-Handwriting-$LanguageCode-Package~31bf3856ad364e35~amd64~~.cab",
        "Microsoft-Windows-LanguageFeatures-OCR-$LanguageCode-Package~31bf3856ad364e35~amd64~~.cab",
        "Microsoft-Windows-LanguageFeatures-Speech-$LanguageCode-Package~31bf3856ad364e35~amd64~~.cab",
        "Microsoft-Windows-LanguageFeatures-TextToSpeech-$LanguageCode-Package~31bf3856ad364e35~amd64~~.cab",
        "Microsoft-Windows-NetFx3-OnDemand-Package~31bf3856ad364e35~amd64~$LanguageCode~.cab",
        "Microsoft-Windows-InternetExplorer-Optional-Package~31bf3856ad364e35~amd64~$LanguageCode~.cab",
        "Microsoft-Windows-MSPaint-FoD-Package~31bf3856ad364e35~amd64~$LanguageCode~.cab",
        "Microsoft-Windows-Notepad-FoD-Package~31bf3856ad364e35~amd64~$LanguageCode~.cab",
        "Microsoft-Windows-PowerShell-ISE-FOD-Package~31bf3856ad364e35~amd64~$LanguageCode~.cab",
        "Microsoft-Windows-Printing-WFS-FoD-Package~31bf3856ad364e35~amd64~$LanguageCode~.cab",
        "Microsoft-Windows-StepsRecorder-Package~31bf3856ad364e35~amd64~$LanguageCode~.cab",
        "Microsoft-Windows-WordPad-FoD-Package~31bf3856ad364e35~amd64~$LanguageCode~.cab")
    ForEach ($Package in $Packages) {
        Add-ValidWindowsPackage -FilePath $([System.IO.Path]::Combine("$($DriveLetter):", $Package))
    }
}

Function Update-LanguageList ($LanguageCode) { #UpdateLanguageList
    #UpdateLanguageList
    Write-Host "Adding $languageCode to LanguageList"
    $LanguageList = Get-WinUserLanguageList
    $LanguageList.Add($LanguageCode)
    Set-WinUserLanguageList -LanguageList $LanguageList -Force
}

Function Install-InboxApp () { #InstallInboxApps
    Write-Host "Installing InboxApps"

    $File = Get-OutputFilePath -FileName "InboxApps"
    $DriveLetter = Mount-File -FilePath $File
    $AppsContent = "$($DriveLetter):\amd64fre"

    ForEach ($App in (Get-AppxProvisionedPackage -Online)) {
        $AppPath = "$($AppsContent)$($App.DisplayName)_$($App.PublisherId)"
        Write-Host "Handling $AppPath."

        $LicFile = Get-Item -Path "$($AppPath)*.xml"
        If ($LicFile.Count -gt 0) {
            $Lic = $true
            $LicFilePath = $LicFile.FullName
        }
        Else {
            $lic = $false
        }

        $appxFile = Get-Item -Path "$($AppPath)*.appx*"
        If ($AppxFile.Count -gt 0) {
            If ($lic) {

                try {
                    $params = @{
                        Online      = $True
                        PackagePath = $AppxFile.FullName
                        LicensePath = $licFilePath
                        ErrorAction = "SilentlyContinue"
                    }
                    Add-AppxProvisionedPackage @params
                }
                catch [System.Exception] {
                    Write-Warning -Message "Add-AppxProvisionedPackage failed with: $($_.Exception.Message)."
                }
            }
            Else {

                try {
                    $params = @{
                        Online      = $True
                        PackagePath = $AppxFile.FullName
                        SkipLicense = $True
                        ErrorAction = "SilentlyContinue"
                    }
                    Add-AppxProvisionedPackage @params
                }
                catch [System.Exception] {
                    Write-Warning -Message "Add-AppxProvisionedPackage failed with: $($_.Exception.Message)."
                }
            }
        }
    }

    DismountFile $file
}

Function Install-LanguageFile ($LanguageCode) { #InstallLanguageFiles

    $LanguagePackDriveLetter = Mount-File -FilePath (Get-OutputFilePath -FileName "LanguagePack")
    $FodDriveLetter = Mount-File -FilePath (Get-OutputFilePath -FileName "FOD")

    Install-LanguagePackage -LanguageCode $LanguageCode -DriveLetter $languagePackDriveLetter
    Install-FeaturesOnDemand -LanguageCode $LanguageCode -DriveLetter $FodDriveLetter
    Update-LanguageList -LanguageCode $LanguageCode

    Dismount-File -FilePath $(Get-OutputFilePath -FileName "LanguagePack")
    Dismount-File -FilePath $(Get-OutputFilePath -FileName "FOD")

    Install-InboxApp
}

Function Install() { #Install

    ListSupportedLanguages
    $languageNumber = Read-Host "Select number to install language"

    if (!($languageNumber -in 1..$languages.Count)) {
        Write-Host "Invalid language number." -ForegroundColor red
        break
    }

    $languageCode = $languages[$languageNumber - 1]

    DownloadLanguageFiles
    InstallLanguageFiles $languageCode
    CleanupLanguageFiles
}

If (!(test-path $downloadPath)) {
    New-Item -ItemType Directory -Force -Path $downloadPath
}

$currentWindowsIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$currentWindowsPrincipal = [Security.Principal.WindowsPrincipal]$currentWindowsIdentity

if( -not $currentWindowsPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){
    Write-Host "Script needs to be run as Administrator." -ForegroundColor red
    Break Script
}

$winver = (Get-Item "HKLM:SOFTWARE\Microsoft\Windows NT\CurrentVersion").GetValue('DisplayVersion')
if (!$winver) {
    $winver = (Get-Item "HKLM:SOFTWARE\Microsoft\Windows NT\CurrentVersion").GetValue('ReleaseId')
}

if (!$languageFiles[$winver]){
    Write-Host "Languages installer is not supported Windows $winver." -ForegroundColor red
    Break Script
}

##Disable language pack cleanup##
Disable-ScheduledTask -TaskPath "\Microsoft\Windows\AppxDeploymentClient\" -TaskName "Pre-staged app cleanup"

Write-Output "Install Windows $winver languages:"
Install
#endregion

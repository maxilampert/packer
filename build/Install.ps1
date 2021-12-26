<#
    Run application install scripts
#>
[CmdletBinding()]
param()
$Scripts = @(
    "https://raw.githubusercontent.com/aaronparker/packer/main/build/rds/01_Rds-PrepImage.ps1",
    "https://raw.githubusercontent.com/aaronparker/packer/main/build/rds/02_Packages.ps1",
    "https://raw.githubusercontent.com/aaronparker/packer/main/build/rds/05_Rds-Roles.ps1",
    "https://raw.githubusercontent.com/aaronparker/packer/main/build/common/03_RegionLanguage.ps1",
    "https://raw.githubusercontent.com/aaronparker/image-customise/main/Install.ps1",
    "https://raw.githubusercontent.com/aaronparker/packer/main/build/common/06_SupportFunctions.ps1",
    "https://raw.githubusercontent.com/aaronparker/packer/main/build/rds/07_MicrosoftVcRedists.ps1",
    "https://raw.githubusercontent.com/aaronparker/packer/main/build/rds/08_MicrosoftFSLogixApps.ps1",
    "https://raw.githubusercontent.com/aaronparker/packer/main/build/rds/09_MicrosoftEdge.ps1",
    "https://raw.githubusercontent.com/aaronparker/packer/main/build/rds/10_Microsoft365Apps.ps1",
    "https://raw.githubusercontent.com/aaronparker/packer/main/build/rds/11_MicrosoftTeams.ps1",
    "https://raw.githubusercontent.com/aaronparker/packer/main/build/rds/12_MicrosoftOneDrive.ps1",
    "https://raw.githubusercontent.com/aaronparker/packer/main/build/rds/14_Wvd-Agents.ps1",
    "https://raw.githubusercontent.com/aaronparker/packer/main/build/rds/39_AdobeAcrobatReaderDC.ps1",
    "https://raw.githubusercontent.com/aaronparker/packer/main/build/rds/98_CitrixOptimizer.ps1",
    "https://raw.githubusercontent.com/aaronparker/packer/main/build/rds/99_Bisf.ps1"
)
ForEach ($Script in $Scripts) {
    Invoke-Expression -Command ((New-Object -TypeName "System.Net.WebClient").DownloadString($Script))
}

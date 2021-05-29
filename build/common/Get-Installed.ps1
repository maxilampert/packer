<#
#>
[CmdletBinding()]
param (
    [Parameter()]
    [System.String] $Path = "$env:SystemRoot\Temp\Reports",

    [Parameter()]
    [System.String] $SoftwareFile = "$Path\InstalledSoftware.json",

    [Parameter()]
    [System.String] $PackagesFile = "$Path\InstalledPackages.json",

    [Parameter()]
    [System.String] $HotfixFile = "$Path\InstalledHotfixes.json",

    [Parameter()]
    [System.String] $FeaturesFile = "$Path\InstalledFeatures.json",

    [Parameter()]
    [System.String] $CapabilitiesFile = "$Path\InstalledCapabilities.json",

    [Parameter()]
    [System.String] $ZipFile = "Installed.zip"
)

# Create the target directory
New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" | Out-Null

#region Functions
Function Get-InstalledSoftware {
    <#
        .SYNOPSIS
            Retrieves a list of all software installed

        .EXAMPLE
            Get-InstalledSoftware
            
            This example retrieves all software installed on the local computer
            
        .PARAMETER Name
            The software title you'd like to limit the query to.

        .NOTES
            Author: Adam Bertram
            URL: https://4sysops.com/archives/find-the-product-guid-of-installed-software-with-powershell/
    #>
    [OutputType([System.Management.Automation.PSObject])]
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String] $Name
    )

    $UninstallKeys = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall", "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    $null = New-PSDrive -Name HKU -PSProvider Registry -Root Registry::HKEY_USERS
    $UninstallKeys += Get-ChildItem HKU: -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'S-\d-\d+-(\d+-){1,14}\d+$' } | `
        ForEach-Object { "HKU:\$($_.PSChildName)\Software\Microsoft\Windows\CurrentVersion\Uninstall" }
    if (-not $UninstallKeys) {
        Write-Verbose -Message "$($MyInvocation.MyCommand): No software registry keys found."
    }
    else {
        foreach ($UninstallKey in $UninstallKeys) {
            if ($PSBoundParameters.ContainsKey('Name')) {
                $WhereBlock = { ($_.PSChildName -match '^{[A-Z0-9]{8}-([A-Z0-9]{4}-){3}[A-Z0-9]{12}}$') -and ($_.GetValue('DisplayName') -like "$Name*") }
            }
            else {
                $WhereBlock = { ($_.PSChildName -match '^{[A-Z0-9]{8}-([A-Z0-9]{4}-){3}[A-Z0-9]{12}}$') -and ($_.GetValue('DisplayName')) }
            }
            $gciParams = @{
                Path        = $UninstallKey
                ErrorAction = 'SilentlyContinue'
            }
            $selectProperties = @(
                @{n = 'Publisher'; e = { $_.GetValue('Publisher') } },
                @{n = 'Name'; e = { $_.GetValue('DisplayName') } },
                @{n = 'Version'; e = { $_.GetValue('DisplayVersion') } }
            )
            Get-ChildItem @gciParams | Where-Object $WhereBlock | Select-Object -Property $selectProperties
        }
    }
}
#endregion

#region Output details of the image to JSON files that Packer can upload back to the runner
# Get the Software list; Output the installed software to the pipeline for Packer output
Write-Host " Export software list to: $SoftwareFile."
$software = Get-InstalledSoftware | Sort-Object -Property "Publisher", "Version"
$software | ConvertTo-Json | Out-File -FilePath $SoftwareFile -Force -Encoding "Utf8"

# Get the installed packages
Write-Host " Export packages list to: $PackagesFile."
$packages = Get-ProvisionedAppPackage -Online | Select-Object -Property "DisplayName", "Version"
If ($Null -ne $packages) { $packages | ConvertTo-Json | Out-File -FilePath $PackagesFile -Force -Encoding "Utf8" }

# Get the installed hotfixes
Write-Host " Export hotfix list to: $HotfixFile."
$hotfixes = Get-Hotfix | Select-Object -Property "Description", "HotFixID", "Caption" | Sort-Object -Property "HotFixID"
$hotfixes | ConvertTo-Json | Out-File -FilePath $HotfixFile -Force -Encoding "Utf8"

# Get installed features
Write-Host " Export features list to: $FeaturesFile."
$features = Get-WindowsOptionalFeature -Online | Where-Object { $_.State -eq "Enabled" } | `
    Select-Object -Property "FeatureName", "State" | Sort-Object -Property "FeatureName" -Descending
$features | ConvertTo-Json | Out-File -FilePath $FeaturesFile -Force -Encoding "Utf8"

# Get installed capabilities
Write-Host " Export capabilities list to: $CapabilitiesFile."
$capabilities = Get-WindowsCapability -Online | Where-Object { $_.State -eq "Installed" } | `
    Select-Object -Property "Name", "State" | Sort-Object -Property "Name" -Descending
$capabilities | ConvertTo-Json | Out-File -FilePath $CapabilitiesFile -Force -Encoding "Utf8"
#endregion

#region Zip JSON files
try {
    $params = @{
        Path             = (Get-ChildItem -Path $Path -Filter "*.json")
        DestinationPath  = (Join-Path -Path $Path -ChildPath $ZipFile)
        CompressionLevel = "NoCompression"
        Verbose          = $True
    }
    Compress-Archive @params
}
catch {
    Write-Warning -Message " ERR: Compress-Archive failed with: $($_.Exception.Message)."
}
#endregion

# Write the installed software list to the pipeline
Write-Output -InputObject $software

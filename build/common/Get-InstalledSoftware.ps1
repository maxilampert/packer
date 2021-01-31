<#
#>
[CmdletBinding()]
param (
    [Parameter()]
    [System.String] $SoftwareFile = "$env:SystemRoot\Temp\InstalledSoftware.json",

    [System.String] $HotfixFile = "$env:SystemRoot\Temp\InstalledHotfix.json"
)

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

Function Get-InstalledHotfixes {
    <#
        .SYNOPSIS
            Retrieves a list of hotfixes installed
    #>
    [OutputType([System.Management.Automation.PSObject])]
    [CmdletBinding()]
    param ()

    try {
        $HotfixList = Get-Hotfix | Select-Object -Property "description", "hotfixid" , "caption" | Sort-Object -Property "HotFixID"
    }
    catch {
        Throw $_
    }
    
    try {
        $HotfixJson = $HotfixList | ConvertTo-Json
    }
    catch {
        Throw $_
    }

    If ($Null -ne $HotfixJson) { Write-Output -InputObject $HotfixJson }
}
#endregion

# Output the installed software to the pipeline for Packer output
$software = Get-InstalledSoftware
Write-Host $software

# Output the software list to a JSON file that Packer can upload back to the runner
Write-Host "================ Export software list to: $SoftwareFile."
$software | ConvertTo-Json | Out-File -FilePath $SoftwareFile -Force -Encoding "Utf8"

# Output the hotfix list to a JSON file that Packer can upload back to the runner
Write-Host "================ Export hotfix list to: $HotfixFile."
Get-InstalledHotfixes | Out-File -FilePath $HotfixFile -Force -Encoding "Utf8"

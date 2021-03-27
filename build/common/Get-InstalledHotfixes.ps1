<#
#>
[CmdletBinding()]
param (
    [Parameter()]
    [System.String] $HotfixFile = "$env:SystemRoot\Temp\InstalledHotfixes.json"
)

#region Functions
Function Get-InstalledHotfixes {
    <#
        .SYNOPSIS
            Retrieves a list of hotfixes installed
    #>
    [OutputType([System.Management.Automation.PSObject])]
    [CmdletBinding()]
    param ()

    try {
        $HotfixList = Get-Hotfix | Select-Object -Property "Description", "HotFixID", "Caption" | Sort-Object -Property "HotFixID"
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

# Output the hotfix list to a JSON file that Packer can upload back to the runner
Write-Host " Export hotfix list to: $HotfixFile."
Get-InstalledHotfixes | Out-File -FilePath $HotfixFile -Force -Encoding "Utf8"

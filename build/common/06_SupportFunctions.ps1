<# 
    .SYNOPSIS
        Install evergreen core applications.
#>
[CmdletBinding()]
Param ()

#region Functions
Function Set-Repository {
    # Trust the PSGallery for modules
    If (Get-PSRepository | Where-Object { $_.Name -eq "PSGallery" -and $_.InstallationPolicy -ne "Trusted" }) {
        Write-Host "================ Trusting the repository: PSGallery"
        Install-PackageProvider -Name "NuGet" -MinimumVersion 2.8.5.208 -Force
        Set-PSRepository -Name "PSGallery" -InstallationPolicy "Trusted"
    }
}

Function Install-RequiredModules {
    # Install the Evergreen module; https://github.com/aaronparker/Evergreen
    # Install the VcRedist module; https://docs.stealthpuppy.com/vcredist/
    ForEach ($module in "Evergreen", "VcRedist") {
        Write-Host "================ Checking module: $module"
        $installedModule = Get-Module -Name $module -ListAvailable | `
            Sort-Object -Property @{ Expression = { [System.Version]$_.Version }; Descending = $true } | `
            Select-Object -First 1
        $publishedModule = Find-Module -Name $module
        If (($Null -eq $installedModule) -or ([System.Version]$publishedModule.Version -gt [System.Version]$installedModule.Version)) {
            Write-Host "================ Installing module: $module"
            Install-Module -Name $module -Force
        }
    }
}
#endregion Functions


#region Script logic
# Run tasks/install apps
Set-Repository
Install-RequiredModules
Write-Host "================ Complete: SupportFunctions."
#endregion

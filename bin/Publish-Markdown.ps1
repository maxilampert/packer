<# 
    .SYNOPSIS
        Creates markdown from JSON ouput generated from Azure DevOps builds
#>
[CmdletBinding()]
Param (
    [Parameter()]
    [System.String] $Path,

    [Parameter()]
    [System.String[]] $InputFile = @("InstalledSoftware.json", "InstalledHotfixes.json"),

    [Parameter()]
    [System.String] $ImagePublisher = "MicrosoftWindowsDesktop",

    [Parameter()]
    [System.String] $ImageOffer = "Windows-10",

    [Parameter()]
    [System.String] $ImageSku = "20h2-ent",

    [Parameter()]
    [System.String] $Version = "20210204.14",

    [Parameter()]
    [System.String] $DestinationPath = "docs"
)

#region Trust the PSGallery for modules
$Repository = "PSGallery"
If (Get-PSRepository | Where-Object { $_.Name -eq $Repository -and $_.InstallationPolicy -ne "Trusted" }) {
    try {
        Write-Host "================ Trusting the repository: $Repository."
        Install-PackageProvider -Name "NuGet" -MinimumVersion 2.8.5.208 -Force
        Set-PSRepository -Name $Repository -InstallationPolicy "Trusted"
    }
    catch {
        Throw $_
        Break
    }
}
#endregion

#region Install the MarkdownPS module
ForEach ($module in "MarkdownPS") {
    try {
        Write-Host "================ Checking module: $module"
        $installedModule = Get-Module -Name $module -ListAvailable | `
            Sort-Object -Property @{ Expression = { [System.Version]$_.Version }; Descending = $true } | `
            Select-Object -First 1
        $publishedModule = Find-Module -Name $module -ErrorAction "SilentlyContinue"
        If (($Null -eq $installedModule) -or ([System.Version]$publishedModule.Version -gt [System.Version]$installedModule.Version)) {
            Write-Host "================ Installing module: $module"
            $params = @{
                Name               = $module
                SkipPublisherCheck = $true
                Force              = $true
                AllowPrerelease    = $False
                AcceptLicense      = $true
                ErrorAction        = "Stop"
            }
            Install-Module @params
        }
    }
    catch {
        Throw $_
        Break 
    }
}
#endregion


# Start with a blank markdown variable
[System.String] $markdown
$markdown += New-MDHeader -Text $version -Level 1
# $markdown += New-MDHeader -Text "$ImagePublisher-$ImageOffer-$ImageSku-$version" -Level 1
#$markdown += ""

# Read the contents of the output files, convert to markdown
ForEach ($file in $InputFile) {
    
    $TargetFile = Join-Path -Path $Path -ChildPath $file
    If (([System.IO.FileInfo]$TargetFile).Exists) {
        try {
            Write-Verbose -Message "Reading: $TargetFile."
            $table = Get-Content -Path $TargetFile | ConvertFrom-Json
        }
        catch {
            Write-Warning -Message $_.Exception.Message
        }

        If ($table) {
            $markdown += New-MDHeader -Text ($file -replace ".json", "") -Level 2
            #$markdown += ""
            $markdown += $table | Sort-Object -Property Publisher, Version | New-MDTable
            $markdown += ""
            Remove-Variable -Name "table"
        }
    }
    Else {
        Write-Warning -Message "Cannot find: $TargetFile."
    }
}

# Write the markdown to a file
$TargetPath = [IO.Path]::Combine($DestinationPath, $ImagePublisher, $ImageOffer, $ImageSku)
New-Item -Path $TargetPath -ItemType "Directory" -Force -ErrorAction "SilentlyContinue"
$markdown | Out-File -FilePath (Join-Path -Path $TargetPath -ChildPath "$Version.md") -Encoding "Utf8" -Force

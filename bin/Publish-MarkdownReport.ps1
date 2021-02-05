<# 
    .SYNOPSIS
        Creates markdown from JSON ouput generated from Azure DevOps builds
        Uses environment variables created inside the Azure DevOps environment
#>
[CmdletBinding()]
Param (
    [Parameter()]
    [System.String] $Path = $env:SYSTEM_DEFAULTWORKINGDIRECTORY,

    [Parameter()]
    [System.String[]] $InputFile = @("InstalledSoftware.json", "InstalledHotfixes.json"),

    [Parameter()]
    [System.String] $ImagePublisher = $env:IMAGE_PUBLISHER,

    [Parameter()]
    [System.String] $ImageOffer = $env:IMAGE_OFFER,

    [Parameter()]
    [System.String] $ImageSku = $IMAGE_SKU,

    [Parameter()]
    [System.String] $Version = $env:CREATED_DATE,

    [Parameter()]
    [System.String] $DestinationPath = [System.IO.Path]::Combine($env:SYSTEM_DEFAULTWORKINGDIRECTORY, "docs")
)

#region Trust the PSGallery for modules
$Repository = "PSGallery"
If (Get-PSRepository | Where-Object { $_.Name -eq $Repository -and $_.InstallationPolicy -ne "Trusted" }) {
    try {
        Write-Host "================ Trusting the repository: $Repository."
        Install-PackageProvider -Name "NuGet" -MinimumVersion "2.8.5.208" -Force
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

# Output variable values
Write-Host "================ Path:              $Path."
Write-Host "================ ImagePublisher:    $ImagePublisher."
Write-Host "================ ImageOffer:        $ImageOffer."
Write-Host "================ ImageSku:          $ImageSku."
Write-Host "================ DestinationPath:   $ImagePublisher."

# Start with a blank markdown variable
[System.String] $markdown
$markdown += New-MDHeader -Text $version -Level 1

# Read the contents of the output files, convert to markdown
ForEach ($file in $InputFile) {
    
    $TargetFile = Join-Path -Path $Path -ChildPath $file
    If (([System.IO.FileInfo]$TargetFile).Exists) {
        try {
            Write-Host "================ Reading: $TargetFile."
            $table = Get-Content -Path $TargetFile | ConvertFrom-Json
        }
        catch {
            Write-Warning -Message $_.Exception.Message
        }

        If ($table) {
            $markdown += New-MDHeader -Text ($file -replace ".json", "") -Level 2
            $markdown += $table | Sort-Object -Property "Publisher", "Name", "Version" | New-MDTable
            $markdown += ""
            Remove-Variable -Name "table"
        }
    }
    Else {
        Write-Warning -Message "================ Cannot find: $TargetFile."
    }
}

# Create the target folder
try {
    $TargetPath = [System.IO.Path]::Combine($DestinationPath, $ImagePublisher, $ImageOffer, $ImageSku)
    New-Item -Path $TargetPath -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null
}
catch {
    Throw $_
    Break
}

# Write the markdown to a file
try {
    $markdown | Out-File -FilePath (Join-Path -Path $TargetPath -ChildPath "$Version.md") -Encoding "Utf8" -Force
}
catch {
    Throw $_
    Break
}

# If we're all good and the markdown has been created, remove the JSON files from the working repo
<#
try {
    Remove-Item -Path $Path -Force -Confirm:$False -ErrorAction "SilentlyContinue"
}
catch {
    Throw "Failed to remove path: $Path."
}
#>

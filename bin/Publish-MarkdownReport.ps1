<# 
    .SYNOPSIS
        Creates markdown from JSON ouput generated from Azure DevOps builds
        Uses environment variables created inside the Azure DevOps environment
#>
[CmdletBinding()]
Param (
    [Parameter()]
    [ValidateNotNullOrEmpty]
    [System.String] $Path = [IO.Path]::Combine($env:SYSTEM_DEFAULTWORKINGDIRECTORY, "Json"),

    [Parameter()]
    [ValidateNotNullOrEmpty]
    [System.String[]] $InputFile = @("InstalledSoftware.json", "InstalledHotfixes.json"),

    [Parameter()]
    [ValidateNotNullOrEmpty]
    [System.String] $ImagePublisher = $env:IMAGE_PUBLISHER,

    [Parameter()]
    [ValidateNotNullOrEmpty]
    [System.String] $ImageOffer = $env:IMAGE_OFFER,

    [Parameter()]
    [ValidateNotNullOrEmpty]
    [System.String] $ImageSku = $IMAGE_SKU,

    [Parameter()]
    [ValidateNotNullOrEmpty]
    [System.String] $Version = $env:CREATED_DATE,

    [Parameter()]
    [ValidateNotNullOrEmpty]
    [System.String] $DestinationPath = [IO.Path]::Combine($env:SYSTEM_DEFAULTWORKINGDIRECTORY, "docs")
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

# Read the contents of the output files, convert to markdown
ForEach ($file in $InputFile) {
    
    $TargetFile = Join-Path -Path $Path -ChildPath $file
    If (([System.IO.FileInfo]$TargetFile).Exists) {
        try {
            Write-Verbose -Message "================ Reading: $TargetFile."
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
    $TargetPath = [IO.Path]::Combine($DestinationPath, $ImagePublisher, $ImageOffer, $ImageSku)
    New-Item -Path $TargetPath -ItemType "Directory" -Force -ErrorAction "SilentlyContinue"
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
Remove-Item -Path $Path -Force

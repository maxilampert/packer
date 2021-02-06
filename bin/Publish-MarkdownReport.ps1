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
    [System.String] $ImageSku = $env:IMAGE_SKU,

    [Parameter()]
    [System.String] $Version = $env:CREATED_DATE,

    [Parameter()]
    [System.String] $DestinationPath = [System.IO.Path]::Combine($env:SYSTEM_DEFAULTWORKINGDIRECTORY, "docs")
)

# Output variable values
Write-Host "================ Path:              $Path."
Write-Host "================ ImagePublisher:    $ImagePublisher."
Write-Host "================ ImageOffer:        $ImageOffer."
Write-Host "================ ImageSku:          $ImageSku."
Write-Host "================ DestinationPath:   $ImagePublisher."

# Start with a markdown variable
[System.String] $markdown += New-MDHeader -Text $version -Level 1 -NoNewLine
$markdown += "`n"

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
            $markdown += New-MDHeader -Text ($file -replace ".json", "") -Level 2 -NoNewLine
            $markdown += "`n"
            $markdown += $table | Sort-Object -Property "Publisher", "Name", "Version" | New-MDTable
            $markdown += "`n"
            Remove-Variable -Name "table" -ErrorAction "SilentlyContinue"
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
    Write-Host "================ Writing markdown to: $(Join-Path -Path $TargetPath -ChildPath "$Version.md")."
    If ($markdown[-1] -ne "`n") { $markdown += "`n" }
    $markdown | Out-File -FilePath (Join-Path -Path $TargetPath -ChildPath "$Version.md") -Encoding "Utf8" -NoNewLine -Force
}
catch {s
    Throw $_
    Break
}

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


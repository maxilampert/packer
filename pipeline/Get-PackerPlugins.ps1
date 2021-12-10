<#
    .SYNOPSIS
        Downloads Hashicorp Packer plugins
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
[CmdletBinding()]
param (
    [Parameter()]
    [System.String] $Path = "$env:AppData\packer.d\plugins"
)

#region Functions
Function Get-GitHubRepoRelease {
    <#
        .SYNOPSIS
            Calls the GitHub Releases API passed via $Uri, validates the response and returns a formatted object
            Example: https://api.github.com/repos/PowerShell/PowerShell/releases/latest
    #>
    [OutputType([System.Management.Automation.PSObject])]
    [CmdletBinding(SupportsShouldProcess = $False)]
    param (
        [Parameter(Mandatory = $True, Position = 0)]
        [System.String] $Uri,

        [Parameter(Mandatory = $False, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [System.String] $MatchVersion = "(\d+(\.\d+){1,4}).*",

        [Parameter(Mandatory = $False, Position = 2)]
        [ValidateNotNullOrEmpty()]
        [System.String] $VersionTag = "tag_name",

        [Parameter(Mandatory = $False, Position = 3)]
        [ValidateNotNullOrEmpty()]
        [System.String] $Filter = "\.zip$"
    )

    # Retrieve the releases from the GitHub API
    try {
        # Invoke the GitHub releases REST API
        # Note that the API performs rate limiting.
        # https://docs.github.com/en/free-pro-team@latest/rest/reference/repos#get-the-latest-release
        $params = @{
            ContentType = "application/vnd.github.v3+json"
            Method      = "Get"
            Uri         = $Uri
        }
        Write-Verbose -Message "$($MyInvocation.MyCommand): Get GitHub release from: $Uri."
        $release = Invoke-RestMethod @params
    }
    catch {
        Write-Warning -Message "$($MyInvocation.MyCommand): REST API call to [$Uri] failed with: $($_.Exception.Response.StatusCode)."
        Throw "$($MyInvocation.MyCommand): $($_.Exception.Message)."
    }

    If ($Null -ne $release) {

        # Build and array of the latest release and download URLs
        Write-Verbose -Message "$($MyInvocation.MyCommand): Found $($release.count) releases."
        Write-Verbose -Message "$($MyInvocation.MyCommand): Found $($release.assets.count) assets."
        ForEach ($item in $release) {
            ForEach ($asset in $item.assets) {

                # Filter downloads by matching the RegEx in the manifest. The the RegEx may perform includes and excludes
                If ($asset.browser_download_url -match $Filter) {
                    Write-Verbose -Message "$($MyInvocation.MyCommand): Building Windows release output object with: $($asset.browser_download_url)."

                    # Capture the version string from the specified release tag
                    try {
                        $version = [RegEx]::Match($item.$VersionTag, $MatchVersion).Captures.Groups[1].Value
                    }
                    catch {
                        Write-Verbose -Message "$($MyInvocation.MyCommand): Failed to match version number, returning: $($item.$VersionTag)."
                        $version = $item.$VersionTag
                    }

                    # Build the output object
                    $PSObject = [PSCustomObject] @{
                        Version  = $version
                        Platform = Get-Platform -String $asset.browser_download_url
                        URI      = $asset.browser_download_url
                    }
                    Write-Output -InputObject $PSObject
                }
                Else {
                    Write-Verbose -Message "$($MyInvocation.MyCommand): Skip: $($asset.browser_download_url)."
                }
            }
        }
    }
}

Function Get-Platform {
    [OutputType([System.String])]
    [CmdletBinding(SupportsShouldProcess = $False)]
    param (
        [Parameter(Mandatory = $True, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [System.String] $String
    )

    Switch -Regex ($String) {
        "rhel" { $platform = "RHEL"; Break }
        "\.rpm" { $platform = "RedHat"; Break }
        "\.tar.gz|linux" { $platform = "Linux"; Break }
        "\.nupkg" { $platform = "NuGet"; Break }
        "mac|osx|darwin" { $platform = "macOS"; Break }
        "\.deb|debian" { $platform = "Debian"; Break }
        "ubuntu" { $platform = "Ubuntu"; Break }
        "centos" { $platform = "CentOS"; Break }
        "\.exe|\.msi|windows|win" { $platform = "Windows"; Break }
        Default {
            Write-Verbose -Message "$($MyInvocation.MyCommand): Platform not found, defaulting to Windows."
            $platform = "Windows"
        }
    }
    Write-Output -InputObject $platform
}
#endregion


# Windows Update plugin
$Latest = Get-GitHubRepoRelease -Uri "https://api.github.com/repos/rgl/packer-plugin-windows-update/releases/latest" | `
    Where-Object { $_.Platform -eq "Windows" } | Select-Object -First 1

# Temporarily use 0.11.0
$Latest = [PSCustomObject]@{
    Version = "0.14.0"
    URI     = "https://github.com/rgl/packer-plugin-windows-update/releases/download/v0.14.0/packer-plugin-windows-update_v0.14.0_x5.0_windows_amd64.zip"
}
$Latest = [PSCustomObject]@{
    Version = "0.11.0"
    URI     = "https://github.com/rgl/packer-plugin-windows-update/releases/download/v0.11.0/packer-provisioner-windows-update_0.11.0_windows_amd64.zip"
}

If ($Null -ne $Latest) {
    Write-Host " Found version: $($Latest.Version)."
    $OutFile = Join-Path -Path $([System.IO.Path]::GetTempPath()) -ChildPath (Split-Path -Path $Latest.URI -Leaf)

    Write-Host " Downloading Windows Update Packer plugin." -ForegroundColor "Cyan"
    try {
        $ProgressPreference = "SilentlyContinue"
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $params = @{
            Uri             = $Latest.URI
            OutFile         = $OutFile
            UseBasicParsing = $True
            ErrorAction     = "SilentlyContinue"
        }
        Invoke-WebRequest @params
    }
    catch {
        Write-Error -Message $_.Exception.Message
        Break
    }
    finally {
        Expand-Archive -Path $OutFile -DestinationPath $Path -Verbose
        Remove-Item -Path $OutFile -ErrorAction "SilentlyContinue"
    }
}

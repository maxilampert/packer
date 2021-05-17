<# 
    .SYNOPSIS
        Install evergreen core applications.
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $False)]
    [System.String] $LogPath = "$env:SystemRoot\Logs\Packer",

    [Parameter(Mandatory = $False)]
    [System.String] $Path = "$env:SystemDrive\Apps\Microsoft\OneDrive"
)

#region Script logic
# Set $VerbosePreference so full details are sent to the log; Make Invoke-WebRequest faster
$VerbosePreference = "Continue"
$ProgressPreference = "SilentlyContinue"

# Create target folder
New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null

# Run tasks/install apps
Write-Host " Microsoft OneDrive"    
$App = Get-EvergreenApp -Name "MicrosoftOneDrive" | Where-Object { $_.Ring -eq "Production" -and $_.Type -eq "Exe" -and $_.Architecture -eq "AMD64" } | `
    Sort-Object -Property @{ Expression = { [System.Version]$_.Version }; Descending = $true } | Select-Object -First 1
If ($App) {

    # Download
    $OutFile = Save-EvergreenApp -InputObject $App -Path $Path

    # Install
    try {
        Write-Host " Installing Microsoft OneDrive"
        $params = @{
            FilePath     = $OutFile.FullName
            ArgumentList = "/ALLUSERS"
            WindowStyle  = "Hidden"
            Wait         = $True
            Verbose      = $True
        }
        Start-Process @params
    }
    catch {
        Write-Warning -Message " ERR: Failed to install Microsoft OneDrive."
    }
}
Else {
    Write-Warning -Message " ERR: Failed to retrieve Microsoft OneDrive"
}

# If (Test-Path -Path $Path) { Remove-Item -Path $Path -Recurse -Confirm:$False -ErrorAction "SilentlyContinue" }
Write-Host " Complete: Microsoft OneDrive."
#endregion

<# 
    .SYNOPSIS
        Customise a Windows image for use as an WVD/XenApp VM in Azure.
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $False)]
    [System.String] $LogPath = "$env:SystemRoot\Logs\Packer",

    [Parameter(Mandatory = $False)]
    [System.String] $Path = "$env:SystemDrive\Apps\image-customise",

    [Parameter(Mandatory = $False)]
    [System.String] $URL = "https://github.com/aaronparker/image-customise/archive/main.zip",

    [Parameter(Mandatory = $False)]
    [System.String] $InvokeScript = "Invoke-Scripts.ps1"
)

#region Script logic
# Set $VerbosePreference so full details are sent to the log; Make Invoke-WebRequest faster
$VerbosePreference = "Continue"
$ProgressPreference = "SilentlyContinue"

# Create target folder
Write-Host " Start: Customise."
New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null

# Validate customisation scripts; Run scripts
If (Test-Path -Path $(Join-Path -Path $Path -ChildPath $InvokeScript)) {
    try {
        Push-Location -Path $Path
        . $InvokeScript
        Pop-Location
    }
    catch {
        Write-Warning -Message " ERR: $InvokeScript error with: $($_.Exception.Message)."
    }
}
Else {
    Write-Warning -Message " ERR: Could not find: $(Join-Path -Path $Path -ChildPath $InvokeScript)."
}

# If (Test-Path -Path $Path) { Remove-Item -Path $Path -Recurse -Confirm:$False -ErrorAction "SilentlyContinue" }
Write-Host " Complete: Customise."
#endregion

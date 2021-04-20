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

# Validate customisation scripts
Write-Host " Directory listing:"
Get-ChildItem -Path $Path -Recurse
$Script = Get-ChildItem -Path $Path -Recurse -Filter $InvokeScript

# Validate customisation scripts 
If (Test-Path -Path $Script) {
    Write-Host " Scripts validated in $Path."
}
Else {
    Write-Host " Scripts not in $Path. Downloading from repository."
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $OutFile = Join-Path -Path $Path -ChildPath $(Split-Path $URL -Leaf)
        Invoke-WebRequest -Uri $URL -OutFile $OutFile -UseBasicParsing
        Expand-Archive -Path $OutFile -DestinationPath $Path -Force -Verbose
    }
    catch {
        Write-Warning -Message " ERR: $($_.Exception.Message)."
    }
    $Script = Get-ChildItem -Path $Path -Recurse -Filter $InvokeScript
}

# Run scripts
IF ($Null -ne $Script) {
    Push-Location -Path (Split-Path -Path $Script.FullName -Parent)
    . $Script.FullName
    Pop-Location
}
Else {
    Write-Warning -Message " ERR: Could not find $InvokeScript in $Path."
}

If (Test-Path -Path $Path) { Remove-Item -Path $Path -Recurse -Confirm:$False -ErrorAction "SilentlyContinue" }
Write-Host " Complete: Customise."
#endregion

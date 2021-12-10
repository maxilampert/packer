#Requires -Modules Evergreen
<#
    .SYNOPSIS
        Install evergreen core applications.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $False)]
    [System.String] $Path = "$env:SystemDrive\Apps\Microsoft\Teams"
)

#region Script logic
# Set $VerbosePreference so full details are sent to the log; Make Invoke-WebRequest faster
$VerbosePreference = "Continue"
$ProgressPreference = "SilentlyContinue"

# Create target folder
New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null

# Run tasks/install apps
Write-Host " Microsoft Teams"
$App = Get-EvergreenApp -Name "MicrosoftTeams" | Where-Object { $_.Architecture -eq "x64" -and $_.Ring -eq "General" -and $_.Type -eq "msi" } | Select-Object -First 1
If ($App) {

    # Download
    $OutFile = Save-EvergreenApp -InputObject $App -Path $Path -WarningAction "SilentlyContinue"

    # Install
    try {
        Write-Host " Installing Microsoft Teams"
        REG add "HKLM\SOFTWARE\Microsoft\Teams" /v "IsWVDEnvironment" /t REG_DWORD /d 1 /f 2> $Null
        REG add "HKLM\SOFTWARE\Citrix\PortICA" /v "IsWVDEnvironment" /t REG_DWORD /d 1 /f 2> $Null

        $params = @{
            FilePath     = "$env:SystemRoot\System32\msiexec.exe"
            ArgumentList = "/package $($OutFile.FullName) OPTIONS=`"noAutoStart=true`" ALLUSER=1 ALLUSERS=1 /quiet"
            WindowStyle  = "Hidden"
            Wait         = $True
            Verbose      = $True
        }
        Start-Process @params
    }
    catch {
        Write-Warning -Message " ERR: Failed to install Microsoft Teams."
    }
}
Else {
    Write-Host " Failed to retrieve Microsoft Teams"
}

# Teams JSON files
$ConfigFiles = @((Join-Path -Path "${env:ProgramFiles(x86)}\Teams Installer" -ChildPath "setup.json"),
    (Join-Path -Path "${env:ProgramFiles(x86)}\Microsoft\Teams" -ChildPath "setup.json"))

# Read the file and convert from JSON
ForEach ($Path in $ConfigFiles) {
    If (Test-Path -Path $Path) {
        try {
            $Json = Get-Content -Path $Path | ConvertFrom-Json
            $Json.noAutoStart = $true
            $Json | ConvertTo-Json | Set-Content -Path $Path -Force
        }
        catch {
            Write-Warning -Message " ERR: Failed to set Teams autostart file: $Path."
        }
    }
}

# Delete the registry auto-start
REG delete "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run" /v "Teams" /f 2> $Null

# If (Test-Path -Path $Path) { Remove-Item -Path $Path -Recurse -Confirm:$False -ErrorAction "SilentlyContinue" }
Write-Host " Complete: Microsoft Teams."
#endregion

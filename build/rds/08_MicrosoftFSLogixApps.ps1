<# 
    .SYNOPSIS
        Install evergreen core applications.
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $False)]
    [System.String] $LogPath = "$env:SystemRoot\Logs\Packer",

    [Parameter(Mandatory = $False)]
    [System.String] $Path = "$env:SystemDrive\Apps\Microsoft\FSLogix"
)


#region Script logic
# Set $VerbosePreference so full details are sent to the log; Make Invoke-WebRequest faster
$VerbosePreference = "Continue"
$ProgressPreference = "SilentlyContinue"

# Create target folder
New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null

Write-Host " Microsoft FSLogix agent"
$App = Get-EvergreenApp -Name "MicrosoftFSLogixApps" | Select-Object -First 1
If ($App) {
    
    # Download
    Write-Host " Microsoft FSLogix: $($App.Version)"
    $OutFile = Save-EvergreenApp -InputObject $App -Path $Path -WarningAction "SilentlyContinue"

    # Unpack
    try {
        Write-Host " Unpacking: $($OutFile.FullName)."
        Expand-Archive -Path $OutFile.FullName -DestinationPath $Path -Force -Verbose
    }
    catch {
        Write-Error -Message "ERROR: Failed to unpack: $($OutFile.FullName)."
    }
    
    # Install
    ForEach ($file in "FSLogixAppsSetup.exe", "FSLogixAppsRuleEditorSetup.exe") {
        $Installers = Get-ChildItem -Path $Path -Recurse -Include $file | Where-Object { $_.Directory -match "x64" }
        ForEach ($installer in $Installers) {
            try {
                Write-Host " Installing: $($installer.FullName)."
                $params = @{
                    FilePath     = $installer.FullName
                    ArgumentList = "/install /quiet /norestart"
                    WindowStyle  = "Hidden"
                    Wait         = $True
                    Verbose      = $True
                }
                Start-Process @params
            }
            catch {
                Write-Warning -Message " ERR: Failed to install: $($installer.FullName)."
            }
        }
    }
}
Else {
    Write-Host " Failed to retrieve Microsoft FSLogix Apps"
}
# If (Test-Path -Path $Path) { Remove-Item -Path $Path -Recurse -Confirm:$False -ErrorAction "SilentlyContinue" }
Write-Host " Complete: FSLogix."
#endregion

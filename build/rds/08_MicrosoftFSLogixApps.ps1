#Requires -Modules Evergreen
<#
    .SYNOPSIS
        Install evergreen core applications.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $False)]
    [System.String] $Path = "$env:SystemDrive\Apps\Microsoft\FSLogix"
)


#region Script logic
# Set $VerbosePreference so full details are sent to the log; Make Invoke-WebRequest faster
$VerbosePreference = "Continue"
$ProgressPreference = "SilentlyContinue"

# Create target folder
New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null

Write-Host "Microsoft FSLogix Apps agent"
$App = Get-EvergreenApp -Name "MicrosoftFSLogixApps" | Where-Object { $_.Channel -eq "Production" } | Select-Object -First 1
If ($App) {

    # Download
    Write-Host "`tMicrosoft FSLogix Apps agent: $($App.Version)."
    $OutFile = Save-EvergreenApp -InputObject $App -Path $Path -WarningAction "SilentlyContinue"

    # Unpack
    try {
        Write-Host "`tUnpacking: $($OutFile.FullName)."
        Expand-Archive -Path $OutFile.FullName -DestinationPath $Path -Force
    }
    catch {
        Write-Host "`tERR:: Failed to unpack: $($OutFile.FullName)."
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
                    PassThru     = $True
                    Verbose      = $True
                }
                $Result = Start-Process @params
            }
            catch {
                Write-Warning -Message "`tERR: Failed to install: $($installer.FullName)."
                Write-Warning -Message "`tExit code: $($Result.ExitCode)."
            }
        }
    }
}
Else {
    Write-Host "`tFailed to retrieve Microsoft FSLogix Apps."
}
# If (Test-Path -Path $Path) { Remove-Item -Path $Path -Recurse -Confirm:$False -ErrorAction "SilentlyContinue" }
Write-Host "Complete: Microsoft FSLogix Apps."
#endregion

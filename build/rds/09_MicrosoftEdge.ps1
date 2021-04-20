<# 
    .SYNOPSIS
        Install evergreen core applications.
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $False)]
    [System.String] $LogPath = "$env:SystemRoot\Logs\Packer",

    [Parameter(Mandatory = $False)]
    [System.String] $Path = "$env:SystemDrive\Apps\Microsoft\Edge"
)

#region Script logic
# Set $VerbosePreference so full details are sent to the log; Make Invoke-WebRequest faster
$VerbosePreference = "Continue"
$ProgressPreference = "SilentlyContinue"

# Create target folder
New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null

Write-Host " Microsoft Edge"
$App = Get-EvergreenApp -Name "MicrosoftEdge" | Where-Object { $_.Architecture -eq "x64" -and $_.Channel -eq "Stable" -and $_.Release -eq "Enterprise" } `
| Sort-Object -Property @{ Expression = { [System.Version]$_.Version }; Descending = $true } | Select-Object -First 1

If ($App) {
    
    # Download
    Write-Host " Downloading Microsoft Edge"
    $OutFile = Save-EvergreenApp -InputObject $App -Path $Path

    # Install
    Write-Host " Installing Microsoft Edge"
    try {
        $params = @{
            FilePath     = "$env:SystemRoot\System32\msiexec.exe"
            ArgumentList = "/package $($OutFile.Path) /quiet /norestart DONOTCREATEDESKTOPSHORTCUT=true"
            WindowStyle  = "Hidden"
            Wait         = $True
            PassThru     = $True
            Verbose      = $True
        }
        Start-Process @params
    }
    catch {
        Write-Warning -Message " ERR: Failed to install Microsoft Edge."
    }

    # Post install configuration
    Write-Host " Post-install config"
    $prefs = @{
        "homepage"               = "https://www.office.com"
        "homepage_is_newtabpage" = $False
        "browser"                = @{
            "show_home_button" = $True
        }
        "distribution"           = @{
            "skip_first_run_ui"              = $True
            "show_welcome_page"              = $False
            "import_search_engine"           = $False
            "import_history"                 = $False
            "do_not_create_any_shortcuts"    = $False
            "do_not_create_taskbar_shortcut" = $False
            "do_not_create_desktop_shortcut" = $True
            "do_not_launch_chrome"           = $True
            "make_chrome_default"            = $True
            "make_chrome_default_for_user"   = $True
            "system_level"                   = $True
        }
    }
    $prefs | ConvertTo-Json | Set-Content -Path "${Env:ProgramFiles(x86)}\Microsoft\Edge\Application\master_preferences" -Force
    Remove-Item -Path "$env:Public\Desktop\Microsoft Edge*.lnk" -Force -ErrorAction SilentlyContinue
    $services = "edgeupdate", "edgeupdatem", "MicrosoftEdgeElevationService"
    ForEach ($service in $services) { Get-Service -Name $service | Set-Service -StartupType "Disabled" }
    ForEach ($task in (Get-ScheduledTask -TaskName *Edge*)) { Unregister-ScheduledTask -TaskName $Task -Confirm:$False -ErrorAction SilentlyContinue }
    Write-Host " Done"
}
Else {
    Write-Warning -Message " ERR: Failed to retrieve Microsoft Edge"
}

If (Test-Path -Path $Path) { Remove-Item -Path $Path -Recurse -Confirm:$False -ErrorAction "SilentlyContinue" }
Write-Host " Complete: MicrosoftEdge."
#endregion

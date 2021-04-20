<# 
    .SYNOPSIS
        Optimise and seal a Windows image.
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $False)]
    [System.String] $LogPath = "$env:SystemRoot\Logs\Packer",

    [Parameter(Mandatory = $False)]
    [System.String] $Path = "$env:SystemDrive\Apps\Tools"
)

#region Script logic
# Set $VerbosePreference so full details are sent to the log; Make Invoke-WebRequest faster
$VerbosePreference = "Continue"
$ProgressPreference = "SilentlyContinue"

# Set TLS to 1.2; Create target folder

#region BIS-F
New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null
Write-Host "Using path: $Path."

$App = Get-EvergreenApp -Name "BISF"
If ($App) {
    
    # Download the latest BIS-F
    $OutFile = Save-EvergreenApp -InputObject $App -Path $Path
    
    # Install BIS-F
    try {
        Write-Host "Found MSI file: $($Installer.FullName)."
        $params = @{
            FilePath     = "$env:SystemRoot\System32\msiexec.exe"
            ArgumentList = "/i $($OutFile.Path) ALLUSERS=1 /quiet"
            WindowStyle  = "Hidden"
            Wait         = $True
            PassThru     = $True
            Verbose      = $True
        }
        $process = Start-Process @params
    }
    catch {
        Write-Warning -Message " ERR: Failed to install BIS-F with: $($_.Exception.Message)."
    }

    # If BIS-F installed OK, continue
    $BisfInstall = Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath "Base Image Script Framework (BIS-F)"
    Write-Host "BIS-F install path: $BisfInstall."
    If (Test-Path -Path $BisfInstall -ErrorAction "SilentlyContinue") {
        
        # Remove Start menu shortcut if it exists
        Write-Host "Remove BIS-F Start menu shortcut."
        $params = @{
            Path        = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Base Image Script Framework (BIS-F).lnk"
            Force       = $True
            Verbose     = $True
            ErrorAction = "SilentlyContinue"
        }
        Remove-Item @params
        
        # Copy BIS-F config files
        try {
            Write-Host "Copy BIS-F configuration files from: $Path to $BisfInstall."
            Switch -Regex ((Get-WmiObject Win32_OperatingSystem).Caption) {
                "Microsoft Windows Server*" {
                    $Config = "BISFconfig_MicrosoftWindowsServer2019Standard_64-bit.json"
                }
                "Microsoft Windows 10*" {
                    $Config = "BISFconfig_MicrosoftWindows10Enterprise_64-bit.json"
                }
                Default {
                }
            }
            $ConfigFile = Get-ChildItem -Path $Path -Recurse -Filter $Config
            $params = @{
                Path        = $ConfigFile.FullName
                Destination = $BisfInstall
                Force       = $True
                Verbose     = $True
                ErrorAction = "SilentlyContinue"
            }
            Write-Host "Copy BIS-F configuration file: $($ConfigFile.FullName)."
            Copy-Item @params
        }
        catch {
            Write-Warning -Message " ERR: Failed to copy BIS-F config file: $($ConfigFile.FullName) with: $($_.Exception.Message)."
        }

        # Set BISFSharedConfig.json
        try {
            $json = [PSCustomObject] @{
                ConfigFile = [System.IO.Path]::Combine(${env:ProgramFiles(x86)}, "Base Image Script Framework (BIS-F)", $ConfigFile) 
            }
            $params = @{
                FilePath    = [System.IO.Path]::Combine(${env:ProgramFiles(x86)}, "Base Image Script Framework (BIS-F)", "BISFSharedConfig.json")
                Encoding    = "utf8"
                Force       = $True
                Verbose     = $True
                ErrorAction = "SilentlyContinue"
            }
            Write-Host "Set BIS-F shared configuration file: BISFSharedConfig.json."
            $json | ConvertTo-Json | Out-File @params
        }
        catch {
            Write-Warning -Message " ERR: Failed to set BIS-F shared config file: $ConfigFile with: $($_.Exception.Message)."
        }

        # Run BIS-F
        Write-Host "Run BIS-F."
        try {
            Push-Location -Path (Join-Path -Path $BisfInstall -ChildPath "Framework")
            & "${env:ProgramFiles(x86)}\Base Image Script Framework (BIS-F)\Framework\PrepBISF_Start.ps1" -Verbose:$False
            Pop-Location
        }
        catch {
            Write-Warning -Message " ERR: BIS-F exited with: $($_.Exception.Message)."
        }
    }
    Else {
        Write-Warning -Message " ERR: Failed to find BIS-F in: ${env:ProgramFiles(x86)}\Base Image Script Framework (BIS-F)."
    }

}
#endregion

# If (Test-Path -Path $Path) { Remove-Item -Path $Path -Recurse -Confirm:$False -ErrorAction "SilentlyContinue" }
Write-Host " Complete: Bisf."
#endregion

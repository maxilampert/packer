<# 
    .SYNOPSIS
        Optimise and seal a Windows image.
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $False)]
    [System.String] $Log = "$env:SystemRoot\Logs\PackerImagePrep.log",

    [Parameter(Mandatory = $False)]
    [System.String] $Path = "$env:SystemDrive\Apps\BISF"
)

#region Functions
Function Global:Invoke-Process {
    <#PSScriptInfo 
    .VERSION 1.4 
    .GUID b787dc5d-8d11-45e9-aeef-5cf3a1f690de 
    .AUTHOR Adam Bertram 
    .COMPANYNAME Adam the Automator, LLC 
    .TAGS Processes 
    #>

    <# 
    .DESCRIPTION 
    Invoke-Process is a simple wrapper function that aims to "PowerShellyify" launching typical external processes. There 
    are lots of ways to invoke processes in PowerShell with Invoke-Process, Invoke-Expression, & and others but none account 
    well for the various streams and exit codes that an external process returns. Also, it's hard to write good tests 
    when launching external proceses. 
 
    This function ensures any errors are sent to the error stream, standard output is sent via the Output stream and any 
    time the process returns an exit code other than 0, treat it as an error. 
    #> 
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $FilePath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String] $ArgumentList
    )

    $ErrorActionPreference = 'Stop'

    try {
        $stdOutTempFile = "$env:TEMP\$((New-Guid).Guid)"
        $stdErrTempFile = "$env:TEMP\$((New-Guid).Guid)"

        $startProcessParams = @{
            FilePath               = $FilePath
            ArgumentList           = $ArgumentList
            RedirectStandardError  = $stdErrTempFile
            RedirectStandardOutput = $stdOutTempFile
            Wait                   = $true
            PassThru               = $true
            NoNewWindow            = $true
        }
        if ($PSCmdlet.ShouldProcess("Process [$($FilePath)]", "Run with args: [$($ArgumentList)]")) {
            $cmd = Start-Process @startProcessParams
            $cmdOutput = Get-Content -Path $stdOutTempFile -Raw
            $cmdError = Get-Content -Path $stdErrTempFile -Raw
            if ($cmd.ExitCode -ne 0) {
                if ($cmdError) {
                    throw $cmdError.Trim()
                }
                if ($cmdOutput) {
                    throw $cmdOutput.Trim()
                }
            }
            else {
                if ([System.String]::IsNullOrEmpty($cmdOutput) -eq $false) {
                    Write-Output -InputObject $cmdOutput
                }
            }
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
    finally {
        Remove-Item -Path $stdOutTempFile, $stdErrTempFile -Force -ErrorAction Ignore
    }
}
#endregion

#region Script logic
# Set $VerbosePreference so full details are sent to the log; Make Invoke-WebRequest faster
$VerbosePreference = "Continue"
$ProgressPreference = "SilentlyContinue"

# Set TLS to 1.2; Create target folder
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12


#region BIS-F
$Bisf = Get-BISF
New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null
$Installer = Join-Path -Path $Path -ChildPath (Split-Path -Path $Bisf.URI -Leaf)
Write-Host "Using path: $Path."

# Download the latest BIS-F
try {
    $params = @{
        Uri             = $Bisf.URI
        OutFile         = $Installer
        UseBasicParsing = $True
    }
    Invoke-WebRequest @params
}
catch {
    Write-Warning -Message "Invoke-WebRequest exited with: $($_.Exception.Message)."
}

$Installer = Get-ChildItem -Path $Path -Filter $(Split-Path -Path $Bisf.URI -Leaf) -ErrorAction "SilentlyContinue" 
If ($Installer) {
    
    # Install BIS-F
    Write-Host "Found MSI file: $($Installer.FullName)."
    try {
        $params = @{
            FilePath     = "$env:SystemRoot\System32\msiexec.exe"
            ArgumentList = "/i $($Installer.FullName) ALLUSERS=1 /quiet"
            Verbose      = $True
        }
        Invoke-Process @params
    }
    catch {
        Throw "Failed to install BIS-F with: $($_.Exception.Message)."
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
        Write-Host "Copy BIS-F configuration files from: $Path to $BisfInstall."
        try {
            Switch -Regex ((Get-WmiObject Win32_OperatingSystem).Caption) {
                "Microsoft Windows Server*" {
                    $ConfigFile = "BISFconfig_MicrosoftWindowsServer2019Standard_64-bit.json"
                }
                "Microsoft Windows 10*" {
                    $ConfigFile = "BISFconfig_MicrosoftWindows10Enterprise_64-bit.json"
                }
                Default {
                }
            }
            $params = @{
                Path        = (Join-Path -Path $Path -ChildPath $ConfigFile)
                Destination = $BisfInstall
                Force       = $True
                Verbose     = $True
                ErrorAction = "SilentlyContinue"
            }
            Write-Host "Copy BIS-F configuration file: $ConfigFile."
            Copy-Item @params
        }
        catch {
            Throw "Failed to copy BIS-F config file: $ConfigFile with: $($_.Exception.Message)."
        }
        try {
            $json = [PSCustomObject] @{
                ConfigFile = [System.IO.Path]::Combine(${env:ProgramFiles(x86)}, "Base Image Script Framework (BIS-F)", $ConfigFile) 
            }
            $params = @{
                FilePath    = [System.IO.Path]::Combine(${env:ProgramFiles(x86)}, "Base Image Script Framework (BIS-F)", "BISFSharedConfig.json")
                Encoding    = utf8
                Force       = $True
                Verbose     = $True
                ErrorAction = "SilentlyContinue"
            }
            Write-Host "Set BIS-F shared configuration file: BISFSharedConfig.json."
            $json | ConvertTo-Json | Out-File @params
        }
        catch {
            Throw "Failed to set BIS-F shared config file: $ConfigFile with: $($_.Exception.Message)."
        }

        # Run BIS-F
        Write-Host "Run BIS-F."
        try {
            $VerbosePreference = "SilentlyContinue"
            Push-Location -Path $BisfInstall
            & "${env:ProgramFiles(x86)}\Base Image Script Framework (BIS-F)\Framework\PrepBISF_Start.ps1"
            Pop-Location
            $VerbosePreference = "Continue"
        }
        catch {
            Write-Warning -Message "BIS-F exited with: $($_.Exception.Message)."
        }
    }
    Else {
        Throw "Failed to find BIS-F in: ${env:ProgramFiles(x86)}\Base Image Script Framework (BIS-F)."
    }
}
Else {
    Throw "Failed to find BIS-F in: $Path."
}
#endregion

Write-Host " Complete: Bisf."
#endregion

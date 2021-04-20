<# 
    .SYNOPSIS
        Optimise and seal a Windows image.
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $False)]
    [System.String] $LogPath = "$env:SystemRoot\Logs\Packer",

    [Parameter(Mandatory = $False)]
    [System.String] $Path = "$env:SystemDrive\Apps\Tools",

    [Parameter(Mandatory = $False)]
    [System.String] $OptimizerTemplate = "Custom-Windows10-20H2.xml"
)

#region Script logic
# Set $VerbosePreference so full details are sent to the log; Make Invoke-WebRequest faster
$VerbosePreference = "Continue"
$ProgressPreference = "SilentlyContinue"

# Set TLS to 1.2; Create target folder
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null

#region Citrix Optimizer
Write-Host "Using path: $Path."
$Installer = Get-ChildItem -Path $Path -Filter "CitrixOptimizer.zip" -Recurse -ErrorAction "SilentlyContinue"

<#
If ($Null -eq $Installer) {
    Write-Host " Citrix Optimizer not in $Path. Downloading from repository."
    try {
        $params = @{
            Uri             = "https://raw.githubusercontent.com/aaronparker/packer/main/tools/rds/citrixoptimizer/CitrixOptimizer.zip"
            OutFile         = (Join-Path -Path $Path -ChildPath "CitrixOptimizer.zip")
            UseBasicParsing = $True
            ErrorAction     = "SilentlyContinue"
        }
        Invoke-WebRequest @params
    }
    catch {
        Write-Warning -Message "Invoke-WebRequest exited with: $($_.Exception.Message)."
    }
    $Installer = Get-ChildItem -Path $Path -Filter "CitrixOptimizer.zip" -Recurse -ErrorAction "SilentlyContinue"
}
#>

If ($Installer) {
    Write-Host "Found zip file: $($Installer.FullName)."
    Expand-Archive -Path $Installer.FullName -DestinationPath $Path -Force -Verbose

    $Template = Get-ChildItem -Path $Path -Recurse -Filter $OptimizerTemplate
    If ($Template) {
        Write-Host "Found template file: $($Template.FullName)."
        try {
            $OptimizerBin = Get-ChildItem -Path $Path -Recurse -Filter "CtxOptimizerEngine.ps1"
            Push-Location -Path $OptimizerBin.Directory
            Write-Host "Running: $($OptimizerBin.FullName) -Source $($Template.FullName) -Mode execute"
            Write-Host "Report will be saved to: $Path\CitrixOptimizer.html."
            Write-Host "Logs will be saved to: $LogPath."
            $params = @{
                Source          = $Template.FullName
                Mode            = "Execute"
                OutputLogFolder = $LogPath
                OutputHtml      = "$Path\CitrixOptimizer.html"
                Verbose         = $False
            }
            & $OptimizerBin.FullName @params
            Pop-Location
        }
        catch {
            Write-Warning -Message " ERR: Citrix Optimizer exited with: $($_.Exception.Message)."
        }
    }
    Else {
        Write-Warning -Message " ERR: Failed to find Citrix Optimizer template: $OptimizerTemplate in $Path."
    }
}
Else {
    Write-Warning -Message " ERR: Failed to find Citrix Optimizer in: $Path."
}
#endregion

# If (Test-Path -Path $Path) { Remove-Item -Path $Path -Recurse -Confirm:$False -ErrorAction "SilentlyContinue" }
Write-Host " Complete: Optimise."
#endregion

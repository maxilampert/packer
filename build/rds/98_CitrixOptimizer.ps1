<#
    .SYNOPSIS
        Optimise and seal a Windows image.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $False)]
    [System.String] $Path = "$env:SystemDrive\Apps\Tools",

    [Parameter(Mandatory = $False)]
    [System.String] $OptimizerTemplate = "Custom-Windows10-20H2.xml"
)

#region Script logic
# Make Invoke-WebRequest faster
$ProgressPreference = "SilentlyContinue"

# Set TLS to 1.2; Create target folder
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null

#region Citrix Optimizer
Write-Host "Citrix Optimizer."
Write-Host "`tUsing path: $Path."
$Installer = Get-ChildItem -Path $Path -Filter "CitrixOptimizer.zip" -Recurse -ErrorAction "SilentlyContinue"

If ($Installer) {
    Write-Host "`tFound zip file: $($Installer.FullName)."
    Expand-Archive -Path $Installer.FullName -DestinationPath $Path -Force

    $Template = Get-ChildItem -Path $Path -Recurse -Filter $OptimizerTemplate
    If ($Template) {
        Write-Host "`tFound template file: $($Template.FullName)."
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
            & $OptimizerBin.FullName @params 2> $Null
            Pop-Location
        }
        catch {
            Write-Warning -Message "`tERR: Citrix Optimizer exited with: $($_.Exception.Message)."
        }
    }
    Else {
        Write-Warning -Message "`tERR: Failed to find Citrix Optimizer template: $OptimizerTemplate in $Path."
    }
}
Else {
    Write-Warning -Message "`tERR: Failed to find Citrix Optimizer in: $Path."
}
#endregion

# If (Test-Path -Path $Path) { Remove-Item -Path $Path -Recurse -Confirm:$False -ErrorAction "SilentlyContinue" }
Write-Host "Complete: Citrix Optimizer."
#endregion

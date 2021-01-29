<# 
    .SYNOPSIS
        Install evergreen core applications.
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $False)]
    [System.String] $Log = "$env:SystemRoot\Logs\PackerImagePrep.log",

    [Parameter(Mandatory = $False)]
    [System.String] $Target = "$env:SystemDrive\Apps"
)

#region Functions
Function Install-FSLogix ($Path) {
    Write-Host "================ Microsoft FSLogix agent"
    $FSLogix = Get-MicrosoftFSLogixApps

    If ($FSLogix) {
        Write-Host "================ Microsoft FSLogix: $($FSLogix.Version)"
        If (!(Test-Path $Path)) { New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null }

        # Download
        $OutFile = Join-Path -Path $Path -ChildPath (Split-Path -Path $FSLogix.URI -Leaf)
        Write-Host "================ Downloading to: $OutFile"
        try {
            Invoke-WebRequest -Uri $FSLogix.URI -OutFile $OutFile -UseBasicParsing
            If (Test-Path -Path $OutFile) { Write-Host "================ Downloaded: $OutFile." }
        }
        catch {
            Throw "Failed to download FSLogix Apps"
        }

        # Unpack
        try {
            Write-Host "================ Unpacking: $OutFile."
            Expand-Archive -Path $OutFile -DestinationPath $Path -Force
        }
        catch {
            Throw "Failed to unpack: $OutFile."
        }
        
        # Install
        ForEach ($file in "FSLogixAppsSetup.exe", "FSLogixAppsRuleEditorSetup.exe") {
            try {
                $installer = (Get-ChildItem -Path $Path -Recurse -Filter $file) -match "x64"
                Write-Host "================ Installing: $($installer.FullName)."
                Invoke-Process -FilePath $installer.FullName -ArgumentList "/install /quiet /norestart" -Verbose
            }
            catch {
                Throw "Failed to install: $($installer.FullName)."
            }
        }
        Write-Host "================ Done"
    }
    Else {
        Write-Host "================ Failed to retreive Microsoft FSLogix Apps"
    }
}
#endregion Functions


#region Script logic
# Set $VerbosePreference so full details are sent to the log; Make Invoke-WebRequest faster
$VerbosePreference = "Continue"
$ProgressPreference = "SilentlyContinue"

# Start logging
Start-Transcript -Path $Log -Append -ErrorAction SilentlyContinue

# Set TLS to 1.2; Create target folder
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
New-Item -Path $Target -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null

# Run tasks/install apps
Install-FSLogix -Path "$Target\FSLogix"

# Stop Logging
Stop-Transcript -ErrorAction SilentlyContinue
Write-Host "================ Complete: FSLogix."
#endregion

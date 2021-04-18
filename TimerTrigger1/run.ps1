# Input bindings are passed in via param block.
[CmdletBinding()]
param(
    [Parameter()]    
    $Timer,

    [Parameter()]
    [System.String] $Path,

    [Parameter()]
    [System.String] $Config = ".\Apps.json"
)

# Get the current universal time in the default string format
# The 'IsPastDue' property is 'true' when the current function invocation is later than scheduled.
# Write an information log with the current time.
<#
$currentUTCtime = (Get-Date).ToUniversalTime()
if ($Timer.IsPastDue) {
    Write-Host "PowerShell timer is running late!"
}
Write-Host "PowerShell timer trigger function ran! TIME: $currentUTCtime"
#>

Function Install-AzCopy {
    [CmdletBinding()]
    param(
        [Parameter()]
        [System.String] $Path = "C:\AzCopy"
    )

    # Set TLS to 1.2; Create target folder
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null

    # Download AzCopy zip for Windows
    try {
        $OutFile = (Join-Path -Path $Path -ChildPath "azcopy.zip")
        $params = @{
            Uri             = "https://aka.ms/downloadazcopy-v10-windows"
            OutFile         = $OutFile
            UseBasicParsing = $True
        }
        Invoke-WebRequest @params
    }
    catch {
        Throw "Invoke-WebRequest exited with: $($_.Exception.Message)."
    }

    # Expand the Zip file
    Expand-Archive -Path $OutFile -DestinationPath $OutFile

    # Move to $Path
    $AzBin = Get-ChildItem -Path $Path -Filter "azcopy.exe" -Recurse
    Write-Output -InputObject $AzBin.FullPath
}

# Create the path folder if it doesn't exist
New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null

# Get the applications list from the provided JSON
$Applications = Get-Content -Path $Config | ConvertFrom-Json

# Walk through each application and save to $Path
$Applications.Apps.PSObject.Properties | ForEach-Object {
    $ScriptBlock = [ScriptBlock]::Create("Get-EvergreenApp -Name $($_.Name) | $($_.Value)")
    $App = Invoke-Command -ScriptBlock $ScriptBlock
    $Folder = Join-Path -Path $Path -ChildPath $_.Name
    New-Item -Path $Folder -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null
    Save-EvergreenApp -Path $Folder -InputObject $App
}

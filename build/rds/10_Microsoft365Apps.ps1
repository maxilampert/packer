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

Function Install-Microsoft365Apps ($Path) {

    $OfficeXml = @"
    <Configuration ID="a39b1c70-558d-463b-b3d4-9156ddbcbb05">
    <Add OfficeClientEdition="64" Channel="MonthlyEnterprise" MigrateArch="TRUE">
      <Product ID="O365ProPlusRetail">
        <Language ID="MatchOS" />
        <Language ID="MatchPreviousMSI" />
        <ExcludeApp ID="Access" />
        <ExcludeApp ID="Groove" />
        <ExcludeApp ID="Lync" />
        <ExcludeApp ID="Publisher" />
        <ExcludeApp ID="Bing" />
        <ExcludeApp ID="Teams" />
      </Product>
    </Add>
    <Property Name="SharedComputerLicensing" Value="0" />
    <Property Name="PinIconsToTaskbar" Value="FALSE" />
    <Property Name="SCLCacheOverride" Value="0" />
    <Property Name="AUTOACTIVATE" Value="0" />
    <Property Name="FORCEAPPSHUTDOWN" Value="TRUE" />
    <Property Name="DeviceBasedLicensing" Value="0" />
    <Updates Enabled="FALSE" />
    <RemoveMSI />
    <AppSettings>
    <User Key="software\microsoft\office\16.0\common\toolbars" Name="customuiroaming" Value="1" Type="REG_DWORD" App="office16" Id="L_AllowRoamingQuickAccessToolBarRibbonCustomizations" />
    <User Key="software\microsoft\office\16.0\common\general" Name="shownfirstrunoptin" Value="1" Type="REG_DWORD" App="office16" Id="L_DisableOptinWizard" />
    <User Key="software\microsoft\office\16.0\common\languageresources" Name="installlanguage" Value="3081" Type="REG_DWORD" App="office16" Id="L_PrimaryEditingLanguage" />
    <User Key="software\microsoft\office\16.0\common\fileio" Name="disablelongtermcaching" Value="1" Type="REG_DWORD" App="office16" Id="L_DeleteFilesFromOfficeDocumentCache" />
    <User Key="software\microsoft\office\16.0\common\graphics" Name="disablehardwareacceleration" Value="1" Type="REG_DWORD" App="office16" Id="L_DoNotUseHardwareAcceleration" />
    <User Key="software\microsoft\office\16.0\common\general" Name="disablebackgrounds" Value="1" Type="REG_DWORD" App="office16" Id="L_DisableBackgrounds" />
    <User Key="software\microsoft\office\16.0\firstrun" Name="disablemovie" Value="1" Type="REG_DWORD" App="office16" Id="L_DisableMovie" />
    <User Key="software\microsoft\office\16.0\firstrun" Name="bootedrtm" Value="1" Type="REG_DWORD" App="office16" Id="L_DisableOfficeFirstrun" />
    <User Key="software\microsoft\office\16.0\common" Name="default ui theme" Value="0" Type="REG_DWORD" App="office16" Id="L_DefaultUIThemeUser" />
    <User Key="software\microsoft\office\16.0\excel\options" Name="defaultformat" Value="51" Type="REG_DWORD" App="excel16" Id="L_SaveExcelfilesas" />
    <User Key="software\microsoft\office\16.0\onenote\options\other" Name="runsystemtrayapp" Value="0" Type="REG_DWORD" App="onent16" Id="L_AddOneNoteicontonotificationarea" />
    <User Key="software\microsoft\office\16.0\outlook\preferences" Name="disablemanualarchive" Value="1" Type="REG_DWORD" App="outlk16" Id="L_DisableFileArchive" />
    <User Key="software\microsoft\office\16.0\outlook\options\rss" Name="disable" Value="1" Type="REG_DWORD" App="outlk16" Id="L_TurnoffRSSfeature" />
    <User Key="software\microsoft\office\16.0\outlook\setup" Name="disableroamingsettings" Value="0" Type="REG_DWORD" App="outlk16" Id="L_DisableRoamingSettings" />
    <User Key="software\microsoft\office\16.0\powerpoint\options" Name="defaultformat" Value="27" Type="REG_DWORD" App="ppt16" Id="L_SavePowerPointfilesas" />
    <User Key="software\microsoft\office\16.0\word\options" Name="defaultformat" Value="" Type="REG_SZ" App="word16" Id="L_SaveWordfilesas" />
    </AppSettings>
    <Display Level="None" AcceptEULA="TRUE" />
    <Logging Level="Standard" Path="C:\Apps" />
  </Configuration>
"@

    # Get Office version
    Write-Host " Microsoft Office"
    $Office = Get-MicrosoftOffice | Where-Object { $_.Channel -eq "Monthly" }
    
    If ($Office) {
        If (!(Test-Path $Path)) { New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null }
        
        # Download setup.exe
        $url = $Office.URI
        $OutFile = Join-Path -Path $Path -ChildPath $(Split-Path -Path $url -Leaf)
        Write-Host " Downloading to: $OutFile"
        try {
            Invoke-WebRequest -Uri $url -OutFile $OutFile -UseBasicParsing
            If (Test-Path -Path $OutFile) { Write-Host " Downloaded: $OutFile." }
        }
        catch {
            Throw "Failed to download Microsoft Office setup."
        }

        # Download Office package, Setup fails to exit, so wait 9-10 mins for Office install to complete
        Write-Host " Installing Microsoft Office"

        Push-Location -Path $Path
        $XmlFile = Join-Path -Path $Path -ChildPath "Office.xml"
        Out-File -FilePath $XmlFile -InputObject $OfficeXml -Encoding utf8

        Invoke-Process -FilePath $OutFile -ArgumentList "/configure $XmlFile" -Verbose
        Pop-Location
        Remove-Variable -Name url
        Write-Host " Done"
    }
    Else {
        Write-Host " Failed to retreive Microsoft Office"
    }
}

Function Install-MicrosoftTeams ($Path) {
    Write-Host " Microsoft Teams"
    Write-Host " Downloading Microsoft Teams"
    $Teams = Get-MicrosoftTeams | Where-Object { $_.Architecture -eq "x64" -and $_.Ring -eq "General" }
    
    If ($Teams) {
        If (!(Test-Path $Path)) { New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null }

        # Download
        $url = $Teams.URI
        $OutFile = Join-Path -Path $Path -ChildPath $(Split-Path -Path $url -Leaf)
        Write-Host " Downloading to: $OutFile"
        try {
            Invoke-WebRequest -Uri $url -OutFile $OutFile -UseBasicParsing
            If (Test-Path -Path $OutFile) { Write-Host " Downloaded: $OutFile." }
        }
        catch {
            Throw "Failed to download Microsoft Teams."
        }

        # Install
        Write-Host " Installing Microsoft Teams"
        try {
            reg add "HKLM\SOFTWARE\Microsoft\Teams" /v "IsWVDEnvironment" /t REG_DWORD /d 1 /f
            reg add "HKLM\SOFTWARE\Citrix\PortICA" /v "IsWVDEnvironment" /t REG_DWORD /d 1 /f
            $params = @{
                FilePath     = "$env:SystemRoot\System32\msiexec.exe"
                # ArgumentList = "/package $OutFile ALLUSER=1 ALLUSERS=1 " + 'OPTIONS="noAutoStart=true" /quiet'
                ArgumentList = "/package $OutFile ALLUSER=1 ALLUSERS=1 /quiet"
                Verbose      = $True
            }
            Invoke-Process @params
            Remove-Variable -Name url
        }
        catch {
            Throw "Failed to install Microsoft Teams."
        }
        Write-Host " Done"
    }
    Else {
        Write-Host " Failed to retreive Microsoft Teams"
    }
}

Function Set-TeamsAutostart {
    # Teams JSON files
    $Paths = @((Join-Path -Path "${env:ProgramFiles(x86)}\Teams Installer" -ChildPath "setup.json"), 
        (Join-Path -Path "${env:ProgramFiles(x86)}\Microsoft\Teams" -ChildPath "setup.json"))

    # Read the file and convert from JSON
    ForEach ($Path in $Paths) {
        If (Test-Path -Path $Path) {
            try {
                $Json = Get-Content -Path $Path | ConvertFrom-Json
                $Json.noAutoStart = $true
                $Json | ConvertTo-Json | Set-Content -Path $Path -Force
            }
            catch {
                Throw "Failed to set Teams autostart file: $Path."
            }
        }
    }

    # Delete the registry auto-start
    reg delete "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run" /v "Teams" /f
}

Function Install-MicrosoftOneDrive ($Path) {
    Write-Host " Microsoft OneDrive"    
    Write-Host " Downloading Microsoft OneDrive"
    $OneDrive = Get-MicrosoftOneDrive | Where-Object { $_.Ring -eq "Production" -and $_.Type -eq "Exe" } | `
        Sort-Object -Property @{ Expression = { [System.Version]$_.Version }; Descending = $true } | Select-Object -First 1

    If ($OneDrive) {
        If (!(Test-Path $Path)) { New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null }

        # Download
        $url = $OneDrive.URI
        $OutFile = Join-Path -Path $Path -ChildPath $(Split-Path -Path $url -Leaf)
        Write-Host " Downloading to: $OutFile"
        try {
            Invoke-WebRequest -Uri $url -OutFile $OutFile -UseBasicParsing
            If (Test-Path -Path $OutFile) { Write-Host " Downloaded: $OutFile." }
        }
        catch {
            Write-Warning "Failed to download Microsoft OneDrive. Falling back to direct URL."
            $url = "https://oneclient.sfx.ms/Win/Prod/20.052.0311.0011/OneDriveSetup.exe"
            $OutFile = Join-Path -Path $Path -ChildPath $(Split-Path -Path $url -Leaf)
            Invoke-WebRequest -Uri $url -OutFile $OutFile -UseBasicParsing
            If (Test-Path -Path $OutFile) { Write-Host " Downloaded: $OutFile." }
        }
    
        # Install
        Write-Host " Installing Microsoft OneDrive"
        try {
            Invoke-Process -FilePath $OutFile -ArgumentList "/ALLUSERS" -Verbose
        }
        catch {
            Throw "Failed to install Microsoft OneDrive."
        }
        Remove-Variable -Name url
        Write-Host " Done"
    }
    Else {
        Write-Host " Failed to retrieve Microsoft OneDrive"
    }
}
#endregion Functions


#region Script logic
# Set $VerbosePreference so full details are sent to the log; Make Invoke-WebRequest faster
$VerbosePreference = "Continue"
$ProgressPreference = "SilentlyContinue"

# Set TLS to 1.2; Create target folder
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
New-Item -Path $Target -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null

# Run tasks/install apps
Install-Microsoft365Apps -Path "$Target\Microsoft365Apps"
Install-MicrosoftTeams -Path "$Target\Teams"
Set-TeamsAutostart
Install-MicrosoftOneDrive -Path "$Target\OneDrive"
Write-Host " Complete: Microsoft365Apps."
#endregion

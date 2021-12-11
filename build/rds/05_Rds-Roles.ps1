<#
    .SYNOPSIS
        Enable/disable Windows roles and features and set language/regional settings.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
[CmdletBinding()]
param ()

#region Script logic
# Set $VerbosePreference so full details are sent to the log; Make Invoke-WebRequest faster
$VerbosePreference = "Continue"
$ProgressPreference = "SilentlyContinue"

# Run tasks
Switch -Regex ((Get-CimInstance -ClassName "CIM_OperatingSystem").Caption) {
    "Microsoft Windows Server*" {
        # Add / Remove roles and features (requires reboot at end of deployment)
        try {
            $params = @{
                FeatureName   = "Printing-XPSServices-Features", "WindowsMediaPlayer"
                Online        = $true
                NoRestart     = $true
                WarningAction = "Continue"
                ErrorAction   = "Continue"
            }
            Disable-WindowsOptionalFeature @params
        }
        catch {
            Write-Warning -Message " ERR: Failed to set feature state with: $($_.Exception.Message)."
        }

        try {
            $params = @{
                Name                   = "BitLocker", "EnhancedStorage", "PowerShell-ISE"
                IncludeManagementTools = $true
                WarningAction          = "Continue"
                ErrorAction            = "Continue"
            }
            Uninstall-WindowsFeature @params
        }
        catch {
            Write-Warning -Message " ERR: Failed to set feature state with: $($_.Exception.Message)."
        }

        $params = @{
            Name          = "RDS-RD-Server", "Server-Media-Foundation", "Search-Service", "NET-Framework-Core", "Remote-Assistance"
            WarningAction = "Continue"
            ErrorAction   = "Continue"
        }
        Install-WindowsFeature @params

        # Enable services
        If ((Get-WindowsFeature -Name "RDS-RD-Server").InstallState -eq "Installed") {
            ForEach ($service in "Audiosrv", "WSearch") {
                try {
                    $params = @{
                        Name          = $service
                        StartupType   = "Automatic"
                        WarningAction = "Continue"
                        ErrorAction   = "Continue"
                    }
                    Set-Service @params
                }
                catch {
                    Write-Warning -Message " ERR: Failed to set service properties with: $($_.Exception.Message)."
                }
            }
        }
        Break
    }
    "Microsoft Windows 1* Enterprise for Virtual Desktops" {
        Break
    }
    "Microsoft Windows 1* Enterprise" {
        Break
    }
    "Microsoft Windows 1*" {
        Break
    }
    Default {
    }
}

Write-Host " Complete: Roles."

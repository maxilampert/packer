<# 
    .SYNOPSIS
        Install evergreen core applications.
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $False)]
    [System.String] $LogPath = "$env:SystemRoot\Logs\Packer",

    [Parameter(Mandatory = $False)]
    [System.String] $Path = "$env:SystemDrive\Apps\Citrix\VDA",

    [Parameter(Mandatory = $False)]
    [System.String] $FilePath = "$Env:ProgramData\Citrix\XenDesktopSetup\XenDesktopVdaSetup.exe"
)

If (Test-Path -Path $FilePath) {
    try {
        $params = @{
            FilePath     = "$Env:ProgramData\Citrix\XenDesktopSetup\XenDesktopVdaSetup.exe"
            ArgumentList = ""
            WindowStyle  = "Hidden"
            Wait         = $True
            PassThru     = $True
            Verbose      = $True
        }
        $process = Start-Process @params
    }
    catch {
        Write-Error -Message "Citrix VDA Setup exited with: $($process.ExitCode)"
    }
}
Else {
    Write-Host " Citrix VDA not found. Skipping resume."
}

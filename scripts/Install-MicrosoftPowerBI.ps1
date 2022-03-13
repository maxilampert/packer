## <Perform Installation tasks here>
$params = '-silent -norestart ACCEPT_EULA=1 INSTALLDESKTOPSHORTCUT=0 DISABLE_UPDATE_NOTIFICATION=1 ENABLECXP=0'
Execute-Process -Path 'PBIDesktopSetup_x64.exe' -Parameters $params

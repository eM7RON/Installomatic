. .\define.ps1

$logPath = Join-Path -Path $logDir -ChildPath ($displayName + "Install.log")

# Create a new, empty log file or clear the existing one
"" | Out-File -FilePath $logPath
Log "Log started at $(Get-Date)"

Ensure-Directory $downloadDir

Log "Installation of $displayName beginning..."


Log "Checking for previous user-level installations..."
if ($preInstallRegistryHives -and $preInstallRegistryHives.Length -gt 0) {
    $uninstallString = Get-UninstallStrings $preInstallRegistryHives

    if ($uninstallStrings -and $uninstallStrings.Length -gt 0) {

        foreach ($uninstallString in $uninstallStrings) {

            Log "Previous install found $uninstallString"
            
            $processedStrings = (Process-UninstallString $uninstallString $preUninstallerArgList)
            $executable = $processedStrings[0]
            $arguments = $processedStrings[1]
            Uninstall-App $executable $arguments

            if (!(Is-Installed)) {
                break
            }
        }
    } 
    else {
        Log "No previous install found"
    }
}

if (!(Is-Installed)) {
    
    if ($wingetAppID) {
        Lof "Attempting to install via Winget..."
        Install-App $wingetPath $wingetInstallArgList
    }

    if (!(Is-Installed)) {
        Log "Attempting to install from 1st fallback option"
        Download-File $fallbackDownloadURL $downloadPath
        Install-App $fallbackInstallerPath1 $fallbackArgList1
        Remove-File $downloadPath

        if (!(Is-Installed)) {
            Log "Attempting to install from second fallback option"
            Install-App $fallbackInstallerPath2 $fallbackArgList2
        }
    }

}

Log "Performing final check..."
if (Is-Installed) {
    Log "Install detected" Green
    Log "Exit code 0"
    Exit 0
} 
else {
    Log "Installation not detected" Red
    Log "Installation failed" Red
    Log "Exit code 1"
    Exit 1
}
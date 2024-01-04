. .\define.ps1

$logPath = Join-Path -Path $logDir -ChildPath ($displayName + "Uninstall.log")

# Create a new, empty log file or clear the existing one
"" | Out-File -FilePath $logPath
Log "Log started at $(Get-Date)"

Log "Uninstall of $displayName starting..."

if (Is-Installed) {
    
    if ($wingetAppID) {
        Log "Attempting to install via Winget..."
        Uninstall-App $wingetPath $wingetUninstallArgList
    }
    
    if (Is-Installed) {
        Log "Attempting to uninstall using uninstall string..."
        $uninstallStrings = Get-UninstallStrings $uninstallRegistryHives

        if ($uninstallStrings -and $uninstallStrings.Length -gt 0) {
            foreach ($uninstallString in $uninstallStrings) {
                $processedStrings = (Process-UninstallString $uninstallString $uninstallerArgList)
                $executable = $processedStrings[0]
                $arguments = $processedStrings[1]
                Uninstall-App $executable $arguments

                if (!(Is-Installed)) {
                    break
                }
            }
        } 
        else {
            Log "No uninstall strings found"
        }

    }

}

Log "Performing final check..."
if (!(Is-Installed)) {
    Log "Installation not detected" Green
    Log "Exit code 0"
    Exit 0
} 
else {
    Log "Installation detected" Red
    Log "Uninstallation failed" Red
    Log "Exit code 1"
    Exit 1
}
##################################################################################################################################
##################################################################################################################################                                                                                                                       
#
# Installomatic
# 2024 Simon Tucker
#                                                                                                                                
##################################################################################################################################
##################################################################################################################################

################################################
# NOTE: The following variables should be set  #
################################################

$displayName = "Notepad++"
# Taken from the registry entry HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*
# this is used to find the app's uninstall string 

$wingetAppID = "Notepad++.Notepad++"
# This is used to identify the app in the Winget database.

$installContext = "machine" # machine | user

$installerType = "exe"
# exe | msi | msixbundle
# The file extension of the fallback installer used if Winget fails.

$installerArgList = '/q /norestart'
$uninstallerArgList = '/quiet'
# Arguments to pass to the fallback installers or uninstaller. The are normally one of the following:
# /qn | /S | --silent etc... The uninstaller will likely come from the uninstall string.

$fallbackDownloadURL = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
# A URL to fetch the latest version of the app.

$githubRegex = ""
# If above is for a Github latest release page this regex pattern will match be used to 
# match the installer asset to be downloaded.

$installRegistryItems = @(
    # @{
    #     Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\SAIIT';
    #     Keys = @(
    #         @{ Name = 'Installed'; Value = 1; Type = 'STRING'},
    #         @{ Name = 'Bld'; Value = 0x0000816a; Type = 'DWORD'}
    #         # Add more key-value pairs as needed for X64
    #     )
    # }
    # @{
    #     Path = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\X86';
    #     Keys = @(
    #         @{ Key = 'Installed'; Value = 1 },
    #         @{ Key = 'Bld'; Value = 0x0000816a }
    #         # Add more key-value pairs as needed for X86
    #     )
    # }
    # Add more path entries as needed
)


############ Testing variables ############## 

$testExecutablePath = ''
# Path to the executable for testing if app is installed.

$testRegistryItems = @(
    @{
        Path = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\X64';
        Keys = @(
            @{ Name = 'Installed'; Value = 1},
            @{ Name = 'Bld'; Value = 0x0000816a}
            # Add more key-value pairs as needed for X64
        )
    }
    # @{
    #     Path = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\X86';
    #     Keys = @(
    #         @{ Name = 'Installed'; Value = 1 },
    #         @{ Name = 'Bld'; Value = 0x0000816a }
    #         # Add more key-value pairs as needed for X86
    #     )
    # }
    # Add more path entries as needed
)

$preInstallRegistryHives = @("HKCU:")
$uninstallRegistryHives = @("HKLM:", "HKCU:")

#######################################################
# NOTE: The following variables should NOT be changed #
#######################################################

param (
    [string] $mode
)

if ($mode) {
    $mode = $mode.ToLower()
    $mode = $mode.Trim()
}

if ($fallbackDownloadURL -Match "github") {
    $fallbackDownloadURL = (Invoke-WebRequest -Uri $fallbackDownloadURL -UseBasicParsing).Content | ConvertFrom-Json |
    Select-Object -ExpandProperty "assets" |
    Where-Object "browser_download_url" -Match $githubRegex |
    Select-Object -ExpandProperty "browser_download_url"
}

$installerFilename = "$displayName.$installerType"
# If Winget fails we will attempt to download the latest installer ourselves. This is what the 
# installer file will be named.

$downloadDir = "C:\ProgramData\SAIIT\temp"
# URL to download the latest MSI installer as 1st fallback option.

$downloadPath = Join-Path -Path $downloadDir -ChildPath $installerFilename
# When we download the fallback installer this will be its full path.

$logDir = "C:\ProgramData\SAIIT\logs"
# The directory where logs are stored

$wingetPath = (Resolve-Path "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe")[-1].Path
$wingetInstallArgList = "install -e --id $wingetAppID --scope=$installContext --silent --accept-package-agreements --accept-source-agreements"
$wingetUninstallArgList = "uninstall -e --id $wingetAppID --silent"

if ($installerType -ne "msi") {
    $fallbackInstallerPath1 = "$downloadPath"
    $fallbackArgList1 = $installerArgList

    $fallbackInstallerPath2 = ".\$((Get-ChildItem -Path . -Filter "*.$installerType")[0].Name)"
    $fallbackArgList2 = $installerArgList
}
else {
    $fallbackInstallerPath1 = "Msiexec"
    $fallbackArgList1 = "/I $downloadPath $installerArgList"

    $fallbackInstallerPath2 = "Msiexec"
    $fallbackArgList2 = "/I $((Get-ChildItem -Path . -Filter "*.$installerType")[0].Name) $installerArgList"
}

function Log {
    param (
        [string] $message,
        [string] $color
    )

    if (!$color) {
        $color = "White"
    }
    
    if ($logPath) {
        $message | Out-File -FilePath $logPath -Append
    }
    Write-Host $message -ForegroundColor $color
}

function Ensure-Path {
    param (
        [string] $dir
    )

    # Check if directory exists and if not create
    if (-not (Test-Path $dir)) {
        Log "$dir does not exist"
        Log "Creating..."
        New-Item -Path $dir -ItemType Directory -Force -ErrorAction SilentlyContinue
    }
}

function Is-Installed {

    if (($testExecutablePath) -or ($testRegistryItems -and $testRegistryItems.Length -gt 0)) {
        
        if ($testExecutablePath) {
            Log "Testing path $testExecutablePath ..."
            if (!(Test-Path $testExecutablePath)) {
                Log "Not detected" Red
                return $false
            }
        }
        if ($testRegistryItems -and $testRegistryItems.Length -gt 0) {
            foreach ($item in $testRegistryItems) {
                if (Test-Path $item.Path) {
                    foreach ($key in $item.Keys) {
                        Log "Testing path: $($item.Path), key: $($key.Name), value: $($key.Value)"
                        try {
                            $value = Get-ItemProperty -Path $item.Path -Name $key.Name -ErrorAction Stop
                            "Testing: $($value.$keyName) -ne $($key.Value))"
                            if ($value.$keyName -ne $key.Value) {
                                "Not equal"
                                return $false
                            }
                        } 
                        catch {
                            Log "Error: $_"
                            return $false
                        }
                    }
                }
                else {
                    return $false
                }
            }
        }
        return $true
    }
    else {
        $path32bit = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
        $path64bit = "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"

        $installedApps = Get-ItemProperty $path32bit, $path64bit

        foreach ($appRegistryEntry in $installedApps) {
            if ($appRegistryEntry.DisplayName -like "*$displayName*") {
                return $true
            }

        return $false
        }
    }
}

function Get-UninstallStrings {
    param (
        [array] $hives
    )

    $uninstallStrings = @() # Array to hold uninstall strings

    foreach ($hive in $hives) {
        $paths = @(
            "$hive\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "$hive\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
        )

        foreach ($path in $paths) {
            $installedApps = Get-ItemProperty $path -ErrorAction SilentlyContinue

            foreach ($appRegistryEntry in $installedApps) {
                if ($appRegistryEntry.DisplayName -like "*$displayName*") {
                    Log "FOUND REGISTRY ENTRY - Uninstall String = $($appRegistryEntry.UninstallString)"
                    $uninstallStrings += $appRegistryEntry.UninstallString
                }
            }
        }
    }
    return $uninstallStrings
}

function Process-UninstallString {
    param (
        [string] $uninstallString,
        [string] $argList
    )

    # Trim the string and replace multiple spaces with a single space
    $uninstallString = $uninstallString.Trim()
    $uninstallString = $uninstallString -replace "\s+", " "

    # Check if it's an msiexec uninstall string and modify if necessary
    if ($uninstallString -like 'msiexec.exe /I*') {
        $uninstallString = $uninstallString -replace '/I', '/X'
    }

    # Append additional arguments
    $uninstallString = "$uninstallString $argList"

    # Handle paths with spaces enclosed in quotes
    if ($uninstallString.StartsWith('"')) {
        $quoteIndex = $uninstallString.IndexOf('"', 1)
        $executable = $uninstallString.Substring(0, $quoteIndex + 1)
        $arguments = $uninstallString.Substring($quoteIndex + 2).Trim()
    } 
    else {
        $fragments = $uninstallString -split ' ', 2
        $executable = $fragments[0]
        $arguments = $fragments[1]
    }

    $executable = $executable -replace '"', ''

    Log "Executable: $executable"
    Log "Arguments: $arguments"
        
    return $executable, $arguments
}

function Download-File {
    param (
        [string] $fallbackDownloadURL,
        [string] $downloadPath
    )
    Log "Downloading from $fallbackDownloadURL to $downloadPath"
    for ($i = 0; $i -lt 2; $i++) {

        Log "Attempt $(($i+1))..."

        if ($i -lt 2) {
            $downloadCommand = "Start-BitsTransfer -Source '$fallbackDownloadURL' -Destination '$downloadPath'"
        }
        else {
            $downloadCommand = "Invoke-WebRequest -Uri '$fallbackDownloadURL' -OutFile '$downloadPath' -UseBasicParsing"
        }
        Log "Download command: $downloadCommand"

        try {
            Invoke-Expression $downloadCommand
        }
        catch {
            Log "Error: $_" Red
        }

        Start-Sleep -seconds 4
        
        if (Test-Path $downloadPath) {
            Log "Download successful" Green
            return
        }
        else {
            Log "Download not detected" Red
        }
    }
}

function Update-Registry ($installRegistryItems) {
    if (($installRegistryItems -and $installRegistryItems.Length -gt 0)) {

        foreach ($registryItem in $installRegistryItems) {

            if (-not (Test-Path $registryItem.Path)) {
                New-Item -Path $registryItem.Path -ItemType Directory
            }

            foreach ($key in $registryItem.Keys) {

                if (-not (Get-ItemProperty -Path $registryItem.Path -Name $key.Name -ErrorAction SilentlyContinue)) {
                    New-ItemProperty -Path $lockscreenKey -Name $key.Name -Value $key.Value -PropertyType $key.Type -Force
                } 
                else {
                    Set-ItemProperty -Path $lockscreenKey -Name $key.Name -Value $key.Value
                }
            }
        }
    }
}

function Install-App {
    param (
        [string] $installerPath,
        [string] $argList
    )
    Log "Installing $installerPath $argList"
    for ($i = 0; $i -lt 3; $i++) {
        Log "Attempt $(($i+1))..."
        try {
            Start-Process "$installerPath" -ArgumentList "$argList" -NoNewWindow -Wait
        }
        catch {
            Log "Error: $_" Red
        }
        Start-Sleep -seconds 7
        if (Is-Installed) {
            Log "Install successful" Green
            break
        }
        else {
            Log "Installation not detected. Retrying..."
        }
    }
}

function Uninstall-App {
    param (
        [string] $uninstallerPath,
        [string] $argList
    )
    Log "Uninstalling $uninstallerPath $argList"
    for ($i = 0; $i -lt 3; $i++) {
        Log "Attempt $(($i+1))..."
        try {
            Start-Process $uninstallerPath -ArgumentList $argList -NoNewWindow -Wait
        }
        catch {
            Log "Error: $_" Red
        }
        Start-Sleep -seconds 7
        if (!(Is-Installed)) {
            Log "Uninstall successful" Green
            break
        }
        else {
            Log "Installation detected. Retrying..."
        }
    }
}

function Remove-File {
    param (
        [string] $path 
    )
    Log "Removing file $path"
    for ($i = 0; $i -lt 3; $i++) {
        Log "Attempt $(($i+1))..."
        try {
            Remove-Item -Recurse -Force $path -ErrorAction SilentlyContinue
        }
        catch {
            Log "Error: $_" Red
        }
        Start-Sleep -seconds 4
        if (-not (Test-Path $path)) {
            Log "Removal successful" Green
            break
        }
    }
}

Ensure-Path $logDir
Ensure-Path $downloadDir

if (! ($mode)) {
    # The script is being run directly
    if (Is-Installed) {
        Write-Host "$displayName installation detected" -ForegroundColor Green
        Exit 0
    }
    else {
        Write-Host "$displayName installation NOT detected" -ForegroundColor Red
        Exit 1
    }
}
elseif ($mode -eq 'install') {

    $logPath = Join-Path -Path $logDir -ChildPath ($displayName + "Install.log")

    # Create a new, empty log file or clear the existing one
    "" | Out-File -FilePath $logPath
    Log "Log started at $(Get-Date)"

    Ensure-Path $downloadDir

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

        if (Is-Installed) {
            Update-Registry $installRegistryItems
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
} 
elseif (($mode -eq 'uninstall') -or ($mode -eq 'remove')) {

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
}
else {
    Write-Host 'Unsupported mode' -ForegroundColor Red
    Exit 1
}
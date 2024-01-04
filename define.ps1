##################################################################################################################################
##################################################################################################################################                                                                                                                       
#
# Intune Win32App Manager
# 2024 Simon Tucker
#                                                                                                                                
##################################################################################################################################
##################################################################################################################################

################################################
# NOTE: The following variables should changed #
################################################

$displayName = "Notepad++"
# Taken from the registry entry HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*
# this is used to find the app's uninstall string 

$wingetAppID = ""
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
# match the installer 

$testExecutablePath = ''
# Path to the executable for testing if app is installed.

$testRegistryPaths = @(
    @{
        Path = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\X64';
        Keys = @(
            @{ Key = 'Installed'; Value = 1 },
            @{ Key = 'Bld'; Value = 0x0000816a }
            # Add more key-value pairs as needed for X64
        )
    }
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

$preInstallRegistryHives = @("HKCU:")
$uninstallRegistryHives = @("HKLM:", "HKCU:")

#######################################################
# NOTE: The following variables should NOT be changed #
#######################################################

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

function Ensure-Directory {
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

    if (($testExecutablePath) -or ($testRegistryPaths -and $testRegistryPaths.Length -gt 0)) {
    
        $notDetected = 0
        
        if ($testExecutablePath) {
            Log "Testing path $testExecutablePath ..."
            if (Test-Path $testExecutablePath) {
                Log "Detected"
            } else {
                Log "Not detected"
                $notDetected += 1
            }
        }
        if ($testRegistryPaths -and $testRegistryPaths.Length -gt 0) {

            foreach ($registryPath in $testRegistryPaths) {
                $properties = $null
                try {
                    $properties = Get-ItemProperty -Path $registryPath.Path -ErrorAction Stop
                }
                catch {
                    Log "Error: Registry path $($registryPath.Path) does not exist."
                    $notDetected += 1
                }
                if ($properties) {
                    foreach ($key in $registryPath.Keys) {
                        try {
                            $actualValue = $properties.$($key.Key)
                            $expectedValue = $key.Value
                            
                            if ($actualValue -eq $expectedValue) {
                                Log "Path: $($registryPath.Path) - The $($key.Key) key matches the expected value of $expectedValue."
                            } else {
                                Log "Path: $($registryPath.Path) - The $($key.Key) key does not match the expected value. Expected: $expectedValue, but got: $actualValue"
                                $notDetected += 1
                            }
                        } catch {
                            Log "Error: Registry path key '$($key.Key)' does not exist."
                            $notDetected += 1
                        }
                    }
                }
            }
        } 

        return !($notDetected -gt 0)
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
    } else {
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

Ensure-Directory $logDir
Ensure-Directory $downloadDir
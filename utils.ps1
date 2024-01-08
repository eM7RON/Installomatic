. .\define.ps1

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

    if (($testExecutablePath) -or ($testRegistryItems -and $testRegistryItems.Length -gt 0)) {
    
        $notDetected = 0
        
        if ($testExecutablePath) {
            Log "Testing path $testExecutablePath ..."
            if (Test-Path $testExecutablePath) {
                Log "Detected"
            } 
            else {
                Log "Not detected"
                $notDetected += 1
            }
        }
        if ($testRegistryItems -and $testRegistryItems.Length -gt 0) {

            foreach ($registryItem in $testRegistryItems) {
                $properties = $null
                try {
                    $properties = Get-ItemProperty -Path $registryItem.Path -ErrorAction Stop
                }
                catch {
                    Log "Error: Registry path $($registryItem.Path) does not exist."
                    $notDetected += 1
                }
                if ($properties) {
                    foreach ($key in $registryItem.Keys) {
                        try {
                            $actualValue = $properties.$($key.Name)
                            $expectedValue = $key.Value
                            
                            if ($actualValue -eq $expectedValue) {
                                Log "Path: $($registryItem.Path) - The $($key.Name) key matches the expected value of $expectedValue."
                            } 
                            else {
                                Log "Path: $($registryItem.Path) - The $($key.Name) key does not match the expected value. Expected: $expectedValue, but got: $actualValue"
                                $notDetected += 1
                            }
                        } 
                        catch {
                            Log "Error: Registry path key '$($key.Name)' does not exist."
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

function update-Registry ($installRegistryItems) {
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

Ensure-Directory $logDir
Ensure-Directory $downloadDir
param (
    [string] $Script
)

. .\env

$latestReleaseURL = "https://europe-west2-saiit-operations.cloudfunctions.net/IntuneWin32AppManagement"
$zipFile = "IntuneWin32AppManager.zip"
$downloadDir = "C:\ProgramData\SAIIT\temp"

# Use the full URL with the parameter in Invoke-WebRequest
Invoke-WebRequest -Uri $latestReleaseURL -Body @{'token' = $TOKEN} -UseBasicParsing -OutFile ".\$zipFile"
# Assume the script is running in the temp directory
$zipFile = ".\IntuneWin32AppManager.zip"
$tempDir = New-Item -ItemType Directory -Path ".\temp_extract" -Force

# Expand the ZIP file to the temporary directory
Expand-Archive -Path $zipFile -DestinationPath $tempDir.FullName -Force

# Get the list of items in the extracted folder (should be only one folder)
$extractedFolderItems = Get-ChildItem -Path $tempDir.FullName

# Assuming there's only one folder and it's not known, we just take the first item
$extractedFolder = $extractedFolderItems | Where-Object { $_.PSIsContainer } | Select-Object -First 1

# Define the list of required files
$requiredFiles = @("install.ps1", "uninstall.ps1", "detect.ps1", "utils.ps1")

# Move the specified files from the extracted folder to the current directory
$requiredFiles | ForEach-Object {
    $filePath = Join-Path -Path $extractedFolder.FullName -ChildPath $_
    if (Test-Path $filePath) {
        Move-Item -Path $filePath -Destination $PWD
    } else {
        Write-Host "File not found: $_"
    }
}

# Clean up: Remove the temporary extracted folder and the ZIP file if no longer needed
Remove-Item -Path $tempDir.FullName -Recurse -Force
# Optional: Remove the ZIP file if it's no longer needed
# Remove-Item -Path $zipFile -Force

# Start-Process command as in your original script (assuming $Script variable is defined elsewhere)
Start-Process -FilePath "powershell" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$($Script)`"" -Wait

param (
    [string] $Script
)

. .\.env

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

# Move the contents of the extracted folder to the current directory
Get-ChildItem -Path $extractedFolder.FullName -Recurse | Move-Item -Destination $PWD

# Clean up: Remove the temporary extracted folder and the ZIP file if no longer needed
Remove-Item -Path $tempDir.FullName -Recurse -Force
# Optional: Remove the ZIP file if it's no longer needed
# Remove-Item -Path $zipFile -Force
Start-Process -FilePath "powershell" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$($Script)`"" -Wait
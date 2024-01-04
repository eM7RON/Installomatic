. .\define.ps1

if (Is-Installed) {
    Write-Host "$displayName installation detected" -ForegroundColor Green
    Exit 0
}
else {
    Write-Host "$displayName installation NOT detected" -ForegroundColor Red
    Exit 1
}
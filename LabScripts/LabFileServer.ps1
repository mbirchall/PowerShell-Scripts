<#
Author:    Mark Birchall
Prereq:    To be used on a server with an uninitialised data disk  
           A security group called $SiteID-GG-AllStaff
           Change variables as required
Usage:     Run in an elevated shell (Administrator)

Version:   1.0 Base Version
#>

# Initialise Data Disk
Get-Disk | Where PartitionStyle -EQ 'raw' | Initialize-Disk -PartitionStyle GPT -PassThru | New-Partition -AssignDriveLetter -UseMaximumSize | Format-Volume -FileSystem NTFS -NewFileSystemLabel "Data" -Confirm:$false

# Install File Server Roles
Install-WindowsFeature FS-FileServer, FS-Data-Deduplication, FS-Resource-Manager -IncludeManagementTools

# Create Home Folders
$SiteID = "MB"
$HomeFolder = "D:\HomeFolders"
$StaffHome = ($HomeFolder + "\Staff")

New-Item -ItemType Directory -Path $HomeFolder -Force | Out-Null
Icacls $HomeFolder /inheritance:d
Icacls $HomeFolder /remove BUILTIN\Users
New-Item -ItemType Directory -Path $StaffHome -Force | Out-Null
New-SmbShare -Name "StaffHome$" -Path $StaffHome -FullAccess Administrators -ChangeAccess ($SiteID + "-GG-AllStaff") -CachingMode Manual
Icacls $StaffHome /grant ($SiteID + "-GG-AllStaff" + ":(M)")

# Create Shared Folders
$SharedFolder = "D:\Shared"
$Public = ($SharedFolder + "\Public")
$Misc = ($SharedFolder + "\Misc")

New-Item -ItemType Directory -Path $SharedFolder -Force | Out-Null
Icacls $SharedFolder /inheritance:d
Icacls $SharedFolder /remove BUILTIN\Users
New-Item -ItemType Directory -Path $Public -Force | Out-Null
New-Item -ItemType Directory -Path $Misc -Force | Out-Null
New-SmbShare -Name "Public$" -Path $Public -FullAccess Administrators -ChangeAccess ($SiteID + "-GG-AllStaff") -CachingMode None
Icacls $Public /grant ($SiteID + "-GG-AllStaff" + ":(OI)(CI)M")
New-SmbShare -Name "Misc$" -Path $Misc -FullAccess Administrators -ReadAccess Everyone -CachingMode None
Icacls $Misc /grant ("Everyone" + ":(OI)(CI)RX")

# Configure File Screen Policies
New-FsrmFileGroup -Name "Malware Files" –IncludePattern @("*.FUN","*.KKK","*.GWS","*.BTC","_DECRYPT_INFO_*","_Locky_recover_instructions.txt","DECRYPT_INSTRUCTIONS.TXT", "DECRYPT_INSTRUCTIONS.HTML", "DECRYPT_INSTRUCTION.TXT", "DECRYPT_INSTRUCTION.HTML", "HELP_DECRYPT.TXT", "HELP_DECRYPT.HTML", "DecryptAllFiles.txt", "enc_files.txt", "HowDecrypt.txt", "How_Decrypt.txt", "How_Decrypt.html", "HELP_TO_DECRYPT_YOUR_FILES.txt", "HELP_RESTORE_FILES.txt", "HELP_TO_SAVE_FILES.txt", "restore_files*.txt", "restore_files.txt", "RECOVERY_KEY.TXT", "how to decrypt aes files.lnk", "HELP_DECRYPT.PNG", "HELP_DECRYPT.lnk", "DecryptAllFiles*.txt", "Decrypt.exe", "ATTENTION!!!.txt", "AllFilesAreLocked*.bmp", "MESSAGE.txt","*.locky","*.ezz", "*.ecc", "*.exx", "*.7z.encrypted", "*.ctbl", "*.encrypted", "*.aaa", "*.xtbl", "*.abc", "*.JUST", "*.EnCiPhErEd", "*.cryptolocker","*.micro")
New-FsrmFileScreenTemplate "Block Malware Files" -IncludeGroup "Malware Files"
New-FsrmFileScreen -Path "D:\HomeFolders\Staff" -Template "Block Executable Files" -IncludeGroup @("Executable Files", "Malware Files")
New-FsrmFileScreen -Path "D:\Shared\Public" -Template "Block Executable Files" -IncludeGroup @("Executable Files", "Malware Files")




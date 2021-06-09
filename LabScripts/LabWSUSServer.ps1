<#
Author:    Mark Birchall
Prereq:    Mount Server Media - Needed for DotNet 3.5
           Change variables as required
           All files are present in the Setup folder
Usage:     Run in an elevated shell (Administrator)
           Run in section individually due to reboots
           Requires Internet Connection Available without Proxy
Version:   1.0 Base Version
#>

# Variables
$Computer = Get-Content env:computername
$DVDPath = "Z:\Sources\SxS"
$SourcePath = "D:\Setup"
$WSUSPath = "D:\WSUS"
$ServerName = 'localhost'
$Port = '8530'
$WSUSSrv = Get-WSUSServer -Name $ServerName -Port $Port
$WSUSSrvCFG = $WSUSSrv.GetConfiguration()
$WSUSSrvSubScrip = $WSUSSrv.GetSubscription()

# Check for Elevation
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
    [Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    Write-Warning "You need to run this script from an elevated PowerShell prompt"
	Write-Warning "Exit script"
    Break
}

# Enable DotNet 3.5 Feature
Write-Host "Enable DotNet 3.5 Feature" -ForegroundColor Magenta
Install-WindowsFeature -Name NET-Framework-Core -Source $DVDPath

# ConfigurationFile.ini Contents
$SQLConf = @"
[OPTIONS]
ACTION="Install"
ROLE="AllFeatures_WithDefaults"
ENU="True"
QUIET="True"
QUIETSIMPLE="False"
UpdateEnabled="False"
ERRORREPORTING="False"
USEMICROSOFTUPDATE="False"
FEATURES=SQLENGINE,REPLICATION,CONN,BC,SDK,SSMS,ADV_SSMS,SNAC_SDK
UpdateSource="MU"
HELP="False"
INDICATEPROGRESS="False"
X86="False"
INSTALLSHAREDDIR="C:\Program Files\Microsoft SQL Server"
INSTALLSHAREDWOWDIR="C:\Program Files (x86)\Microsoft SQL Server"
INSTANCENAME="SQLEXPRESS"
SQMREPORTING="False"
INSTANCEID="SQLEXPRESS"
INSTANCEDIR="C:\Program Files\Microsoft SQL Server"
AGTSVCACCOUNT="NT AUTHORITY\NETWORK SERVICE"
AGTSVCSTARTUPTYPE="Disabled"
COMMFABRICPORT="0"
COMMFABRICNETWORKLEVEL="0"
COMMFABRICENCRYPTION="0"
MATRIXCMBRICKCOMMPORT="0"
SQLSVCSTARTUPTYPE="Automatic"
FILESTREAMLEVEL="0"
ENABLERANU="True"
SQLCOLLATION="Latin1_General_CI_AS"
SQLSVCACCOUNT="NT Service\MSSQL$SQLEXPRESS"
SQLSYSADMINACCOUNTS="DEPLOYLAB\administrator" "DEPLOYLAB\Domain Admins"
INSTALLSQLDATADIR="D:\SQLData"
ADDCURRENTUSERASSQLADMIN="True"
TCPENABLED="0"
NPENABLED="0"
BROWSERSVCSTARTUPTYPE="Disabled"
"@

If (Test-Path "$SourcePath\Scripts\ConfigurationFile.ini") {
    Remove-Item -Path "$SourcePath\Scripts\ConfigurationFile.ini" -Force
}    
Set-Content -Path "$SourcePath\Scripts\ConfigurationFile.ini" -Value $SQLConf

# Install SQL 2014 Express with Tools
Write-Host "Install SQL 2014 Express with Tools" -ForegroundColor Magenta
Start-Process -FilePath "$SourcePath\SQLExpress2014\SETUP.exe" -Wait -ArgumentList "/IAcceptSQLServerLicenseTerms /Configurationfile=$SourcePath\Scripts\ConfigurationFile.ini" | Out-Null

# Install Microsoft Report Viewer 2008 SP1
Write-Host "Install Microsoft Report Viewer 2008 SP1" -ForegroundColor Magenta
Start-Process -FilePath "$SourcePath\ReportViewer\ReportViewer.exe" -Wait -ArgumentList "/q" | Out-Null

# Enable WSUS Feature
Write-Host "Enable WSUS Feature" -ForegroundColor Magenta
Install-WindowsFeature -Name UpdateServices-Services,UpdateServices-DB -IncludeManagementTools

# Create WSUS Folder
Write-Host "Create WSUS Folder" -ForegroundColor Magenta
New-Item -Path "$WSUSPath" -ItemType Directory

# Set WSUS SQL Server
Write-Host "Set WSUS SQL Server" -ForegroundColor Magenta
Start-Process -FilePath "C:\Program Files\Update Services\Tools\WsusUtil.exe" -Wait -ArgumentList "postinstall SQL_INSTANCE_NAME=$Computer\SQLExpress CONTENT_DIR=$WSUSPath" | Out-Null

# Install Hotfix https://support.microsoft.com/en-gb/kb/2938066
Write-Host "Install KB2938066" -ForegroundColor Magenta
Start-Process -FilePath wusa.exe -Wait -ArgumentList "$SourcePath\WSUSHotfixes\Windows8.1-KB2938066-x64.msu /quiet /norestart" | Out-Null

# Install Hotfix https://support.microsoft.com/en-gb/kb/3095113
Write-Host "Install KB3095113" -ForegroundColor Magenta
Start-Process -FilePath wusa.exe -Wait -ArgumentList "$SourcePath\WSUSHotfixes\Windows8.1-KB3095113-x64.msu /quiet /norestart" | Out-Null

# Restart Host
Write-Host "Restart Host to complete installation" -ForegroundColor Magenta

# Set WSUS to download from Microsoft Update
Write-Host "Set WSUS to download from Microsoft Update" -ForegroundColor Magenta
Set-WsusServerSynchronization -SyncFromMU

# Set WSUS Update Languages
Write-Host "Set WSUS Update Language to EN" -ForegroundColor Magenta
$WSUSSrvCFG = $WSUSSrv.GetConfiguration()
$WSUSSrvCFG.AllUpdateLanguagesEnabled = $false
$WSUSSrvCFG.AllUpdateLanguagesDssEnabled = $false
$WSUSSrvCFG.SetEnabledUpdateLanguages('en')
$WSUSSrvCFG.Save()

# Disable All Products and Classifications
Write-Host "Disable all Classifications and all Products" -ForegroundColor Magenta
Get-WsusClassification | Set-WsusClassification -Disable
Get-WsusProduct | Set-WsusProduct -Disable

# Run the initial Configuration - NO DOWNLOAD
Write-Host "Start Synchronization for Category only - Will take awhile" -ForegroundColor Magenta
$WSUSSrvSubScrip = $WSUSSrv.GetSubscription()
$WSUSSrvSubScrip.StartSynchronizationForCategoryOnly()            
While($WSUSSrvSubScrip.GetSynchronizationStatus() -ne 'NotProcessing') 
{   
    $TotalItems = $($WSUSSrvSubScrip.GetSynchronizationProgress().TotalItems)
    $ProcessedItems = $($WSUSSrvSubScrip.GetSynchronizationProgress().ProcessedItems)
    if($ProcessedItems -eq 0){
    Write-Progress -id 1 -Activity "$($WSUSSrvSubScrip.GetSynchronizationProgress().Phase)" -PercentComplete 0
    }
    else
    {
    $PercentComplete = $ProcessedItems/$TotalItems*100
    Write-Progress -id 1 -Activity "$($WSUSSrvSubScrip.GetSynchronizationProgress().Phase)" -PercentComplete $PercentComplete
    }
} 

# Set Synchronization to Automatic
Write-Host "Set Synchronization to Automatic" -ForegroundColor Magenta
$WSUSSrvSubScrip = $WSUSSrv.GetSubscription()
$WSUSSrvSubScrip.SynchronizeAutomatically=$True

# Set Sync at 11PM and 1 times per day
Write-Host "Set Sync at 11PM and 1 times per day" -ForegroundColor Magenta
$WSUSSrvSubScrip.SynchronizeAutomaticallyTimeOfDay='22:00:00'
$WSUSSrvSubScrip.NumberOfSynchronizationsPerDay='1'
$WSUSSrvSubScrip.Save()

# Set WSUS Classifications
Write-Host "Set WSUS Classifications" -ForegroundColor Magenta
Get-WsusClassification | Where-Object –FilterScript {$_.Classification.Id -Eq "e6cf1350-c01b-414d-a61f-263d14d133b4"} | Set-WsusClassification #Critical Updates
Get-WsusClassification | Where-Object –FilterScript {$_.Classification.Id -Eq "e0789628-ce08-4437-be74-2495b842f43b"} | Set-WsusClassification #Definition Updates
Get-WsusClassification | Where-Object –FilterScript {$_.Classification.Id -Eq "b54e7d24-7add-428f-8b75-90a396fa584f"} | Set-WsusClassification #Feature Packs
Get-WsusClassification | Where-Object –FilterScript {$_.Classification.Id -Eq "0fa1201d-4330-4fa8-8ae9-b877473b6441"} | Set-WsusClassification #Security Updates
Get-WsusClassification | Where-Object –FilterScript {$_.Classification.Id -Eq "68c5b0a3-d1a6-4553-ae49-01d3a7827828"} | Set-WsusClassification #Service Packs
Get-WsusClassification | Where-Object –FilterScript {$_.Classification.Id -Eq "28bc880e-0592-4cbf-8f95-c79b17911d5f"} | Set-WsusClassification #Update Rollups
Get-WsusClassification | Where-Object –FilterScript {$_.Classification.Id -Eq "cd5ffd1e-e932-4e3a-bf74-18bf0b1bbd83"} | Set-WsusClassification #Updates

# Set WSUS Products
Write-Host "Set WSUS Products" -ForegroundColor Magenta
Get-WsusProduct | Where-Object –FilterScript {$_.Product.ID -Eq "48ce8c86-6850-4f68-8e9d-7dc8535ced60"} | Set-WsusProduct #Developer Tools, Runtimes, and Redistributables
Get-WsusProduct | Where-Object –FilterScript {$_.Product.ID -Eq "704a0a4a-518f-4d69-9e03-10ba44198bd5"} | Set-WsusProduct #Office 2013
Get-WsusProduct | Where-Object –FilterScript {$_.Product.ID -Eq "25aed893-7c2d-4a31-ae22-28ff8ac150ed"} | Set-WsusProduct #Office 2016
Get-WsusProduct | Where-Object –FilterScript {$_.Product.ID -Eq "30eb551c-6288-4716-9a78-f300ec36d72b"} | Set-WsusProduct #Office 365 Client                                             
Get-WsusProduct | Where-Object –FilterScript {$_.Product.ID -Eq "8c3fcc84-7410-4a95-8b89-a166a0190486"} | Set-WsusProduct #Windows Defender
Get-WsusProduct | Where-Object –FilterScript {$_.Product.ID -Eq "bfe5b177-a086-47a0-b102-097e4fa1f807"} | Set-WsusProduct #Windows 7
Get-WsusProduct | Where-Object –FilterScript {$_.Product.ID -Eq "a3c2375d-0c8a-42f9-bce0-28333e198407"} | Set-WsusProduct #Windows 10

# Run the initial Configuration - NO DOWNLOAD
Write-Host "Run the initial Configuration - NO DOWNLOAD" -ForegroundColor Magenta
$WSUSSrvSubScrip = $WSUSSrv.GetSubscription()
$WSUSSrvSubScrip.StartSynchronization()
While($WSUSSrvSubScrip.GetSynchronizationStatus() -ne 'NotProcessing') 
{   
    $TotalItems = $($WSUSSrvSubScrip.GetSynchronizationProgress().TotalItems)
    $ProcessedItems = $($WSUSSrvSubScrip.GetSynchronizationProgress().ProcessedItems)
    if($ProcessedItems -eq 0){
    Write-Progress -id 1 -Activity "$($WSUSSrvSubScrip.GetSynchronizationProgress().Phase)" -PercentComplete 0
    }
    else
    {
    $PercentComplete = $ProcessedItems/$TotalItems*100
    Write-Progress -id 1 -Activity "$($WSUSSrvSubScrip.GetSynchronizationProgress().Phase)" -PercentComplete $PercentComplete
    }
} 

# Decline Superseeded Updates
Write-Host "Decline Superseeded Updates" -ForegroundColor Magenta
$SuperSeededUpdates = Get-WsusUpdate -Approval AnyExceptDeclined -Classification All -Status Any | Where-Object -Property UpdatesSupersedingThisUpdate -NE -Value 'None'
$SuperSeededUpdates | Deny-WsusUpdate

# Create the Default Approvel Rule
Write-Host "Create the Default Approvel Rule" -ForegroundColor Magenta
$CategoryCollection = New-Object Microsoft.UpdateServices.Administration.UpdateCategoryCollection
$ClassificationCollection = New-Object Microsoft.UpdateServices.Administration.UpdateClassificationCollection
$TargetgroupCollection = New-Object Microsoft.UpdateServices.Administration.ComputerTargetGroupCollection

# Define Workstation Default Rule
Write-Host "Define Workstation Default Rule" -ForegroundColor Magenta
$ApprovalRule = "Workstation Default Rule"

# Define Categories
Write-Host "Define Categories" -ForegroundColor Magenta
$UpdateCategories = "48ce8c86-6850-4f68-8e9d-7dc8535ced60|704a0a4a-518f-4d69-9e03-10ba44198bd5|25aed893-7c2d-4a31-ae22-28ff8ac150ed|30eb551c-6288-4716-9a78-f300ec36d72b|8c3fcc84-7410-4a95-8b89-a166a0190486|bfe5b177-a086-47a0-b102-097e4fa1f807|a3c2375d-0c8a-42f9-bce0-28333e198407"

# Define Classifications
Write-Host "Define Classifications" -ForegroundColor Magenta
$UpdateClassifications = "Critical Updates|Security Updates|Definition Updates"

# Define Computer Target Groups
Write-Host "Define Computer Target Groups" -ForegroundColor Magenta
$ComputerTargetGroup = "All Computers"

# Create Workstation Default Rule
Write-Host "Create Workstation Default Rule" -ForegroundColor Magenta
$NewRule = $WSUSSrv.CreateInstallApprovalRule($ApprovalRule)

# Add Categories
Write-Host "Add Categories" -ForegroundColor Magenta
$UpdateCategories = $WSUSSrv.GetUpdateCategories() | Where {  $_.Id -match $UpdateCategories}
$CategoryCollection.AddRange($updateCategories)
$NewRule.SetCategories($categoryCollection)

# Add Classifications
Write-Host "Add Classifications" -ForegroundColor Magenta
$UpdateClassifications = $WSUSSrv.GetUpdateClassifications() | Where { $_.Title -match $UpdateClassifications}
$ClassificationCollection.AddRange($updateClassifications )
$NewRule.SetUpdateClassifications($classificationCollection)

# Add Target Group
Write-Host "Add Target Group" -ForegroundColor Magenta
$TargetGroups = $WSUSSrv.GetComputerTargetGroups() | Where {$_.Name -Match $ComputerTargetGroup}
$TargetgroupCollection.AddRange($targetGroups)

# Save and Enable
Write-Host "Save and Enable" -ForegroundColor Magenta
$NewRule.SetComputerTargetGroups($targetgroupCollection)
$NewRule.Enabled = $True
$NewRule.Save()

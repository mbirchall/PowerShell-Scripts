<#
Author:    Mark Birchall
Prereq:    Global Admin credentials to the O365 Tenant   
           
Usage:     Run in an elevated shell (Administrator)
           
Version:   1.0 Base Version
#>

# Install Prereqs
Get-Module -Name Microsoft.Online.SharePoint.PowerShell -ListAvailable | Select Name,Version
Install-Module -Name Microsoft.Online.SharePoint.PowerShell

# Connect to Tenant
Connect-SPOService -Url https://tshs-admin.sharepoint.com

# Apply Blocking specfic file types from syncing
Set-SPOTenantSyncClientRestriction  -ExcludedFileExtensions "bat;cmd;com;cpl;exe;inf;js;jse;msh;msi;msp;ocx;pif;pl;ps1;scr;vb;vbs;wsf;wsh;fun;kkk;gws;btc;locky;ezz;ecc;exx;ctbl;encrypted;aaa;xtbl;abc;just;EnCiPhErEd;cryptolocker;micro"

# Disconnect
Get-PSSession | Remove-PSSession

<#
Author:    Mark Birchall
Prereq:    Global Admin credentials to the O365 Tenant   
           
Usage:     Run in an elevated shell (Administrator)
           
Version:   1.0 Base Version
#>

### Prereqs ###
# Install Skype for Business Online Module https://www.microsoft.com/en-us/download/details.aspx?id=39366

# Install Azure AD Preview Module
Uninstall-Module -Name AzureAD
Install-Module -Name AzureADPreview -Force

# Connect to Tenant via AzureAD & SkypeOnline
Connect-AzureAD
$sfbSession = New-CsOnlineSession
Import-PSSession $sfbSession

# Enabling Meeting Attendance Report
Set-CsTeamsMeetingPolicy -Identity Global -AllowEngagementReport "Enabled"

# Disconnect 
Disconnect-AzureAD
Get-PSSession | Remove-PSSession

<#
Author:    Mark Birchall
Prereq:    To be used on a clean virtual machine in a Lab environment    
           Change variables as required

Usage:     Run in an elevated shell (Administrator)
           Run in section individually due to reboots

Version:   1.0 Base Version
#>

# Basic Settings
Rename-Computer -NewName DC01
$IPAddress = "192.168.80.10"
$DNSAddress = "127.0.0.1"
New-NetIPAddress -InterfaceAlias Ethernet -IPAddress $IPAddress -AddressFamily IPv4 -PrefixLength 24
Set-DnsClientServerAddress -InterfaceAlias Ethernet -ServerAddresses $DNSAddress
Restart-Computer

# Install ADDS Role
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools

# Perform Prereq Check
Test-ADDSForestInstallation -DomainName "mbirchall.com"
Test-ADDSDomainInstallation -NewDomainName "mbirchall.com" -ParentDomainName "mbirchall.com"
Test-ADDSDomainControllerInstallation -DomainName "mbirchall.com"

# Validate DC after reboot
Get-Service ADWS,KDC,NETLOGON,DNS

# Raise Forest and Domain to 2016
$ADDomain = "mbirchall.com"
$ADForest = Get-ADForest
Set-ADDomainMode -Identity $ADDomain -DomainMode Windows2016Domain
Set-ADForestMode -Identity $ADForest -Server $ADForest.SchemaMaster -ForestMode Windows2016Forest

# Configure Sites
$SiteName = "MBirchall-HQ"
$Subnet = "192.168.80.0/24"
$SubnetDesc = "192.168.80.0/255.255.255.0"
$ConfigNCDN = (Get-ADRootDSE).ConfigurationNamingContext
$SiteContainerDN = ("CN=Sites," + $ConfigNCDN)
$SiteDN = "CN=Default-First-Site-Name," + $SiteContainerDN
$SiteObject = ("CN=" + $SiteName + "," + $SiteContainerDN)
Get-ADObject -Identity $SiteDN | Rename-ADObject -NewName:$SiteName
New-ADObject -Name:$Subnet -Type Subnet -Description:$SubnetDesc -OtherAttributes @{location=$SiteName;siteObject=$SiteObject} -Path ("CN=Subnets," + $SiteContainerDN)

# Determine DNS Forwarders
Get-DnsServerForwarder

# Configure DNS
$DNSZone = "192.168.80.0/24"
Add-DnsServerPrimaryZone -NetworkID:$DNSZone -ReplicationScope Forest
Set-DnsServerForwarder -IPAddress 8.8.8.8,8.8.4.4
Set-DnsServerScavenging -RefreshInterval 3.00:00:00 -Verbose -PassThru -ApplyOnAllZones -ScavengingState $True

# Configure AD
$OURootName = "MBirchall"
$SiteID = "MB"
$UPN = "mbirchall.com"
$SrvPasswd = ConvertTo-SecureString -String "5rvPassw0rd" -AsPlainText -Force
$CurrentDomain = Get-ADDomain

$DomainRoot=(Get-ADDomain).distinguishedName
New-ADOrganizationalUnit -Name $OURootName -Path $DomainRoot -ProtectedFromAccidentalDeletion:$True
$OURootPath=(Get-ADOrganizationalUnit -SearchBase $DomainRoot -Filter 'name -eq $OURootName').distinguishedName
New-ADOrganizationalUnit -Name "Computers" -Path $OURootPath -ProtectedFromAccidentalDeletion:$True
New-ADOrganizationalUnit -Name "Security Groups" -Path $OURootPath -ProtectedFromAccidentalDeletion:$True
New-ADOrganizationalUnit -Name "Servers" -Path $OURootPath -ProtectedFromAccidentalDeletion:$True
New-ADOrganizationalUnit -Name "Service Accounts" -Path $OURootPath -ProtectedFromAccidentalDeletion:$True
New-ADOrganizationalUnit -Name "Users" -Path $OURootPath -ProtectedFromAccidentalDeletion:$True
$OUComputerPath=(Get-ADOrganizationalUnit -SearchBase $OURootPath -Filter 'name -eq "Computers"').distinguishedName
New-ADOrganizationalUnit -Name "_Build" -Path $OUComputerPath -ProtectedFromAccidentalDeletion:$True
New-ADOrganizationalUnit -Name "Desktops" -Path $OUComputerPath -ProtectedFromAccidentalDeletion:$True
New-ADOrganizationalUnit -Name "Laptops" -Path $OUComputerPath -ProtectedFromAccidentalDeletion:$True
$OUServicePath=(Get-ADOrganizationalUnit -SearchBase $OURootPath -Filter 'name -eq "Service Accounts"').distinguishedName
New-ADUser -Name "SvcDHCPUpdate" -AccountPassword $SrvPasswd -DisplayName "SvcDHCPUpdate" -Enabled $true -GivenName SvcDHCPUpdate -SamAccountName SvcDHCPUpdate -UserPrincipalName ("SvcDHCPUpdate"+"@"+$UPN) -Path $OUServicePath -Description "DHCP Update Account" -CannotChangePassword $True -PasswordNeverExpires $True

# Configure DHCP
$DNSDomain = "mbirchall.com"
$DNSServerIP = "192.168.80.10"
$DHCPServerIP = "192.168.80.10"
$DHCPStartRange = "192.168.80.100"
$DHCPEndRange = "192.168.80.200"
$DHCPSubnet = "255.255.255.0"
$Router = "192.168.80.1"
$DNSUser = "MBIRCHALL\SvcDHCPUpdate"
$DNSPassword = ConvertTo-SecureString -String "5rvPassw0rd" -AsPlainText -Force
$DNSCred = New-Object System.Management.Automation.PSCredential -ArgumentList $DNSUser, $DNSPassword

Install-WindowsFeature DHCP -IncludeManagementTools
CMD /C "NETSH DHCP ADD Securitygroups"
Restart-Service DHCPServer
Add-DhcpServerInDC -DnsName $env:COMPUTERNAME
Set-ItemProperty –Path registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\ServerManager\Roles\12 –Name ConfigurationState –Value 2
Add-DhcpServerV4Scope -Name "Internal" -StartRange $DHCPStartRange -EndRange $DHCPEndRange -SubnetMask $DHCPSubnet
Set-DhcpServerV4OptionValue -DnsDomain $DNSDomain -DnsServer $DNSServerIP -Router $Router
Set-DhcpServerv4Scope -ScopeId $DHCPServerIP -LeaseDuration 1.00:00:00
Get-DhcpServerInDC | % {Set-DhcpServerSetting -ComputerName $_.dnsname -ConflictDetectionAttempts 2}
Set-DhcpServerDnsCredential -ComputerName Localhost -Credential $DNSCred


<#
Author:    Mark Birchall
Prereq:    Global Admin credentials to the O365 Tenant   
           
Usage:     Run in an elevated shell (Administrator)
           
Version:   1.0 Base Version
#>

### Prereqs ###
# Install Skype for Business Online Module https://www.microsoft.com/en-us/download/details.aspx?id=39366
# Install Azure AD PowerShell for Graph Module https://docs.microsoft.com/powershell/azure/active-directory/install-adv2
# Install Azure AD Preview Module
Uninstall-Module -Name AzureAD
Install-Module -Name AzureADPreview -Force
# Install Latest Microsoft Teams Module
Install-Module -Name MicrosoftTeams -Force

# Import Modules
Import-Module SkypeOnlineConnector

### Configure Teams Policies ###
# Connect to Tenant via AzureAD & SkypeOnline
Connect-AzureAD
$sfbSession = New-CsOnlineSession
Import-PSSession $sfbSession

# Create Staff Team Policies
New-CsTeamsMessagingPolicy -Identity StaffMessagingPolicy -AllowOwnerDeleteMessage $True -AllowUserDeleteMessage $True -AllowUserEditMessage $True -AllowUserChat $True -AllowGiphy $True -GiphyRatingType "Strict" -AllowMemes $True -AllowStickers $True -AllowUrlPreviews $True -AllowUserTranslation $True -AllowImmersiveReader $True -AllowPriorityMessages $True -AudioMessageEnabledType ChatsAndChannels -ChannelsInChatListEnabledType DisabledUserOverride -AllowRemoveUser $True
New-CsTeamsMeetingPolicy -Identity StaffMeetingPolicy -AllowMeetNow $True -AllowOutlookAddIn $True -AllowChannelMeetingScheduling $True -AllowPrivateMeetingScheduling $True -AllowTranscription $True -AllowCloudRecording $True -AllowIPAudio $True -AllowIPVideo $True -ScreenSharingMode EntireScreen -AllowParticipantGiveRequestControl $True -AllowExternalParticipantGiveRequestControl $True -AllowPowerPointSharing $True -AllowWhiteboard $True -AllowSharedNotes $True -AllowAnonymousUsersToStartMeeting $False -AutoAdmittedUsers EveryoneInCompany -AllowPrivateMeetNow $False -MeetingChatEnabledType Enabled
New-CsTeamsAppSetupPolicy -Identity StaffAppSetupPolicy -AllowSideLoading $False -AllowUserPinning $True
New-CsTeamsCallingPolicy -Identity StaffCallingPolicy -AllowPrivateCalling $True -AllowCallForwardingToUser $False -AllowCallForwardingToPhone $False -AllowVoicemail AlwaysDisabled -AllowCallGroups $False -AllowDelegation $False -PreventTollBypass $False -BusyOnBusyEnabledType Disabled -AllowWebPSTNCalling $True
New-CsTeamsMeetingBroadcastPolicy -Identity StaffLiveEventPolicy -AllowBroadcastScheduling $True -AllowBroadcastTranscription $True -BroadcastAttendeeVisibilityMode EveryoneInCompany -BroadcastRecordingMode AlwaysEnabled
New-CsTeamsChannelsPolicy -Identity StaffTeamsPolicy -AllowPrivateTeamDiscovery $False -AllowPrivateChannelCreation $True

# Manually Modify Teams App Setup Policies to restrict what Pinned Apps are available
# Manually Modify Teams App Permission globally policy to restrict what apps can be used

# Modify Global Team Policies - Student Lockdown
Set-CsTeamsMessagingPolicy -Identity Global -AllowOwnerDeleteMessage $True -AllowUserDeleteMessage $False -AllowUserEditMessage $True -AllowUserChat $False -AllowGiphy $False -GiphyRatingType "Strict" -AllowMemes $False -AllowStickers $False -AllowUrlPreviews $True -AllowUserTranslation $True -AllowImmersiveReader $True -AllowPriorityMessages $False -AudioMessageEnabledType Disabled -ChannelsInChatListEnabledType DisabledUserOverride -AllowRemoveUser $False
Set-CsTeamsMeetingPolicy -Identity Global -AllowMeetNow $False -AllowOutlookAddIn $False -AllowChannelMeetingScheduling $False -AllowPrivateMeetingScheduling $False -AllowTranscription $True -AllowCloudRecording $False -AllowIPAudio $True -AllowIPVideo $False -ScreenSharingMode SingleApplication -AllowParticipantGiveRequestControl $False -AllowExternalParticipantGiveRequestControl $False -AllowPowerPointSharing $True -AllowWhiteboard $True -AllowSharedNotes $False -AllowAnonymousUsersToStartMeeting $False -AutoAdmittedUsers EveryoneInCompany -AllowPrivateMeetNow $False -MeetingChatEnabledType Enabled
Set-CsTeamsAppSetupPolicy -Identity Global -AllowSideLoading $False -AllowUserPinning $False
Set-CsTeamsCallingPolicy -Identity Global -AllowPrivateCalling $False -AllowCallForwardingToUser $False -AllowCallForwardingToPhone $False -AllowVoicemail AlwaysDisabled -AllowCallGroups $False -AllowDelegation $False -PreventTollBypass $False -BusyOnBusyEnabledType Disabled -AllowWebPSTNCalling $False
Set-CsTeamsMeetingBroadcastPolicy -Identity Global -AllowBroadcastScheduling $False -AllowBroadcastTranscription $True -BroadcastAttendeeVisibilityMode EveryoneInCompany -BroadcastRecordingMode UserOverride
Set-CsTeamsChannelsPolicy -Identity Global -AllowPrivateTeamDiscovery $False -AllowPrivateChannelCreation $False
Set-CsTeamsClientConfiguration -Identity Global -AllowDropbox $False -AllowBox $False -AllowGoogleDrive $False -AllowShareFile $False -AllowGuestUser $False -AllowOrganizationTab $False -AllowScopedPeopleSearchandAccess $False

# Assign Staff policies using Portal

# Disconnect 
Disconnect-AzureAD
Disconnect-MicrosoftTeams
Get-PSSession | Remove-PSSession

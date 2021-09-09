##############  DEFINE VARIABLE/PARAMETER  ##############
<#

.DESCRIPTION
  This script performs the following actions for users leaving from your company
    Removes the user's O365 license
    Removes user from Azure groups
    Removes user from Local AD groups
    Disables the user's AD account
    
#>

param
(
    # User info
    [string]$PrincipalName = 'user@test.local',      # User O365 account
    [string]$DisabledUserOU = 'OU=Disableuser, DC=test, DC=local',     #Disabled USer OU path (Distinguished Name)

    [string]$O365License = '',        # Enter your license name. You can see your license from your portal or with "Get-MsolAccountSku" command

    #PTS and User personal Mail 
    [string]$SenderUserName = 'sender@test.local',  # E-mail sender and Azure/O365 conneciton account
    [string]$SysAdminMail = 'receiver@test.local'    # SysAdmin Mail Account

)


$CloudCredential = Get-Credential  # Azure Account Credential


##############  CONNECT TO MICROSOFT O365 ACCOUNT  ##############
Connect-MsolService -Credential $CloudCredential 
$O365License = (Get-MsolUser -UserPrincipalName $PrincipalName).isLicensed

if($O365License -eq $true)  {

    #Removing licenses from user accounts
    try{
        (get-MsolUser -UserPrincipalName $PrincipalName).licenses.AccountSkuId | ForEach-Object { Set-MsolUserLicense -UserPrincipalName $PrincipalName -RemoveLicenses $_ -ErrorAction Stop } 
            
        Write-Host "O365 license removed from $PrincipalName"
        $LicenseRemovalResult = "All Microsoft 365 Licenses removed successfully."
    }
    catch [System.Exception] {
        $LicenseRemovalResult = "Removing Microsoft 365 licenses failed."
        "Failed to remove license: {0}" -f  $_.Exception.Message
    }
}
else
{
$LicenseRemovalResult = "There is no license assigned to this user"
}
$ActiveLicense = (Get-MsolAccountSku | where {$_.AccountSkuId -eq $O365License}).activeunits #Number of the license
$AssignedLicense = (Get-MsolAccountSku | where {$_.AccountSkuId -eq $O365License}).consumedunits # Number of the assigned license
$AvailableLicense = $ActiveLicense-$AssignedLicense

##############  REMOVE THE USER FROM ALL O365 GROUPS  ##############
Connect-AzureAD -Credential $CloudCredential #Connect to AzureAD
  
$AADGroups = Get-AzureADMSGroup -Filter "groupTypes/any(c:c eq 'Unified')" -All:$true # Get all Azure AD Unified Groups
$UserAzureID = (Get-AzureADUser -ObjectID $PrincipalName).ObjectID # User Object ID
 
#Check each group for the user
ForEach ($Group in $AADGroups) 
{
    $GroupMembers = (Get-AzureADGroupMember -ObjectId $Group.id).UserPrincipalName
    If ($GroupMembers -contains $PrincipalName)
    {
        #Remove user from Group
        try {
            Remove-AzureADGroupMember -ObjectId $Group.Id -MemberId $UserAzureID
            Write-Output "$PrincipalName was removed from $($Group.DisplayName)"
            $AZGroupResult = "Success"
        } catch [System.Exception] {
            "Failed to remove account from Azure groups: {0}" -f  $_.Exception.Message
            $AZGroupResult = "Failed"              
        }
    }
}


##############  REMOVE THE USER FROM ALL AD GROUPS  ##############
try {
    Get-ADUser -Filter {UserPrincipalName -eq $PrincipalName} -Properties MemberOf | ForEach-Object { $_.MemberOf | Remove-ADGroupMember -Members $_.DistinguishedName -Confirm:$false}
    $ADGroupResult = "Success"
}
catch [System.Exception] {
    "Failed to remove account from AD groups: {0}" -f  $_.Exception.Message
    $ADGroupResult = "Failed"  
}


##############  DISABLE AD ACCOUNT  ##############
$ADAccountStatus = Get-ADUser -Filter {UserPrincipalName -eq $PrincipalName} | Select-Object -ExpandProperty enabled
if ($ADAccountStatus -eq $true) {
    try {
        Get-aduser -Filter {UserPrincipalName -eq $PrincipalName} | Disable-ADAccount
        Write-Host "$PrincipalName AD account disabled."
        $ADAccountResult = "Successfully disabled"

        Get-ADUser -Filter {UserPrincipalName -eq $PrincipalName}| Move-ADObject -TargetPath $DisabledUserOU #Move disabled user account
    }
    catch [System.Exception] {
        "Failed to disable AD account: {0}" -f  $_.Exception.Message
        $ADAccountResult = "Failed to disable"
   }
}else {
    Write-Host "$PrincipalName AD account account is already disabled."
    $ADAccountResult = "Already disabled"
}


##############  Replication of all local DCs according to the last repliction results  ##############

#The PowerShell AD module uses Active Directory Web Services on DC to communicate with ADDS. The TCP port 9389 on the domain controller must be accessible from your computer to communicate properly with ADWS.
try 
{
    Start-Process -FilePath repadmin.exe -ArgumentList "/syncall" #Run replication.
}
catch [System.Exception]
{
    "An error occurred during replication: {0}" -f  $_.Exception.Message  #if DCs does not replicate with other dc print the reason for error
}


##############  SYNC AZURE WITH DC  ##############
try {
    Start-ADSyncSyncCycle -PolicyType Delta  #"delta" sync only checks and syncs changes since the last run
}
catch [System.Exception] {
    "Check the Azure AD sync: {0}" -f  $_.Exception.Message
}


##############  SEND INFO MAIL TO SYSADMIN TEAM  ############## 
$EmailBody = @"
 
<p>Hello Sysadmins,</p>
<p>PTS has disabled $PrincipalName account.</p>
<p>&nbsp;</p>
<p><strong style="color: #000;">Username:</strong> $PrincipalName</p>
<p><strong style="color: #000;">Remove AD groups result:</strong> $ADGroupResult</p>
<p><strong style="color: #000;">Remove Azure groups result:</strong> $AZGroupResult</p>
<p><strong style="color: #000;">AD account disable result:</strong> $ADAccountResult</p>
<p><strong style="color: #000;">License removal result:</strong> $LicenseRemovalResult</p>
<p><strong style="color: #000;">Available 365 Business Basic license:</strong> $AvailableLicense</p> 
<p>&nbsp;</p>
<p>Regards,</p>
<p>PTS</p>
 
"@

function SysAdminMailFunction (){

    $AccountMailParameter = @{
    Credential = $CloudCredential

    To = $SysAdminMail
    From = $SenderUserName

    Subject = "Disable User Account - $(Get-Date -Format g)"
    Body = $EmailBody

    SmtpServer = 'smtp.office365.com'
    Port = '587'
    UseSsl = $true        
    DeliveryNotificationOption = 'OnFailure', 'OnSuccess'}


    try {
        Write-Host "Sending mail to SysAdmin Team ..."
        Send-MailMessage @AccountMailParameter -BodyAsHtml
    }
    catch [System.Exception] {
        "Failed to send email: {0}" -f  $_.Exception.Message
    }
}
SysAdminMailFunction

Disconnect-AzureAD

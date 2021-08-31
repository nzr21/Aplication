################ SID Function for user ###################
function SIDFunction ([string]$UserAccount)
{
  $ObjectUser = New-Object System.Security.Principal.NTAccount($UserAccount)
  $SIDValue = $ObjectUser.Translate([System.Security.Principal.SecurityIdentifier])
  return $SIDValue.Value
}

################ User Name from SID Value ###################
function NameFunction ([string]$UserSID)
{
  $ObjectSID = New-Object System.Security.Principal.SecurityIdentifier($UserSID)
  $ObjectName = $ObjectSID.Translate( [System.Security.Principal.NTAccount])
  return $ObjectName.Value
}
    
################ Current user SID & new user SID & SamAccountName Domain User ############
$CurrentUser = [Environment]::UserName
$CurrentUserSID = SIDFunction $CurrentUser
$NewUserSID = SIDFunction "DOMAIN USER ACCOUNT"
$SamAccountName = NameFunction $NewUserSID

############## Local and Domain User Registry Keys ################
$RegistryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList"
$LocalUserProfile = Get-ChildItem -LiteralPath $RegistryPath | ? {$_.name -match $CurrentUserSID} 
$DomainUserProfile = Get-ChildItem -LiteralPath $RegistryPath | ? {$_.name -match $DomainUserSID} 
 
# Obtain registry, profile path, user and profile new path
$LocalUserRegistry = $($($LocalUserProfile.pspath.tostring().split("::") | Select-Object -Last 1).Replace("HKEY_LOCAL_MACHINE","HKLM:"))
$DomainUserRegistry = $($($DomainUserProfile.pspath.tostring().split("::") | Select-Object -Last 1).Replace("HKEY_LOCAL_MACHINE","HKLM:"))

################# Local and Domain User Folders and Name #################
$LocalProfilePath = $(Get-ItemProperty -LiteralPath $LocalUserRegistry -name ProfileImagePath).ProfileImagePath.ToString()
$LocalProfileName =$LocalProfilePath.Split("\")[-1]
$DomainProfilePath = $(Get-ItemProperty -LiteralPath $DomainUserRegistry -name ProfileImagePath).ProfileImagePath.ToString()
$DomainProfileName = $LocalProfilePath.Split("\")[-1]


# Move the profile folders to the new location
try
{
    $CopyCommand = "robocopy /e /MOVE /copyall /r:0 /mt:4 /b /nfl /xj /xjd /xjf $OldPath $NewPath"
    echo "Copying folders to new location ($DomainProfilePath)..."        
    #xcopy $OldPath $NewPath /s /v /e /c /y /h /k /i /g
    robocopy.exe $LocalProfilePath $DomainProfilePath /E /Z /ZB /R:2 /TBD /NP /V /XD /XF
    Write-Host "Copying file proccess is finished..."	
}
catch [System.Exception] {
    "Copying Files Error: {0}" -f  $_.Exception.Message
}

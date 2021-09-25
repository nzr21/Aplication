param(
[string]$deviceName = 'NBK-VM2',   # Device Name
[string]$newOwner = 'nezir.kadah@bbconsult.co.uk'   # New user UPN
)


# Connect Azure Portal
try
{
    Get-AzureADTenantDetail
}

Catch [Microsoft.Open.Azure.AD.CommonLibrary.AadNeedAuthenticationException]
 {
    Write-Host "You're not connected to AzureAD and O365. Attempting to connect now"
    Connect-AzureAD
 } 
 

# List device and user info
<#
Get-AzureADDevice | where { $_.Name -eq $deviceName } >> For Azure registered device
Get-MsolDevice -Name $deviceName                      >> For Azure domian joined device


https://docs.microsoft.com/en-us/powershell/module/msonline/get-msoldevice?view=azureadps-1.0
#>
 
$device = Get-AzureADDevice -filter "DisplayName eq '$deviceName'"
$aduser = Get-AzureADUser -Filter "userPrincipalName eq '$newOwner'"
$oldowner = (Get-AzureADDeviceRegisteredOwner -ObjectId $device.ObjectId).ObjectId

if ($OldOwner -eq $NewOwner)
{
    Write-Output "They are already the owner!"
}
else
{
    "Change owner of device " + $deviceName + " to " + $aduser.DisplayName
    Add-AzureADDeviceRegisteredOwner -ObjectId $device.ObjectId -RefObjectId $aduser.ObjectId # add the new owner
    Remove-AzureADDeviceRegisteredOwner -ObjectId $device.ObjectId -OwnerId $oldowner         # remove the previous owner
    Get-AzureADDeviceRegisteredOwner -ObjectId $device.ObjectId                               # see the result
}

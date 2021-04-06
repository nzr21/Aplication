##############  DEFINE VARIABLE/PARAMETER  ##############

param
(
    #New User info
    [string]$DisplayName = 'Walter Benjamin',       # User Full Name
    [string]$FirstName = 'Walter',                  # User First Name
    [string]$LastName = 'Benjamin',                 # User Surname
    [string]$UPNSuffix = 'test1.co.uk',             # ("test1.co.uk" / "test2.co.uk")
    [string]$Department = 'Help Desk',              # User Department
    [string]$Title = 'System Administrator',        # User Title
    [string]$MobilePhone = '+4401212121212',        # User Mobile Phone
    [string]$PasswordLength = 8,
    [string]$ExpirationDate = 'never'               #Account Expiration Date format must be 'MM/DD/YEAR' with single quote. If the user account is permanent, type 'never'
    
)



##############  COMPLEX PASSWORD GENERATOR  ##############

function PasswordGenerator($LengthPassword, $CharactersPassword) {
    
    $random = 1..$LengthPassword | ForEach-Object { Get-Random -Maximum $CharactersPassword.length }
    $private:ofs="" # Remove the blank between characters
    return [String]$CharactersPassword[$random]
}

$Characters = @('qabcdefghijkmnprstuxwvyz' , 'QABCDEFGHJKLMNPRSTXWUVYZ' , '1234567890' , '.@,:;=()#$!+*?%/-"') #Array of password characters
$AllCharacters = 'qabcdefghijkmnprstuxwvyzQABCDEFGHJKLMNPRSTXWUVYZ1234567890!.@,:;=()#$!+*?%/-"'   # all of password characters

$UserPassword = PasswordGenerator -LengthPassword 1 -characters $Characters[0]
$UserPassword += PasswordGenerator -LengthPassword 1 -characters $Characters[1]
$UserPassword += PasswordGenerator -LengthPassword 1 -characters $Characters[2]
$UserPassword += PasswordGenerator -LengthPassword 1 -characters $Characters[3]

$UserPassword += PasswordGenerator -LengthPassword ([Int]$PasswordLength-4) -characters $AllCharacters #User password (length of password = 8)
$LoginPassword = ConvertTo-SecureString -string $UserPassword -AsPlainText -Force #Secure password generate for AD User



##############  CHECK THE UPN SUFFIX and SET IT FOR EMAIL  ##############

[hashtable]$UPNS = @{
    #Domain : test.local

    UPN1  = "test1.co.uk";
    OU1 = "OU=AAAAA,DC=test,DC=local"; #Path for "test1" 

    UPN2  = "test2.co.uk";
    OU2 = "OU=BBBBB,DC=test,DC=local"  #Path for "test2"
}

if ($UPNSuffix -eq $UPNS.UPN1)
{
    $MailSuffix = "@"+ $UPNSuffix
    $UserPath = $UPNS.OU1
}
elseif ($UPNSuffix -eq $UPNS.UPN2)
{
    $MailSuffix = "@"+ $UPNSuffix
    $UserPath = $UPNS.OU2
}
else
{
    Write-Host 'Please check the UPN Value! UPN suffix string is not valid'
}




##############  CREATE NEW AD USER  ##############

#Import-Module ActiveDirectory

#Assume the user not exist and create "UPN, CN and sAMAccountName"
$AccountName = ($FirstName+"."+$LastName).ToLower()          # AccountName = walter.benjamin
$PrincipalName = $AccountName + $MailSuffix                  # UPN = walter.benjamin@bbconsult.co.uk
$sAMAccountName = ($FirstName[0]+$LastName+$stri).ToLower()  # sAMAccountName = wbenjamin
$Name = $DisplayName                                         # CN = walter benjamin

# "UPN, CN and sAMAccountName" must be unique for each user. The parameter -Name sets not only the attribute name but also "cn (common name)", which must be unique just like sAMAccountName.
function MailAccountExists() {
	
	$Acc1 = $AccountName + "@"+ $UPNS.UPN1
	$Acc2 = $AccountName + "@"+ $UPNS.UPN2
	
    return ((Get-ADUser -Filter { UserPrincipalName -eq $Acc1 }) -or (Get-ADUser -Filter { UserPrincipalName -eq $Acc2 }))
}

function SamAccountExists() {

    return (Get-ADUser -Filter { sAMAccountName -eq $sAMAccountName })
}

function CommonNameExists() {

    return (Get-ADUser -Filter { Name -eq $Name })
}

#Check user "UPN, CN and sAMAccountName" in local domain
for ($i=2; (MailAccountExists -or SamAccountExists -or CommonNameExists); $i++) #check the user account, if the user exist increase the suffix each time
{

	$str = $i.ToString();
	$Name = $DisplayName+$str
	$AccountName = ($FirstName+"."+$LastName+$str).ToLower() 
	$sAMAccountName = ($FirstName[0]+$LastName+$str).ToLower()
}

$PrincipalName = $AccountName + $MailSuffix # Create the unique UPN for user 


#Create User with attributes		
$NewUserParams = @{
	'Name' = $Name
	'GivenName' = $FirstName
	'Surname' = $LastName
    'DisplayName' = $DisplayName
	'Title' = $Title
    'Department' = $Department
    'MobilePhone' = $MobilePhone
	'sAMAccountName' = $sAMAccountName
	'AccountPassword' = $LoginPassword
    'EmailAddress' = $PrincipalName
    'UserPrincipalName' = $PrincipalName
    'Path' = $UserPath
	'ChangePasswordAtLogon' = $true
	'Enabled' = $true
}

try {
    New-AdUser @NewUserParams
    #Remove-ADUser -Identity "CN = $Name, $UserPath"
}
catch [System.Exception] {
        "Failed to creating new account: {0}" -f  $_.Exception.Message #Reason for user account not being created 
}

#Adding proxy addres for new user
$ProxyAddrs = "smtp:" +$AccountName + "@365." + $UPNS.UPN1 # Define Proxy address as "o365.test1.co.uk".
Set-ADUser -Identity $sAMAccountName -Replace @{proxyAddresses = $proxyAddrs}

#Set Account Expiration Date for new user, if the user is not permanent
if ($ExpirationDate -ne 'never')
{
    Set-ADUser -Identity $sAMAccountName -AccountExpirationDate $ExpirationDate
}

#Export USer Credential
$DesktopPath = [Environment]::GetFolderPath("Desktop") # Get current user deskop path
$PrincipalName , $UserPassword | Out-File -FilePath ($DesktopPath + "\$Name.txt") #Save the user info on deskop

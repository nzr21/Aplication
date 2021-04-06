##############  DEFINE VARIABLE/PARAMETER  ##############

param
(
    #New User info
    [string]$DisplayName = 'Walter Benjamin',
    [string]$Department = 'IT',
    [string]$Title = 'System Administrator',
    [string]$MobilePhone = '+4401212121212',
    [string]$UserPath = 'OU=testuser,DC=test,DC=local', #User path - Domain: test.local
    [string]$PasswordLength = 8
)



##############  COMPLEX PASSWORD GENERATOR  ##############

function PasswordGenerator($LengthPassword, $CharactersPassword) {
    
    $random = 1..$LengthPassword | ForEach-Object { Get-Random -Maximum $CharactersPassword.length }
    $private:ofs=""
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



##############  CREATE NEW AD USER  ##############

Import-Module ActiveDirectory

#Create user attributes
$FirstName = $DisplayName.Split(" ")[0]               #First name = Walter
$LastName = $DisplayName.Split(" ")[1]                #Last name = Benjamin
$SamAccountName = ($FirstName[0]+$LastName).ToLower() #SamAccountName = wbenjamin
$AccountName = ($FirstName+"."+$LastName).ToLower()   #AccountName = walter.benjamin
$PrincipalName = $AccountName + "@test.com"           #UserPrincipalName = walter.benjamin@test.com

#Check user name in local domain and create user account.
if (!(Get-ADUser -Filter { UserPrincipalName -eq $PrincipalName })) 
{ 
	#Create New User in Local Domain
    New-ADUser -Name $DisplayName -GivenName $FirstName -Surname $LastName -SamAccountName $SamAccountName -UserPrincipalName $PrincipalName `
 -EmailAddress $PrincipalName -Department $Department -Title $Title -MobilePhone $MobilePhone -AccountPassword $LoginPassword -Path $UserPath -Enabled $true
} 
else #If the duplicate, append 2 the account name and mail
{ 
    #The parameter -Name sets not only the attribute name but also "cn (common name)", which must be unique just like sAMAccountName. 
    $DisplayName = $DisplayName +2
    $SamAccountName = ($FirstName[0]+$LastName+2).ToLower()
    $AccountName = ($FirstName+"."+$LastName+2).ToLower() 
    $PrincipalName = "$AccountName@bbconsult.co.uk"

    #Create New User in Local Domain
    New-ADUser -Name $DisplayName -GivenName $FirstName -Surname $LastName -SamAccountName $SamAccountName -UserPrincipalName $PrincipalName` -EmailAddress $PrincipalName -Department $Department -Title $Title -MobilePhone $MobilePhone -AccountPassword $LoginPassword -Path $UserPath -Enabled $true
}
		

#Export USer Credential
$PrincipalName , $UserPassword | Out-File -FilePath C:\$DisplayName.txt
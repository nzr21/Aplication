<#
domain : test.local
UPN type : firstname.lastname@test.local
sAMAccountName : First letter of name + LastName
Path: Synced user OU
#>

$UserPersonalMail = '',   # User personal mail account (xxx.yyy@gmail.com)
$SysAdminMail = 'sysadmin@test.local',  # Sysadmin Mail Account
	
#Azure connection Credential
$CloudCredential = $(Get-Credential)  # Azure Account Credential.  Also, this account will be the mailing account.
connect-msolservice -Credential $CloudCredential

 	
#Export User Info#
$Email = "aaaaa.nnnnn@test.local" #User Email account
Get-MsolUser -UserPrincipalName $Email | Select-Object City, Country, Department, DisplayName, Fax, FirstName, LastName, MobilePhone, Office, PasswordNeverExpires, `
PhoneNumber, PostalCode, SignInName, State, StreetAddress, Title, UserPrincipalName, @{L = “ProxyAddresses”; E = { $_.ProxyAddresses -join “;”}} | Export-Csv C:\UserInfo.csv -Encoding UTF8


#Create User AD account
import-csv C:\UserInfo.csv -Encoding UTF8 | foreach-object { `
	#Check if the Email of this user (UPN is already registrered)
	$UPN = $_.UserPrincipalName 
	if (!(Get-ADUser -Filter { UserPrincipalName -eq $UPN })) {`
	
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
		
		#Netbios/sAMAccountName string Formatting
		$sAMAccountName = ($_.FirstName[0]+$_.LastName).ToLower(); `
		
		#Cheking if user is trying to duplicate - if not used normal name
		if (!(Get-ADUser -Filter { sAMAccountName -eq $sAMAccountName })) { `
			$sAMAccountName = ($_.FirstName[0]+$_.LastName).ToLower(); `
			$localName = ($_.DisplayName) `
		} `
		#If trying to duplicate just append a 2 at the Netbios/sAMAccountName String
		else { `
			$sAMAccountName = ($_.FirstName[0]+$_.LastName+2).ToLower(); `
			$localName = ($_.DisplayName+2)`
		} `
		
		#Create the User entry in LocalAD
		New-ADUser -Name $localName -sAMAccountName $sAMAccountName -GivenName $_.FirstName -Surname $_.LastName -City $_.City `
		-Department $_.Department -DisplayName $_.DisplayName -Fax $_.Fax -MobilePhone $_.MobilePhone -Office $_.Office -PasswordNeverExpires ($_.PasswordNeverExpires -eq "True") `
		-OfficePhone $_.PhoneNumber -PostalCode $_.PostalCode -EmailAddress $_.SignInName -State $_.State -StreetAddress $_.StreetAddress -Title $_.Title `
		-UserPrincipalName $_.UserPrincipalName -AccountPassword $LoginPassword -Path "OU=SyncedUser,DC=test,DC=local" -Enabled $true `
		; `
		#Set the user proxy Addresses if any are present in the CSV
		If (-not [string]::IsNullOrWhiteSpace($_.ProxyAddresses)){ `
			foreach( $ProxyAddress in ( $_.ProxyAddresses -split ';' ) ){ `
				Set-ADUser -Identity $uniqueName -Add @{proxyAddresses=$ProxyAddress}`
			} `
		} `
	} `
	#if the Email of this user UPN is already taken don't do any action just notify
	else { `
		echo ("THIS"+$_.FirstName+" "+$_.LastName+"ACCOUNT ALREADY EXIST ON AN ACCOUNT"); `
	} `
}


##############  SEND USER ACCOUNT via MAIL  ##############  
$PersonalEmailBody = @"
 
<p>Hi $DisplayName,</p>
<p>Please use this link to login to your Office 365 account.</p>
<p><span style="color: #0000ff;"><a href="https://login.microsoftonline.com/">https://login.microsoftonline.com/</a></span></p>
<p><strong>Your username is:</strong> $PrincipalName</p>
<p><strong>Your password is:</strong> $UserPassword</p>
<p>Please use the  this temporary password. You need to change it after first login.</p>
<p>Regards,</p>
<p>Sys Admin Team</p>
 
"@

function MailFunction (){

    $MailParameter = @{
    Credential = $CloudCredential

    To = $UserPersonalMail
    From = $SysAdminMail

    Subject = "Login Account - $(Get-Date -Format g)"
    Body = $PersonalEmailBody
    SmtpServer = 'smtp.office365.com'
    Port = '587'
    UseSsl = $true        
    DeliveryNotificationOption = 'OnFailure', 'OnSuccess'}


    try {
        Write-Host "Sending mail to the user ..."
        Send-MailMessage @MailParameter -BodyAsHtml
    }
    catch [System.Exception] {
        "Failed to send email: {0}" -f  $_.Exception.Message
    }
}
MailFunction

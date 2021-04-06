cls
$PasswordLength = 8 #length of password = 8

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

$UserPassword += PasswordGenerator -LengthPassword ([Int]$PasswordLength-4) -characters $AllCharacters #User password
$LoginPassword = ConvertTo-SecureString -string $UserPassword -AsPlainText -Force #Secure password generate for AD User

Write-Host "Your password is $UserPassword"
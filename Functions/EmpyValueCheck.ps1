#I have CSV file contains users data, I wanted to filter which user date of birth field is empty. How can I  compare empty field ?

[string]::IsNullOrWhiteSpace($birthdate)
Import-Csv C:\test\users.csv | Where-Object { [string]::IsNullOrWhiteSpace($_.birthdate) -eq $true }
Import-Csv  C:\test\users.csv | Where-Object { [string]::IsNullOrWhiteSpace($_.birthdate) -eq $true -or ([string]$_.birthdate -as [datetime]) -is [datetime] -eq $false }


# Change the name of table with ProccesID 
Get-Process | Select-Object -Property Name, @{name='ProccesID';expression={$_.ID}}
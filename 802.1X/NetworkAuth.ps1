cls

#Setting of Wired AutoConfig
$Service = Get-Service -Name 'dot3svc' #The Wired AutoConfig (DOT3SVC) service is responsible for performing IEEE 802.1X authentication on Ethernet interfaces.
$Service | Set-Service -StartupType Automatic
$Service | Set-Service -Status Running


<#

Export network profile with following command. Use command prompt
netsh lan export profile folder=c:\

#>

#Import LAN profile configuration file
$FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{ 
    InitialDirectory = [Environment]::GetFolderPath('Desktop') 
    Filter = 'Profile (*.xml)|*.xml'
}
$null = $FileBrowser.ShowDialog()
$Path = $FileBrowser.FileName

#Change connected LAN configuration
$AdapterName = (get-wmiobject win32_networkadapter -filter "netconnectionstatus = 2").netconnectionid #Connected LAN Interface

foreach ($Interface in $AdapterName)
{
    if ($Interface -like "Ethernet*") #Skip virtual interfaces
    {
        
        #Add profile to LAN interface. For WIFI use <<<netsh wlan add profile filename=XMLpath interface="$AdapterName">>>
        netsh lan add profile filename=$Path interface="$Interface"
        
        Disable-NetAdapter -Name $Interface -Confirm:$false #Disable a network adapter
        Rename-NetAdapter -Name "$Interface" -NewName "802.1X" #Rename a network adapter
        Enable-NetAdapter -Name "802.1X" -Confirm:$false #Enable a network adapter
    }
}

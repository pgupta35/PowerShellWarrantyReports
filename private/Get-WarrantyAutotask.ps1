function Get-WarrantyAutotask {
    [CmdletBinding()]
    Param(
        [Pscredential]$AutotaskCredentials,
        [String]$AutotaskAPIKey,
        [boolean]$SyncWithSource,
        [boolean]$Missingonly,
        [boolean]$OverwriteWarranty
    )
    If (Get-Module -ListAvailable -Name "AutoTaskAPI") { Import-module "AutotaskAPI" } Else { install-module "AutotaskAPI" -Force }
    Import-Module AutotaskAPI
    Add-AutotaskAPIAuth -ApiIntegrationcode $AutotaskAPIKey -credentials $AutotaskCredentials
    write-host "Logging into Autotask. Grabbing all client information." -ForegroundColor "Green"
    $AllClients = Get-AutotaskAPIResource -resource Companies -SimpleSearch 'isactive eq true' 
    write-host "Client information found. Grabbing all devices" -ForegroundColor "Green"
    $AllDevices = Get-AutotaskAPIResource -resource ConfigurationItems -SimpleSearch 'isactive eq true'
    write-host "Collecting information. This can take a long time." -ForegroundColor "Green"
    $i = 0
    $warrantyObject = foreach ($Device in $AllDevices) {
        $i++
        Write-Progress -Activity "Grabbing Warranty information" -status "Processing $($device.serialnumber). Device $i of $($Alldevices.Count)" -percentComplete ($i / $Alldevices.Count * 100)
        $Client = ($AllClients | Where-Object { $_.id -eq $device.companyID }).CompanyName
        $WarState = Get-Warrantyinfo -DeviceSerial $device.serialnumber -client $Client

        if ($SyncWithSource -eq $true) {
            switch ($OverwriteWarranty) {
                $true {
                    if ($null -ne $warstate.EndDate) {
                        $device | ForEach-Object { $_.warrantyExpirationDate = $warstate.EndDate; $_ } | Set-AutotaskAPIResource -Resource ConfigurationItems
                        "$((get-date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss')) Autotask: $Client / $($device.SerialNumber) with AT ID $($device.id) warranty has been overwritten to $($warstate.EndDate)" | out-file $script:LogPath -Append -Force
                    }
                     
                }
                $false { 
                    if ($null -eq $device.WarrantyExpirationDate -and $null -ne $warstate.EndDate) { 
                        $device | ForEach-Object { $_.warrantyExpirationDate = $warstate.EndDate; $_ } | Set-AutotaskAPIResource -Resource ConfigurationItems
                        "$((get-date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss')) Autotask: $Client / $($device.SerialNumber) with AT ID $($device.id) warranty has been set to $($warstate.EndDate)" | out-file $script:LogPath -Append -Force
                    } 
                }
            }
        }
        $WarState
    }
 
    return $warrantyObject
}
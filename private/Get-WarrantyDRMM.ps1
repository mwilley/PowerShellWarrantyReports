function  Get-WarrantyDattoRMM {
    [CmdletBinding()]
    Param(
        [string]$DRMMAPIKey,
        [String]$DRMMApiURL,
        [String]$DRMMSecret,
        [boolean]$SyncWithSource,
        [boolean]$OverwriteWarranty
    )
    write-host "Source is Datto RMM. Grabbing all devices." -ForegroundColor Green
    If (Get-Module -ListAvailable -Name "DattoRMM") { 
        Import-module DattoRMM
    }
    Else { 
        Install-Module DattoRMM -Force
        Import-Module DattoRMM
    }
    #Settings DRMM
    # Provide API Parameters
    $params = @{
        Url       = $DRMMApiURL
        Key       = $DRMMAPIKey
        SecretKey = $DRMMSecret
    }

    # Set API Parameters
    Set-DrmmApiParameters @params
    write-host "Getting DattoRMM Devices" -foregroundColor green
    $AllDevices = Get-DrmmAccountDevices
    $i = 0
    $warrantyObject = foreach ($device in $AllDevices) {
        try {
            if ($Device.DeviceClass -eq 'esxihost') {
                $DeviceSerial = (Get-DrmmAuditesxi  -deviceUid $device.uid).systeminfo.servicetag
            }
            else {
                $DeviceSerial = (Get-DrmmAuditDevice -deviceUid $device.uid).bios.serialnumber
            }
        }
        catch {
            write-host "Could not retrieve serialnumber for $device"
            continue
        }
        $i++
        Write-Progress -Activity "Grabbing Warranty information" -status "Processing $($DeviceSerial). Device $i of $($AllDevices.Count)" -percentComplete ($i / $AllDevices.Count * 100)

        $WarState = Get-Warrantyinfo -DeviceSerial $DeviceSerial -client $device.siteName

        if ($SyncWithSource -eq $true) {
            switch ($OverwriteWarranty) {
                $true {
                    if ($null -ne $warstate.EndDate) {
                        Set-DrmmDeviceWarranty -deviceUid $device.uid -warranty $warstate.EndDate
                    }
                     
                }
                $false { 
                    if ($null -eq $device.WarrantyExpirationDate -and $null -ne $warstate.EndDate) { 
                        Set-DrmmDeviceWarranty -deviceuid $device.uid -warranty $warstate.EndDate
                    } 
                }
            }
        }
        $WarState
    }
    return $warrantyObject
}
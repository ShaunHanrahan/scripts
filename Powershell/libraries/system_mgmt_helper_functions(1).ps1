function Get-AssetTag {
    return (Get-WmiObject -Class Win32_SystemEnclosure).SMBIOSAssetTag
}

function Get-Manufacturer {
    return (Get-WmiObject -Class Win32_ComputerSystem).Manufacturer
}

function Get-SerialNumber {
    return (Get-WmiObject -Class Win32_BIOS).SerialNumber
}

function Get-LaptopOrDesktop {
    $chassisType = (Get-WmiObject -Class Win32_SystemEnclosure).ChassisTypes[0]
    switch ($chassisType) {
        3 { return 'Desktop' }
        4 { return 'Desktop' }
        6 { return 'Desktop' }
        7 { return 'Desktop' }
        8 { return 'Laptop' }
        9 { return 'Laptop' }
        10 { return 'Laptop' }
        default { return 'Unknown' }
    }
}
Function Set-RegistryKey {
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('HKLM:', 'HKCU:')]
        [string] $Hive,

        [Parameter(Mandatory=$true)]
        [string] $Path,

        [Parameter(Mandatory=$true)]
        [string] $Name,

        [Parameter(Mandatory=$true)]
        [string] $Value,

        [Parameter(Mandatory=$true)]
        [string] $Type
    )

    $FullPath = Join-Path -Path $Hive -ChildPath $Path

    if(!(Test-Path -Path $FullPath)){
        Write-Host "Path does not exist. Creating now..."
        New-Item -Path $FullPath -Force | Out-Null
    }

    Write-Host "Setting value of $Name to $Value in $FullPath"
    Set-ItemProperty -Path $FullPath -Name $Name -Value $Value

}
param (
    [Parameter(Mandatory)]
    [string] $UserName
)
([ADSI]"WinNT://./Administrators,group").Remove("WinNT://$env:COMPUTERNAME/$UserName")
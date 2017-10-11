param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $ConnectionString
)

$connectionParams = $ConnectionString -split ';' | ConvertFrom-StringData

Add-Type -Path 'C:\Program Files (x86)\Mendix\Service Console\Mendix.M2EE.dll'
$appSettings = [Mendix.M2EE.Settings]::GetInstance('C:\Mendix\Apps\MendixApp')
$appSettings.DatabaseType = 'SQLSERVER'
$appSettings.DatabaseHost = $connectionParams.'Data Source'
$appSettings.DatabaseName = $connectionParams.'Initial Catalog'
$appSettings.DatabaseUserName = $connectionParams.'User ID'
$appSettings.DatabasePassword = $connectionParams.Password
$appSettings.AdminServerPassword = 'Demo1234!'
$appSettings.Save()

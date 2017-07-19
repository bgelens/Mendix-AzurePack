param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $ServerName,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $SqlPassword,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $Database
)
$dbPassword = 'Demo1234!'
Add-Type -Path 'C:\Program Files (x86)\Mendix\Service Console\Mendix.M2EE.dll'
$appSettings = [Mendix.M2EE.Settings]::GetInstance('C:\Mendix\Apps\MendixApp')
$appSettings.DatabaseType = 'SQLSERVER'
$appSettings.DatabaseHost = $ServerName
$appSettings.DatabaseName = $Database
$appSettings.DatabaseUserName = $Database
$appSettings.DatabasePassword = $dbPassword
$appSettings.AdminServerPassword = 'Demo1234!'
$appSettings.Save()

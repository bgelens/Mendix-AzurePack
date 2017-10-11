Import-Module -Name 'C:\Program Files (x86)\Mendix\Service Console\Mendix.Service.Commands.dll'
Add-Type -Path 'C:\Program Files (x86)\Mendix\Service Console\Mendix.M2EE.dll'

$null = Stop-MxApp -Name MendixApp

# Encrypt database password
$yamlContent = Get-Content -Path C:\Mendix\Apps\MendixApp\Settings.yaml
$origDbPassword = ($yamlContent | Select-String -Pattern "\s*\bDatabasePassword:.*").ToString()
$dbPassword = $origDbPassword.Split(':')[-1].Trim()
$newDbPassword = [Mendix.M2EE.Utils.Encryption]::Encrypt($dbPassword)
$newDbPassword = $origDbPassword.Split(':')[0] + ': ' + $newDbPassword
$yamlContent = $yamlContent.Replace($origDbPassword, $newDbPassword)
$yamlContent | Out-File C:\Mendix\Apps\MendixApp\Settings.yaml -Encoding utf8 -Force

$null = Start-MxApp -Name MendixApp
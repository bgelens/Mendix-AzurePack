param (
    [Parameter(Mandatory)]
    [string] $UserCred
)
$ErrorActionPreference = 'Stop'
$mendixSCPath = 'C:\Program Files (x86)\Mendix\Service Console'
$yamlPath = 'C:\Mendix\Apps\MendixApp\Settings.yaml'

Add-Type -Path "$mendixSCPath\Newtonsoft.Json.dll"
Add-Type -Path "$mendixSCPath\YamlSerializer.dll"
Add-Type -Path "$mendixSCPath\Mendix.M2EE.dll"

$userPassword = $UserCred.Split(':')[-1]

$yamlContent = Get-Content -Path $yamlPath
$origServicePassword = ($yamlContent | Select-String -Pattern "\s*\bPassword:.*").ToString()

$newServicePassword = [Mendix.M2EE.Utils.Encryption]::Encrypt('Demo1234!','Administrator',{[string]$userPassword})

$replaceSCPassword = $origServicePassword.Split(':')[0] + ': ' + $newServicePassword

$yamlContent = $yamlContent.Replace($origServicePassword, $replaceSCPassword)
$yamlContent | Out-File -FilePath $yamlPath -Encoding utf8 -Force
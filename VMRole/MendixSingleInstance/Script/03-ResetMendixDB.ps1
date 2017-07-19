$ErrorActionPreference = 'Stop'
$mendixSCPath = 'C:\Program Files (x86)\Mendix\Service Console'
$yamlPath = 'C:\Mendix\Apps\MendixApp\Settings.yaml'
$yamlContent = Get-Content -Path $yamlPath

Add-Type -Path "$mendixSCPath\Newtonsoft.Json.dll"
Add-Type -Path "$mendixSCPath\YamlSerializer.dll"
Add-Type -Path "$mendixSCPath\Mendix.M2EE.dll"

$origDbPassword = ($yamlContent | Select-String -Pattern "\s*\bDatabasePassword:.*").ToString()

# generate new passwords
$newDbPassword = [Mendix.M2EE.Utils.Encryption]::Encrypt('Demo1234!','MxAdmin',{[string]'Demo1234!'})

$replaceDbPassword = $origDbPassword.Split(':')[0] + ': ' + $newDbPassword

$yamlContent = $yamlContent.Replace($origDbPassword, $replaceDbPassword)
$yamlContent | Out-File -FilePath $yamlPath -Encoding utf8 -Force
$ErrorActionPreference = 'Stop'
if (Test-Path -Path c:\VMRole\First) {
    Import-Module -Name 'C:\Program Files (x86)\Mendix\Service Console\Mendix.Service.Commands.dll'
    $null = Start-MxApp -Name MendixApp -SynchronizeDatabase

    $client = [Mendix.M2EE.M2EEClient]::new([version]"1.0.0",'http://localhost:8090/','Demo1234!')
    $client.CreateAdminUser('Demo1234!')
} else {
    Import-Module -Name 'C:\Program Files (x86)\Mendix\Service Console\Mendix.Service.Commands.dll'
    $null = Start-MxApp -Name MendixApp
}
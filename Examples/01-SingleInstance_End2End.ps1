# Get your publishsetting file from 'https://tenant.portal/publishsettings'

# Load the PowerShell module
Import-Module -Name MXWAPack

# Import the publishsetting file and select one of it's subscriptions to work with
Import-MXWAPackPublishSettingFile -Path C:\Users\administrator.WAP\Desktop\Default-SecondPlan-7-13-2017-credentials.publishsettings
Get-MXWAPackPublishSettingSubscription -Name Default | Select-MXWAPackPublishSettingSubscription

# Create a Cloud Service which will contain the VM Role / VM(s)
$cloudService = New-MXWAPackCloudService -Name MyApp01

# Lookup the VM network to connect to
$vmNet = Get-MXWAPackVMNetwork -Name Tenant

# Lookup the VM size to use
$size = Get-MXWAPackVMRoleSizeProfile -Name Medium

# Get the Gallery Item to deploy
$gi = Get-MXWAPackGalleryItem -Name MendixSingleInstance

# Get the Gallery Item properties
$params = $gi | New-MXWAPackGalleryItemParameterObject

# Fill in the blanks / overwrite default properties
$params.VMRoleAdminCredential = 'administrator:Welkom01'
$params.VMRoleComputerNamePattern = 'Mendix###'
$params.VMRoleNetworkRef = $vmNet.Name
$params.VMRoleVMSize = $size.Name

# Start the deployment
New-MXWAPackVMRoleDeployment -CloudService $cloudService -GalleryItem $gi -ParameterObject $params

# Wait for deployment to finish
do {
    Start-Sleep -Seconds 3
    $vmRole = $cloudService | Get-MXWAPackVMRole
} until ($vmRole.ProvisioningState -ne 'Provisioning')

# Check if deployment has failed or succeedded
$vmRole.ProvisioningState

# If deployment has failed, check for messages
$vmRole.Substate.VMRoleMessages

# When deployment was succesfull get VM objects
$vmRole | Get-MXWAPackVMRoleVM

# To shutdown the VM (shutdown OS)
$vmRole | Get-MXWAPackVMRoleVM | Stop-MXWAPackVMRoleVM

# To power off the VM (in case the OS cannot shutdown)
$vmRole | Get-MXWAPackVMRoleVM | Stop-MXWAPackVMRoleVM -PowerOff

# To start the VM
$vmRole | Get-MXWAPackVMRoleVM | Start-MXWAPackVMRoleVM

# or to restart the VM in one go
$vmRole | Get-MXWAPackVMRoleVM | Restart-MXWAPackVMRoleVM

# To find the VM IPv4 address
$vmRole | Get-MXWAPackVMRoleVM | ForEach-Object -Process {
    $_.ConnectToAddresses.Where{
        [ipaddress]::Parse($_.IPAddress).AddressFamily -eq 'InterNetwork'
    }
}

<#
    If you are connected to the same network as the VM (directly or routed)
    you can use the VM ip address for the following functions.

    If the VM Network is isolated from you, you need to make the VM tcp port
    80 and 5986 available to you through NAT / PAT 
#>
$ipAddress = '192.168.1.100'

# See if the webserver is up and responding
(Invoke-WebRequest -UseBasicParsing -Uri "http://$ipAddress").StatusCode -eq 200

# See if the remoting endpoint is listening
Test-NetConnection -ComputerName $ipAddress -Port 5986

# Create a credential object to interface with the VM
$cred = New-Object -TypeName pscredential -ArgumentList @(
    $params.VMRoleAdminCredential.Split(':')[0],
    (ConvertTo-SecureString -String $params.VMRoleAdminCredential.Split(':')[-1] -AsPlainText -Force)
)
# Get-Credential can be used as well

# Get info on installed App(s)
Get-MXWAPackMendixApp -ComputerName $ipAddress -Credential $cred

# Get detailed App configuration
Get-MXWAPackMendixAppSettings -ComputerName $ipAddress -Credential $cred

# Get Installed Server runtimes
Get-MXWAPackInstalledServerPackage -ComputerName $ipAddress -Credential $cred

# Get information about App to install from package (e.g. Required RuntimeVersion)
Get-MXWAPackMendixAppPackage -Path ~\Desktop\Downloads\FieldExampleaHold_1.0.0.8.mda

# Install additional runtime (when required)
Install-MXWAPackServerPackage -ComputerName $ipAddress -Credential $cred -Path ~\Desktop\Downloads\mendix-6.10.2.tar.gz

# Update the Application with new package
Update-MXWAPackMendixApp -ComputerName $ipAddress -Credential $cred -Path ~\Desktop\Downloads\FieldExampleaHold_1.0.0.8.mda -SynchronizeDatabase

# Stop Mendix App
Stop-MXWAPackMendixApp -ComputerName $ipAddress -Credential $cred

# Start Mendix App
Start-MXWAPackMendixApp -ComputerName $ipAddress -Credential $cred

# Install and bind SSL certificate so port 443 will be available
$pin = Read-Host -AsSecureString -Prompt Pin
Add-MXWAPackSSLBinding -ComputerName $ipAddress -Credential $cred -Path ~\Desktop\MyCert.pfx -Pin $pin -TryImportTrustChain

# Get LincenseId to aqcuire License key from Mendix support
Get-MXWAPackMendixServerLicenseInfo -ComputerName $ipAddress -Credential $cred

# Set LicenseKey once acquired from Mendix support
$lic = 'Key Provided by Mendix support'
Set-MXWAPackMendixServerLicense -License $lic -ComputerName $ipAddress -Credential $cred

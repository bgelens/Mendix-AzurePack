# Get your publishsetting file from 'https://tenant.portal/publishsettings'
# This example is based on the VM Role available at: 'https://github.com/itnetxbe/VMRoles/tree/master/SQL2016'

# Load the PowerShell module
Import-Module -Name MXWAPack

# Import the publishsetting file and select one of it's subscriptions to work with
Import-MXWAPackPublishSettingFile -Path C:\Users\administrator.WAP\Desktop\Default-SecondPlan-7-13-2017-credentials.publishsettings
Get-MXWAPackPublishSettingSubscription -Name Default | Select-MXWAPackPublishSettingSubscription

# Create a Cloud Service which will contain the SQL VM Role / VM(s)
$cloudService = New-MXWAPackCloudService -Name SQL01

# Lookup the VM network to connect to
$vmNet = Get-MXWAPackVMNetwork -Name Tenant

# Lookup the VM size to use
$size = Get-MXWAPackVMRoleSizeProfile -Name Medium

# Lookup the VM OS disk to use
$osDisk = $gi | Get-MXWAPackVMRoleOSDisk

# Get the Gallery Item to deploy
$gi = Get-MXWAPackGalleryItem -Name SQLServer2016

# Get the Gallery Item properties
$params = $gi | New-MXWAPackGalleryItemParameterObject

# Fill in the blanks / overwrite default properties
$params.VMRoleAdminCredential = 'administrator:Welkom01'
$params.VMRoleNetworkRef = $vmNet.Name
$params.VMRoleVMSize = $size.Name
$params.VMRoleTimeZone = 'W. Europe Standard Time'
$params.SQLServer2016SQLSAPassword = 'Welkom01'
$params.VMRoleOSVirtualHardDiskImage = '{0}:{1}' -f $osDisk.FamilyName, $osDisk.Release

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

# Get data needed to construct sql connectionstring
$VMRole = $cloudService | Get-MXWAPackVMRole

$ipv4 = $VMRole | Get-MXWAPackVMRoleVM | ForEach-Object -Process {
    $_.ConnectToAddresses.Where{
        [ipaddress]::Parse($_.IPAddress).AddressFamily -eq 'InterNetwork'
    }
}

'SQL instance available on: {0} using port: {1}' -f $ipv4.IPAddress, $params.SQLServer2016SQLPort

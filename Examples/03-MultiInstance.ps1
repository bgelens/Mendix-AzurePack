# Get your publishsetting file from 'https://tenant.portal/publishsettings'

# Load the PowerShell module
Import-Module -Name MXWAPack

# Import the publishsetting file and select one of it's subscriptions to work with
Import-MXWAPackPublishSettingFile -Path C:\Users\administrator.WAP\Desktop\Default-SecondPlan-7-13-2017-credentials.publishsettings
Get-MXWAPackPublishSettingSubscription -Name Default | Select-MXWAPackPublishSettingSubscription

# Create a Cloud Service which will contain the Multi Instance VM Role / VM(s)
$cloudService = New-MXWAPackCloudService -Name MXMulti01

# Lookup the VM network to connect to
$vmNet = Get-MXWAPackVMNetwork -Name Tenant

# Lookup the VM size to use
$size = Get-MXWAPackVMRoleSizeProfile -Name Medium

# Get the Gallery Item to deploy
$gi = Get-MXWAPackGalleryItem -Name MendixMultiInstance

# Lookup the VM OS disk to use
$osDisk = $gi | Get-MXWAPackVMRoleOSDisk

# Get the Gallery Item properties
$params = $gi | New-MXWAPackGalleryItemParameterObject

# Fill in the blanks / overwrite default properties
$params.VMRoleAdminCredential = 'administrator:Welkom01'
$params.VMRoleNetworkRef = $vmNet.Name
$params.VMRoleVMSize = $size.Name
$params.VMRoleOSVirtualHardDiskImage = '{0}:{1}' -f $osDisk.FamilyName, $osDisk.Release
$params.MendixMultiInstanceSqlServerUserName = 'sa'
$params.MendixMultiInstanceSqlServerPassword = 'Welkom01'
$params.MendixMultiInstanceSqlServerName = '172.16.1.117'
$params.MendixMultiInstanceDatabase = 'MendixApp'

# the sql server name can also be specified as '172.16.1.117\MSSQLSERVER:1433' containing the instancename and port number.

# Start the deployment
New-MXWAPackVMRoleDeployment -CloudService $cloudService -GalleryItem $gi -ParameterObject $params

<#
    The fist VM will create a database on the remote sql server using the sql credentials specified.
    The database will have the name as specified by the user for MendixMultiInstanceDatabase.
    If the database already exists, the Deployment will fail.

    Once the database is created, a SQL login named after the database name will be created as well.
    The login will be granted sysadmin rights as required by the Mendix application.
    The login will be granted the owner role of the database.

    All the other VMs and also future scale-out VMs will just check for the database to be present and if so
    Continue with deployment.
#>

<#
    Updating a Mendix app using multiple instances requires that all Mendix runtimes are stopped.
    The Update-MXWAPackMendixApp function need to run with the switch SynchronizeDatabase on the
    first VM that gets updated. On all other VMs must not be used.
#>
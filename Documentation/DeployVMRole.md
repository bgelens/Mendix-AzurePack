# Deploy VM Role

## Get the publishsettings file

To deploy a VM Role using the MXWAPack PowerShell module, the tenant has to fetch a publishsetting file from the Azure Pack portal.
The publishsettings file can be retrieved by going to https://<tenantPortalUri>/publishsettings.

## Make the MXWAPack module available for use

The MXWAPack PowerShell module can be installed by copying the MXWAPack folder and contents in one of the PSModulePath directories.

```powershell
$env:PSModulePath.Split(';')

C:\Users\<UserName>\Documents\WindowsPowerShell\Modules
C:\Program Files\WindowsPowerShell\Modules
C:\WINDOWS\system32\WindowsPowerShell\v1.0\Modules
```

Once the module is installed, it can be imported into a PowerShell session.

```powershell
Import-Module -Name MXWAPack
```

## Deploy a VM Role using the MXWAPack module

Now the PowerShell module is installed and imported, the publishsettings file can imported.

```powershell
Import-MXWAPackPublishSettingFile -Path C:\Users\<username>\Desktop\Plan1-Plan2-7-13-2017-credentials.publishsettings
```

If you have a single or multiple Azure Pack subscriptions, you need to select the subscription to work with.
First enumate the subscriptions made available through the publishsettings file.

```powershell
Get-MXWAPackPublishSettingSubscription | Format-Table -AutoSize

ServiceManagementUrl   Id                                   Name       ManagementCertificate
--------------------   --                                   ----       ---------------------
https://api.wap.local/ 59853252-2e02-4484-bb79-4bd73d412a64 Default    MIIJ7QIBAzCCCa0GCSqGSIb3DQEHAaCCCZ4EggmaMIIJljCCBe4GCSqGSIb3DQE...
https://api.wap.local/ 95ea732d-cff5-49b4-b546-11f204a1b46f SecondPlan MIIJ8wIBAzCCCbMGCSqGSIb3DQEHAaCCCaQEggmgMIIJnDCCBe4GCSqGSIb3DQE...
```

Next select the subscription you want to work with.

```powershell
Get-MXWAPackPublishSettingSubscription -Name Default | Select-MXWAPackPublishSettingSubscription
```

Find the VM Role you want to deploy and assign it to a variable.

```powershell
Get-MXWAPackGalleryItem | ft name,publisher,version

Name                 Publisher Version
----                 --------- -------
MendixSingleInstance Mendix    1.0.0.0

$gi = Get-MXWAPackGalleryItem -Name MendixSingleInstance
```

A VM Role will take parameters it uses to customize the deployment. These parameters can be acquired by sending the Gallery Item object to the ```New-MXWAPackGalleryItemParameterObject``` function.

```powershell
$params = $gi | New-MXWAPackGalleryItemParameterObject
$params

VMRoleAdminCredential        :
VMRoleComputerNamePattern    : Mendix###
VMRoleVMSize                 :
VMRoleNetworkRef             :
VMRoleOSVirtualHardDiskImage : Mendix:1.0.0.0
```

As the result you'll see all the Parameters required for deployment. VM Role deployment requires that all parameters have been assigned proper values.
In this case you can see that a couple of properties have already been assigned default values (this will hapen if the Gallery Item author has assigned default values).

You can overwrite default values and assign values to properties not containing values already.

From this example you can see that a credential need to be assigned for the VM Administrator. Credentials need to be supplied in the format ```username:password```. Please note that the username has to be ```Administrator```.

```powershell
$params.VMRoleAdminCredential = 'Administrator:Welkom01'
```

The ComputerNamePattern has the format ```Name###``` where the ```#``` symbol is used to automatically assign incremental numbers. There should always be at least one ```#``` symbol trailing in the name.

The VMSize property value has to match a name of a VM Role Size Profile available on the specific Azure Pack platform.
To find out what size profiles are available you can use the ```Get-MXWAPackVMRoleSizeProfile``` function.

```powershell
Get-MXWAPackVMRoleSizeProfile

StampId                              Name       CpuCount MemoryInMB
-------                              ----       -------- ----------
9b1e9d00-5271-45ef-b358-e175fbc30595 Small      1        1792
9b1e9d00-5271-45ef-b358-e175fbc30595 A7         8        57344
9b1e9d00-5271-45ef-b358-e175fbc30595 ExtraSmall 1        768
9b1e9d00-5271-45ef-b358-e175fbc30595 Large      4        7168
9b1e9d00-5271-45ef-b358-e175fbc30595 A6         4        28672
9b1e9d00-5271-45ef-b358-e175fbc30595 Medium     2        3584
9b1e9d00-5271-45ef-b358-e175fbc30595 ExtraLarge 8        14336
```

Assign a profile as the parameter value.

```powershell
$params.VMRoleVMSize = 'Medium'
```

The VMRoleNetworkRef property value has to match a VM Network available in the current subscription. To find out what VM Networks are available you can use the ```Get-MXWAPackVMNetwork``` function.

```powershell
Get-MXWAPackVMNetwork | Select-Object -Property Name

Name
----
Tenant
```

Assign a VM Network as the parameter value.

```powershell
$params.VMRoleNetworkRef = 'Tenant'
```

The VMRoleOSVirtualHardDiskImage refers to the VHD(x) to use for deployment. In this case the value has been predefined by a default (if this is not the case, the correct OS disk can be discoverred by using the ```Get-MXWAPackVMRoleOSDisk``` function).

Now the parameter object should have all values assigned.

```powershell
$params

VMRoleAdminCredential        : Administrator:Welkom01
VMRoleComputerNamePattern    : Mendix###
VMRoleVMSize                 : Medium
VMRoleNetworkRef             : Tenant
VMRoleOSVirtualHardDiskImage : Mendix:1.0.0.0
```

A VM Role in Azure Pack is deployed to a Cloud Service which serves as a logical container.

```powershell
$cloudService = New-MXWAPackCloudService -Name MyMendixApp
```

Note that the Cloud Service name will be what is reflected in the portal and has to be unique within the subscription.

Now the Cloud Service has been created, the VM Role can be deployed to it.

```powershell
New-MXWAPackVMRoleDeployment -CloudService $cloudService -GalleryItem $gi -ParameterObject $params

odata.metadata        : https://spf01.wap.local:8090/SC2012R2/VMM/Microsoft.Management.Odata.svc/$metadata#VMRole/@Element
Name                  : MyMendixApp
Label                 : MyMendixApp
ResourceDefinition    : @{Name=MendixSingleInstance; Version=1.0.0.0; Publisher=Mendix; SchemaVersion=1.0; Type=Microsoft.Compute/VMRole/
                        1.0; ResourceParameters=System.Object[]; ResourceExtensionReferences=System.Object[]; IntrinsicSettings=}
ResourceConfiguration : @{Version=1.0.0.0; ParameterValues={"VMRoleVMSize":"Medium","VMRoleAdminCredential":"Administrator:__**__","VMRol
                        eComputerNamePattern":"Mendix###","VMRoleNetworkRef":"Tenant","VMRoleOSVirtualHardDiskImage":"Mendix:1.0.0.0"}}
ProvisioningState     : Provisioning
Substate              : @{VMRoleMessages=System.Object[]}
InstanceView          : @{VIPs=System.Object[]; InstanceCount=0; ResolvedResourceDefinition=}
```

From the resulting object you can see the ProvisioningState as 'Provisioning'. Once this state is changed, deployment is done or has failed for some reason.

To see the current state of the deployment you can quiry using ```Get-MXWAPackVMRole```.

```powershell
$cloudService  | Get-MXWAPackVMRole

Name                  : MyMendixApp
Label                 : MyMendixApp
ResourceDefinition    : @{Name=MendixSingleInstance; Version=1.0.0.0; Publisher=Mendix; SchemaVersion=1.0; Type=Microsoft.Compute/VMRole/
                        1.0; ResourceParameters=System.Object[]; ResourceExtensionReferences=System.Object[]; IntrinsicSettings=}
ResourceConfiguration : @{Version=1.0.0.0; ParameterValues={"VMRoleVMSize":"Medium","VMRoleAdminCredential":"Administrator:__**__","VMRol
                        eComputerNamePattern":"Mendix###","VMRoleNetworkRef":"Tenant","VMRoleOSVirtualHardDiskImage":"Mendix:1.0.0.0"}}
ProvisioningState     : Provisioned
Substate              : @{VMRoleMessages=System.Object[]}
InstanceView          : @{VIPs=System.Object[]; InstanceCount=0; ResolvedResourceDefinition=}
```

In this case the VM Role has been deployed succesfully.

If for some reason the deployment fails, you can check the reason by expanding the Substate property.

```powershell
$cloudService  | Get-MXWAPackVMRole | Select-Object -ExpandProperty Substate

VMRoleMessages
--------------
{@{VMId=; MessageQualifier=Error; Message=The job was stopped by the user *.}}
```

To see what VMs have been deployed as part of the VM Role deployment you can query using the ```Get-MXWAPackVMRoleVM``` function.

```powershell
$VMRole = $cloudService | Get-MXWAPackVMRole
$VMRole | Get-MXWAPackVMRoleVM

Id                 : c4befd2b-13a6-4cd4-a523-9cbdd7e10d89
ComputerName       : Mendix002
RuntimeState       : Running
ConnectToAddresses : {@{IPAddress=172.16.1.94; NetworkName=Tenant; Port=3389}, @{IPAddress=fe80::d0fc:df7:9cbf:e62; NetworkName=Tenant; P
                     ort=3389}, @{IPAddress=2001:828:13c8:200:d0fc:df7:9cbf:e62; NetworkName=Tenant; Port=3389}}
CloudServiceName   : MyMendixApp
```

You can extract the ip address to connect to the VM using RDP or PowerShell remoting. In this case we will look explicitly for an IPv4 address.

```powershell
$VMRole | Get-MXWAPackVMRoleVM | ForEach-Object -Process {
    $_.ConnectToAddresses.Where{
        [ipaddress]::Parse($_.IPAddress).AddressFamily -eq 'InterNetwork'
    }
}

IPAddress   NetworkName Port
---------   ----------- ----
172.16.1.94 Tenant      3389
```

Note that if the Azure Pack platform makes use of DHCP for IP assignment, it might require a refresh to occur before the information is available.

Example to interface with the VM using PowerShell remoting (this works for VM Roles that provision an SSL based WSMAN listener):

```powershell
$cred = [pscredential]::new('Administrator',(ConvertTo-SecureString 'Welkom01' -AsPlainText -Force))
$pssession = New-PSSession -ComputerName 172.16.1.94 -UseSSL -SessionOption (New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck) -Credential $cred
Invoke-Command -Session $pssession -ScriptBlock {
    $env:ComputerName
}

Mendix002
```

A VM Role can contain one or multiple VMs. To Stop a specific VM use the following example:

```powershell
$VMRole | Get-MXWAPackVMRoleVM | Where-Object -FilterScript { $_.ComputerName -eq 'Mendix002'} | Stop-MXWAPackVMRoleVM

# if the VM won't stop because of a freeze you can use the PowerOff switch
$VMRole | Get-MXWAPackVMRoleVM | Where-Object -FilterScript { $_.ComputerName -eq 'Mendix002'} | Stop-MXWAPackVMRoleVM -PowerOff
```

You can also start the VMs:

```powershell
$VMRole | Get-MXWAPackVMRoleVM | Start-MXWAPackVMRoleVM
```

Or restart them:

```powershell
$VMRole | Get-MXWAPackVMRoleVM | Restart-MXWAPackVMRoleVM
```

To Scale In / Out the amount of instances of a VM Role first check the current amount of VM instances that are provisioned.

```powershell
# check current instance count
$VMRole = Get-MXWAPackCloudService -Name MyMendixApp | Get-MXWAPackVMRole
$VMRole.InstanceView.InstanceCount

1
```

Next check the maximum amount that can be scaled up / down

```powershell
$VMRole.ResourceDefinition.IntrinsicSettings.ScaleOutSettings

InitialInstanceCount MaximumInstanceCount MinimumInstanceCount UpgradeDomainCount
-------------------- -------------------- -------------------- ------------------
1                    10                   1                    1
```

In this case there is 1 VM instance provisioned and it can be scaled out until 10 VM Instances.

Let's scale the VM Role out to 3 VM Instances:

```powershell
$VMRole = Get-MXWAPackCloudService -Name MyMendixApp | Get-MXWAPackVMRole
$VMRole | Invoke-MXWAPackVMRoleScaleAction -Action ScaleUp -Unit 2
```

And scale it down to 2 VM Instances:

```powershell
$VMRole = Get-MXWAPackCloudService -Name MyMendixApp | Get-MXWAPackVMRole
$VMRole | Invoke-MXWAPackVMRoleScaleAction -Action ScaleDown -Unit 1
```

\* Note that the VMRole variable is refreshed every time as it represents stale data and is not automatically updated.

It is possible that the deployment or scaling in / out action failed:

```powershell
$VMRole = Get-MXWAPackCloudService -Name MyMendixApp | Get-MXWAPackVMRole
$VMRole


Name                  : MyMendixApp
Label                 : MyMendixApp
ResourceDefinition    : @{Name=MendixSingleInstance; Version=1.0.0.0; Publisher=Mendix; SchemaVersion=1.0; Type=Microsoft.Compute/VMRole/1.0; ResourceParameters=System.Object[]; R
                        esourceExtensionReferences=System.Object[]; IntrinsicSettings=}
ResourceConfiguration : @{Version=1.0.0.0; ParameterValues={"VMRoleVMSize":"Small","VMRoleAdminCredential":"administrator:__**__","VMRoleComputerNamePattern":"Mendix###","VMRoleNe
                        tworkRef":"Tenant","VMRoleOSVirtualHardDiskImage":"Mendix:1.0.0.0"}}
ProvisioningState     : Failed
Substate              : @{VMRoleMessages=System.Object[]}
InstanceView          : @{VIPs=System.Object[]; InstanceCount=1; ResolvedResourceDefinition=}
```

In this case you can either remove the VM Role by deleting the Cloud Service and deploy again:

```powershell
Get-MXWAPackCloudService -Name MyMendixApp | Remove-MXWAPackCloudService

Confirm
Are you sure you want to perform this action?
Performing the operation "Remove-MXWAPackCloudService" on target "ben".
[Y] Yes [A] Yes to All [N] No [L] No to All [S] Suspend [?] Help (default is "Yes"):

# you can overwrite the confirmation inquiry
# Get-MXWAPackCloudService -Name MyMendixApp | Remove-MXWAPackCloudService -Confirm:$false
```

Or try to repair / retry the action:

```powershell
# this will skip the VM that failed and move on the the next VM if applicable
$VMRole | Repair-MXWAPackVMRole

# this will retry the VM that failed
$VMRole | Repair-MXWAPackVMRole -Retry
```

It is possible that a Repair is needed before an alternate action as Remove or Scale Up / Down can be executed.

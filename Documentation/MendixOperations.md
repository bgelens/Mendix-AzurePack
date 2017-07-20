# Mendix Remote Operations

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

## Work with already deployed Single Intance VM Role using the MXWAPack module

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

To find all VM Role deployments you need to enumare the Cloud Services hosting them first.

```powershell
Get-MXWAPackCloudService

Name              : Single01
Label             :
ProvisioningState : Provisioned
Owner             : @{UserName=john@doe.com; RoleName=john@doe.com_59853252-2e02-4484-bb79-4bd73d412a64; RoleID=59853252-2e02-4484-bb79-4bd73d412a64}
GrantedToList     : {}

Name              : MXSql01
Label             : MXSql01
ProvisioningState : Provisioned
Owner             : @{UserName=john@doe.com; RoleName=john@doe.com_59853252-2e02-4484-bb79-4bd73d412a64; RoleID=59853252-2e02-4484-bb79-4bd73d412a64}
GrantedToList     : {}
```

Once you find the Cloud Service created to host the Mendix VM Role, you can get the VM Role object from it.

```powershell
Get-MXWAPackCloudService -Name single01 | Get-MXWAPackVMRole


Name                  : Single01
Label                 : Single01
ResourceDefinition    : @{Name=MendixSingleInstance; Version=1.0.0.0; Publisher=Mendix; SchemaVersion=1.0; Type=Microsoft.Compute/VMRole/1.0; ResourceParameters=System.
                        Object[]; ResourceExtensionReferences=System.Object[]; IntrinsicSettings=}
ResourceConfiguration : @{Version=1.0.0.0; ParameterValues={"VMRoleVMSize":"Small","VMRoleAdminCredential":"administrator:__**__","VMRoleComputerNamePattern":"Mendix###
                        ","VMRoleNetworkRef":"Tenant","VMRoleOSVirtualHardDiskImage":"Mendix:1.0.0.0"}}
ProvisioningState     : Provisioned
Substate              : @{VMRoleMessages=System.Object[]}
InstanceView          : @{VIPs=System.Object[]; InstanceCount=1; ResolvedResourceDefinition=}
```

And from there, the VMs which are deployed as part of the VM Role can be enumerated.

```powershell
Get-MXWAPackCloudService -Name single01 | Get-MXWAPackVMRole | Get-MXWAPackVMRoleVM


Id                 : 110ae2d4-dbaa-4ea1-91c5-ea427268146f
ComputerName       : Mendix001
RuntimeState       : Running
ConnectToAddresses : {@{IPAddress=172.16.1.65; NetworkName=Tenant; Port=3389}, @{IPAddress=fe80::9f4:1160:2575:a176; NetworkName=Tenant; Port=3389}, @{IPAddress=2001:82
                     8:13c8:200:9f4:1160:2575:a176; NetworkName=Tenant; Port=3389}}
CloudServiceName   : Single01
```

To locate the IPv4 address of the VM, you can parse the returned object.

```powershell
$VMRole = Get-MXWAPackCloudService -Name single01 | Get-MXWAPackVMRole
$VMRole | Get-MXWAPackVMRoleVM | ForEach-Object -Process {
    $_.ConnectToAddresses.Where{
        [ipaddress]::Parse($_.IPAddress).AddressFamily -eq 'InterNetwork'
    }
}

IPAddress    NetworkName Port
---------    ----------- ----
172.16.1.65  Tenant      3389
```

>>Please note that the IPv4 address shown here is an "internal" ip address and the port displayed is the RDP port (which can be ignored as tcp 5986 is used for remote connectivity to the VM).
>>If you want to connect to the VM using this ip address, you need to be connected to that network.
>>Alternatively, if deployed in an Azure Pack environment using network virtualization, a PAT rule can be created for the VM so the port 5986 is exposed via a public IP.

Now you can run functions where the name starts with the noun ```MXWAPackMendixApp``` to manipulate the Mendix App / Services via the VMs address.
First run  ```Get-Credential``` (you need to enter the VMs administrator credentials) and capture the result in a variable.

```powershell
$cred = Get-Credential
````

To see what Applications are installed:

```powershell
Get-MXWAPackMendixApp -ComputerName 172.16.1.65 -Credential $cred

RuntimeVersion  : 6.8.1
ProjectID       : b63a43c3-6eef-4fa7-9dab-0518f7d62678
ProjectName     : FieldExampleaHold
ModelVersion    : 1.0.0.8
Description     :
AdminUser       : MxAdmin
Roles           : @{8dd52bfa-6d7e-453b-b506-303c0a3d9567=; 53f5d6fa-6da9-4a71-b011-454ec052cce8=}
AdminRole       : 8dd52bfa-6d7e-453b-b506-303c0a3d9567
Constants       : {@{Name=AdvanceGoogleMaps.BatchSize; Type=Integer; Description=Batch size would be the amount of elements allowed by
                  the Google Distance Matrix API.

                  At Time of Creation :

                  The free version allows for 100 elements in a query, the cap should be
                  set to 99. The queries will be made with one "origin" and 99 "destinations".

                  The business version allows for 625 elements in a query, the cap should be
                  set to 624. The queries will be made with one "origin" and 624 "destinations".; DefaultValue=99}}
ScheduledEvents : {}
Configuration   : @{SourceDatabaseType=HSQLDB; SourceDatabaseName=default; SourceBuiltInDatabasePath=model/sampledata/data/database}
RequestHandlers : {@{Name=/api/; DefaultEnabled=True; MatchExactly=False}, @{Name=/link/; DefaultEnabled=True; MatchExactly=False}, @{Name=/ws/; DefaultEnabled=True; MatchExactly=False}, @{Name=/ws-doc/; Defaul
                  tEnabled=False; MatchExactly=False}...}
PSComputerName  : 172.16.1.65
RunspaceId      : efa468a1-5f08-473a-8a69-acb6df2e7c6d
```

To see the MendixApp configuration:

```powershell
Get-MXWAPackMendixAppSettings -ComputerName 172.16.1.65 -Credential $cred

OtherVMArguments              :
RuntimeServerPortNumber       : 8080
AdminServerPortNumber         : 8090
AdminServerPassword           : Demo1234!
RuntimeServerListenAddresses  :
AdminServerListenAddresses    :
ApplicationRootUrl            :
ScheduledEventExecution       : ALL
RuntimeVersion                : 6.8.1
RawRuntimeVersion             : 6.8.1
ModelVersion                  : 1.0.0.8
AdminUserName                 : MxAdmin
CustomRuntimeSettings         : {}
ApplicationConstants          : {Mendix.M2EE.ApplicationConstant}
JettyRuntimeMaxThreads        :
JettyRuntimeMinThreads        :
JettyRequestHeaderSize        :
JettyResponseHeaderSize       :
JettySetStatsOn               : False
DatabaseType                  : POSTGRESQL
DatabaseHost                  : localhost
DatabaseName                  : local
DatabaseUserName              : postgres
DatabasePassword              : AQAAANCMnd8BFdERjHoAwE/Cl+sBAAAA3xoNNSejTku1G0jc75vL0wAAAAACAAAAAAAQZgAAAAEAACAAAADDrWCY38QsCcZiLlEAzwGmqAe6HOpuzJ8mT5oZ7PzptAAAAAAOgAAA
                                AAIAACAAAABbRPiuHJOQlP4B4O4S5haGPbrzWKItacp4xaJsxpd+xxAAAAD4ECWSgso7smuu7B6eU3KlQAAAANarvBB+0WT0rh2BWiAx44A0ZgzHYxbMqCzOIpuTNW951VFc2YwE
                                ixXOIrXKNPYsuECLCtSX8Uz8yauYiTgyPfU=
DatabaseUseIntegratedSecurity : False
ModelDateTime                 : 15-12-2016 10:56:47
Service                       : Mendix.M2EE.Service
```

To stop the app:

```powershell
Stop-MXWAPackMendixApp -ComputerName 172.16.1.65 -Credential $cred
```

To start the app:

```powershell
Start-MXWAPackMendixApp -ComputerName 172.16.1.65 -Credential $cred
```

To get details from a Mendix package to be installed:

```powershell
Get-MXWAPackMendixAppPackage -Path ~\Desktop\Downloads\FieldExampleaHold_1.0.0.6.mda

RuntimeVersion  : 6.8.0
ProjectID       : b63a43c3-6eef-4fa7-9dab-0518f7d62678
ProjectName     : FieldExampleaHold
ModelVersion    : 1.0.0.6
Description     :
AdminUser       : MxAdmin
Roles           : @{8dd52bfa-6d7e-453b-b506-303c0a3d9567=; 53f5d6fa-6da9-4a71-b011-454ec052cce8=}
AdminRole       : 8dd52bfa-6d7e-453b-b506-303c0a3d9567
Constants       : {@{Name=AdvanceGoogleMaps.BatchSize; Type=Integer; Description=Batch size would be the amount of elements allowed by
                  the Google Distance Matrix API.

                  At Time of Creation :

                  The free version allows for 100 elements in a query, the cap should be
                  set to 99. The queries will be made with one "origin" and 99 "destinations".

                  The business version allows for 625 elements in a query, the cap should be
                  set to 624. The queries will be made with one "origin" and 624 "destinations".; DefaultValue=99}}
ScheduledEvents : {}
Configuration   : @{SourceDatabaseType=HSQLDB; SourceDatabaseName=default; SourceBuiltInDatabasePath=model/sampledata/data/database}
RequestHandlers : {@{Name=/api/; DefaultEnabled=True; MatchExactly=False}, @{Name=/link/; DefaultEnabled=True; MatchExactly=False}, @{Name=/ws/; DefaultEnabled=True; MatchExactly=False}, @{Name=/ws-doc/; Defaul
                  tEnabled=False; MatchExactly=False}...}
```

To update the app:

```powershell
Update-MXWAPackMendixApp -ComputerName 172.16.1.65 -Credential $cred -Path ~\Desktop\Downloads\FieldExampleaHold_1.0.0.8.mda
```

To check what Runtime versions are installed:

```powershell
Get-MXWAPackInstalledServerPackage -ComputerName 172.16.1.65 -Credential $cred

6.10.2
6.8.1
```

To install a newer Runtime version:

```powershell
Install-MXWAPackServerPackage -ComputerName 172.16.1.65 -Credential $cred -Path ~\Desktop\Downloads\mendix-6.8.1.tar.gz -Verbose
```

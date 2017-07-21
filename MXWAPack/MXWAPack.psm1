# module classes
Add-Type -TypeDefinition @'
using System;
using System.Security.Cryptography.X509Certificates;

namespace MXWAPack
{
    public class PublishSettingSubscription
    {
        public string ServiceManagementUrl { get; set; }
        public string Id { get; set; }
        public string Name { get; set; }
        public string ManagementCertificate { get; set; }
        public X509Certificate2 Certificate
        {
            get
            {
                return new X509Certificate2(Convert.FromBase64String(this.ManagementCertificate));
            }
        }

        public PublishSettingSubscription (string serviceManagementUrl, string id, string name, string managementCertificate)
        {
            this.ServiceManagementUrl = serviceManagementUrl;
            this.Id = id;
            this.Name = name;
            this.ManagementCertificate = managementCertificate;
        }
    }
}
'@

# module vars
$publishSettingFileContent = $null
$selectedSubscription = $null

# main functions
function Import-MXWAPackPublishSettingFile {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript( {(Test-Path -Path $_) -and ($_.split('.')[-1] -eq 'publishsettings')})]
        [string] $Path
    )
    $publishSettings = [xml](Get-Content -Path $Path)
    $script:publishSettingFileContent = $publishSettings.PublishData.PublishProfile.Subscription
}

function Get-MXWAPackPublishSettingSubscription {
    [cmdletbinding(DefaultParameterSetName = 'List')]
    param (
        [Parameter(ParameterSetName = 'Name')]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(ParameterSetName = 'Id')]
        [Alias('SubscriptionId')]
        [guid] $Id
    )

    PreFlight

    $script:publishSettingFileContent | ForEach-Object -Process {
        if ($PSBoundParameters.ContainsKey('Name') -and $_.Name -ne $Name) {
            return
        }

        if ($PSBoundParameters.ContainsKey('Id') -and $_.Id -ne $Id) {
            return
        }

        New-Object -TypeName MXWAPack.PublishSettingSubscription -ArgumentList @(
            $_.ServiceManagementUrl,
            $_.Id,
            $_.Name,
            $_.ManagementCertificate
        )
    }
}

function Select-MXWAPackPublishSettingSubscription {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [MXWAPack.PublishSettingSubscription] $Subscription
    )
    if ($Input.Count -gt 1) {
        Write-Error -Message 'Only 1 Subscription can be selected. Make sure only 1 subscription is passed to this function.' -ErrorAction Stop
    }
    $script:selectedSubscription = $Subscription
}

function Get-MXWAPackCloudService {
    [cmdletbinding(DefaultParameterSetName = 'List')]
    param (
        [Parameter(ParameterSetName = 'Name')]
        [ValidateNotNullOrEmpty()]
        [string] $Name
    )
    PreFlight -IncludeSubscription

    $cloudServices = InvokeAPICall -PartialUri '/CloudServices'

    foreach ($c in $cloudServices) {
        if ($PSBoundParameters.ContainsKey('Name') -and $c.Name -ne $Name) {
            continue
        }
        $c.PSObject.TypeNames.Insert(0,'MXWAPack.CloudService')
        $c
    }
}

function Remove-MXWAPackCloudService {
    [cmdletbinding(ConfirmImpact='High', SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [System.Management.Automation.PSTypeName('MXWAPack.CloudService')] $CloudService
    )
    begin {
        PreFlight -IncludeSubscription
    } process {
        if ($PSCmdlet.ShouldProcess($CloudService.Name)) {
            InvokeAPICall -Method Delete -PartialUri ('/CloudServices/{0}' -f $CloudService.Name)
        }
    }
}

function New-MXWAPackCloudService {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name
    )

    PreFlight -IncludeSubscription

    $body = @{
        Name  = $Name
        Label = $Name
    } | ConvertTo-Json -Compress

    $cloudService = InvokeAPICall -Method Post -Body $body -PartialUri '/CloudServices'
    $cloudService.PSObject.Properties.Remove('odata.metadata')
    $cloudService.PSObject.TypeNames.Insert(0, 'MXWAPack.CloudService')
    $cloudService
}

function Get-MXWAPackVMRole {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [System.Management.Automation.PSTypeName('MXWAPack.CloudService')] $CloudService
    )
    begin {
        PreFlight -IncludeSubscription
    } process {
        $VMRole = InvokeAPICall -PartialUri ('/CloudServices/{0}/Resources/MicrosoftCompute/VMRoles' -f $CloudService.Name)
        $VMRole.PSObject.TypeNames.Insert(0, 'MXWAPack.VMRole')
        $VMRole
    }
}

function Get-MXWAPackGalleryItem {
    [cmdletbinding(DefaultParameterSetName = 'List')]
    param (
        [Parameter(ParameterSetName = 'Name')]
        [ValidateNotNullOrEmpty()]
        [string] $Name
    )

    PreFlight -IncludeSubscription

    $galleryItems = InvokeAPICall -PartialUri '/Gallery/GalleryItems/$/MicrosoftCompute.VMRoleGalleryItem'
    foreach ($g in $galleryItems) {
        if ($PSBoundParameters.ContainsKey('Name') -and $g.Name -ne $Name) {
            continue
        }
        $resDef = InvokeAPICall -PartialUri "/$($g.ResourceDefinitionUrl)/"
        $viewDef = InvokeAPICall -PartialUri "/$($g.ViewDefinitionUrl)/"

        Add-Member -InputObject $g -MemberType NoteProperty -Name ResDef -Value $resDef
        Add-Member -InputObject $g -MemberType NoteProperty -Name ViewDef -Value $viewDef

        $g.PublishDate = [datetime]$g.PublishDate
        $g.PSObject.TypeNames.Insert(0, 'MXWAPack.GalleryItem')
        $g
    }
}

function New-MXWAPackGalleryItemParameterObject {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [System.Management.Automation.PSTypeName('MXWAPack.GalleryItem')] $GalleryItem
    )
    $ht = @{
        PSTypeName = 'MXWAPack.GalleryItemParameterObject'
    }
    $GalleryItem.ViewDef.ViewDefinition.Sections.Categories.Parameters.foreach{
        if ($_.DefaultValue) {
            $ht.Add($_.Name, $_.DefaultValue)
        } else {
            $ht.Add($_.Name, [string]::Empty)
        }
    }
    [pscustomobject]$ht
}

function New-MXWAPackVMRoleDeployment {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory)]
        [System.Management.Automation.PSTypeName('MXWAPack.CloudService')] $CloudService,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSTypeName('MXWAPack.GalleryItem')] $GalleryItem,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSTypeName('MXWAPack.GalleryItemParameterObject')] $ParameterObject
    )

    $resDefConfig = New-Object -TypeName 'System.Collections.Generic.Dictionary[String,Object]'
    $resDefConfig.Add('Version',$GalleryItem.Version)
    $resDefConfig.Add('ParameterValues',($ParameterObject | ConvertTo-Json))

    $body = @{
        InstanceView = $null
        Substate = $null
        Name = $CloudService.Name
        Label = $CloudService.Name
        ProvisioningState = $null
        ResourceConfiguration = $resDefConfig
        ResourceDefinition = $GalleryItem.ResDef
    } | ConvertTo-Json -Depth 20

    $deploy = InvokeAPICall -Method Post -Body $body -PartialUri ('/CloudServices/{0}/Resources/MicrosoftCompute/VMRoles/' -f $CloudService.Name)
    $deploy.PSObject.TypeNames.Insert(0, 'MXWAPack.VMRole')
    $deploy
}

function Get-MXWAPackVMRoleVM {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'CloudService')]
        [System.Management.Automation.PSTypeName('MXWAPack.CloudService')] $CloudService,

        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'VMRole')]
        [System.Management.Automation.PSTypeName('MXWAPack.VMRole')] $VMRole
    )

    if ($PSBoundParameters.ContainsKey('CloudService')) {
        $name = $CloudService.Name
    } else {
        $name = $VMRole.Name
    }

    $vms = InvokeAPICall -PartialUri ('/CloudServices/{0}/Resources/MicrosoftCompute/VMRoles/{0}/VMs' -f $name)
    foreach ($v in $vms) {
        $v.PSObject.TypeNames.Insert(0, 'MXWAPack.VMRoleVM')
        $v | Add-Member -Name CloudServiceName -MemberType NoteProperty -Value $name
        $v
    }

}

function Get-MXWAPackVMNetwork {
    [cmdletbinding(DefaultParameterSetName = 'List')]
    param (
        [Parameter(Mandatory, ParameterSetName = 'Name')]
        [ValidateNotNullOrEmpty()]
        [string] $Name
    )

    PreFlight -IncludeSubscription

    $vmNetworks = InvokeAPICall -PartialUri '/services/systemcenter/vmm/VMNetworks' -ExcludeAPI

    foreach ($v in $vmNetworks) {
        if ($PSBoundParameters.ContainsKey('Name') -and $v.Name -ne $Name) {
            continue
        }
        $v.PSObject.TypeNames.Insert(0,'MXWAPack.VMNetwork')
        $v
    }
}

function Get-MXWAPackVMRoleSizeProfile {
    [cmdletbinding(DefaultParameterSetName = 'List')]
    param (
        [Parameter(Mandatory, ParameterSetName = 'Name')]
        [ValidateNotNullOrEmpty()]
        [String] $Name
    )

    PreFlight -IncludeSubscription

    $sizeProfiles = InvokeAPICall -PartialUri '/services/systemcenter/vmm/VMRoleSizeProfiles' -ExcludeAPI
    foreach ($s in $sizeProfiles) {
        if ($PSBoundParameters.ContainsKey('Name') -and $s.Name -ne $Name) {
            continue
        }
        $s.PSObject.TypeNames.Insert(0,'MXWAPack.VMRoleSizeProfile')
        $s
    }
}

function Start-MXWAPackVMRoleVM {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [System.Management.Automation.PSTypeName('MXWAPack.VMRoleVM')] $VMRoleVM
    )

    process {
        InvokeAPICall -PartialUri ('/CloudServices/{0}/Resources/MicrosoftCompute/VMRoles/{0}/VMs/{1}/Start' -f $VMRoleVM.CloudServiceName, $VMRoleVM.Id) -Method Post
    }
}

function Stop-MXWAPackVMRoleVM {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [System.Management.Automation.PSTypeName('MXWAPack.VMRoleVM')] $VMRoleVM,

        [switch] $PowerOff
    )

    process {
        if ($PowerOff) {
            $action = 'Stop'
        } else {
            $action = 'Shutdown'
        }
        InvokeAPICall -PartialUri ('/CloudServices/{0}/Resources/MicrosoftCompute/VMRoles/{0}/VMs/{1}/{2}' -f $VMRoleVM.CloudServiceName, $VMRoleVM.Id, $action) -Method Post
    }
}

function Restart-MXWAPackVMRoleVM {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [System.Management.Automation.PSTypeName('MXWAPack.VMRoleVM')] $VMRoleVM
    )

    process {
        InvokeAPICall -PartialUri ('/CloudServices/{0}/Resources/MicrosoftCompute/VMRoles/{0}/VMs/{1}/Restart' -f $VMRoleVM.CloudServiceName, $VMRoleVM.Id) -Method Post
    }
}

function Invoke-MXWAPackVMRoleScaleAction {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [System.Management.Automation.PSTypeName('MXWAPack.VMRole')] $VMRole,

        [Parameter()]
        [ValidateSet('ScaleUp', 'ScaleDown')]
        [string] $Action = 'ScaleUp',

        [Parameter()]
        [uint16] $Unit = 1
    )

    $scaleProperties = $VMRole.ResourceDefinition.IntrinsicSettings.ScaleOutSettings

    $currentInstanceCount = $VMRole.InstanceView.InstanceCount -as [uint16]

    if ($Action -eq 'ScaleUp') {
        if ($currentInstanceCount -eq [uint16]$scaleProperties.MaximumInstanceCount) {
            Write-Error -Message ('Cannot Scale Up as Maximum instances {0} are already in place' -f $scaleProperties.MaximumInstanceCount) -ErrorAction stop
        }
        if ($currentInstanceCount + $Unit -gt [uint16]$scaleProperties.MaximumInstanceCount) {
            Write-Error -Message ('Cannot Scale Up by {0} units as this would breach the Maximum allowed instance count {1}' -f $Unit, $scaleProperties.MaximumInstanceCount) -ErrorAction stop
        }
        $body = @{
            InstanceCount = $currentInstanceCount + $Unit
        } | ConvertTo-Json
    } else {
        if ($currentInstanceCount -eq [uint16]$scaleProperties.MinimumInstanceCount) {
            Write-Error -Message ('Cannot Scale Down as the current amount of instances {0} is the Minimum amount' -f $currentInstanceCount) -ErrorAction stop
        }
        if ($currentInstanceCount - $Unit -lt [uint16]$scaleProperties.MinimumInstanceCount) {
            Write-Error -Message ('Cannot Scale Down by {0} units as this would breach the Minimum allowed instance count {1}' -f $Unit, $scaleProperties.MinimumInstanceCount) -ErrorAction stop
        }
        $body = @{
            InstanceCount = $currentInstanceCount - $Unit
        } | ConvertTo-Json
    }
    InvokeAPICall -PartialUri ('/CloudServices/{0}/Resources/MicrosoftCompute/VMRoles/{0}/Scale' -f $VMRole.Name) -Method Post -Body $body
}

function Repair-MXWAPackVMRole {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [System.Management.Automation.PSTypeName('MXWAPack.VMRole')] $VMRole,

        [switch] $Retry
    )

    if ($Retry) {
        $body = @{
            Skip = $false
        } | ConvertTo-Json
    } else {
        $body = @{
            Skip = $true
        } | ConvertTo-Json
    }

    InvokeAPICall -PartialUri ('/CloudServices/{0}/Resources/MicrosoftCompute/VMRoles/{0}/Repair' -f $VMRole.Name) -Method Post -Body $body
}

function Get-MXWAPackVMRoleOSDisk {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [System.Management.Automation.PSTypeName('MXWAPack.GalleryItem')] $GalleryItem
    )
    begin {
        $disks = InvokeAPICall -PartialUri '/services/systemcenter/vmm/VirtualHardDisks' -ExcludeAPI
    } process {
        $osDisk = $GalleryItem.ViewDef.ViewDefinition.Sections.Categories.Parameters.Where{$_.Type -eq 'OSVirtualHardDisk'}
        foreach ($d in $disks) {
            $diskTags = $d.Tag
            $compareTags = Compare-Object -ReferenceObject $diskTags -DifferenceObject $osDisk.ImageTags -IncludeEqual -ExcludeDifferent -PassThru
            if ($null -ne $compareTags) {
                if ($null -eq (Compare-Object -ReferenceObject $CompareTags -DifferenceObject $osDisk.ImageTags -PassThru)) {
                    if ($d.enabled -eq $false) {
                        continue
                    }
                    $d.AddedTime = [datetime] $d.AddedTime
                    $d.ModifiedTime = [datetime] $d.ModifiedTime
                    $d.ReleaseTime = [datetime] $d.ReleaseTime
                    $d.PSObject.TypeNames.Insert(0,'MXWAPack.VMRoleOSDisk')
                    Write-Output -InputObject $d
                } else {
                    continue
                }
            }
        }
    }
}

function Install-MXWAPackServerPackage {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Alias('IPAddress')]
        [string[]] $ComputerName,

        [Parameter(Mandatory)]
        [pscredential] 
        [System.Management.Automation.CredentialAttribute()] $Credential,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({(Test-Path -Path $_) -and ($_.Split('.')[-1] -eq 'gz')})]
        [string] $Path,

        [switch] $UseUnencryptedConnection
    )
    process {
        foreach ($c in $ComputerName) {
            $sessionArgs = @{
                ComputerName = $c
                Credential =  $Credential
            }
            if (!$UseUnencryptedConnection) {
                [void] $sessionArgs.Add('UseSSL', $true)
                [void] $sessionArgs.Add('SessionOption', (New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck))
            }

            try {
                $resolvedPath = (Resolve-Path -Path $Path).ToString()
                $psSession = New-PSSession @sessionArgs -ErrorAction Stop
                $fileName = $resolvedPath.Split('\')[-1]
                $tempDir = Invoke-Command -Session $psSession -ScriptBlock { $env:Temp }
                Copy-Item -ToSession $psSession -Path $resolvedPath -Destination $tempDir\$fileName -Force
                Invoke-Command -Session $psSession -ScriptBlock {
                    Import-Module -Name 'C:\Program Files (x86)\Mendix\Service Console\Mendix.Service.Commands.dll'
                    $packagePath = (Resolve-Path $env:Temp\$using:fileName).ToString()
                    Install-MxServer -LiteralPath $packagePath
                    Remove-Item -Path $packagePath -Force
                }
            } catch {
                Write-Error -ErrorRecord $_ -ErrorAction Continue
            } finally {
                if ($null -ne $psSession) {
                    $psSession | Remove-PSSession
                }
            }
        }
    }
}

function Get-MXWAPackInstalledServerPackage {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Alias('IPAddress')]
        [string[]] $ComputerName,

        [Parameter(Mandatory)]
        [pscredential] 
        [System.Management.Automation.CredentialAttribute()] $Credential
    )
    process {
        foreach ($c in $ComputerName) {
            $sessionArgs = @{
                ComputerName = $c
                Credential =  $Credential
            }
            if (!$UseUnencryptedConnection) {
                [void] $sessionArgs.Add('UseSSL', $true)
                [void] $sessionArgs.Add('SessionOption', (New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck))
            }

            try {
                $psSession = New-PSSession @sessionArgs -ErrorAction Stop
                Invoke-Command -Session $psSession -ScriptBlock {
                    Add-Type -Path 'C:\Program Files (x86)\Mendix\Service Console\Mendix.Service.Management.dll'
                    $instance = [Mendix.Service.Management.ApplicationManagerSettings]::Instance
                    Get-ChildItem -Path $instance.ServersPath | ForEach-Object -Process {
                        [string] $_.Name
                    }
                }
            } catch {
                Write-Error -ErrorRecord $_ -ErrorAction Continue
            } finally {
                if ($null -ne $psSession) {
                    $psSession | Remove-PSSession
                }
            }
        }
    }
}

function Get-MXWAPackMendixServerLicenseInfo {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Alias('IPAddress')]
        [string] $ComputerName,

        [Parameter(Mandatory)]
        [pscredential] 
        [System.Management.Automation.CredentialAttribute()] $Credential
    )
    process {
        foreach ($c in $ComputerName) {
            $sessionArgs = @{
                ComputerName = $c
                Credential =  $Credential
            }
            if (!$UseUnencryptedConnection) {
                [void] $sessionArgs.Add('UseSSL', $true)
                [void] $sessionArgs.Add('SessionOption', (New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck))
            }

            try {
                $psSession = New-PSSession @sessionArgs -ErrorAction Stop
                Invoke-Command -Session $psSession -ScriptBlock {
                    Add-Type -Path 'C:\Program Files (x86)\Mendix\Service Console\Mendix.M2EE.dll'
                    Add-Type -Path 'C:\Program Files (x86)\Mendix\Service Console\Mendix.Service.Management.dll'
                    $instance = [Mendix.Service.Management.ApplicationManagerSettings]::Instance
                    $settings = [Mendix.M2EE.Settings]::GetInstances($instance.AppsPath,$instance.MdsGuid,$instance.ServersPath)
                    $client = New-Object -TypeName Mendix.M2EE.M2EEClient -ArgumentList @(
                        [version]"1.0.0",
                        "http://localhost:$($settings.AdminServerPortNumber)/",
                        $settings.AdminServerPassword
                    )
                    $client.GetLicenseInfo()
                }
            } catch {
                Write-Error -ErrorRecord $_ -ErrorAction Continue
            } finally {
                if ($null -ne $psSession) {
                    $psSession | Remove-PSSession
                }
            }
        }
    }
}

function Set-MXWAPackMendixServerLicense {
[cmdletbinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Alias('IPAddress')]
        [string] $ComputerName,

        [Parameter(Mandatory)]
        [pscredential] 
        [System.Management.Automation.CredentialAttribute()] $Credential,

        [Parameter()]
        [string] $NewServerKey,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $License
    )
    process {
        foreach ($c in $ComputerName) {
            $sessionArgs = @{
                ComputerName = $c
                Credential =  $Credential
            }
            if (!$UseUnencryptedConnection) {
                [void] $sessionArgs.Add('UseSSL', $true)
                [void] $sessionArgs.Add('SessionOption', (New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck))
            }

            try {
                $psSession = New-PSSession @sessionArgs -ErrorAction Stop
                Invoke-Command -Session $psSession -ScriptBlock {
                    Add-Type -Path 'C:\Program Files (x86)\Mendix\Service Console\Mendix.M2EE.dll'
                    Add-Type -Path 'C:\Program Files (x86)\Mendix\Service Console\Mendix.Service.Management.dll'
                    $instance = [Mendix.Service.Management.ApplicationManagerSettings]::Instance
                    $settings = [Mendix.M2EE.Settings]::GetInstances($instance.AppsPath,$instance.MdsGuid,$instance.ServersPath)
                    
                    $client = New-Object -TypeName Mendix.M2EE.M2EEClient -ArgumentList @(
                        [version]"1.0.0",
                        "http://localhost:$($settings.AdminServerPortNumber)/",
                        $settings.AdminServerPassword
                    )

                    # trigger get first so license file content is written to disk
                    $null = $client.GetLicenseInfo()

                    if ($using:NewServerKey) {
                        $licSettingsFile = Get-ChildItem -Path "$env:ProgramData\Mendix\MDS\$($instance.MdsGuid)"
                        $settingsContent = Get-Content $licSettingsFile.FullName
                        $oldId = ($settingsContent | Select-String -Pattern "id:").ToString().Split(':')[-1].Trim()
                        if ($oldId -ne $using:NewServerKey) {
                            Import-Module -Name 'C:\Program Files (x86)\Mendix\Service Console\Mendix.Service.Commands.dll'
                            $null = Stop-MxApp -Name MendixApp
                            $null = New-Item -Path $licSettingsFile.PSParentPath -Name backup -ItemType Directory -Force
                            if (!(Test-Path -Path "$($licSettingsFile.PSParentPath)\backup")) {
                                $null = New-Item -Path "$($licSettingsFile.PSParentPath)\backup" -Name ([datetime]::Now).ToString('MMddyyhhmmss') -Value $oldId.ToString()
                            }
                            $settingsContent = $settingsContent.Replace($oldId, $using:NewServerKey)
                            $settingsContent | Out-File -FilePath $licSettingsFile.FullName -Encoding utf8 -Force
                            $null = Start-MxApp -Name MendixApp
                        }
                    }

                    $client.SetLicenseKey(($using:License).Trim())
                }
            } catch {
                Write-Error -ErrorRecord $_ -ErrorAction Continue
            } finally {
                if ($null -ne $psSession) {
                    $psSession | Remove-PSSession
                }
            }
        }
    }
}

function Start-MXWAPackMendixApp {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Alias('IPAddress')]
        [string[]] $ComputerName,

        [Parameter(Mandatory)]
        [pscredential] 
        [System.Management.Automation.CredentialAttribute()] $Credential
    )
    process {
        foreach ($c in $ComputerName) {
            $sessionArgs = @{
                ComputerName = $c
                Credential =  $Credential
            }
            if (!$UseUnencryptedConnection) {
                [void] $sessionArgs.Add('UseSSL', $true)
                [void] $sessionArgs.Add('SessionOption', (New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck))
            }

            try {
                $psSession = New-PSSession @sessionArgs -ErrorAction Stop
                Invoke-Command -Session $psSession -ScriptBlock {
                    Import-Module -Name 'C:\Program Files (x86)\Mendix\Service Console\Mendix.Service.Commands.dll'
                    $null = Start-MxApp -Name MendixApp
                }
            } catch {
                Write-Error -ErrorRecord $_ -ErrorAction Continue
            } finally {
                if ($null -ne $psSession) {
                    $psSession | Remove-PSSession
                }
            }
        }
    }
}

function Stop-MXWAPackMendixApp {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Alias('IPAddress')]
        [string[]] $ComputerName,

        [Parameter(Mandatory)]
        [pscredential] 
        [System.Management.Automation.CredentialAttribute()] $Credential
    )
    process {
        foreach ($c in $ComputerName) {
            $sessionArgs = @{
                ComputerName = $c
                Credential =  $Credential
            }
            if (!$UseUnencryptedConnection) {
                [void] $sessionArgs.Add('UseSSL', $true)
                [void] $sessionArgs.Add('SessionOption', (New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck))
            }

            try {
                $psSession = New-PSSession @sessionArgs -ErrorAction Stop
                Invoke-Command -Session $psSession -ScriptBlock {
                    Import-Module -Name 'C:\Program Files (x86)\Mendix\Service Console\Mendix.Service.Commands.dll'
                    $null = Stop-MxApp -Name MendixApp
                }
            } catch {
                Write-Error -ErrorRecord $_ -ErrorAction Continue
            } finally {
                if ($null -ne $psSession) {
                    $psSession | Remove-PSSession
                }
            }
        }
    }
}

function Get-MXWAPackMendixAppSettings {
     [cmdletbinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Alias('IPAddress')]
        [string[]] $ComputerName,

        [Parameter(Mandatory)]
        [pscredential] 
        [System.Management.Automation.CredentialAttribute()] $Credential
    )
    process {
        foreach ($c in $ComputerName) {
            $sessionArgs = @{
                ComputerName = $c
                Credential =  $Credential
            }
            if (!$UseUnencryptedConnection) {
                [void] $sessionArgs.Add('UseSSL', $true)
                [void] $sessionArgs.Add('SessionOption', (New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck))
            }

            try {
                $psSession = New-PSSession @sessionArgs -ErrorAction Stop
                Invoke-Command -Session $psSession -ScriptBlock {
                    Add-Type -Path 'C:\Program Files (x86)\Mendix\Service Console\Mendix.Service.Management.dll'
                    $instance = [Mendix.Service.Management.ApplicationManagerSettings]::Instance
                    [Mendix.M2EE.Settings]::GetInstances($instance.AppsPath,$instance.MdsGuid,$instance.ServersPath)
                }
            } catch {
                Write-Error -ErrorRecord $_ -ErrorAction Continue
            } finally {
                if ($null -ne $psSession) {
                    $psSession | Remove-PSSession
                }
            }
        }
    }
}

function Get-MXWAPackMendixApp {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Alias('IPAddress')]
        [string[]] $ComputerName,

        [Parameter(Mandatory)]
        [pscredential] 
        [System.Management.Automation.CredentialAttribute()] $Credential
    )
    process {
        foreach ($c in $ComputerName) {
            $sessionArgs = @{
                ComputerName = $c
                Credential =  $Credential
            }
            if (!$UseUnencryptedConnection) {
                [void] $sessionArgs.Add('UseSSL', $true)
                [void] $sessionArgs.Add('SessionOption', (New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck))
            }

            try {
                $psSession = New-PSSession @sessionArgs -ErrorAction Stop
                Invoke-Command -Session $psSession -ScriptBlock {
                    Add-Type -Path 'C:\Program Files (x86)\Mendix\Service Console\Mendix.Service.Management.dll'
                    $instance = [Mendix.Service.Management.ApplicationManagerSettings]::Instance
                    $apps = Get-ChildItem -Path $instance.AppsPath
                    foreach ($a in $apps) {
                        $metaData = "$($a.FullName)\Project\model\metadata.json"
                        if (Test-Path -Path $metaData) {
                            Get-Content -Path $metaData | ConvertFrom-Json
                        }
                    }
                }
            } catch {
                Write-Error -ErrorRecord $_ -ErrorAction Continue
            } finally {
                if ($null -ne $psSession) {
                    $psSession | Remove-PSSession
                }
            }
        }
    }
}
function Update-MXWAPackMendixApp {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Alias('IPAddress')]
        [string[]] $ComputerName,

        [Parameter(Mandatory)]
        [pscredential] 
        [System.Management.Automation.CredentialAttribute()] $Credential,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
            (Test-Path -Path $_) -and
            ($_.Split('.')[-1] -eq 'mda') -and
            (TestMendixPackage -Path $_)
        })]
        [string] $Path,

        [switch] $UseUnencryptedConnection,

        [switch] $SynchronizeDatabase
    )
    process {
        foreach ($c in $ComputerName) {
            $sessionArgs = @{
                ComputerName = $c
                Credential =  $Credential
            }
            if (!$UseUnencryptedConnection) {
                [void] $sessionArgs.Add('UseSSL', $true)
                [void] $sessionArgs.Add('SessionOption', (New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck))
            }

            try {
                $resolvedPath = (Resolve-Path -Path $Path).ToString()
                $psSession = New-PSSession @sessionArgs -ErrorAction Stop
                $fileName = $resolvedPath.Split('\')[-1]
                $tempDir = Invoke-Command -Session $psSession -ScriptBlock { $env:Temp }
                Copy-Item -ToSession $psSession -Path $resolvedPath -Destination $tempDir\$fileName -Force
                Invoke-Command -Session $psSession -ScriptBlock {
                    Import-Module -Name 'C:\Program Files (x86)\Mendix\Service Console\Mendix.Service.Commands.dll'
                    $packagePath = (Resolve-Path $env:Temp\$using:fileName).ToString()
                    $null = Stop-MxApp -Name MendixApp
                    if ($using:SynchronizeDatabase) {
                        $null = Update-MxApp -LiteralPath $packagePath -Name MendixApp |
                            Start-MxApp -SynchronizeDatabase
                    } else {
                        $null = Update-MxApp -LiteralPath $packagePath -Name MendixApp |
                            Start-MxApp
                    }
                    Remove-Item -Path $packagePath -Force
                }
            } catch {
                Write-Error -ErrorRecord $_ -ErrorAction Continue
            } finally {
                if ($null -ne $psSession) {
                    $psSession | Remove-PSSession
                }
            }
        }
    }
}

function Get-MXWAPackMendixAppPackage {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
            (Test-Path -Path $_) -and
            ($_.Split('.')[-1] -eq 'mda') -and
            (TestMendixPackage -Path $_)
        })]
        [string] $Path
    )
    $resolvedPath = (Resolve-Path -Path $Path).ToString()
    $fileGuid = [guid]::NewGuid().Guid
    $manifestFile = [io.compression.zipfile]::OpenRead($resolvedPath).Entries |
        Where-Object -FilterScript {$_.FullName -eq 'model/metadata.json'}
    [System.IO.Compression.ZipFileExtensions]::ExtractToFile($manifestFile, "$env:TEMP\$fileGuid.json", $true)
    try {
        Get-Content -Path $env:TEMP\$fileGuid.json | ConvertFrom-Json
    } finally {
        Remove-Item -Path $env:TEMP\$fileGuid.json -ErrorAction SilentlyContinue
    }
}

function Add-MXWAPackSSLBinding {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Alias('IPAddress')]
        [string[]] $ComputerName,

        [Parameter(Mandatory)]
        [pscredential] 
        [System.Management.Automation.CredentialAttribute()] $Credential,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
            (Test-Path -Path $_) -and
            ($_.Split('.')[-1] -eq 'pfx')
        })]
        [string] $Path,

        [Parameter(Mandatory)]
        [securestring] $Pin,

        [switch] $TryImportTrustChain,

        [switch] $UseUnencryptedConnection
    )
    process {
        foreach ($c in $ComputerName) {
            $sessionArgs = @{
                ComputerName = $c
                Credential =  $Credential
            }
            if (!$UseUnencryptedConnection) {
                [void] $sessionArgs.Add('UseSSL', $true)
                [void] $sessionArgs.Add('SessionOption', (New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck))
            }

            $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($pinging)
            $plainTextPin = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)

            try {
                $resolvedPath = (Resolve-Path -Path $Path).ToString()

                # first check pfx is valid, throw if not
                $certCollection = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Certificate2Collection
                $certCollection.Import(
                    $resolvedPath,
                    $plainTextPin,
                    [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::PersistKeySet
                )

                if ($certCollection.Count -eq 0) {
                    Write-Error -Message 'PFX is either invalid or doesn''t include any certificates' -ErrorAction Stop
                }

                $psSession = New-PSSession @sessionArgs -ErrorAction Stop
                $fileName = $resolvedPath.Split('\')[-1]
                $tempDir = Invoke-Command -Session $psSession -ScriptBlock { $env:Temp }
                Copy-Item -ToSession $psSession -Path $resolvedPath -Destination $tempDir\$fileName -Force
                Invoke-Command -Session $psSession -ScriptBlock {
                    $pfxPath = (Resolve-Path $env:Temp\$using:fileName).ToString()

                    if ($using:TryImportTrustChain) {
                        function ImportCertPublicKey {
                            param (
                                [Parameter(Mandatory)]
                                [System.Security.Cryptography.X509Certificates.X509Certificate2] $Certificate,

                                [Parameter()]
                                [ValidateSet('CA', 'Root')]
                                [string] $Store
                            )
                            try {
                                $certGuid = [guid]::NewGuid().Guid
                                $certByteArray = $Certificate.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)
                                [System.IO.File]::WriteAllBytes("$env:TEMP\$certGuid.cer",$certByteArray)
                                $null = Import-Certificate -FilePath "$env:TEMP\$certGuid.cer" -CertStoreLocation Cert:\LocalMachine\$Store
                            } finally {
                                $null = Remove-Item -Path "$env:TEMP\$certGuid.cer" -ErrorAction SilentlyContinue
                            }
                        }

                        $certCollection = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Certificate2Collection
                        $certCollection.Import(
                            $pfxPath,
                            $using:plainTextPin,
                            [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::PersistKeySet
                        )

                        if ($CertCollection.Count -eq 2) {
                            ImportCertPublicKey -Certificate $certCollection[0] -Store Root
                        } elseif ($certCollection.Count -gt 2) {
                            ImportCertPublicKey -Certificate $certCollection[-2] -Store Root
                            $maxIndex = $certCollection.Count - 2
                            for ($i = 0; $i -lt $maxIndex; $i++) {
                                ImportCertPublicKey -Certificate $certCollection[$i] -Store CA
                            }
                        } elseif ($certCollection[-1].Issuer -eq $certCollection[-1].Subject) {
                            ImportCertPublicKey -Certificate $certCollection[-1] -Store Root
                        }
                    }

                    $certImportArgs = @{
                        FilePath = $pfxPath
                        Password = ConvertTo-SecureString -String $using:plainTextPin -AsPlainText -Force
                        CertStoreLocation = 'Cert:\LocalMachine\My'
                    }
                    $cert = Import-PfxCertificate  @CertImportArgs

                    Import-Module -Name WebAdministration
                    $currentSSLBinding = Get-WebBinding -Name MendixApp -Protocol https
                    if ($currentSSLBinding) {
                        $currentSSLBinding | Remove-WebBinding
                        Remove-Item -Path IIS:\SslBindings\0.0.0.0!443 -ErrorAction SilentlyContinue
                    }
                    New-WebBinding -Protocol https -Port 443 -IPAddress * -Name MendixApp
                    $null = New-Item -Path 'IIS:\SslBindings\0.0.0.0!443' -Thumbprint $cert.Thumbprint
                }
            } catch {
                Write-Error -ErrorRecord $_ -ErrorAction Continue
            } finally {
                if ($null -ne $psSession) {
                    $psSession | Remove-PSSession
                }
            }
        }
    }
}

# helper functions
function PreFlight {
    param (
        [switch] $IncludeSubscription
    )
    if ($null -eq $script:publishSettingFileContent) {
        Write-Error -Message 'Run Import-MXWAPackPublishSettingFile first!' -ErrorAction Stop
    }

    if ($IncludeSubscription -and $null -eq $script:selectedSubscription) {
        Write-Error -Message 'Run Select-MXWAPackPublishSettingSubscription first!' -ErrorAction Stop
    }
}

function TestMendixPackage {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path
    )
    $resolvedPath = (Resolve-Path -Path $Path).ToString()
    Add-Type -AssemblyName 'System.IO.Compression.FileSystem'
    [io.compression.zipfile]::OpenRead($resolvedPath).Entries.FullName -contains 'model/metadata.json'
}

function InvokeAPICall {
    [cmdletbinding()]
    param (
        [Parameter()]
        [ValidateSet('Get', 'Post', 'Delete')]
        [string] $Method = 'Get',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $Body,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $PartialUri,

        [switch] $ExcludeAPI
    )

    $uri = $script:selectedSubscription.ServiceManagementUrl +
        $script:selectedSubscription.Id +
        $PartialUri

    if (!$ExcludeAPI) {
        $uri += '?api-version=2013-03'
    }

    $irmArgs = @{
        UseBasicParsing = $true
        Certificate = $script:selectedSubscription.Certificate
        Headers = @{
            Accept = 'application/json'
        }
        Method = $Method
        Uri = $uri
    }

    if ($PSBoundParameters.ContainsKey('Body')) {
        [void] $irmArgs.Add('Body', $Body)
    }

    if ($Method -eq 'Post') {
        [void] $irmArgs.Add('ContentType', 'application/json')
    }

    $restCall = Invoke-RestMethod @irmArgs
    if ($restCall.value) {
        $restCall.value
    } elseif ($null -ne $restCall) {
        $restCall
    }
}

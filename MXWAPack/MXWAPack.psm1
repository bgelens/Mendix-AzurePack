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

    $currentInstanceCount = ($VMRole | Get-MXWAPackVMRoleVM).Count

    if ($Action -eq 'ScaleUp') {
        if ($currentInstanceCount -eq $scaleProperties.MaximumInstanceCount) {
            Write-Error -Message ('Cannot Scale Up as Maximum instances {0} are already in place' -f $scaleProperties.MaximumInstanceCount) -ErrorAction stop
        }
        if ($currentInstanceCount + $Unit -gt $scaleProperties.MaximumInstanceCount) {
            Write-Error -Message ('Cannot Scale Up by {0} units as this would breach the Maximum allowed instance count {1}' -f $Unit, $scaleProperties.MaximumInstanceCount) -ErrorAction stop
        }
        $body = @{
            InstanceCount = $currentInstanceCount + $Unit
        } | ConvertTo-Json
    } else {
        if ($currentInstanceCount -eq $scaleProperties.MinimumInstanceCount) {
            Write-Error -Message ('Cannot Scale Down as the current amount of instances {0} is the Minimum amount' -f $currentInstanceCount) -ErrorAction stop
        }
        if ($currentInstanceCount - $Unit -lt $scaleProperties.MinimumInstanceCount) {
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

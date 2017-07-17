# Add VM Role

## Overview

The Mendix gallery resources enable a service provider to publish a gallery item for tenants which deploys a workgroup based Mendix application server on Windows Server.
In order to publish the gallery resources as a gallery item, you must:

- Import the resource extension package into System Center Virtual Machine Manager.
- Ensure the virtual hard disks in SCVMM are properly prepared and have all the necessary properties set.
- Import the resource definition package as a gallery item.
- Make the gallery item public.
- Add the gallery item to a plan.

## System Center Virtual Machine Manager

In order to use a gallery resource, you must take the following actions in System Center Virtual Machine Manager.

### Import Resource Extension Package

Using PowerShell, you must import the resource extension package into the virtual machine manager library.
Sample Windows PowerShell:

```powershell
$libsharepath = '' #you must set the library sharepath from your environment
$resextpkg = 'C:\GalleryResources\Mendix\MendixSingleInstance.resextpkg'
Import-CloudResourceExtension –ResourceExtensionPath $resextpkg –SharePath $libsharepath -AllowUnencryptedTransfer
```

\* The import can only be done using PowerShell.

To verify the import, run the Get-CloudResourceExtension PowerShell command and locate the newly imported extension.

```powerShell
Get-CloudResourceExtension
```

### Prepare the virtual hard disks

A virtual hard disk containing a sysprepped version of Windows Server including the Mendix specific components must be added to a SCVMM library share.
For instuctions on how to create this generalized image see these [instructions](/BaseImage.md).
Add the image to the library by copying it to the library fileshare and wait for the library refresh to occur (or manually invoke a refresh) to make the image available.

#### Library properties

Once the VHDx Files are added to the library and have been discovered, they need to be updated with the correct metadata.

```powershell
Get-SCVirtualHardDisk -Name Mendix.vhdx |
    Set-SCVirtualHardDisk -Tag @('Mendix') -Release 1.0.0.0 -FamilyName 'Mendix' -VirtualizationPlatform HyperV
```

\* Note: Also specify a product key for the VHDx if you created your own OS disk

```powershell
Get-SCVirtualHardDisk -Name Win2012R2.vhdx |
    Set-SCVirtualHardDisk -ProductKey 'Enter Product Key here'
```

### Windows Azure Pack Service Administrator Portal

Once the resource extension and virtual hard disk are all correctly set in SCVMM, you can import the resource definition package using the Service Administrator Portal in the Windows Azure Pack.

#### Import Resource Definition Package

- Open the Service Admin Portal.
- Navigate to the VM Clouds workspace.
- Click the Gallery tab.
- Click Import.
- Select and import the MendixSingleInstance.resdefpkg file.
- Note that the gallery item now is listed on the Gallery tab.

Now that the packages for the Virtual Machine Role have been installed, you can publish the gallery item to make it available to tenants.

#### Publish gallery item and add to a plan

To make the Virtual Machine Role available to the tenant, you need to add it to a plan. In this procedure, you publish the Virtual Machine Role that you installed.

- On the Gallery tab, select the version of the gallery item that you just imported.
- Click the arrow next to the gallery item name.
- Explore the details of the gallery item.
- Navigate back and click Make Public.
- Select the Plans workspace in the Service Admin Portal.
- Select the plan to which you want to add this gallery item.
- Select the Virtual Machine Clouds service.
- Scroll to the Gallery section.
- Click Add Gallery Items.
- Select the gallery items that you imported, and then click Save.

The Virtual Machine Role is now available (after syncing is done) to the tenant as part of the selected plan.

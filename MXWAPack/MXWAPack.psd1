#
# Module manifest for module 'MXWAPack'
#
# Generated by: Ben Gelens
#
# Generated on: 12-7-2017
#

@{

# Script module or binary module file associated with this manifest.
RootModule = 'MXWAPack.psm1'

# Version number of this module.
ModuleVersion = '1.0.0'

# Supported PSEditions
# CompatiblePSEditions = @()

# ID used to uniquely identify this module
GUID = '1515b8cc-fa52-4bee-8f62-4b91f4ffd1e8'

# Author of this module
Author = 'Ben Gelens'

# Company or vendor of this module
CompanyName = 'Mendix'

# Copyright statement for this module
Copyright = '(c) 2017 Mendix. All rights reserved.'

# Description of the functionality provided by this module
# Description = ''

# Minimum version of the Windows PowerShell engine required by this module
PowerShellVersion = '4.0'

# Name of the Windows PowerShell host required by this module
# PowerShellHostName = ''

# Minimum version of the Windows PowerShell host required by this module
# PowerShellHostVersion = ''

# Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
DotNetFrameworkVersion = '4.5'

# Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
# CLRVersion = ''

# Processor architecture (None, X86, Amd64) required by this module
# ProcessorArchitecture = ''

# Modules that must be imported into the global environment prior to importing this module
# RequiredModules = @()

# Assemblies that must be loaded prior to importing this module
# RequiredAssemblies = @()

# Script files (.ps1) that are run in the caller's environment prior to importing this module.
# ScriptsToProcess = @()

# Type files (.ps1xml) to be loaded when importing this module
# TypesToProcess = @()

# Format files (.ps1xml) to be loaded when importing this module
# FormatsToProcess = @()

# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
# NestedModules = @()

# Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
FunctionsToExport = @(
    'Import-MXWAPackPublishSettingFile',
    'Get-MXWAPackPublishSettingSubscription',
    'Select-MXWAPackPublishSettingSubscription',
    'Get-MXWAPackCloudService',
    'New-MXWAPackCloudService',
    'Remove-MXWAPackCloudService',
    'Get-MXWAPackVMRole',
    'Get-MXWAPackGalleryItem',
    'New-MXWAPackGalleryItemParameterObject',
    'New-MXWAPackVMRoleDeployment',
    'Get-MXWAPackVMRoleVM',
    'Get-MXWAPackVMNetwork',
    'Get-MXWAPackVMRoleSizeProfile',
    'Start-MXWAPackVMRoleVM',
    'Stop-MXWAPackVMRoleVM',
    'Restart-MXWAPackVMRoleVM',
    'Refresh-MXWAPackVMRoleVM',
    'Invoke-MXWAPackVMRoleScaleAction',
    'Repair-MXWAPackVMRole',
    'Install-MXWAPackServerPackage',
    'Start-MXWAPackMendixApp',
    'Stop-MXWAPackMendixApp',
    'Get-MXWAPackVMRoleOSDisk',
    'Update-MXWAPackMendixApp',
    'Get-MXWAPackMendixAppSettings',
    'Get-MXWAPackMendixApp',
    'Get-MXWAPackInstalledServerPackage',
    'Get-MXWAPackMendixAppPackage',
    'Get-MXWAPackMendixServerLicenseInfo',
    'Set-MXWAPackMendixServerLicense',
    'Add-MXWAPackSSLBinding'
)

# Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
# CmdletsToExport = '*'

# Variables to export from this module
# VariablesToExport = '*'

# Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
# AliasesToExport = '*'

# DSC resources to export from this module
# DscResourcesToExport = @()

# List of all modules packaged with this module
# ModuleList = @()

# List of all files packaged with this module
# FileList = @()

# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
PrivateData = @{

    PSData = @{

        # Tags applied to this module. These help with module discovery in online galleries.
        # Tags = @()

        # A URL to the license for this module.
        # LicenseUri = ''

        # A URL to the main website for this project.
        # ProjectUri = ''

        # A URL to an icon representing this module.
        # IconUri = ''

        # ReleaseNotes of this module
        # ReleaseNotes = ''

    } # End of PSData hashtable

} # End of PrivateData hashtable

# HelpInfo URI of this module
# HelpInfoURI = ''

# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
# DefaultCommandPrefix = ''

}


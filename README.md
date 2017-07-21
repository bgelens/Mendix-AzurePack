# Mendix-AzurePack

This repository contains:

* PowerShell Module [MXWAPack](/MXWAPack) to work with the Azure Pack Public Tenant API
* VM Role artifacts
  * [MendixSingleInstance](/VMRole/MendixSingleInstance)
  * [MendixMultiInstance](/VMRole/MendixMultiInstance)
* Documentation
  * Base Image Creation
    * [Single Instance](/Documentation/BaseImage.md)
    * [Multi Instance](/Documentation/BaseImage_MultiInstance.md)
  * [Make VM Role available for tenants](/Documentation/AddVMRole.md)
  * [Deploy VM Role using MXWAPack PowerShell module](/Documentation/DeployVMRole.md)
  * [Mendix operational instructions using MXWAPack PowerShell module](/Documentation/MendixOperations.md)
* Examples
  * [Single Instance End to End](/Examples/01-SingleInstance_End2End.ps1)
  * [Deploy SQL VM Role and acquire data to construct connection string](/Examples/02-SQLInstance.ps1)

\* Currently the MXWAPack PowerShell module only works when the Public Tenant API Certificate is trusted.

The Mendix SingleInstance VM Role targets a local PostgreSQL Instance. If you are planning to deploy against a shared SQL Server backend, see [this](https://github.com/itnetxbe/VMRoles/tree/master/SQL2016) external documentation to create a SQL VM Role or [this](https://github.com/itnetxbe/VMRoles/tree/master/SQL2016AO) to create a SQL Always On VM Role and deploy the Mendix Multi Instance VM Role instead of the Single Instance. Make sure the SQL server supports SQL authentication!

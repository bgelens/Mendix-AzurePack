# Mendix-AzurePack

This repository contains:

* PowerShell Module [MXWAPack](/MXWAPack) to work with the Azure Pack Public Tenant API
* VM Role artifacts
  * [MendixSingleInstance](/VMRole/MendixSingleInstance) (Deployes a single VM but can be scaled to a maximum of 10)
* Documentation
  * Base Image Creation
  * Make VM Role available for tenants
  * [Deploy VM Role using MXWAPack PowerShell module](/Documentation/DeployVMRole.md)
  * Start / Stop / Update Mendix Application instructions using MXWAPack PowerShell module

\* Currently the MXWAPack PowerShell module only works when the Public Tenant API Certificate is trusted.

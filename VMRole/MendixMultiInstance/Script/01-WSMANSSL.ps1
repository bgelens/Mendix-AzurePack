$cert = New-SelfSignedCertificate -Subject "CN=$env:COMPUTERNAME" -FriendlyName 'WinRM SSL' -NotAfter ([datetime]::Today).AddYears(4) -CertStoreLocation Cert:\LocalMachine\My
$listener = New-Item -Path WSMan:\localhost\Listener -Address * -Transport HTTPS -CertificateThumbPrint $cert.Thumbprint -Force
$fw = New-NetFirewallRule -Name 'Windows Remote Management (HTTPs-In)' -DisplayName 'Windows Remote Management (HTTPs-In)' -Enabled True -Profile Any -Direction Inbound -Action Allow -Protocol tcp
Set-Item WSMan:\localhost\MaxEnvelopeSizekb -Value (250mb / 1kb)
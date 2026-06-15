# Based on https://stackoverflow.com/a/79405293

# First, make sure WinRM can't be connected to
netsh advfirewall firewall set rule name="Windows Remote Management (HTTP-In)" new enable=yes action=block

# Delete any existing WinRM listeners
winrm delete winrm/config/listener?Address=*+Transport=HTTP  2>$Null
winrm delete winrm/config/listener?Address=*+Transport=HTTPS 2>$Null

# Disable group policies which block basic authentication and unencrypted login

Function Set-DWORD {
	param ( $KeyPath, $Name, $Value )

	If ( -Not ( Test-Path $KeyPath ) ) {
		New-Item $KeyPath
	}

	If ( (Get-ItemProperty -Path $KeyPath).PSObject.Properties.Name -contains $Name ) {
		Set-ItemProperty -Path $KeyPath -Name $Name -Value $Value
	}
	Else {
		New-ItemProperty -Path $KeyPath -Name $Name -PropertyType DWord -Value $Value
	}
}

If ( -Not ( Test-Path HKLM:\Software\Policies\Microsoft\Windows\WinRM ) ) {
	New-Item HKLM:\Software\Policies\Microsoft\Windows\WinRM
}

Set-DWORD -KeyPath HKLM:\Software\Policies\Microsoft\Windows\WinRM\Client -Name AllowBasic -Value 1
Set-DWORD -KeyPath HKLM:\Software\Policies\Microsoft\Windows\WinRM\Client -Name AllowUnencryptedTraffic -Value 1

Set-DWORD -KeyPath HKLM:\Software\Policies\Microsoft\Windows\WinRM\Service -Name AllowBasic -Value 1
Set-DWORD -KeyPath HKLM:\Software\Policies\Microsoft\Windows\WinRM\Service -Name AllowUnencryptedTraffic -Value 1

# Create a new WinRM listener and configure
winrm create winrm/config/listener?Address=*+Transport=HTTP
winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="0"}'
winrm set winrm/config '@{MaxTimeoutms="7200000"}'
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
winrm set winrm/config/service '@{MaxConcurrentOperationsPerUser="12000"}'
winrm set winrm/config/service/auth '@{Basic="true"}'
winrm set winrm/config/client/auth '@{Basic="true"}'

# Configure UAC to allow privilege elevation in remote shells
$Key = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
$Setting = 'LocalAccountTokenFilterPolicy'
Set-ItemProperty -Path $Key -Name $Setting -Value 1 -Force

# Configure and restart the WinRM Service; Enable the required firewall exception
Stop-Service -Name WinRM
Set-Service -Name WinRM -StartupType Automatic
netsh advfirewall firewall set rule name="Windows Remote Management (HTTP-In)" new action=allow localip=any remoteip=any
# Start-Service -Name WinRM

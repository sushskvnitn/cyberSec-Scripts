# Define a function to ask the user before executing a command
function Ask-Confirmation {
    param (
        [string]$Message,
        [scriptblock]$Action
    )

    Write-Host "`n$Message" -ForegroundColor Yellow
    $response = Read-Host "Do you want to proceed? (yes/no)"
    if ($response -eq "yes") {
        & $Action
        Write-Host "Action completed!" -ForegroundColor Green
    } else {
        Write-Host "Skipped!" -ForegroundColor Red
    }
}

# 1. Enable BitLocker
Ask-Confirmation -Message "This will enable BitLocker to encrypt your C: drive. BitLocker protects data from unauthorized access." -Action {
    Enable-BitLocker -MountPoint "C:" -EncryptionMethod XtsAes256 -UsedSpaceOnlyEncryption -RecoveryPasswordProtector
}

# 2. Enable Auditing for sensitive actions
Ask-Confirmation -Message "This will enable advanced auditing for file system access and removable storage." -Action {
    auditpol /set /subcategory:"File System" /success:enable /failure:enable
    auditpol /set /subcategory:"Removable Storage" /success:enable /failure:enable
}

# 3. Restrict admin account network access
Ask-Confirmation -Message "This will disable network logins for the Administrator account to reduce the risk of abuse." -Action {
    net user administrator /active:no
}

# 4. Configure Windows Firewall to restrict access by IP
Ask-Confirmation -Message "This will create a firewall rule to allow access only from specific IPs." -Action {
    New-NetFirewallRule -DisplayName "Allow Trusted IPs" -Direction Inbound -Protocol TCP -LocalPort 22 -RemoteAddress "192.168.1.0/24" -Action Allow
}

# 5. Disable legacy SMBv1 protocol
Ask-Confirmation -Message "This will disable the outdated SMBv1 protocol, which is vulnerable to attacks like WannaCry." -Action {
    Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol
}

# 6. Enforce execution policy and enable PowerShell logging
Ask-Confirmation -Message "This will enforce the 'RemoteSigned' execution policy and enable PowerShell script logging." -Action {
    Set-ExecutionPolicy RemoteSigned -Scope LocalMachine
    Set-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Name "EnableScriptBlockLogging" -Value 1
}

# 7. Secure system files by restricting write permissions
Ask-Confirmation -Message "This will restrict write access to critical system files in the System32 directory." -Action {
    icacls "C:\Windows\System32" /deny Everyone:(W)
}

# 8. Configure TLS to disable outdated versions
Ask-Confirmation -Message "This will disable older versions of TLS to secure encrypted communications." -Action {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Client" -Name "Enabled" -Value 0
}

# 9. Enable periodic full malware scans
Ask-Confirmation -Message "This will enable and start a full malware scan using Windows Defender." -Action {
    Set-MpPreference -DisableTamperProtection $false
    Start-MpScan -ScanType FullScan
}

# 10. Set file system quotas to prevent overuse
Ask-Confirmation -Message "This will enforce disk quotas on drive C: to prevent excessive disk usage." -Action {
    fsutil quota enforce C:
}

# 11. Start secure system backup
Ask-Confirmation -Message "This will start a secure backup of the C: drive to drive D:." -Action {
    wbadmin start backup -backupTarget:D: -include:C: -quiet
}

# 12. Check for open ports and list them
Ask-Confirmation -Message "This will scan for open and potentially unwanted ports on the system." -Action {
    netstat -ano | Select-String "LISTENING"
}

# 13. Enable Windows Updates
Ask-Confirmation -Message "This will enable automatic Windows Updates to ensure the system stays up-to-date." -Action {
    Set-Service -Name wuauserv -StartupType Automatic
    Start-Service -Name wuauserv
    wuauclt /detectnow
}

# 14. Configure Application Whitelisting
Ask-Confirmation -Message "This will create a default AppLocker policy to control which applications can run on this system." -Action {
    New-AppLockerPolicy -DefaultPolicy -XMLPolicyFilePath "C:\AppLockerPolicy.xml"
}

# 15. Enable secure DNS settings
Ask-Confirmation -Message "This will configure Cloudflare's DNS (1.1.1.1) for enhanced security." -Action {
    Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses ("1.1.1.1","1.0.0.1")
}

Write-Host "`nScript execution completed. Review skipped actions to apply them later if necessary." -ForegroundColor Cyan

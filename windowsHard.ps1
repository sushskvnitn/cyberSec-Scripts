# Ensure running as Administrator
If (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "Please run this script as an Administrator!"
    exit
}

# Turn on Windows Firewall
Write-Output "Enabling Windows Firewall..."
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True

# Disable unnecessary services
Write-Output "Disabling unnecessary services..."
$services = @(
    "RemoteRegistry",      # Disable Remote Registry
    "wuauserv",            # Disable Windows Update (if managed by other tools)
    "BITS",                # Background Intelligent Transfer Service
    "telnet",              # Disable Telnet
    "ssdp",                # SSDP Discovery
    "upnphost"             # UPnP Device Host
)
foreach ($service in $services) {
    Set-Service -Name $service -StartupType Disabled
    Stop-Service -Name $service -Force
}

# Enable audit policies
Write-Output "Enabling auditing policies..."
auditpol /set /subcategory:"Logon" /success:enable /failure:enable
auditpol /set /subcategory:"Account Lockout" /success:enable /failure:enable
auditpol /set /subcategory:"Policy Change" /success:enable /failure:enable
auditpol /set /subcategory:"Privilege Use" /success:enable /failure:enable

# Enforce strong password policy
Write-Output "Configuring password policies..."
secedit /configure /db SecDB.sdb /cfg "$env:SystemRoot\security\templates\basicdc.inf" /areas SECURITYPOLICY

# Disable SMBv1 to prevent outdated protocol vulnerabilities
Write-Output "Disabling SMBv1..."
Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force
Disable-WindowsOptionalFeature -Online -FeatureName smb1protocol -NoRestart

# Enable UAC (User Account Control)
Write-Output "Enabling User Account Control..."
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA" -Value 1 -PropertyType DWord -Force

# Disable Remote Desktop (RDP) if not required
Write-Output "Disabling Remote Desktop..."
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 1

# Remove unnecessary scheduled tasks
Write-Output "Removing unnecessary scheduled tasks..."
$tasks = @(
    "\Microsoft\Windows\Media Center\mcupdate_scheduled",
    "\Microsoft\Windows\Mobile Broadband Accounts\MNO Metadata Parser",
    "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser"
)
foreach ($task in $tasks) {
    schtasks /delete /tn $task /f
}

# Enable Windows Defender real-time protection
Write-Output "Enabling Windows Defender real-time protection..."
Set-MpPreference -DisableRealtimeMonitoring $false

# Restrict guest access
Write-Output "Restricting guest access to local accounts..."
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "LimitBlankPasswordUse" -Value 1

# Scan for open ports
Write-Output "Scanning for open ports..."
$openPorts = netstat -an | Select-String "LISTENING" | ForEach-Object {
    ($_ -split '\s+')[1] -replace '.*:', ''
} | Sort-Object | Get-Unique

Write-Output "Open ports detected: $($openPorts -join ', ')"

# Identify unwanted ports
Write-Output "Checking for unwanted ports..."
$unwantedPorts = @('21', '23', '25', '135', '139', '445', '3389') # Add unwanted ports here
$foundUnwantedPorts = $openPorts | Where-Object { $unwantedPorts -contains $_ }

if ($foundUnwantedPorts) {
    Write-Warning "Unwanted ports detected: $($foundUnwantedPorts -join ', ')"
    Write-Warning "Consider closing these ports or disabling associated services."
} else {
    Write-Output "No unwanted ports detected."
}

# Apply changes
Write-Output "Applying system changes..."
gpupdate /force

Write-Output "Windows Hardening Script execution completed. Restart the system for all changes to take effect!"



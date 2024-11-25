# List of vulnerable Windows services to check
$servicesToCheck = @(
    "TermService",      # Remote Desktop Services
    "LanmanServer",     # SMB Service
    "WinRM",            # Windows Remote Management
    "Spooler",          # Print Spooler
    "Schedule",         # Task Scheduler
    "wmiApSrv",         # WMI Service
    "RemoteRegistry",   # Remote Registry
    "DHCP",             # DHCP Client Service
    "Dnscache",         # DNS Client Service
    "IISADMIN"          # IIS Admin Service
)

# Function to restrict access to a service
function Harden-ServiceAccess {
    param (
        [string]$ServiceName
    )
    Write-Host "Hardening access to $ServiceName..."
    try {
        # Grant access only to Administrators
        sc.exe sdset $ServiceName "D:(A;;CCLCSWRPWPDTLOCRRC;;;BA)(A;;CCLCSWLOCRRC;;;SY)(A;;CCLCSWRPWPDTLOCRRC;;;AU)"
        Write-Host "Access to $ServiceName has been hardened."
    } catch {
        Write-Host "Failed to harden access: $_" -ForegroundColor Red
    }
}

# Loop through each service
foreach ($serviceName in $servicesToCheck) {
    # Get service details
    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

    if ($service) {
        Write-Host "`nService Name: $($service.DisplayName) [$serviceName]"
        Write-Host "Status: $($service.Status)"
        
        # Check if the service is running
        if ($service.Status -eq "Running") {
            # Prompt the user to disable the service
            $response = Read-Host "The service is running. Do you want to disable and stop it? (yes/no)"
            if ($response -eq "yes") {
                try {
                    # Stop the service
                    Stop-Service -Name $serviceName -Force -ErrorAction Stop
                    Write-Host "Service stopped successfully."
                    
                    # Disable the service
                    Set-Service -Name $serviceName -StartupType Disabled
                    Write-Host "Service disabled successfully."
                } catch {
                    Write-Host "Failed to disable or stop the service: $_" -ForegroundColor Red
                }
            } else {
                Write-Host "Service left running."
            }
        } else {
            Write-Host "The service is not running. No action needed."
        }

        # Prompt the user to harden access to the service
        $hardenResponse = Read-Host "Do you want to harden access to this service? (yes/no)"
        if ($hardenResponse -eq "yes") {
            Harden-ServiceAccess -ServiceName $serviceName
        } else {
            Write-Host "Access hardening skipped for $serviceName."
        }
    } else {
        Write-Host "`nService [$serviceName] not found on this system."
    }
}

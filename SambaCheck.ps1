# Samba/SMB Network Drive Troubleshooting Script
# Simplified version for Windows 10/11 compatibility
# Run as Administrator for best results

param(
    [string]$ServerIP = "",
    [string]$ShareName = "",
    [switch]$Detailed
)

# Simple color output function
function Write-Status {
    param([string]$Message, [string]$Status = "INFO")
    
    $timestamp = Get-Date -Format "HH:mm:ss"
    switch ($Status) {
        "SUCCESS" { Write-Host "[$timestamp] [OK] $Message" -ForegroundColor Green }
        "ERROR"   { Write-Host "[$timestamp] [ERROR] $Message" -ForegroundColor Red }
        "WARNING" { Write-Host "[$timestamp] [WARN] $Message" -ForegroundColor Yellow }
        "INFO"    { Write-Host "[$timestamp] [INFO] $Message" -ForegroundColor White }
        "HEADER"  { 
            Write-Host ""
            Write-Host "========================================" -ForegroundColor Cyan
            Write-Host $Message -ForegroundColor Cyan
            Write-Host "========================================" -ForegroundColor Cyan
        }
    }
}

function Test-AdminRights {
    try {
        $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        return $false
    }
}

function Test-NetworkConnection {
    param([string]$Target)
    
    if ([string]::IsNullOrEmpty($Target)) {
        Write-Status "No target specified for ping test" "WARNING"
        return $false
    }
    
    try {
        Write-Status "Testing network connectivity to $Target..."
        $result = ping $Target -n 2 -w 3000
        
        if ($LASTEXITCODE -eq 0) {
            Write-Status "Network connectivity to $Target is working" "SUCCESS"
            return $true
        } else {
            Write-Status "Cannot reach $Target - check network connection" "ERROR"
            return $false
        }
    } catch {
        Write-Status "Ping test failed: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Test-Ports {
    param([string]$ServerIP)
    
    if ([string]::IsNullOrEmpty($ServerIP)) {
        Write-Status "No server IP provided for port testing" "WARNING"
        return
    }
    
    Write-Status "Testing SMB ports on $ServerIP..."
    
    # Test port 445 (SMB)
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $connection = $tcp.BeginConnect($ServerIP, 445, $null, $null)
        $wait = $connection.AsyncWaitHandle.WaitOne(3000, $false)
        
        if ($wait) {
            $tcp.EndConnect($connection)
            Write-Status "Port 445 (SMB) is open on $ServerIP" "SUCCESS"
        } else {
            Write-Status "Port 445 (SMB) is not accessible on $ServerIP" "ERROR"
        }
        $tcp.Close()
    } catch {
        Write-Status "Cannot test port 445 on $ServerIP" "ERROR"
    }
    
    # Test port 139 (NetBIOS)
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $connection = $tcp.BeginConnect($ServerIP, 139, $null, $null)
        $wait = $connection.AsyncWaitHandle.WaitOne(3000, $false)
        
        if ($wait) {
            $tcp.EndConnect($connection)
            Write-Status "Port 139 (NetBIOS) is open on $ServerIP" "SUCCESS"
        } else {
            Write-Status "Port 139 (NetBIOS) is not accessible on $ServerIP" "WARNING"
        }
        $tcp.Close()
    } catch {
        Write-Status "Cannot test port 139 on $ServerIP" "WARNING"
    }
}

function Check-Services {
    Write-Status "Windows Services Check" "HEADER"
    
    $services = @(
        @{Name="LanmanWorkstation"; DisplayName="Workstation"},
        @{Name="LanmanServer"; DisplayName="Server"},
        @{Name="Browser"; DisplayName="Computer Browser"}
    )
    
    foreach ($svc in $services) {
        try {
            $service = Get-Service -Name $svc.Name -ErrorAction Stop
            if ($service.Status -eq "Running") {
                Write-Status "$($svc.DisplayName) service is running" "SUCCESS"
            } else {
                Write-Status "$($svc.DisplayName) service is $($service.Status)" "ERROR"
                Write-Status "Try: net start $($svc.Name)" "INFO"
            }
        } catch {
            Write-Status "$($svc.DisplayName) service not found or accessible" "WARNING"
        }
    }
}

function Check-SMBSettings {
    Write-Status "SMB Configuration Check" "HEADER"
    
    try {
        # Check if SMB client is working
        $smbClient = Get-Command Get-SmbClientConfiguration -ErrorAction SilentlyContinue
        if ($smbClient) {
            $config = Get-SmbClientConfiguration
            Write-Status "SMB2 Protocol Enabled: $($config.EnableSMB2Protocol)" $(if ($config.EnableSMB2Protocol) {"SUCCESS"} else {"ERROR"})
            Write-Status "SMB1 Protocol Enabled: $($config.EnableSMB1Protocol)" $(if ($config.EnableSMB1Protocol) {"WARNING"} else {"SUCCESS"})
        } else {
            Write-Status "SMB PowerShell module not available" "WARNING"
        }
    } catch {
        Write-Status "Cannot check SMB configuration: $($_.Exception.Message)" "WARNING"
    }
}

function Check-NetworkDrives {
    Write-Status "Current Network Drives" "HEADER"
    
    try {
        # Check mapped drives using net use
        $netUse = net use 2>&1
        if ($LASTEXITCODE -eq 0) {
            $drives = $netUse | Where-Object { $_ -match "^\w:" }
            if ($drives) {
                foreach ($drive in $drives) {
                    Write-Status "Mapped drive: $drive" "INFO"
                }
            } else {
                Write-Status "No network drives currently mapped" "INFO"
            }
        }
        
        # Also check with PowerShell
        $psDrives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.DisplayRoot -like "\\*" }
        foreach ($drive in $psDrives) {
            $accessible = Test-Path $drive.Root -ErrorAction SilentlyContinue
            if ($accessible) {
                Write-Status "$($drive.Name): $($drive.DisplayRoot) - Accessible" "SUCCESS"
            } else {
                Write-Status "$($drive.Name): $($drive.DisplayRoot) - Not Accessible" "ERROR"
            }
        }
    } catch {
        Write-Status "Error checking network drives: $($_.Exception.Message)" "ERROR"
    }
}

function Test-ShareAccess {
    param([string]$ServerIP, [string]$ShareName)
    
    if ([string]::IsNullOrEmpty($ServerIP)) {
        Write-Status "No server specified for share testing" "WARNING"
        return
    }
    
    Write-Status "Share Access Test" "HEADER"
    
    # Try to list shares using net view command
    try {
        Write-Status "Attempting to list shares on \\$ServerIP..."
        $netView = net view "\\$ServerIP" 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Status "Successfully connected to \\$ServerIP" "SUCCESS"
            Write-Status "Available shares:" "INFO"
            
            # Parse and display shares
            $shareLines = $netView | Where-Object { $_ -match "^\s+\w" }
            foreach ($line in $shareLines) {
                Write-Status "  $line" "INFO"
            }
        } else {
            Write-Status "Cannot list shares on \\$ServerIP" "ERROR"
            Write-Status "Error details: $($netView -join ' ')" "ERROR"
        }
    } catch {
        Write-Status "Share listing failed: $($_.Exception.Message)" "ERROR"
    }
    
    # Test specific share if provided
    if (![string]::IsNullOrEmpty($ShareName)) {
        $uncPath = "\\$ServerIP\$ShareName"
        Write-Status "Testing access to $uncPath..."
        
        if (Test-Path $uncPath -ErrorAction SilentlyContinue) {
            Write-Status "Share $uncPath is accessible" "SUCCESS"
        } else {
            Write-Status "Share $uncPath is not accessible" "ERROR"
        }
    }
}

function Show-TroubleshootingSteps {
    Write-Status "Troubleshooting Steps" "HEADER"
    
    Write-Host "If you're having issues, try these commands:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. Restart network services:" -ForegroundColor White
    Write-Host "   net stop lanmanworkstation" -ForegroundColor Gray
    Write-Host "   net start lanmanworkstation" -ForegroundColor Gray
    Write-Host ""
    Write-Host "2. Clear credential cache:" -ForegroundColor White
    Write-Host "   cmdkey /list" -ForegroundColor Gray
    Write-Host "   cmdkey /delete:<server_name>" -ForegroundColor Gray
    Write-Host ""
    Write-Host "3. Reset network settings:" -ForegroundColor White
    Write-Host "   ipconfig /flushdns" -ForegroundColor Gray
    Write-Host "   nbtstat -R" -ForegroundColor Gray
    Write-Host ""
    Write-Host "4. Map drive manually:" -ForegroundColor White
    Write-Host "   net use Z: \\server\share /persistent:yes" -ForegroundColor Gray
    Write-Host ""
    Write-Host "5. Check Windows features:" -ForegroundColor White
    Write-Host "   - Enable 'SMB 1.0/CIFS File Sharing Support' if needed" -ForegroundColor Gray
    Write-Host "   - Check firewall settings for File and Printer Sharing" -ForegroundColor Gray
}

# Main script execution
Clear-Host
Write-Status "SMB/Samba Network Drive Diagnostic Tool" "HEADER"

# Check admin rights
if (Test-AdminRights) {
    Write-Status "Running with Administrator privileges" "SUCCESS"
} else {
    Write-Status "Not running as Administrator - some checks may be limited" "WARNING"
    Write-Status "For complete diagnostics, right-click and 'Run as Administrator'" "INFO"
}

# Get input if not provided
if ([string]::IsNullOrEmpty($ServerIP)) {
    Write-Host ""
    $ServerIP = Read-Host "Enter Samba server IP address (or press Enter to skip network tests)"
}

if (![string]::IsNullOrEmpty($ServerIP) -and [string]::IsNullOrEmpty($ShareName)) {
    $ShareName = Read-Host "Enter share name to test (or press Enter to skip)"
}

# Run diagnostic checks
Check-Services
Check-SMBSettings
Check-NetworkDrives

# Network-specific tests if server IP provided
if (![string]::IsNullOrEmpty($ServerIP)) {
    Write-Status "Network Tests" "HEADER"
    $networkOK = Test-NetworkConnection -Target $ServerIP
    
    if ($networkOK) {
        Test-Ports -ServerIP $ServerIP
        Test-ShareAccess -ServerIP $ServerIP -ShareName $ShareName
    } else {
        Write-Status "Skipping port and share tests due to network connectivity issues" "WARNING"
    }
}

Show-TroubleshootingSteps

Write-Host ""
Write-Status "Diagnostic complete. Review the results above for any issues." "INFO"
Write-Status "If problems persist, try the troubleshooting steps or contact your IT administrator." "INFO"
# Samba Service and Network Drive Connectivity Check Script
# For Windows 10/11 - Troubleshooting network drive mapping issues
# Run as Administrator for best results

param(
    [Parameter(Mandatory=$false)]
    [string]$ServerIP = "",
    
    [Parameter(Mandatory=$false)]
    [string]$ShareName = "",
    
    [Parameter(Mandatory=$false)]
    [switch]$Detailed
)

# Color coding for output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

function Write-Header {
    param([string]$Title)
    Write-Host ""
    Write-Host "=" * 60 -ForegroundColor Cyan
    Write-Host $Title -ForegroundColor Cyan
    Write-Host "=" * 60 -ForegroundColor Cyan
}

function Test-NetworkConnectivity {
    param([string]$Target)
    
    if ([string]::IsNullOrEmpty($Target)) {
        Write-ColorOutput "No target specified for network test" "Yellow"
        return $false
    }
    
    try {
        $ping = Test-Connection -ComputerName $Target -Count 2 -Quiet
        if ($ping) {
            Write-ColorOutput "✓ Network connectivity to $Target: SUCCESS" "Green"
            return $true
        } else {
            Write-ColorOutput "✗ Network connectivity to $Target: FAILED" "Red"
            return $false
        }
    } catch {
        Write-ColorOutput "✗ Network connectivity test failed: $($_.Exception.Message)" "Red"
        return $false
    }
}

function Test-SambaPort {
    param([string]$ServerIP)
    
    if ([string]::IsNullOrEmpty($ServerIP)) {
        Write-ColorOutput "No server IP specified for port test" "Yellow"
        return
    }
    
    $ports = @(139, 445)  # NetBIOS and SMB ports
    
    foreach ($port in $ports) {
        try {
            $tcpClient = New-Object System.Net.Sockets.TcpClient
            $connection = $tcpClient.BeginConnect($ServerIP, $port, $null, $null)
            $wait = $connection.AsyncWaitHandle.WaitOne(3000, $false)
            
            if ($wait) {
                $tcpClient.EndConnect($connection)
                Write-ColorOutput "✓ Port $port is open on $ServerIP" "Green"
            } else {
                Write-ColorOutput "✗ Port $port is closed/filtered on $ServerIP" "Red"
            }
            $tcpClient.Close()
        } catch {
            Write-ColorOutput "✗ Cannot connect to port $port on $ServerIP" "Red"
        }
    }
}

function Get-SMBClientConfiguration {
    Write-Header "SMB Client Configuration"
    
    try {
        $smbConfig = Get-SmbClientConfiguration
        Write-ColorOutput "SMB1 Protocol: $($smbConfig.EnableSMB1Protocol)" $(if ($smbConfig.EnableSMB1Protocol) {"Yellow"} else {"Green"})
        Write-ColorOutput "SMB2 Protocol: $($smbConfig.EnableSMB2Protocol)" $(if ($smbConfig.EnableSMB2Protocol) {"Green"} else {"Red"})
        Write-ColorOutput "Require Security Signature: $($smbConfig.RequireSecuritySignature)" "White"
        Write-ColorOutput "Connection Count Per Server: $($smbConfig.ConnectionCountPerRssNetworkInterface)" "White"
    } catch {
        Write-ColorOutput "Failed to get SMB client configuration: $($_.Exception.Message)" "Red"
    }
}

function Get-NetworkServices {
    Write-Header "Relevant Windows Services Status"
    
    $services = @(
        "LanmanWorkstation",  # Workstation service
        "LanmanServer",       # Server service
        "Browser",            # Computer Browser
        "NetBT"              # NetBIOS over TCP/IP
    )
    
    foreach ($serviceName in $services) {
        try {
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            if ($service) {
                $status = $service.Status
                $color = if ($status -eq "Running") {"Green"} else {"Red"}
                Write-ColorOutput "$($service.DisplayName): $status" $color
            } else {
                Write-ColorOutput "$serviceName: Service not found" "Yellow"
            }
        } catch {
            Write-ColorOutput "$serviceName: Error checking service" "Red"
        }
    }
}

function Get-WindowsFeatures {
    Write-Header "SMB Related Windows Features"
    
    try {
        # Check SMB 1.0 feature
        $smb1Feature = Get-WindowsOptionalFeature -Online -FeatureName "SMB1Protocol" -ErrorAction SilentlyContinue
        if ($smb1Feature) {
            $color = if ($smb1Feature.State -eq "Enabled") {"Yellow"} else {"Green"}
            Write-ColorOutput "SMB 1.0/CIFS File Sharing Support: $($smb1Feature.State)" $color
            if ($smb1Feature.State -eq "Enabled") {
                Write-ColorOutput "  Warning: SMB 1.0 is enabled (security risk)" "Yellow"
            }
        }
        
        # Check SMB Direct
        $smbDirect = Get-WindowsOptionalFeature -Online -FeatureName "SmbDirect" -ErrorAction SilentlyContinue
        if ($smbDirect) {
            Write-ColorOutput "SMB Direct: $($smbDirect.State)" "White"
        }
    } catch {
        Write-ColorOutput "Could not check Windows features (may require admin privileges)" "Yellow"
    }
}

function Test-CredentialManager {
    Write-Header "Credential Manager Check"
    
    try {
        $credentials = cmdkey /list | Select-String "Target:"
        if ($credentials.Count -gt 0) {
            Write-ColorOutput "Found $($credentials.Count) stored credentials" "Green"
            if ($Detailed) {
                foreach ($cred in $credentials) {
                    Write-ColorOutput "  $cred" "White"
                }
            }
        } else {
            Write-ColorOutput "No stored network credentials found" "Yellow"
        }
    } catch {
        Write-ColorOutput "Could not check credential manager" "Red"
    }
}

function Get-NetworkDrives {
    Write-Header "Current Network Drive Mappings"
    
    try {
        $networkDrives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.DisplayRoot -like "\\*" }
        
        if ($networkDrives.Count -gt 0) {
            foreach ($drive in $networkDrives) {
                $accessible = Test-Path $drive.Root
                $status = if ($accessible) {"✓ Accessible"} else {"✗ Not Accessible"}
                $color = if ($accessible) {"Green"} else {"Red"}
                Write-ColorOutput "$($drive.Name): $($drive.DisplayRoot) - $status" $color
            }
        } else {
            Write-ColorOutput "No network drives currently mapped" "Yellow"
        }
    } catch {
        Write-ColorOutput "Error checking network drives: $($_.Exception.Message)" "Red"
    }
}

function Test-SMBShare {
    param([string]$ServerIP, [string]$ShareName)
    
    if ([string]::IsNullOrEmpty($ServerIP)) {
        Write-ColorOutput "No server specified for SMB share test" "Yellow"
        return
    }
    
    Write-Header "SMB Share Accessibility Test"
    
    try {
        # Test if we can list shares on the server
        $shares = Get-SmbShare -CimSession $ServerIP -ErrorAction SilentlyContinue
        if ($shares) {
            Write-ColorOutput "✓ Can connect to SMB server at $ServerIP" "Green"
            Write-ColorOutput "Available shares:" "White"
            foreach ($share in $shares) {
                Write-ColorOutput "  - $($share.Name): $($share.Path)" "White"
            }
        } else {
            Write-ColorOutput "✗ Cannot list shares on $ServerIP" "Red"
        }
    } catch {
        Write-ColorOutput "✗ SMB connection failed: $($_.Exception.Message)" "Red"
        
        # Try alternative method with net view
        try {
            $netView = net view "\\$ServerIP" 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-ColorOutput "✓ Net view successful for \\$ServerIP" "Green"
            } else {
                Write-ColorOutput "✗ Net view failed for \\$ServerIP" "Red"
                Write-ColorOutput "Error: $netView" "Red"
            }
        } catch {
            Write-ColorOutput "✗ Net view command failed" "Red"
        }
    }
    
    # Test specific share if provided
    if (![string]::IsNullOrEmpty($ShareName)) {
        $uncPath = "\\$ServerIP\$ShareName"
        Write-ColorOutput "Testing access to: $uncPath" "White"
        
        if (Test-Path $uncPath) {
            Write-ColorOutput "✓ Share $ShareName is accessible" "Green"
        } else {
            Write-ColorOutput "✗ Share $ShareName is not accessible" "Red"
        }
    }
}

function Get-EventLogs {
    Write-Header "Recent SMB Related Event Log Entries"
    
    try {
        $events = Get-WinEvent -FilterHashtable @{LogName='System'; Id=@(1001,1006,1014,1020); StartTime=(Get-Date).AddDays(-1)} -MaxEvents 10 -ErrorAction SilentlyContinue
        
        if ($events) {
            Write-ColorOutput "Recent SMB/Network related events (last 24 hours):" "White"
            foreach ($event in $events) {
                $level = switch ($event.LevelDisplayName) {
                    "Error" { "Red" }
                    "Warning" { "Yellow" }
                    default { "White" }
                }
                Write-ColorOutput "[$($event.TimeCreated)] $($event.LevelDisplayName): $($event.Message.Split("`n")[0])" $level
            }
        } else {
            Write-ColorOutput "No recent SMB-related events found" "Green"
        }
    } catch {
        Write-ColorOutput "Could not check event logs (may require admin privileges)" "Yellow"
    }
}

function Show-TroubleshootingTips {
    Write-Header "Troubleshooting Tips"
    
    Write-ColorOutput "Common Solutions:" "Cyan"
    Write-ColorOutput "1. Restart the Workstation service: " "White" -NoNewline
    Write-ColorOutput "net stop lanmanworkstation && net start lanmanworkstation" "Gray"
    
    Write-ColorOutput "2. Clear cached credentials: " "White" -NoNewline
    Write-ColorOutput "cmdkey /delete:ServerName" "Gray"
    
    Write-ColorOutput "3. Reset network adapter: " "White" -NoNewline
    Write-ColorOutput "netsh winsock reset && netsh int ip reset" "Gray"
    
    Write-ColorOutput "4. Enable SMB2: " "White" -NoNewline
    Write-ColorOutput "Set-SmbClientConfiguration -EnableSMB2Protocol `$true" "Gray"
    
    Write-ColorOutput "5. Check firewall rules for ports 139 and 445" "White"
    
    Write-ColorOutput "6. Verify network discovery is enabled in Network Settings" "White"
    
    Write-ColorOutput "7. Try mapping with IP address instead of hostname" "White"
}

# Main execution
Clear-Host
Write-ColorOutput "Samba/SMB Network Drive Troubleshooting Script" "Cyan"
Write-ColorOutput "=============================================" "Cyan"
Write-ColorOutput "Run as Administrator for complete results" "Yellow"

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if ($isAdmin) {
    Write-ColorOutput "✓ Running with Administrator privileges" "Green"
} else {
    Write-ColorOutput "⚠ Not running as Administrator - some checks may be limited" "Yellow"
}

# Get server details if not provided
if ([string]::IsNullOrEmpty($ServerIP)) {
    $ServerIP = Read-Host "Enter Samba server IP address (optional, press Enter to skip)"
}

if ([string]::IsNullOrEmpty($ShareName) -and ![string]::IsNullOrEmpty($ServerIP)) {
    $ShareName = Read-Host "Enter share name to test (optional, press Enter to skip)"
}

# Run all checks
Get-NetworkServices
Get-SMBClientConfiguration
Get-WindowsFeatures
Get-NetworkDrives
Test-CredentialManager

if (![string]::IsNullOrEmpty($ServerIP)) {
    Test-NetworkConnectivity -Target $ServerIP
    Test-SambaPort -ServerIP $ServerIP
    Test-SMBShare -ServerIP $ServerIP -ShareName $ShareName
}

if ($Detailed) {
    Get-EventLogs
}

Show-TroubleshootingTips

Write-Host ""
Write-ColorOutput "Script completed. Check the results above for any issues." "Cyan"
Write-ColorOutput "For persistent issues, consider running Windows Network Diagnostics or contacting your system administrator." "White"
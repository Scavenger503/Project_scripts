# SMB Client Check Script - Simple & Compatible Version
# Checks local SMB services and destination connectivity
# Works on Windows 10/11 without complex PowerShell cmdlets

param(
    [string]$ServerIP = "",
    [string]$ShareName = ""
)

# Simple output function
function Write-Result {
    param([string]$Message, [string]$Status = "INFO")
    
    switch ($Status) {
        "OK"    { Write-Host "[OK]    $Message" -ForegroundColor Green }
        "ERROR" { Write-Host "[ERROR] $Message" -ForegroundColor Red }
        "WARN"  { Write-Host "[WARN]  $Message" -ForegroundColor Yellow }
        "INFO"  { Write-Host "[INFO]  $Message" -ForegroundColor White }
        "TITLE" { 
            Write-Host ""
            Write-Host "========================================" -ForegroundColor Cyan
            Write-Host $Message -ForegroundColor Cyan
            Write-Host "========================================" -ForegroundColor Cyan
        }
    }
}

function Check-Service {
    param([string]$ServiceName, [string]$DisplayName, [bool]$Critical = $false)
    
    try {
        $service = Get-Service -Name $ServiceName -ErrorAction Stop
        if ($service.Status -eq "Running") {
            Write-Result "$DisplayName is running" "OK"
            return $true
        } else {
            if ($Critical) {
                Write-Result "$DisplayName is $($service.Status) - NETWORK DRIVES WILL NOT WORK" "ERROR"
                Write-Result "Run: net start $ServiceName" "INFO"
            } else {
                Write-Result "$DisplayName is $($service.Status)" "WARN"
            }
            return $false
        }
    } catch {
        if ($Critical) {
            Write-Result "$DisplayName service not found - CRITICAL PROBLEM" "ERROR"
        } else {
            Write-Result "$DisplayName service not available" "WARN"
        }
        return $false
    }
}

function Check-LocalSMBServices {
    Write-Result "LOCAL SMB CLIENT SERVICES" "TITLE"
    
    Write-Result "Checking critical services for network drive functionality..." "INFO"
    
    $critical1 = Check-Service -ServiceName "LanmanWorkstation" -DisplayName "Workstation Service" -Critical $true
    $critical2 = Check-Service -ServiceName "MRxSmb" -DisplayName "SMB 1.x MiniRedirector" -Critical $false
    $critical3 = Check-Service -ServiceName "MRxSmb20" -DisplayName "SMB 2.x/3.x MiniRedirector" -Critical $false
    
    Write-Result "Checking supporting services..." "INFO"
    Check-Service -ServiceName "LanmanServer" -DisplayName "Server Service" -Critical $false
    Check-Service -ServiceName "Browser" -DisplayName "Computer Browser" -Critical $false
    
    if ($critical1) {
        Write-Result "Primary SMB client service is working" "OK"
    } else {
        Write-Result "PRIMARY SMB CLIENT SERVICE IS DOWN - FIX THIS FIRST" "ERROR"
    }
}

function Check-NetworkDrives {
    Write-Result "CURRENT NETWORK DRIVES" "TITLE"
    
    try {
        # Use simple net use command
        $netUse = cmd /c "net use 2>nul"
        
        if ($netUse) {
            $hasDrives = $false
            foreach ($line in $netUse) {
                if ($line -match "^\s*[A-Z]:.*\\\\") {
                    Write-Result "Mapped: $($line.Trim())" "OK"
                    $hasDrives = $true
                }
            }
            
            if (-not $hasDrives) {
                Write-Result "No network drives currently mapped" "INFO"
            }
        } else {
            Write-Result "No network drives found" "INFO"
        }
    } catch {
        Write-Result "Cannot check current network drives" "WARN"
    }
}

function Test-NetworkConnection {
    param([string]$ServerIP)
    
    if ([string]::IsNullOrEmpty($ServerIP)) {
        return $false
    }
    
    Write-Result "Testing network connection to $ServerIP..." "INFO"
    
    try {
        # Use simple ping command
        $pingResult = ping $ServerIP -n 2 -w 3000
        if ($LASTEXITCODE -eq 0) {
            Write-Result "Server $ServerIP is reachable" "OK"
            return $true
        } else {
            Write-Result "Cannot reach server $ServerIP" "ERROR"
            return $false
        }
    } catch {
        Write-Result "Network test failed" "ERROR"
        return $false
    }
}

function Test-SMBPorts {
    param([string]$ServerIP)
    
    if ([string]::IsNullOrEmpty($ServerIP)) {
        return
    }
    
    Write-Result "Testing SMB ports on $ServerIP..." "INFO"
    
    # Test port 445 (main SMB port)
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $result = $tcp.BeginConnect($ServerIP, 445, $null, $null)
        $success = $result.AsyncWaitHandle.WaitOne(3000)
        
        if ($success) {
            $tcp.EndConnect($result)
            Write-Result "Port 445 (SMB) is open" "OK"
        } else {
            Write-Result "Port 445 (SMB) is blocked - SMB connections will fail" "ERROR"
        }
        $tcp.Close()
    } catch {
        Write-Result "Cannot test port 445" "ERROR"
    }
    
    # Test port 139 (NetBIOS)
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $result = $tcp.BeginConnect($ServerIP, 139, $null, $null)
        $success = $result.AsyncWaitHandle.WaitOne(2000)
        
        if ($success) {
            $tcp.EndConnect($result)
            Write-Result "Port 139 (NetBIOS) is open" "OK"
        } else {
            Write-Result "Port 139 (NetBIOS) is not accessible" "WARN"
        }
        $tcp.Close()
    } catch {
        Write-Result "Cannot test port 139" "WARN"
    }
}

function Test-ShareAccess {
    param([string]$ServerIP, [string]$ShareName)
    
    if ([string]::IsNullOrEmpty($ServerIP)) {
        return
    }
    
    Write-Result "SHARE ACCESS TEST" "TITLE"
    
    # Try to list shares
    Write-Result "Attempting to list shares on \\$ServerIP..." "INFO"
    try {
        $netView = cmd /c "net view \\$ServerIP 2>&1"
        
        if ($LASTEXITCODE -eq 0) {
            Write-Result "Successfully connected to \\$ServerIP" "OK"
            
            # Show available shares
            $shareFound = $false
            foreach ($line in $netView) {
                if ($line -match "^\s+(\S+)\s+Disk") {
                    $foundShare = $matches[1]
                    Write-Result "Available share: $foundShare" "INFO"
                    $shareFound = $true
                }
            }
            
            if (-not $shareFound) {
                Write-Result "No disk shares found on server" "WARN"
            }
            
        } else {
            Write-Result "Cannot connect to \\$ServerIP" "ERROR"
            Write-Result "This could be: wrong IP, server down, firewall blocking, or authentication issue" "INFO"
        }
    } catch {
        Write-Result "Share listing failed" "ERROR"
    }
    
    # Test specific share if provided
    if (![string]::IsNullOrEmpty($ShareName)) {
        $uncPath = "\\$ServerIP\$ShareName"
        Write-Result "Testing access to $uncPath..." "INFO"
        
        if (Test-Path $uncPath) {
            Write-Result "Share $uncPath is accessible" "OK"
        } else {
            Write-Result "Share $uncPath is not accessible" "ERROR"
            Write-Result "Check: share name, permissions, or credentials" "INFO"
        }
    }
}

function Test-DriveMapping {
    param([string]$ServerIP, [string]$ShareName)
    
    if ([string]::IsNullOrEmpty($ServerIP) -or [string]::IsNullOrEmpty($ShareName)) {
        return
    }
    
    Write-Result "DRIVE MAPPING TEST" "TITLE"
    
    $uncPath = "\\$ServerIP\$ShareName"
    
    # Find available drive letter
    $testDrive = $null
    for ($i = 90; $i -ge 65; $i--) {  # Z to A
        $letter = [char]$i + ":"
        $existing = cmd /c "net use $letter 2>nul"
        if ($LASTEXITCODE -ne 0) {
            $testDrive = $letter
            break
        }
    }
    
    if ($testDrive) {
        Write-Result "Testing drive mapping: $testDrive -> $uncPath" "INFO"
        
        $mapResult = cmd /c "net use $testDrive $uncPath 2>&1"
        if ($LASTEXITCODE -eq 0) {
            Write-Result "Drive mapping test SUCCESSFUL!" "OK"
            # Clean up
            cmd /c "net use $testDrive /delete /y 2>nul"
            Write-Result "Test mapping cleaned up" "INFO"
        } else {
            Write-Result "Drive mapping test FAILED" "ERROR"
            Write-Result "Error details: $($mapResult -join ' ')" "ERROR"
        }
    } else {
        Write-Result "No available drive letters for testing" "WARN"
    }
}

function Show-FixCommands {
    Write-Result "COMMON FIXES" "TITLE"
    
    Write-Host "If Workstation service is not running:" -ForegroundColor Cyan
    Write-Host "  net start LanmanWorkstation" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "To restart SMB client services:" -ForegroundColor Cyan
    Write-Host "  net stop LanmanWorkstation" -ForegroundColor Gray
    Write-Host "  net start LanmanWorkstation" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "To clear saved credentials:" -ForegroundColor Cyan
    Write-Host "  cmdkey /list" -ForegroundColor Gray
    Write-Host "  cmdkey /delete:SERVERNAME" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "To map a drive manually:" -ForegroundColor Cyan
    Write-Host "  net use Z: \\server\share" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "If SMB 1.0 is needed for old servers:" -ForegroundColor Cyan
    Write-Host "  Go to 'Turn Windows features on or off'" -ForegroundColor Gray
    Write-Host "  Enable 'SMB 1.0/CIFS File Sharing Support'" -ForegroundColor Gray
}

# MAIN SCRIPT
Clear-Host
Write-Result "SMB NETWORK DRIVE DIAGNOSTIC TOOL" "TITLE"

# Check if running as admin
try {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if ($isAdmin) {
        Write-Result "Running as Administrator" "OK"
    } else {
        Write-Result "Not running as Administrator (some fixes may require admin)" "WARN"
    }
} catch {
    Write-Result "Cannot determine admin status" "WARN"
}

# Get server info if not provided
if ([string]::IsNullOrEmpty($ServerIP)) {
    Write-Host ""
    Write-Host "Enter server details (or press Enter to skip server tests):" -ForegroundColor Yellow
    $ServerIP = Read-Host "Server IP address"
}

if (![string]::IsNullOrEmpty($ServerIP) -and [string]::IsNullOrEmpty($ShareName)) {
    $ShareName = Read-Host "Share name (optional)"
}

# Run all checks
Check-LocalSMBServices
Check-NetworkDrives

# Server tests if IP provided
if (![string]::IsNullOrEmpty($ServerIP)) {
    Write-Result "SERVER CONNECTIVITY TESTS" "TITLE"
    
    $networkOK = Test-NetworkConnection -ServerIP $ServerIP
    if ($networkOK) {
        Test-SMBPorts -ServerIP $ServerIP
        Test-ShareAccess -ServerIP $ServerIP -ShareName $ShareName
        Test-DriveMapping -ServerIP $ServerIP -ShareName $ShareName
    } else {
        Write-Result "Skipping other server tests due to network connectivity failure" "WARN"
    }
}

Show-FixCommands

Write-Result "DIAGNOSTIC COMPLETE" "TITLE"
Write-Result "Check the results above - focus on any ERROR messages first" "INFO"

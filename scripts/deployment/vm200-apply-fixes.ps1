# VM200 Apply Fixes Script
# Purpose: Install drivers, fix MSSQL, optimize Windows

Write-Host "=== VM200 Apply Fixes Script ===" -ForegroundColor Cyan
Write-Host ""

# Function to install VirtIO drivers
function Install-VirtIODrivers {
    Write-Host "[Fix 1] Installing VirtIO Drivers..." -ForegroundColor Yellow

    # Find VirtIO ISO
    $virtioISO = Get-Volume | Where-Object {$_.FileSystemLabel -like "*virtio*"} | Select-Object -First 1

    if (-not $virtioISO) {
        Write-Host "✗ VirtIO ISO not found. Please mount virtio-win.iso" -ForegroundColor Red
        return $false
    }

    $viotioDrive = "$($virtioISO.DriveLetter):"
    Write-Host "VirtIO ISO found at: $viotioDrive" -ForegroundColor Green

    # Determine Windows version for driver path
    $os = Get-WmiObject Win32_OperatingSystem
    $driverPath = ""

    if ($os.Caption -like "*2016*") {
        $driverPath = "2k16"
    } elseif ($os.Caption -like "*2019*") {
        $driverPath = "2k19"
    } elseif ($os.Caption -like "*2022*") {
        $driverPath = "2k22"
    } elseif ($os.Caption -like "*Windows 10*") {
        $driverPath = "w10"
    } elseif ($os.Caption -like "*Windows 11*") {
        $driverPath = "w11"
    }

    if (-not $driverPath) {
        Write-Host "✗ Could not determine Windows version for drivers" -ForegroundColor Red
        return $false
    }

    Write-Host "Detected OS: $($os.Caption) - Using driver path: $driverPath" -ForegroundColor Cyan

    # Install VirtIO SCSI driver
    $scsiPath = "$viotioDrive\vioscsi\$driverPath\amd64"
    if (Test-Path $scsiPath) {
        Write-Host "Installing VirtIO SCSI driver from $scsiPath..." -ForegroundColor Yellow
        pnputil /add-driver "$scsiPath\*.inf" /subdirs /install
        Write-Host "✓ VirtIO SCSI driver installed" -ForegroundColor Green
    }

    # Install VirtIO Balloon driver (memory management)
    $balloonPath = "$viotioDrive\Balloon\$driverPath\amd64"
    if (Test-Path $balloonPath) {
        Write-Host "Installing VirtIO Balloon driver from $balloonPath..." -ForegroundColor Yellow
        pnputil /add-driver "$balloonPath\*.inf" /subdirs /install
        Write-Host "✓ VirtIO Balloon driver installed" -ForegroundColor Green
    }

    # Install VirtIO Network driver
    $netPath = "$viotioDrive\NetKVM\$driverPath\amd64"
    if (Test-Path $netPath) {
        Write-Host "Installing VirtIO Network driver from $netPath..." -ForegroundColor Yellow
        pnputil /add-driver "$netPath\*.inf" /subdirs /install
        Write-Host "✓ VirtIO Network driver installed" -ForegroundColor Green
    }

    return $true
}

# Function to install QEMU Guest Agent
function Install-QEMUGuestAgent {
    Write-Host "`n[Fix 2] Installing QEMU Guest Agent..." -ForegroundColor Yellow

    $virtioISO = Get-Volume | Where-Object {$_.FileSystemLabel -like "*virtio*"} | Select-Object -First 1
    if (-not $virtioISO) {
        Write-Host "✗ VirtIO ISO not found" -ForegroundColor Red
        return $false
    }

    $viotioDrive = "$($virtioISO.DriveLetter):"
    $guestAgentPath = "$viotioDrive\guest-agent\qemu-ga-x86_64.msi"

    if (Test-Path $guestAgentPath) {
        Write-Host "Installing QEMU Guest Agent from $guestAgentPath..." -ForegroundColor Yellow
        Start-Process msiexec.exe -ArgumentList "/i `"$guestAgentPath`" /qn /norestart" -Wait
        Write-Host "✓ QEMU Guest Agent installed" -ForegroundColor Green

        # Start the service
        Start-Service "QEMU-GA" -ErrorAction SilentlyContinue
        Set-Service "QEMU-GA" -StartupType Automatic -ErrorAction SilentlyContinue
        Write-Host "✓ QEMU Guest Agent service configured" -ForegroundColor Green
        return $true
    } else {
        Write-Host "✗ QEMU Guest Agent installer not found at $guestAgentPath" -ForegroundColor Red
        return $false
    }
}

# Function to fix SQL Server startup
function Fix-SQLServerStartup {
    Write-Host "`n[Fix 3] Fixing SQL Server Startup..." -ForegroundColor Yellow

    # Find main SQL Server service
    $sqlServices = Get-Service | Where-Object {$_.Name -eq "MSSQLSERVER" -or $_.Name -like "MSSQL$*"}
    $mainSqlService = $sqlServices | Select-Object -First 1

    if (-not $mainSqlService) {
        Write-Host "✗ SQL Server service not found" -ForegroundColor Red
        return $false
    }

    Write-Host "Found SQL Server service: $($mainSqlService.Name)" -ForegroundColor Cyan

    # Set to Automatic (Delayed Start) to avoid dependency issues
    Write-Host "Setting $($mainSqlService.Name) to Automatic (Delayed Start)..." -ForegroundColor Yellow
    sc.exe config "$($mainSqlService.Name)" start= delayed-auto

    # Check and fix dependencies
    Write-Host "Ensuring required services are set to Automatic..." -ForegroundColor Yellow

    # SQL Server depends on these services
    $requiredServices = @("LanmanServer", "RPCSS", "Netman")
    foreach ($svc in $requiredServices) {
        $service = Get-Service -Name $svc -ErrorAction SilentlyContinue
        if ($service) {
            if ($service.StartType -ne "Automatic") {
                Set-Service -Name $svc -StartupType Automatic
                Write-Host "  ✓ Set $svc to Automatic" -ForegroundColor Green
            }
            if ($service.Status -ne "Running") {
                Start-Service -Name $svc -ErrorAction SilentlyContinue
                Write-Host "  ✓ Started $svc" -ForegroundColor Green
            }
        }
    }

    # Try to start SQL Server
    Write-Host "Attempting to start SQL Server..." -ForegroundColor Yellow
    try {
        Start-Service -Name $mainSqlService.Name -ErrorAction Stop
        Write-Host "✓ SQL Server started successfully" -ForegroundColor Green

        # Check status
        $status = Get-Service -Name $mainSqlService.Name
        Write-Host "  Status: $($status.Status)" -ForegroundColor Green
        Write-Host "  StartType: $($status.StartType)" -ForegroundColor Green

        return $true
    } catch {
        Write-Host "✗ Failed to start SQL Server: $($_.Exception.Message)" -ForegroundColor Red

        # Check Event Log for details
        Write-Host "`nChecking Event Log for SQL Server errors..." -ForegroundColor Yellow
        $errors = Get-EventLog -LogName Application -Source "*SQL*" -EntryType Error -Newest 3 -ErrorAction SilentlyContinue
        if ($errors) {
            foreach ($error in $errors) {
                Write-Host "  [$(($error.TimeGenerated))] $($error.Message)" -ForegroundColor Red
            }
        }

        return $false
    }
}

# Function to optimize Windows for VM
function Optimize-WindowsVM {
    Write-Host "`n[Fix 4] Optimizing Windows for VM Experience..." -ForegroundColor Yellow

    # Disable unnecessary visual effects
    Write-Host "Optimizing visual effects..." -ForegroundColor Yellow
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFXSetting" -Value 2 -ErrorAction SilentlyContinue

    # Disable Windows Search indexing for better performance
    Write-Host "Configuring Windows Search..." -ForegroundColor Yellow
    Set-Service "WSearch" -StartupType Manual -ErrorAction SilentlyContinue
    Stop-Service "WSearch" -Force -ErrorAction SilentlyContinue

    # Disable Superfetch/SysMain (not needed in VM)
    Write-Host "Disabling Superfetch/SysMain..." -ForegroundColor Yellow
    Set-Service "SysMain" -StartupType Disabled -ErrorAction SilentlyContinue
    Stop-Service "SysMain" -Force -ErrorAction SilentlyContinue

    # Optimize power plan for performance
    Write-Host "Setting High Performance power plan..." -ForegroundColor Yellow
    powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c

    # Disable hibernation to free disk space
    Write-Host "Disabling hibernation..." -ForegroundColor Yellow
    powercfg /hibernate off

    # Enable VirtIO Balloon service for dynamic memory
    $balloonService = Get-Service "BalloonService" -ErrorAction SilentlyContinue
    if ($balloonService) {
        Set-Service "BalloonService" -StartupType Automatic -ErrorAction SilentlyContinue
        Start-Service "BalloonService" -ErrorAction SilentlyContinue
        Write-Host "✓ VirtIO Balloon service enabled" -ForegroundColor Green
    }

    # Set pagefile to system managed
    Write-Host "Configuring pagefile..." -ForegroundColor Yellow
    $cs = Get-WmiObject -Class Win32_ComputerSystem -EnableAllPrivileges
    $cs.AutomaticManagedPagefile = $true
    $cs.Put() | Out-Null

    Write-Host "✓ Windows optimization complete" -ForegroundColor Green
    return $true
}

# Main execution
Write-Host "Starting fixes..." -ForegroundColor Cyan
Write-Host ""

$results = @{
    "VirtIO_Drivers" = Install-VirtIODrivers
    "QEMU_Guest_Agent" = Install-QEMUGuestAgent
    "SQL_Server_Fix" = Fix-SQLServerStartup
    "Windows_Optimization" = Optimize-WindowsVM
}

# Summary
Write-Host "`n=== Fix Summary ===" -ForegroundColor Cyan
foreach ($fix in $results.GetEnumerator()) {
    $status = if ($fix.Value) { "✓ SUCCESS" } else { "✗ FAILED" }
    $color = if ($fix.Value) { "Green" } else { "Red" }
    Write-Host "$($fix.Key): $status" -ForegroundColor $color
}

Write-Host "`n=== Recommendations ===" -ForegroundColor Cyan
Write-Host "1. Restart VM to apply all driver changes" -ForegroundColor Yellow
Write-Host "2. After restart, verify SQL Server starts automatically" -ForegroundColor Yellow
Write-Host "3. Remove VirtIO ISO from VM configuration (ide3) after drivers are confirmed working" -ForegroundColor Yellow
Write-Host "4. Enable QEMU Guest Agent in Proxmox VM options" -ForegroundColor Yellow

Write-Host "`nRestart now? (Y/N)" -ForegroundColor Cyan
$restart = Read-Host
if ($restart -eq "Y" -or $restart -eq "y") {
    Write-Host "Restarting in 10 seconds..." -ForegroundColor Yellow
    shutdown /r /t 10 /c "Applying VM optimizations - restarting"
}

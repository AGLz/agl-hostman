# VM200 Diagnostic and Fix Script
# Purpose: Install VirtIO drivers, fix MSSQL Server, optimize Windows

Write-Host "=== VM200 Diagnostic and Fix Script ===" -ForegroundColor Cyan
Write-Host ""

# 1. Check VirtIO SCSI Driver
Write-Host "[1/7] Checking VirtIO SCSI Driver..." -ForegroundColor Yellow
$scsiDriver = Get-WmiObject Win32_SCSIController | Where-Object {$_.Name -like "*VirtIO*" -or $_.Name -like "*Red Hat*"}
if ($scsiDriver) {
    Write-Host "✓ VirtIO SCSI driver detected: $($scsiDriver.Name)" -ForegroundColor Green
} else {
    Write-Host "✗ VirtIO SCSI driver NOT detected - needs installation" -ForegroundColor Red
    Write-Host "  Action required: Install from E:\vioscsi\2k16\amd64\" -ForegroundColor Yellow
}

# 2. Check Disk Configuration
Write-Host "`n[2/7] Checking Disk Configuration..." -ForegroundColor Yellow
Get-Disk | Select-Object Number, FriendlyName, Size, PartitionStyle | Format-Table -AutoSize

# 3. Check SQL Server Services
Write-Host "`n[3/7] Checking SQL Server Services..." -ForegroundColor Yellow
$sqlServices = Get-Service | Where-Object {$_.Name -like "*SQL*"}
if ($sqlServices) {
    $sqlServices | Select-Object Name, Status, StartType | Format-Table -AutoSize

    # Identify main SQL Server instance
    $mainSqlService = $sqlServices | Where-Object {$_.Name -eq "MSSQLSERVER" -or $_.Name -like "MSSQL$*"} | Select-Object -First 1

    if ($mainSqlService) {
        Write-Host "`nMain SQL Service: $($mainSqlService.Name)" -ForegroundColor Cyan
        Write-Host "  Status: $($mainSqlService.Status)" -ForegroundColor $(if($mainSqlService.Status -eq "Running"){"Green"}else{"Red"})
        Write-Host "  StartType: $($mainSqlService.StartType)" -ForegroundColor $(if($mainSqlService.StartType -eq "Automatic"){"Green"}else{"Yellow"})
    }
} else {
    Write-Host "✗ No SQL Server services found" -ForegroundColor Red
}

# 4. Check SQL Server Event Logs
Write-Host "`n[4/7] Checking SQL Server Event Logs (last 10 errors)..." -ForegroundColor Yellow
try {
    $sqlErrors = Get-EventLog -LogName Application -Source "*SQL*" -EntryType Error -Newest 10 -ErrorAction SilentlyContinue
    if ($sqlErrors) {
        $sqlErrors | Select-Object TimeGenerated, Message | Format-List
    } else {
        Write-Host "No recent SQL Server errors in Event Log" -ForegroundColor Green
    }
} catch {
    Write-Host "Could not read Application Event Log" -ForegroundColor Yellow
}

# 5. Check SQL Server Startup Dependencies
Write-Host "`n[5/7] Checking SQL Server Service Dependencies..." -ForegroundColor Yellow
if ($mainSqlService) {
    $dependencies = Get-Service -Name $mainSqlService.Name -DependentServices
    if ($dependencies) {
        Write-Host "Dependent Services:"
        $dependencies | Select-Object Name, Status | Format-Table -AutoSize
    }

    $requiredServices = Get-Service -Name $mainSqlService.Name -RequiredServices
    if ($requiredServices) {
        Write-Host "Required Services:"
        $requiredServices | Select-Object Name, Status, StartType | Format-Table -AutoSize
    }
}

# 6. Check Windows Boot Configuration
Write-Host "`n[6/7] Checking Windows Boot Configuration..." -ForegroundColor Yellow
$bootConfig = bcdedit /enum | Select-String "timeout|bootstatuspolicy|safeboot"
$bootConfig

# 7. System Information
Write-Host "`n[7/7] System Information..." -ForegroundColor Yellow
$os = Get-WmiObject Win32_OperatingSystem
Write-Host "OS: $($os.Caption) - Version $($os.Version)" -ForegroundColor Cyan
Write-Host "Last Boot: $($os.ConvertToDateTime($os.LastBootUpTime))" -ForegroundColor Cyan
Write-Host "System Drive: $($os.SystemDrive)" -ForegroundColor Cyan

# Get VirtIO ISO drive
$virtioISO = Get-Volume | Where-Object {$_.FileSystemLabel -like "*virtio*"} | Select-Object -First 1
if ($virtioISO) {
    Write-Host "`nVirtIO ISO mounted at: $($virtioISO.DriveLetter):" -ForegroundColor Green
}

Write-Host "`n=== End of Diagnostic ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps will be provided based on findings..." -ForegroundColor Yellow

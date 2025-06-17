# WorldEdit Snapshot Backup Manager
# PowerShell script for Windows to manage all WorldEdit backup operations

param(
    [switch]$Help = $false
)

# Import shared functions
. "$PSScriptRoot\functions.ps1"

# Show help if requested
if ($Help) {
    Show-ScriptHelp -ScriptName "backup-manager.ps1" -HelpText @"
WorldEdit Snapshot Backup Manager

Usage: .\backup-manager.ps1

This script provides an interactive menu to manage WorldEdit backup operations.

Features:
- One-time backups
- Scheduled daily backups
- Multi-world backups
- Service management
- Status monitoring

"@
}

# Function to show main menu
function Show-MainMenu {
    Clear-Host
    Write-Host "WorldEdit Snapshot Backup Manager" -ForegroundColor Cyan
    Write-Host "=================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. Run One-Time Backup" -ForegroundColor White
    Write-Host "2. Start Daily Backup Service" -ForegroundColor White
    Write-Host "3. Service Management" -ForegroundColor White
    Write-Host "4. View Backup Status" -ForegroundColor White
    Write-Host "5. View Backup Logs" -ForegroundColor White
    Write-Host "6. Exit" -ForegroundColor White
    Write-Host ""
}

# Function to show service management menu
function Show-ServiceMenu {
    Clear-Host
    Write-Host "Service Management" -ForegroundColor Cyan
    Write-Host "==================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. Start Daily Backup Service" -ForegroundColor White
    Write-Host "2. Stop Daily Backup Service" -ForegroundColor White
    Write-Host "3. Restart Daily Backup Service" -ForegroundColor White
    Write-Host "4. View Service Status" -ForegroundColor White
    Write-Host "5. Back to Main Menu" -ForegroundColor White
    Write-Host ""
}

# Function to run one-time backup
function Start-OneTimeBackup {
    Clear-Host
    Write-Host "One-Time Backup Configuration" -ForegroundColor Cyan
    Write-Host "=============================" -ForegroundColor Cyan
    Write-Host ""
    
    $worldPath = Read-Host "World path (press Enter for auto-detection)"
    $backupPath = Read-Host "Backup path (press Enter for auto-detection)"
    $compression = Read-Host "Compression type (zip/tar.gz/none) [zip]"
    if ([string]::IsNullOrEmpty($compression)) { $compression = "zip" }
    
    $regionOnly = Read-Host "Region only backup? (y/N)"
    $regionOnlyFlag = ""
    if ($regionOnly -eq "y" -or $regionOnly -eq "Y") {
        $regionOnlyFlag = "-RegionOnly"
    }
    
    Write-Host "`nStarting one-time backup..." -ForegroundColor Yellow
    
    $args = @()
    if (-not [string]::IsNullOrEmpty($worldPath)) { $args += "-WorldPath"; $args += $worldPath }
    if (-not [string]::IsNullOrEmpty($backupPath)) { $args += "-BackupPath"; $args += $backupPath }
    if ($compression -ne "zip") { $args += "-CompressionType"; $args += $compression }
    if ($regionOnlyFlag) { $args += $regionOnlyFlag }
    
    & ".\backup-now.ps1" @args
    
    Wait-ForUserInput
}

# Function to start daily backup service
function Start-DailyBackupService {
    Clear-Host
    Write-Host "Daily Backup Service Configuration" -ForegroundColor Cyan
    Write-Host "===================================" -ForegroundColor Cyan
    Write-Host ""
    
    $worldPath = Read-Host "World path (press Enter for auto-detection)"
    $backupPath = Read-Host "Backup path (press Enter for auto-detection)"
    $schedule = Read-Host "Schedule (cron format) [0 2 * * *]"
    if ([string]::IsNullOrEmpty($schedule)) { $schedule = "0 2 * * *" }
    
    $retention = Read-Host "Retention (number of backups) [7]"
    if ([string]::IsNullOrEmpty($retention)) { $retention = "7" }
    
    $compression = Read-Host "Compression type (zip/tar.gz/none) [zip]"
    if ([string]::IsNullOrEmpty($compression)) { $compression = "zip" }
    
    $regionOnly = Read-Host "Region only backup? (y/N)"
    $regionOnlyFlag = ""
    if ($regionOnly -eq "y" -or $regionOnly -eq "Y") {
        $regionOnlyFlag = "-RegionOnly"
    }
    
    Write-Host "`nStarting daily backup service..." -ForegroundColor Yellow
    
    $args = @()
    if (-not [string]::IsNullOrEmpty($worldPath)) { $args += "-WorldPath"; $args += $worldPath }
    if (-not [string]::IsNullOrEmpty($backupPath)) { $args += "-BackupPath"; $args += $backupPath }
    if ($schedule -ne "0 2 * * *") { $args += "-Schedule"; $args += $schedule }
    if ($retention -ne "7") { $args += "-Retention"; $args += $retention }
    if ($compression -ne "zip") { $args += "-CompressionType"; $args += $compression }
    if ($regionOnlyFlag) { $args += $regionOnlyFlag }
    
    & ".\backup-daily.ps1" @args
    
    Wait-ForUserInput
}

# Function to manage services
function Manage-Services {
    do {
        Show-ServiceMenu
        $choice = Get-UserChoice
        
        switch ($choice) {
            1 { # Start service
                Write-Host "Starting daily backup service..." -ForegroundColor Yellow
                & ".\backup-daily.ps1"
                Wait-ForUserInput
            }
            2 { # Stop service
                Write-Host "Stopping daily backup service..." -ForegroundColor Yellow
                & ".\backup-daily.ps1" -Stop
                Wait-ForUserInput
            }
            3 { # Restart service
                Write-Host "Restarting daily backup service..." -ForegroundColor Yellow
                & ".\backup-daily.ps1" -Stop
                Start-Sleep -Seconds 2
                & ".\backup-daily.ps1"
                Wait-ForUserInput
            }
            4 { # View status
                & ".\backup-daily.ps1" -Status
                Wait-ForUserInput
            }
            5 { # Back to main menu
                return
            }
            default {
                Write-Host "Invalid choice. Press any key to continue..." -ForegroundColor Red
                Wait-ForUserInput
            }
        }
    } while ($true)
}

# Function to view backup status
function View-BackupStatus {
    Clear-Host
    Write-Host "Backup Status" -ForegroundColor Cyan
    Write-Host "=============" -ForegroundColor Cyan
    Write-Host ""
    
    # Check if .env file exists
    if (Test-Path ".env") {
        Write-Host "Configuration file found (.env)" -ForegroundColor Green
        Write-Host ""
        Write-Host "Configuration:" -ForegroundColor Yellow
        Get-Content ".env" | ForEach-Object {
            if ($_ -match '^[^#]' -and $_ -match '=') {
                Write-Host "  $_" -ForegroundColor White
            }
        }
    } else {
        Write-Host "No configuration file found (.env)" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "Docker Services:" -ForegroundColor Yellow
    try {
        docker compose ps
    }
    catch {
        Write-Host "  No Docker services running" -ForegroundColor Gray
    }
    
    Wait-ForUserInput
}

# Function to view backup logs
function View-BackupLogs {
    Clear-Host
    Write-Host "Backup Logs" -ForegroundColor Cyan
    Write-Host "===========" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "Select service to view logs:" -ForegroundColor Yellow
    Write-Host "1. Daily backup service" -ForegroundColor White
    Write-Host "2. Hourly backup service" -ForegroundColor White
    Write-Host "3. Weekly backup service" -ForegroundColor White
    Write-Host "4. Back to main menu" -ForegroundColor White
    Write-Host ""
    
    $choice = Get-UserChoice
    
    switch ($choice) {
        1 { # Daily backup logs
            Write-Host "`nDaily backup service logs:" -ForegroundColor Yellow
            docker compose logs --tail=20 worldedit-backup-daily
        }
        2 { # Hourly backup logs
            Write-Host "`nHourly backup service logs:" -ForegroundColor Yellow
            docker compose logs --tail=20 worldedit-backup-hourly
        }
        3 { # Weekly backup logs
            Write-Host "`nWeekly backup service logs:" -ForegroundColor Yellow
            docker compose logs --tail=20 worldedit-backup-weekly
        }
        4 { # Back to main menu
            return
        }
        default {
            Write-Host "Invalid choice." -ForegroundColor Red
        }
    }
    
    Wait-ForUserInput
}

# Main script execution
Write-Host "WorldEdit Snapshot Backup Manager" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan

# Check prerequisites
if (-not (Test-Prerequisites)) {
    exit 1
}

Write-Host "Docker and Docker Compose detected. Starting manager..." -ForegroundColor Green
Start-Sleep -Seconds 2

# Main menu loop
do {
    Show-MainMenu
    $choice = Get-UserChoice
    
    switch ($choice) {
        1 { # One-time backup
            Start-OneTimeBackup
        }
        2 { # Start daily backup service
            Start-DailyBackupService
        }
        3 { # Service management
            Manage-Services
        }
        4 { # View backup status
            View-BackupStatus
        }
        5 { # View backup logs
            View-BackupLogs
        }
        6 { # Exit
            Write-Host "Goodbye!" -ForegroundColor Green
            exit 0
        }
        default {
            Write-Host "Invalid choice. Press any key to continue..." -ForegroundColor Red
            Wait-ForUserInput
        }
    }
} while ($true) 
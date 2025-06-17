# WorldEdit Snapshot Backup - Daily Scheduled Backup
# PowerShell script for Windows to start daily WorldEdit backups

param(
    [string]$WorldPath = "",
    [string]$BackupPath = "",
    [string]$WorldName = "world",
    [string]$CompressionType = "zip",
    [switch]$RegionOnly = $false,
    [string]$Schedule = "0 2 * * *",
    [int]$Retention = 7,
    [switch]$Stop = $false,
    [switch]$Status = $false,
    [switch]$Help = $false
)

# Import shared functions
. "$PSScriptRoot\functions.ps1"

# Show help if requested
if ($Help) {
    Show-ScriptHelp -ScriptName "backup-daily.ps1" -HelpText @"
WorldEdit Snapshot Backup - Daily Scheduled Backup

Usage: .\backup-daily.ps1 [options]

Options:
    -WorldPath <path>        Path to Minecraft world folder (auto-detected if not specified)
    -BackupPath <path>       Path to store backups (auto-detected if not specified)
    -WorldName <name>        World name for backup structure (default: world)
    -CompressionType <type>  Compression type: zip, tar.gz, none (default: zip)
    -RegionOnly              Backup only region folder to save space
    -Schedule <cron>         Cron schedule (default: "0 2 * * *" = 2 AM daily)
    -Retention <number>      Number of backups to keep (default: 7)
    -Stop                    Stop the daily backup service
    -Status                  Show status of the daily backup service
    -Help                    Show this help message

Examples:
    .\backup-daily.ps1
    .\backup-daily.ps1 -WorldPath "C:\minecraft\server\world" -BackupPath "D:\backups"
    .\backup-daily.ps1 -RegionOnly -Retention 14
    .\backup-daily.ps1 -Stop
    .\backup-daily.ps1 -Status

"@
}

# Main script execution
Write-Host "WorldEdit Snapshot Backup - Daily Scheduled Backup" -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan

# Handle status check
if ($Status) {
    Show-ServiceStatus -ServiceName "worldedit-backup-daily"
    exit 0
}

# Handle stop command
if ($Stop) {
    Write-Host "Stopping daily backup service..." -ForegroundColor Yellow
    try {
        $exitCode = Invoke-DockerCompose -Command "stop" -ServiceName "worldedit-backup-daily"
        if ($exitCode -eq 0) {
            Write-Host "Daily backup service stopped successfully" -ForegroundColor Green
        } else {
            Write-Host "Failed to stop daily backup service" -ForegroundColor Red
            exit 1
        }
    }
    catch {
        Write-Host "Failed to stop service: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
    exit 0
}

# Check prerequisites
if (-not (Test-Prerequisites)) {
    exit 1
}

# Auto-detect or use provided paths
if ([string]::IsNullOrEmpty($WorldPath)) {
    $WorldPath = Get-DefaultWorldPath
} else {
    if (-not (Test-WorldPath -Path $WorldPath -WorldType "World")) {
        exit 1
    }
}

if ([string]::IsNullOrEmpty($BackupPath)) {
    $BackupPath = Get-DefaultBackupPath
} else {
    if (-not (Test-AndCreateBackupDirectory -BackupPath $BackupPath)) {
        exit 1
    }
}

# Validate compression type
if (-not (Test-CompressionType -CompressionType $CompressionType)) {
    exit 1
}

# Validate retention
if (-not (Test-Retention -Retention $Retention)) {
    exit 1
}

# Display configuration
Show-BackupConfiguration -WorldPath $WorldPath -BackupPath $BackupPath -WorldName $WorldName -CompressionType $CompressionType -RegionOnly $RegionOnly -Schedule $Schedule -Retention $Retention

# Create .env file
New-EnvFileWithSchedule -WorldPath $WorldPath -BackupPath $BackupPath -WorldName $WorldName -CompressionType $CompressionType -RegionOnly $RegionOnly -Schedule $Schedule -Retention $Retention

# Build Docker image if needed
if (-not (Build-DockerImage -ServiceName "worldedit-backup-daily")) {
    exit 1
}

# Start daily backup service
Write-Host "`nStarting daily backup service..." -ForegroundColor Yellow
try {
    $exitCode = Invoke-DockerCompose -Command "up -d" -ServiceName "worldedit-backup-daily"
    if ($exitCode -eq 0) {
        Write-Host "`nDaily backup service started successfully!" -ForegroundColor Green
        Write-Host "Service will run according to schedule: $Schedule" -ForegroundColor Cyan
        Write-Host "Backup location: $BackupPath" -ForegroundColor Cyan
        Write-Host "Retention: $Retention backups" -ForegroundColor Cyan
        
        Write-Host "`nUseful commands:" -ForegroundColor Yellow
        Write-Host "  .\backup-daily.ps1 -Status    # Check service status" -ForegroundColor Gray
        Write-Host "  .\backup-daily.ps1 -Stop      # Stop the service" -ForegroundColor Gray
        Write-Host "  docker compose logs -f worldedit-backup-daily  # Follow logs" -ForegroundColor Gray
    } else {
        Write-Host "`nFailed to start daily backup service" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host "`nFailed to start service: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "`nDone!" -ForegroundColor Green 
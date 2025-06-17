# WorldEdit Snapshot Backup - One Time Backup
# PowerShell script for Windows to run a single WorldEdit backup

param(
    [string]$WorldPath = "",
    [string]$BackupPath = "",
    [string]$WorldName = "world",
    [string]$CompressionType = "zip",
    [switch]$RegionOnly = $false,
    [switch]$FullBackup = $false,
    [switch]$Help = $false
)

# Import shared functions
. "$PSScriptRoot\functions.ps1"

# Show help if requested
if ($Help) {
    Show-ScriptHelp -ScriptName "backup-now.ps1" -HelpText @"
WorldEdit Snapshot Backup - One Time Backup

Usage: .\backup-now.ps1 [options]

Options:
    -WorldPath <path>        Path to Minecraft world folder (auto-detected if not specified)
    -BackupPath <path>       Path to store backups (auto-detected if not specified)
    -WorldName <name>        World name for backup structure (default: world)
    -CompressionType <type>  Compression type: zip, tar.gz, none (default: zip)
    -RegionOnly              Backup only region folder to save space
    -FullBackup              Backup the entire .minecraft folder with "-full" suffix
    -Help                    Show this help message

Examples:
    .\backup-now.ps1
    .\backup-now.ps1 -WorldPath "C:\minecraft\server\world" -BackupPath "D:\backups"
    .\backup-now.ps1 -RegionOnly -CompressionType tar.gz
    .\backup-now.ps1 -FullBackup

"@
}

# Main script execution
Write-Host "WorldEdit Snapshot Backup - One Time Backup" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

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

# Display configuration
Show-BackupConfiguration -WorldPath $WorldPath -BackupPath $BackupPath -WorldName $WorldName -CompressionType $CompressionType -RegionOnly $RegionOnly -FullBackup $FullBackup

# Create .env file
New-EnvFile -WorldPath $WorldPath -BackupPath $BackupPath -WorldName $WorldName -CompressionType $CompressionType -RegionOnly $RegionOnly -FullBackup $FullBackup

# Build Docker image if needed
if (-not (Build-DockerImage -ServiceName "worldedit-backup-now" -Profile "worldedit-backup")) {
    exit 1
}

# Run backup
Write-Host "`nStarting WorldEdit backup..." -ForegroundColor Yellow

# Capture Docker output and exit code separately
$dockerOutput = & docker compose --profile worldedit-backup up worldedit-backup-now 2>&1
$exitCode = $LASTEXITCODE

# Add a clear separator after Docker output
Write-Host "`n" -ForegroundColor White

if ($exitCode -eq 0) {
    Write-Host "✅ Backup completed successfully!" -ForegroundColor Green
    Write-Host "📁 Backup location: $BackupPath" -ForegroundColor Cyan
    
    # Extract backup filename from Docker output
    $backupFile = $dockerOutput | Select-String "completed.*\.(zip|tar\.gz)$" | ForEach-Object { 
        $_.Matches[0].Value -replace ".*completed: /backups/", "" 
    }
    if ($backupFile) {
        Write-Host "📦 Backup file: $backupFile" -ForegroundColor Cyan
    }
    
    # Show backup type
    if ($FullBackup) {
        Write-Host "🔧 Backup type: Full .minecraft folder" -ForegroundColor Yellow
    } else {
        Write-Host "🔧 Backup type: WorldEdit snapshot" -ForegroundColor Yellow
    }
} else {
    Write-Host "❌ Backup failed with exit code: $exitCode" -ForegroundColor Red
    Write-Host "`nDocker output:" -ForegroundColor Gray
    Write-Host $dockerOutput -ForegroundColor Gray
    exit 1
}

Write-Host "`n🎉 Done!" -ForegroundColor Green 
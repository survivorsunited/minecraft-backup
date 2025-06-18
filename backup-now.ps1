# WorldEdit Snapshot Backup - One Time Backup
# Description: Creates a one-time backup of a Minecraft world
# Usage: .\backup-now.ps1 [-WorldPath <path>] [-BackupPath <path>] [-WorldName <name>] [-CompressionType <type>] [-RegionOnly] [-FullBackup]

param(
    [string]$WorldPath,
    [string]$BackupPath,
    [string]$WorldName = "world",
    [ValidateSet("zip", "tar.gz", "tgz", "none")]
    [string]$CompressionType = "zip",
    [switch]$RegionOnly,
    [switch]$FullBackup
)

# Import shared functions
. "$PSScriptRoot\functions.ps1"

Write-Host "WorldEdit Snapshot Backup - One Time Backup" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Note: If the Minecraft server is running, some files may be locked." -ForegroundColor Yellow
Write-Host "The script will automatically fall back to Docker mode if needed." -ForegroundColor Yellow
Write-Host ""

# Auto-detect paths if not provided
if (-not $WorldPath) {
    $WorldPath = Get-DefaultWorldPath
}
if (-not $BackupPath) {
    $BackupPath = Get-DefaultBackupPath
}

# Validate paths
if (-not (Test-WorldPath $WorldPath)) {
    exit 1
}

# Validate compression type
if (-not (Test-CompressionType $CompressionType)) {
    exit 1
}

# Display configuration
Write-Host ""
Write-Host "Backup Configuration:" -ForegroundColor Yellow
Write-Host "  World Path: $WorldPath" -ForegroundColor White
Write-Host "  Backup Path: $BackupPath" -ForegroundColor White
Write-Host "  World Name: $WorldName" -ForegroundColor White
Write-Host "  Compression: $CompressionType" -ForegroundColor White
Write-Host "  Region Only: $RegionOnly" -ForegroundColor White
Write-Host "  Full Backup: $FullBackup" -ForegroundColor White

# Create .env file
New-EnvFile -WorldPath $WorldPath -BackupPath $BackupPath -WorldName $WorldName -CompressionType $CompressionType -RegionOnly $RegionOnly -FullBackup $FullBackup

# Load environment variables
if (Test-Path ".env") {
    Get-Content ".env" | ForEach-Object {
        if ($_ -match "^([^#][^=]+)=(.*)$") {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            Set-Variable -Name $name -Value $value -Scope Global
        }
    }
}

# Determine backup mode (default to native)
$backupMode = if ($env:BACKUP_MODE) { $env:BACKUP_MODE } else { "native" }
Write-Host ""
Write-Host "Backup Mode: $backupMode" -ForegroundColor Magenta

if ($backupMode -eq "native") {
    # Native PowerShell backup
    Write-Host "Using native PowerShell backup with 7zip..." -ForegroundColor Green
    
    # Check if 7zip is available
    $7zipPath = Test-7ZipAvailable
    if (-not $7zipPath) {
        Write-Host "7zip not found. Falling back to Docker mode..." -ForegroundColor Yellow
        $backupMode = "docker"
    }
    else {
        Write-Host "7zip found: $7zipPath" -ForegroundColor Green
        
        # Create timestamp
        $timestamp = Get-Date -Format "yyyy-MM-dd-HH-mm-ss"
        
        # Determine world path for native backup
        # If the provided path is already a world path, use it directly
        # Otherwise, calculate the minecraft home path
        if ((Split-Path $WorldPath -Leaf) -eq $WorldName) {
            # User provided a world path directly, use it as is
            $actualWorldPath = $WorldPath
        } else {
            # User provided a minecraft home path, calculate world path
            $minecraftHomePath = $WorldPath
            $actualWorldPath = Get-WorldPath -MinecraftHomePath $minecraftHomePath -WorldName $WorldName
        }
        
        # Create backup
        try {
            $backupFile = New-NativeBackup -WorldPath $actualWorldPath -BackupPath $BackupPath -WorldName $WorldName -CompressionType $CompressionType -RegionOnly $RegionOnly -FullBackup $FullBackup -Timestamp $timestamp -Retention 0
            
            Write-Host ""
            Write-Host "✅ Backup completed successfully!" -ForegroundColor Green
            Write-Host "📁 Backup location: $BackupPath" -ForegroundColor Cyan
            Write-Host "📦 Backup file: $(Split-Path $backupFile -Leaf)" -ForegroundColor Cyan
            Write-Host "🔧 Backup type: $(if ($FullBackup) { 'Full .minecraft folder' } else { 'WorldEdit snapshot' })" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "🎉 Done!" -ForegroundColor Green
            exit 0
        }
        catch {
            $exitCode = $LASTEXITCODE
            if ($exitCode -eq 2) {
                Write-Host "Native backup failed due to file access issues (Minecraft server may be running)." -ForegroundColor Yellow
                Write-Host "Automatically falling back to Docker mode..." -ForegroundColor Yellow
                $backupMode = "docker"
            } else {
                Write-Host "Native backup failed. Falling back to Docker mode..." -ForegroundColor Yellow
                $backupMode = "docker"
            }
        }
    }
}

if ($backupMode -eq "docker") {
    # Docker backup
    Write-Host "Using Docker backup..." -ForegroundColor Green
    
    # Check Docker availability
    if (-not (Test-DockerAvailable)) {
        Write-Host "Docker not available. Cannot proceed with backup." -ForegroundColor Red
        exit 1
    }
    
    if (-not (Test-DockerComposeAvailable)) {
        Write-Host "Docker Compose not available. Cannot proceed with backup." -ForegroundColor Red
        exit 1
    }
    
    Write-Host "Building Docker image..." -ForegroundColor Yellow
    
    # Build and run Docker container
    try {
        docker compose --profile worldedit-backup build worldedit-backup-now
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Failed to build Docker image" -ForegroundColor Red
            exit 1
        }
        
        Write-Host ""
        Write-Host "Starting WorldEdit backup..." -ForegroundColor Yellow
        
        # Run the backup
        docker compose --profile worldedit-backup up worldedit-backup-now
        $exitCode = $LASTEXITCODE
        
        # Clean up
        docker compose --profile worldedit-backup down
        
        if ($exitCode -eq 0) {
            Write-Host ""
            Write-Host "✅ Backup completed successfully!" -ForegroundColor Green
            Write-Host "📁 Backup location: $BackupPath" -ForegroundColor Cyan
            Write-Host "🔧 Backup type: $(if ($FullBackup) { 'Full .minecraft folder' } else { 'WorldEdit snapshot' })" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "🎉 Done!" -ForegroundColor Green
        }
        else {
            Write-Host ""
            Write-Host "❌ Backup failed!" -ForegroundColor Red
            exit 1
        }
    }
    catch {
        Write-Host "Docker backup failed: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
} 
# WorldEdit Snapshot Backup - Shared Functions
# PowerShell functions shared across all backup scripts

# Function to detect default Minecraft world path
function Get-DefaultWorldPath {
    $possiblePaths = @(
        "C:\minecraft\server\world",
        "C:\minecraft\world",
        "C:\Program Files\Minecraft Server\world",
        "C:\Program Files (x86)\Minecraft Server\world",
        "$env:USERPROFILE\AppData\Roaming\.minecraft\saves\world",
        "$env:USERPROFILE\Desktop\minecraft\world",
        "$env:USERPROFILE\Documents\minecraft\world"
    )
    
    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            if (Test-Path "$path\region") {
                Write-Host "Auto-detected world path: $path" -ForegroundColor Green
                return $path
            }
        }
    }
    
    Write-Host "Could not auto-detect world path. Please specify -WorldPath parameter." -ForegroundColor Red
    Write-Host "Common locations:" -ForegroundColor Yellow
    foreach ($path in $possiblePaths) {
        Write-Host "  $path" -ForegroundColor Gray
    }
    exit 1
}

# Function to detect default backup path relative to .minecraft folder
function Get-DefaultBackupPath {
    # First, try to find the .minecraft folder
    $minecraftPaths = @(
        "$env:USERPROFILE\AppData\Roaming\.minecraft",
        "$env:USERPROFILE\.minecraft",
        "C:\.minecraft"
    )
    
    $minecraftPath = $null
    foreach ($path in $minecraftPaths) {
        if (Test-Path $path) {
            $minecraftPath = $path
            break
        }
    }
    
    # If .minecraft folder found, create backup INSIDE .minecraft
    if ($minecraftPath) {
        $backupPath = Join-Path $minecraftPath "backups"
        
        # Check if the backup path already exists
        if (Test-Path $backupPath) {
            Write-Host "Auto-detected backup path: $backupPath" -ForegroundColor Green
            return $backupPath
        }
        
        # Create default backup directory INSIDE .minecraft
        Write-Host "Creating default backup directory: $backupPath" -ForegroundColor Yellow
        try {
            New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
            Write-Host "Created backup directory: $backupPath" -ForegroundColor Green
            return $backupPath
        }
        catch {
            Write-Host "Failed to create backup directory: $backupPath" -ForegroundColor Red
            Write-Host "Please specify -BackupPath parameter." -ForegroundColor Red
            exit 1
        }
    }
    
    # Fallback to old behavior if .minecraft not found
    $possiblePaths = @(
        "C:\minecraft\backups",
        "C:\backups\minecraft",
        "D:\backups\minecraft",
        "$env:USERPROFILE\Documents\minecraft\backups",
        "$env:USERPROFILE\Desktop\minecraft\backups"
    )
    
    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            Write-Host "Auto-detected backup path: $path" -ForegroundColor Green
            return $path
        }
    }
    
    # Create default backup directory
    $defaultPath = "C:\minecraft\backups"
    Write-Host "Creating default backup directory: $defaultPath" -ForegroundColor Yellow
    try {
        New-Item -ItemType Directory -Path $defaultPath -Force | Out-Null
        Write-Host "Created backup directory: $defaultPath" -ForegroundColor Green
        return $defaultPath
    }
    catch {
        Write-Host "Failed to create backup directory. Please specify -BackupPath parameter." -ForegroundColor Red
        exit 1
    }
}

# Function to check if Docker is available
function Test-DockerAvailable {
    try {
        $dockerVersion = docker --version 2>$null
        if ($dockerVersion) {
            Write-Host "Docker detected: $dockerVersion" -ForegroundColor Green
            return $true
        }
    }
    catch {
        Write-Host "Docker not found. Please install Docker Desktop for Windows." -ForegroundColor Red
        return $false
    }
    return $false
}

# Function to check if docker-compose is available
function Test-DockerComposeAvailable {
    try {
        $composeVersion = docker-compose --version 2>$null
        if ($composeVersion) {
            Write-Host "Docker Compose detected: $composeVersion" -ForegroundColor Green
            return $true
        }
    }
    catch {
        Write-Host "Docker Compose not found. Please install Docker Compose." -ForegroundColor Red
        return $false
    }
    return $false
}

# Function to validate world path
function Test-WorldPath {
    param([string]$Path, [string]$WorldType = "World")
    
    if ([string]::IsNullOrEmpty($Path)) {
        return $false
    }
    
    if (-not (Test-Path $Path)) {
        Write-Host "$WorldType path does not exist: $Path" -ForegroundColor Red
        return $false
    }
    
    if (-not (Test-Path "$Path\region")) {
        Write-Host "$WorldType path does not contain region folder: $Path" -ForegroundColor Red
        return $false
    }
    
    return $true
}

# Function to validate compression type
function Test-CompressionType {
    param([string]$CompressionType)
    
    $validCompressionTypes = @("zip", "tar.gz", "tgz", "none")
    if ($validCompressionTypes -notcontains $CompressionType) {
        Write-Host "Invalid compression type: $CompressionType" -ForegroundColor Red
        Write-Host "Valid types: $($validCompressionTypes -join ', ')" -ForegroundColor Yellow
        return $false
    }
    return $true
}

# Function to create .env file for single world backup
function New-EnvFile {
    param(
        [string]$WorldPath,
        [string]$BackupPath,
        [string]$WorldName,
        [string]$CompressionType,
        [bool]$RegionOnly,
        [bool]$FullBackup = $false
    )
    
    $envContent = @"
# WorldEdit Snapshot Backup Configuration
# Generated by PowerShell script

# Minecraft World Paths
MINECRAFT_WORLD_PATH=$($WorldPath.Replace('\', '/'))
MINECRAFT_WORLD_NAME=$WorldName

# WorldEdit Backup Configuration
WORLDEDIT_BACKUP_PATH=$($BackupPath.Replace('\', '/'))
WORLDEDIT_TMP_DIR=/tmp/minecraft_backup
WORLDEDIT_COMPRESSION_TYPE=$CompressionType
WORLDEDIT_REGION_ONLY=$($RegionOnly.ToString().ToLower())
WORLDEDIT_FULL_BACKUP=$($FullBackup.ToString().ToLower())

# WorldEdit Backup Schedules (Cron Expressions)
WORLDEDIT_CRON_HOURLY=0 * * * *
WORLDEDIT_CRON_DAILY=0 2 * * *
WORLDEDIT_CRON_WEEKLY=0 3 * * 0

# WorldEdit Backup Retention
WORLDEDIT_FILES_TO_KEEP_HOURLY=24
WORLDEDIT_FILES_TO_KEEP_DAILY=7
WORLDEDIT_FILES_TO_KEEP_WEEKLY=4

# Timezone
TZ=UTC
"@
    
    $envContent | Out-File -FilePath ".env" -Encoding UTF8
    Write-Host "Created .env file with configuration" -ForegroundColor Green
}

# Function to create .env file with custom schedule and retention
function New-EnvFileWithSchedule {
    param(
        [string]$WorldPath,
        [string]$BackupPath,
        [string]$WorldName,
        [string]$CompressionType,
        [bool]$RegionOnly,
        [string]$Schedule,
        [int]$Retention
    )
    
    $envContent = @"
# WorldEdit Snapshot Backup Configuration
# Generated by PowerShell script

# Minecraft World Paths
MINECRAFT_WORLD_PATH=$($WorldPath.Replace('\', '/'))
MINECRAFT_WORLD_NAME=$WorldName

# WorldEdit Backup Configuration
WORLDEDIT_BACKUP_PATH=$($BackupPath.Replace('\', '/'))
WORLDEDIT_TMP_DIR=/tmp/minecraft_backup
WORLDEDIT_COMPRESSION_TYPE=$CompressionType
WORLDEDIT_REGION_ONLY=$($RegionOnly.ToString().ToLower())

# WorldEdit Backup Schedules (Cron Expressions)
WORLDEDIT_CRON_HOURLY=0 * * * *
WORLDEDIT_CRON_DAILY=$Schedule
WORLDEDIT_CRON_WEEKLY=0 3 * * 0

# WorldEdit Backup Retention
WORLDEDIT_FILES_TO_KEEP_HOURLY=24
WORLDEDIT_FILES_TO_KEEP_DAILY=$Retention
WORLDEDIT_FILES_TO_KEEP_WEEKLY=4

# Timezone
TZ=UTC
"@
    
    $envContent | Out-File -FilePath ".env" -Encoding UTF8
    Write-Host "Created .env file with configuration" -ForegroundColor Green
}

# Function to build Docker image
function Build-DockerImage {
    param([string]$ServiceName)
    
    Write-Host "Building Docker image..." -ForegroundColor Yellow
    try {
        docker-compose build $ServiceName
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Failed to build Docker image" -ForegroundColor Red
            return $false
        }
        return $true
    }
    catch {
        Write-Host "Failed to build Docker image: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to show service status
function Show-ServiceStatus {
    param([string]$ServiceName = "worldedit-backup-daily")
    
    Write-Host "`nChecking $ServiceName service status..." -ForegroundColor Yellow
    
    try {
        $containers = docker-compose ps $ServiceName 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Service Status:" -ForegroundColor Green
            Write-Host $containers -ForegroundColor White
        } else {
            Write-Host "Service is not running" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "Failed to check service status: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Show recent logs
    Write-Host "`nRecent logs:" -ForegroundColor Yellow
    try {
        docker-compose logs --tail=10 $ServiceName
    }
    catch {
        Write-Host "No logs available" -ForegroundColor Gray
    }
}

# Function to display backup configuration
function Show-BackupConfiguration {
    param(
        [string]$WorldPath,
        [string]$BackupPath,
        [string]$WorldName,
        [string]$CompressionType,
        [bool]$RegionOnly,
        [string]$Schedule = "",
        [int]$Retention = 0,
        [bool]$FullBackup = $false
    )
    
    Write-Host "`nBackup Configuration:" -ForegroundColor Yellow
    Write-Host "  World Path: $WorldPath" -ForegroundColor White
    Write-Host "  Backup Path: $BackupPath" -ForegroundColor White
    Write-Host "  World Name: $WorldName" -ForegroundColor White
    Write-Host "  Compression: $CompressionType" -ForegroundColor White
    Write-Host "  Region Only: $RegionOnly" -ForegroundColor White
    Write-Host "  Full Backup: $FullBackup" -ForegroundColor White
    
    if ($Schedule) {
        Write-Host "  Schedule: $Schedule" -ForegroundColor White
    }
    if ($Retention -gt 0) {
        Write-Host "  Retention: $Retention backups" -ForegroundColor White
    }
}

# Function to check prerequisites
function Test-Prerequisites {
    if (-not (Test-DockerAvailable)) {
        return $false
    }
    
    if (-not (Test-DockerComposeAvailable)) {
        return $false
    }
    
    return $true
}

# Function to validate and create backup directory
function Test-AndCreateBackupDirectory {
    param([string]$BackupPath)
    
    if (-not (Test-Path $BackupPath)) {
        Write-Host "Creating backup directory: $BackupPath" -ForegroundColor Yellow
        try {
            New-Item -ItemType Directory -Path $BackupPath -Force | Out-Null
            return $true
        }
        catch {
            Write-Host "Failed to create backup directory: $BackupPath" -ForegroundColor Red
            return $false
        }
    }
    return $true
}

# Function to get user choice for interactive menus
function Get-UserChoice {
    param([string]$Prompt = "Enter your choice: ")
    
    do {
        $choice = Read-Host $Prompt
        if ($choice -match '^\d+$') {
            return [int]$choice
        }
        Write-Host "Please enter a valid number." -ForegroundColor Red
    } while ($true)
}

# Function to show help for scripts
function Show-ScriptHelp {
    param([string]$ScriptName, [string]$HelpText)
    
    Write-Host $HelpText
    exit 0
}

# Function to pause and wait for user input
function Wait-ForUserInput {
    param([string]$Message = "Press any key to continue...")
    
    Write-Host "`n$Message" -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Function to validate retention number
function Test-Retention {
    param([int]$Retention)
    
    if ($Retention -lt 1) {
        Write-Host "Retention must be at least 1" -ForegroundColor Red
        return $false
    }
    return $true
}

# Function to run Docker Compose command with error handling
function Invoke-DockerCompose {
    param(
        [string]$Command,
        [string]$ServiceName = "",
        [string]$Profile = ""
    )
    
    $args = @("compose")
    
    if ($Profile) {
        $args += "--profile"
        $args += $Profile
    }
    
    $args += $Command
    
    if ($ServiceName) {
        $args += $ServiceName
    }
    
    try {
        & docker @args
        return $LASTEXITCODE
    }
    catch {
        Write-Host "Failed to run Docker Compose command: $($_.Exception.Message)" -ForegroundColor Red
        return 1
    }
} 
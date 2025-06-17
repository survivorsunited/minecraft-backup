#!/bin/bash

################################################################################
# Script Description:
# This script performs scheduled Minecraft world backups for WorldEdit snapshots,
# rotates backups to maintain a set number of files, and ensures robust validation
# and error handling. The script creates backups in the format required by WorldEdit
# for its snapshot functionality.
#
# Key Feature: It also records the next scheduled backup time to a file so that
# if the script (container) restarts after the scheduled time, it can detect
# a missed backup and perform it immediately. If reading/writing the state file
# fails, the script falls back to a fresh schedule and continues normal operation.
#
# Variables:
# CRON_EXPRESSION       - Cron expression specifying the backup schedule.
# BACKUP_PATH           - Directory where the backup files will be stored.
# WORLD_PATH            - Path to the Minecraft world folder to backup.
# WORLD_NAME            - Name of the world (used in backup structure).
# FILES_TO_KEEP         - Number of backup files to retain before rotating,
#                         if not set, will create a backup with a timestamp.
# TMP_DIR               - Temporary directory used for creating backups.
# COMPRESSION_TYPE      - Type of compression to use (zip, tar.gz, none).
# INCLUDE_REGION_ONLY   - Whether to only backup region folder (true/false).
# FULL_BACKUP           - Whether to backup entire .minecraft folder (true/false).
#                         If true, creates backup with "-full" suffix.
#
# Dependencies (Executables and Libraries):
# - zip                        : For creating ZIP archives (default).
# - tar                        : For creating TAR archives.
# - gzip                       : For compressing TAR archives.
# - ./cron_parser.pl           : A script to calculate the next execution time
#                                 based on the cron expression. Ensure this script
#                                 is executable.
# - libdatetime-event-cron-perl : Perl module required by cron_parser.pl. Install via:
#                                 `sudo apt install libdatetime-event-cron-perl`.
#
# Notes:
# 1) If CRON_EXPRESSION is unset, the script runs exactly one backup immediately
#    and exits (no scheduling).
# 2) If the script is killed before the next scheduled backup, and the container
#    restarts afterwards, the script reads the stored epoch time from file. If it
#    finds that the backup time is in the past, it performs a "catch-up" backup
#    immediately. Then it calculates and saves the next run time for future runs.
# 3) If reading/writing the state file fails for any reason, the script logs a
#    warning and does a fresh calculation for the next backup time, continuing
#    normal operation without persisting state.
# 4) WorldEdit requires specific backup structure: timestamp folders containing
#    world folders with region subfolders.
################################################################################

# File used to record the next scheduled backup time (epoch).
NEXT_RUN_FILE=""

# ------------------------------------------------------------------------------
# Function: check_prerequisites
# Description: Validates required environment variables and checks for necessary
#              directories, executables, and Perl modules.
# ------------------------------------------------------------------------------
check_prerequisites() {
    # List of all required environment variables
    REQUIRED_VARS=(
        "BACKUP_PATH"
        "WORLD_PATH"
        "WORLD_NAME"
        "TMP_DIR"
    )

    for var in "${REQUIRED_VARS[@]}"; do
        if [[ -z "${!var}" ]]; then
            echo "Error: Environment variable $var is not set."
            exit 1
        fi
    done

    # Set defaults for optional variables
    if [[ -z "$COMPRESSION_TYPE" ]]; then
        COMPRESSION_TYPE="zip"
    fi

    if [[ -z "$INCLUDE_REGION_ONLY" ]]; then
        INCLUDE_REGION_ONLY="false"
    fi

    if [[ -z "$FULL_BACKUP" ]]; then
        FULL_BACKUP="false"
    fi

    # Validate world path
    if [[ ! -d "$WORLD_PATH" ]]; then
        echo "Error: World path $WORLD_PATH does not exist."
        exit 1
    fi

    # Check if region folder exists (required for WorldEdit)
    if [[ ! -d "$WORLD_PATH/region" ]]; then
        echo "Error: Region folder not found in $WORLD_PATH. This is required for WorldEdit snapshots."
        exit 1
    fi

    # Validate backup path
    if [[ ! -d "$BACKUP_PATH" ]]; then
        echo "Creating backup directory: $BACKUP_PATH"
        mkdir -p "$BACKUP_PATH"
    fi
    if [[ ! -d "$BACKUP_PATH" || ! -w "$BACKUP_PATH" ]]; then
        echo "Error: Backup path $BACKUP_PATH does not exist or is not writable."
        exit 1
    fi

    # Validate temporary directory
    if [[ ! -d "$TMP_DIR" ]]; then
        echo "Creating temporary directory: $TMP_DIR"
        mkdir -p "$TMP_DIR"
    fi

    # List of required executables based on compression type
    case "$COMPRESSION_TYPE" in
        "zip")
            REQUIRED_EXECUTABLES=("zip" "./cron_parser.pl")
            ;;
        "tar.gz"|"tgz")
            REQUIRED_EXECUTABLES=("tar" "gzip" "./cron_parser.pl")
            ;;
        "none")
            REQUIRED_EXECUTABLES=("./cron_parser.pl")
            ;;
        *)
            echo "Error: Unsupported compression type: $COMPRESSION_TYPE. Supported: zip, tar.gz, tgz, none"
            exit 1
            ;;
    esac

    for exe in "${REQUIRED_EXECUTABLES[@]}"; do
        if ! command -v "$exe" &>/dev/null; then
            if [[ "$exe" == "./cron_parser.pl" ]]; then
                # Special handling for cron_parser.pl (not in PATH)
                if [[ ! -x "$exe" ]]; then
                    echo "Error: Required script $exe is not executable or missing."
                    exit 1
                fi
            else
                echo "Error: Required executable $exe is not installed or available in PATH."
                exit 1
            fi
        fi
    done

    # Validate Perl dependency for cron_parser.pl
    if ! perl -MDateTime::Event::Cron -e 1 &>/dev/null; then
        echo "Error: Perl module libdatetime-event-cron-perl is not installed. Install it using:"
        echo "       sudo apt install libdatetime-event-cron-perl"
        exit 1
    fi

    # Set the next run file path after we confirm BACKUP_PATH
    NEXT_RUN_FILE="$BACKUP_PATH/${WORLD_NAME}.next_run"
}

# ------------------------------------------------------------------------------
# Function: save_next_run_time
# Description: Writes an epoch timestamp to NEXT_RUN_FILE. Logs a warning and
#              returns non-zero if writing fails.
# ------------------------------------------------------------------------------
save_next_run_time() {
    local epoch_time="$1"

    if ! echo "$epoch_time" > "$NEXT_RUN_FILE" 2>/dev/null; then
        echo "Warning: Unable to write next run time to $NEXT_RUN_FILE. Continuing without persisted state."
        return 1
    fi
    return 0
}

# ------------------------------------------------------------------------------
# Function: load_next_run_time
# Description: Reads the epoch timestamp from NEXT_RUN_FILE if it exists and is valid.
#              Echoes the timestamp on success, or returns non-zero if invalid/missing.
# ------------------------------------------------------------------------------
load_next_run_time() {
    # If file doesn't exist or is not readable, return 1
    if [[ ! -r "$NEXT_RUN_FILE" ]]; then
        return 1
    fi

    local stored_time
    stored_time=$(cat "$NEXT_RUN_FILE" | tr -d ' \t\r\n')
    if [[ "$stored_time" =~ ^[0-9]+$ ]]; then
        echo "$stored_time"
        return 0
    fi

    # If the file is corrupt or empty, return 1
    return 1
}

# ------------------------------------------------------------------------------
# Function: calculate_next_run_time
# Description: Uses cron_parser.pl to calculate the next run time based on
#              CRON_EXPRESSION and returns the epoch timestamp.
#              Exits if calculation fails.
# ------------------------------------------------------------------------------
calculate_next_run_time() {
    local cron_expr="$CRON_EXPRESSION"
    local next_time

    next_time=$(./cron_parser.pl "$cron_expr")
    if [[ -z "$next_time" ]]; then
        echo "Error: Unable to parse the cron expression or calculate the next execution time."
        exit 1
    fi
    echo "$next_time"
}

# ------------------------------------------------------------------------------
# Function: create_full_backup
# Description: Creates a backup of the entire .minecraft folder with "-full" suffix.
# ------------------------------------------------------------------------------
create_full_backup() {
    local timestamp=$(date +"%Y-%m-%d-%H-%M-%S")
    local backup_name="${timestamp}-full"
    local minecraft_parent_dir=$(dirname "$WORLD_PATH")
    local final_backup_path=""

    echo "Creating full .minecraft backup: $backup_name"

    # Create final backup based on compression type
    case "$COMPRESSION_TYPE" in
        "zip")
            final_backup_path="$BACKUP_PATH/$backup_name.zip"
            echo "Creating ZIP archive: $final_backup_path"
            # Zip the entire .minecraft folder
            cd "$minecraft_parent_dir" && zip -r "$final_backup_path" ".minecraft" >/dev/null 2>&1
            ;;
        "tar.gz"|"tgz")
            final_backup_path="$BACKUP_PATH/$backup_name.tar.gz"
            echo "Creating TAR.GZ archive: $final_backup_path"
            # Tar the entire .minecraft folder
            cd "$minecraft_parent_dir" && tar -czf "$final_backup_path" ".minecraft" >/dev/null 2>&1
            ;;
        "none")
            final_backup_path="$BACKUP_PATH/$backup_name"
            echo "Creating uncompressed backup: $final_backup_path"
            cp -r "$minecraft_parent_dir/.minecraft" "$final_backup_path"
            ;;
    esac

    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to create full backup archive."
        exit 1
    fi

    echo "Full .minecraft backup completed: $final_backup_path"
    echo "Backup structure: .minecraft/ (Complete Minecraft installation)"
}

# ------------------------------------------------------------------------------
# Function: create_worldedit_backup
# Description: Creates a backup in the WorldEdit-compatible format with proper
#              timestamp and world structure.
# ------------------------------------------------------------------------------
create_worldedit_backup() {
    local timestamp=$(date +"%Y-%m-%d-%H-%M-%S")
    local backup_name="$timestamp"
    local temp_backup_dir="$TMP_DIR/$backup_name"
    local world_backup_dir="$temp_backup_dir/$WORLD_NAME"
    local final_backup_path=""

    echo "Creating WorldEdit snapshot backup: $backup_name"

    # Create temporary directory structure - put world folder directly in temp
    local direct_world_dir="$TMP_DIR/$WORLD_NAME"
    mkdir -p "$direct_world_dir"

    # Copy world data based on INCLUDE_REGION_ONLY setting
    if [[ "$INCLUDE_REGION_ONLY" == "true" ]]; then
        echo "Backing up region folder only..."
        cp -r "$WORLD_PATH/region" "$direct_world_dir/"
    else
        echo "Backing up entire world folder..."
        cp -r "$WORLD_PATH"/* "$direct_world_dir/"
    fi

    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to copy world data to temporary directory."
        exit 1
    fi

    # Create final backup based on compression type
    case "$COMPRESSION_TYPE" in
        "zip")
            final_backup_path="$BACKUP_PATH/$backup_name.zip"
            echo "Creating ZIP archive: $final_backup_path"
            # Zip the world folder directly from temp directory
            cd "$TMP_DIR" && zip -r "$final_backup_path" "$WORLD_NAME" >/dev/null 2>&1
            ;;
        "tar.gz"|"tgz")
            final_backup_path="$BACKUP_PATH/$backup_name.tar.gz"
            echo "Creating TAR.GZ archive: $final_backup_path"
            # Tar the world folder directly from temp directory
            cd "$TMP_DIR" && tar -czf "$final_backup_path" "$WORLD_NAME" >/dev/null 2>&1
            ;;
        "none")
            final_backup_path="$BACKUP_PATH/$backup_name"
            echo "Creating uncompressed backup: $final_backup_path"
            mv "$direct_world_dir" "$final_backup_path"
            ;;
    esac

    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to create backup archive."
        exit 1
    fi

    # Clean up temporary directory
    rm -rf "$direct_world_dir"

    echo "WorldEdit snapshot backup completed: $final_backup_path"
    echo "Backup structure: $WORLD_NAME/region/ (WorldEdit compatible)"
}

# ------------------------------------------------------------------------------
# Function: create_backup_timestamp
# Description: Creates a backup file name using a timestamp suffix.
# ------------------------------------------------------------------------------
create_backup_timestamp() {
    create_worldedit_backup
}

# ------------------------------------------------------------------------------
# Function: create_backup_rotated
# Description: Creates a backup using a rotation scheme based on an index file.
# ------------------------------------------------------------------------------
create_backup_rotated() {
    local current_index_file="$BACKUP_PATH/${WORLD_NAME}.index"
    local next_index=1

    # If the index file exists, calculate the next index
    if [[ -f "$current_index_file" ]]; then
        current_index=$(cat "$current_index_file" | tr -d ' \t\r\n')
        next_index=$((current_index % FILES_TO_KEEP + 1))
    fi

    # Save the updated index
    echo "$next_index" > "$current_index_file"

    # Format the index as a 4-digit number (e.g., 0001, 0002)
    local padded_index
    printf -v padded_index "%04d" "$next_index"

    # Create backup with index-based name
    local timestamp=$(date +"%Y-%m-%d-%H-%M-%S")
    local backup_name="${timestamp}-${padded_index}"
    local temp_backup_dir="$TMP_DIR/$backup_name"
    local world_backup_dir="$temp_backup_dir/$WORLD_NAME"
    local final_backup_path=""

    echo "Creating rotated WorldEdit snapshot backup: $backup_name"

    # Create temporary directory structure
    mkdir -p "$world_backup_dir"

    # Copy world data based on INCLUDE_REGION_ONLY setting
    if [[ "$INCLUDE_REGION_ONLY" == "true" ]]; then
        echo "Backing up region folder only..."
        cp -r "$WORLD_PATH/region" "$world_backup_dir/"
    else
        echo "Backing up entire world folder..."
        cp -r "$WORLD_PATH"/* "$world_backup_dir/"
    fi

    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to copy world data to temporary directory."
        exit 1
    fi

    # Create final backup based on compression type
    case "$COMPRESSION_TYPE" in
        "zip")
            final_backup_path="$BACKUP_PATH/$backup_name.zip"
            echo "Creating ZIP archive: $final_backup_path"
            cd "$TMP_DIR" && zip -r "$final_backup_path" "$backup_name" >/dev/null 2>&1
            ;;
        "tar.gz"|"tgz")
            final_backup_path="$BACKUP_PATH/$backup_name.tar.gz"
            echo "Creating TAR.GZ archive: $final_backup_path"
            cd "$TMP_DIR" && tar -czf "$final_backup_path" "$backup_name" >/dev/null 2>&1
            ;;
        "none")
            final_backup_path="$BACKUP_PATH/$backup_name"
            echo "Creating uncompressed backup: $final_backup_path"
            mv "$temp_backup_dir" "$final_backup_path"
            ;;
    esac

    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to create backup archive."
        exit 1
    fi

    # Clean up temporary directory
    rm -rf "$temp_backup_dir"

    echo "Rotated WorldEdit snapshot backup completed: $final_backup_path"
    echo "Backup structure: $backup_name/$WORLD_NAME/region/ (WorldEdit compatible)"
}

# ------------------------------------------------------------------------------
# Function: create_backup
# Description: Chooses between timestamp-based or rotated backups depending
#              on whether FILES_TO_KEEP is set.
# ------------------------------------------------------------------------------
create_backup() {
    if [[ -z "$FILES_TO_KEEP" ]]; then
        echo "FILES_TO_KEEP is not set. Using timestamp-based backup."
        create_backup_timestamp
    else
        create_backup_rotated
    fi
}

# ------------------------------------------------------------------------------
# Function: main
# Description: Orchestrates the script flow:
#              1) Checks prerequisites.
#              2) If CRON_EXPRESSION is unset, performs a single backup immediately.
#              3) Otherwise, loads or calculates the next run time.
#              4) If the stored time is in the past, run a missed backup now.
#              5) If the stored time is in the future, sleep until that time,
#                 then run the backup.
#              6) Calculates & saves the new next run time.
#              7) Exits (container may restart it depending on your setup).
# ------------------------------------------------------------------------------
main() {
    # Run prerequisite checks
    check_prerequisites

    # If CRON_EXPRESSION is unset, do a single immediate backup and exit
    if [[ -z "$CRON_EXPRESSION" ]]; then
        echo "CRON_EXPRESSION is not set. Running backup immediately..."
        if [[ "$FULL_BACKUP" == "true" ]]; then
            echo "FULL_BACKUP is set to true. Creating full .minecraft backup..."
            create_full_backup
        else
            create_backup
        fi
        exit 0
    fi

    local current_time
    current_time="$(date +%s)"

    # Try loading a previously stored next run time
    local stored_time
    if ! stored_time="$(load_next_run_time)"; then
        echo "Warning: No valid or readable next run time found in $NEXT_RUN_FILE."
        echo "Will calculate a fresh next run time."
        stored_time=""  # Force a new calculation below
    else
        echo "Loaded next run time from file: $stored_time"
    fi

    # If no stored time, calculate a new one and attempt to save it
    if [[ -z "$stored_time" ]]; then
        stored_time="$(calculate_next_run_time)"
        if ! save_next_run_time "$stored_time"; then
            # If saving fails, we just log a warning and continue in-memory
            echo "Continuing with in-memory next run time: $stored_time"
        fi
        echo "Next scheduled backup (epoch): $stored_time"
    fi

    # If the stored time is in the past, we've missed the backup => run immediately
    if (( stored_time <= current_time )); then
        echo "Detected a missed backup (originally scheduled for $stored_time). Running now..."
        create_backup
    else
        # Otherwise, sleep until the stored time
        local sleep_duration=$(( stored_time - current_time ))
        echo "Sleeping for $sleep_duration seconds, next backup at $(date -d @"$stored_time")..."
        sleep "$sleep_duration"

        echo "Backup time reached. Starting backup."
        create_backup
    fi

    # Once this backup is done, compute and save the next run time for future use
    local next_run
    next_run="$(calculate_next_run_time)"

    # Attempt to save the new run time; if it fails, we log a warning and continue
    if ! save_next_run_time "$next_run"; then
        echo "Warning: Could not save next run time to file. Will rely on in-memory value only."
    fi

    echo "Scheduled next run time (epoch): $next_run"
    echo "Backup completed at $(date). Exiting..."
}

# Start the script
main 
# ------------------------------------------------------------------------------

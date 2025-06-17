FROM ubuntu:22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Install system dependencies
RUN apt-get update && apt-get install -y \
    zip \
    unzip \
    tar \
    gzip \
    cron \
    perl \
    libdatetime-event-cron-perl \
    p7zip-full \
    curl \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Create necessary directories
RUN mkdir -p /backups /tmp/backup /minecraft

# Copy backup script and cron parser
COPY worldedit_snapshot.sh /worldedit_snapshot.sh
COPY cron_parser.pl /cron_parser.pl

# Make scripts executable
RUN chmod +x /worldedit_snapshot.sh /cron_parser.pl

# Set working directory
WORKDIR /

# Default command
CMD ["/worldedit_snapshot.sh"] 
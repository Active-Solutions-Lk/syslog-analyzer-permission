#!/bin/bash

################################################################################
# ANALYZER SERVER SETUP SCRIPT
# Purpose: Configure MariaDB, Install Dependencies, and Setup Auto-Sync Cron
################################################################################

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration Variables
LOCAL_DB="analyzer"
LOCAL_TABLE="log_mirror"
LOCAL_USER="ruser"
LOCAL_PASS="ruser1@Analyzer"

# Script Locations
SCRIPT_DIR="/var/www/html/syslog-analyzer-permission"
SYNC_SCRIPT="dynamic_incremental_transfer.sh"

################################################################################
# Functions
################################################################################

print_header() {
    echo -e "${BLUE}=========================================="
    echo -e "$1"
    echo -e "==========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ ERROR: $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ WARNING: $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

install_dependencies() {
    print_info "Checking and installing dependencies..."
    
    # List of required packages
    PACKAGES="mariadb-client bc net-tools php-cli php-mysql"
    
    # Update package list lightly
    apt update -qq
    
    for pkg in $PACKAGES; do
        if dpkg -l | grep -q "^ii  $pkg"; then
            print_success "$pkg is already installed"
        else
            print_info "Installing $pkg..."
            # Try installing default-mysql-client if mariadb-client fails (compatibility)
            if [ "$pkg" == "mariadb-client" ]; then
                apt install -y mariadb-client &> /dev/null || apt install -y default-mysql-client &> /dev/null
            else
                apt install -y $pkg &> /dev/null
            fi
            
            if [ $? -eq 0 ]; then
                print_success "$pkg installed successfully"
            else
                print_error "Failed to install $pkg"
                # Don't exit, just warn, as some systems might have different package names
            fi
        fi
    done
}

create_database_user() {
    print_info "Creating database user and granting privileges..."
    
    # Create SQL commands file
    cat > /tmp/mariadb_setup.sql << EOF
-- Create user
CREATE USER IF NOT EXISTS '${LOCAL_USER}'@'localhost' IDENTIFIED BY '${LOCAL_PASS}';

-- Grant privileges on analyzer database
GRANT ALL PRIVILEGES ON ${LOCAL_DB}.* TO '${LOCAL_USER}'@'localhost';

-- Apply privileges
FLUSH PRIVILEGES;
EOF

    # Execute SQL commands
    mysql -u root < /tmp/mariadb_setup.sql
    
    if [ $? -eq 0 ]; then
        print_success "Database user created and privileges granted"
        rm /tmp/mariadb_setup.sql
    else
        print_error "Failed to create database user"
        rm /tmp/mariadb_setup.sql
        return 1
    fi
}

verify_database_exists() {
    print_info "Verifying database '${LOCAL_DB}' exists..."
    
    DB_EXISTS=$(mysql -u root -N -e "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='${LOCAL_DB}';" 2>/dev/null)
    
    if [ -z "$DB_EXISTS" ]; then
        print_error "Database '${LOCAL_DB}' does not exist"
        read -p "$(echo -e ${YELLOW}Do you want to create it? [y/N]: ${NC})" -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            mysql -u root -e "CREATE DATABASE ${LOCAL_DB};"
            if [ $? -eq 0 ]; then
                print_success "Database '${LOCAL_DB}' created"
            else
                print_error "Failed to create database"
                return 1
            fi
        else
            print_error "Cannot proceed without database"
            return 1
        fi
    else
        print_success "Database '${LOCAL_DB}' exists"
    fi
}

create_mirror_table() {
    print_info "Creating '${LOCAL_TABLE}' table in '${LOCAL_DB}' database..."
    
    # Check if table already exists
    TABLE_EXISTS=$(mysql -u root -N -e "SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='${LOCAL_DB}' AND TABLE_NAME='${LOCAL_TABLE}';" 2>/dev/null)
    
    if [ ! -z "$TABLE_EXISTS" ]; then
        print_info "Table '${LOCAL_TABLE}' already exists. Skipping creation."
        return 0
    fi
    
    # Create table
    cat > /tmp/create_table.sql << EOF
USE ${LOCAL_DB};

CREATE TABLE ${LOCAL_TABLE} (
  id INT NOT NULL AUTO_INCREMENT,
  collector_id INT NOT NULL DEFAULT 4,
  original_log_id INT NOT NULL,
  received_at DATETIME,
  hostname VARCHAR(255),
  facility VARCHAR(50),
  message TEXT,
  port VARCHAR(50),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_received_at (received_at),
  KEY idx_hostname (hostname),
  KEY idx_collector_original (collector_id, original_log_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
EOF

    mysql -u root < /tmp/create_table.sql
    
    if [ $? -eq 0 ]; then
        print_success "Table '${LOCAL_TABLE}' created successfully"
        rm /tmp/create_table.sql
    else
        print_error "Failed to create table"
        rm /tmp/create_table.sql
        return 1
    fi
}

setup_cron_job() {
    print_info "Setting up cron job for ${SYNC_SCRIPT}..."
    
    # Ensure script exists and is executable
    FULL_PATH="${SCRIPT_DIR}/${SYNC_SCRIPT}"
    if [ ! -f "$FULL_PATH" ]; then
        print_error "Script $FULL_PATH not found!"
        return 1
    fi
    
    chmod +x "$FULL_PATH"
    
    # Define cron command (run every minute)
    CRON_CMD="* * * * * $FULL_PATH >> ${SCRIPT_DIR}/logs/cron_output.log 2>&1"
    
    # Check if job already exists
    (crontab -l 2>/dev/null | grep -v "$SYNC_SCRIPT"; echo "$CRON_CMD") | crontab -
    
    print_success "Cron job installed to run every minute."
    print_info "Logs will be written to ${SCRIPT_DIR}/logs/cron_output.log"
}

create_quick_commands() {
    print_info "Creating quick command aliases..."
    
    cat >> /root/.bashrc << EOF

# Analyzer Sync Quick Commands
alias sync-now='${SCRIPT_DIR}/${SYNC_SCRIPT}'
alias sync-logs='mysql -u ${LOCAL_USER} -p"${LOCAL_PASS}" ${LOCAL_DB} -e "SELECT * FROM ${LOCAL_TABLE} ORDER BY id DESC LIMIT 10;"'
alias sync-status='tail -f ${SCRIPT_DIR}/logs/cron_output.log'
EOF

    print_success "Quick command aliases added to /root/.bashrc"
}

show_summary() {
    print_header "SETUP COMPLETE - SUMMARY"
    
    echo ""
    echo -e "${GREEN}Analyzer Server Configuration:${NC}"
    echo "  Database: $LOCAL_DB"
    echo "  Table: $LOCAL_TABLE"
    echo "  User: $LOCAL_USER"
    echo ""
    echo -e "${GREEN}Automation:${NC}"
    echo "  ✓ Dependencies installed (php, mysql-client, bc, net-tools)"
    echo "  ✓ Cron job configured (runs every minute)"
    echo "  ✓ Script: ${SCRIPT_DIR}/${SYNC_SCRIPT}"
    echo ""
    echo -e "${YELLOW}Quick Commands (reload shell with 'source ~/.bashrc'):${NC}"
    echo "  ${BLUE}sync-now${NC}      - Manually trigger sync"
    echo "  ${BLUE}sync-logs${NC}     - View latest 10 logs from DB"
    echo "  ${BLUE}sync-status${NC}   - Tail the cron output log"
    echo ""
    print_success "Analyzer setup completed successfully!"
}

################################################################################
# Main Script Execution
################################################################################

clear
print_header "ANALYZER SERVER SETUP SCRIPT"

echo ""
print_info "This script will configure the Analyzer server environment."
echo ""

read -p "$(echo -e ${YELLOW}Do you want to continue? [y/N]: ${NC})" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Setup cancelled"
    exit 0
fi

echo ""

check_root
install_dependencies

echo ""
create_database_user

echo ""
verify_database_exists

echo ""
create_mirror_table

echo ""
setup_cron_job

echo ""
create_quick_commands

echo ""
show_summary

################################################################################
# End of Script
################################################################################
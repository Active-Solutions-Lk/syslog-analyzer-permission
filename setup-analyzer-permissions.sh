#!/bin/bash

################################################################################
# ANALYZER SERVER SETUP SCRIPT
# Server: 142.91.101.137 (Debian, MariaDB)
# Purpose: Configure MariaDB and create sync scripts for remote data collection
################################################################################

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration Variables
COLLECTOR_IP="142.91.101.142"
COLLECTOR_DB="syslog_db"
COLLECTOR_TABLE="remote_logs"
COLLECTOR_USER="Admin"
COLLECTOR_PASS="Admin@collector1"

LOCAL_DB="analyzer"
LOCAL_TABLE="log_mirror"
LOCAL_USER="ruser"
LOCAL_PASS="ruser1@Analyzer"

BATCH_SIZE=5000

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

check_mariadb_installed() {
    if ! command -v mysql &> /dev/null && ! command -v mariadb &> /dev/null; then
        print_error "MariaDB/MySQL is not installed"
        exit 1
    fi
    print_success "MariaDB/MySQL is installed"
}

install_bc() {
    print_info "Checking for bc (calculator tool)..."
    
    if command -v bc &> /dev/null; then
        print_success "bc is already installed"
    else
        print_info "Installing bc..."
        apt update -qq
        apt install -y bc &> /dev/null
        
        if [ $? -eq 0 ]; then
            print_success "bc installed successfully"
        else
            print_error "Failed to install bc"
            return 1
        fi
    fi
}

install_net_tools() {
    print_info "Checking for network tools..."
    
    if ! command -v netstat &> /dev/null; then
        print_info "Installing net-tools..."
        apt install -y net-tools &> /dev/null
        if [ $? -eq 0 ]; then
            print_success "net-tools installed"
        fi
    else
        print_success "Network tools available"
    fi
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

-- Show grants
SHOW GRANTS FOR '${LOCAL_USER}'@'localhost';
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
        print_warning "Table '${LOCAL_TABLE}' already exists"
        read -p "$(echo -e ${YELLOW}Do you want to drop and recreate it? [y/N]: ${NC})" -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            mysql -u root ${LOCAL_DB} -e "DROP TABLE ${LOCAL_TABLE};"
            print_info "Existing table dropped"
        else
            print_info "Keeping existing table"
            return 0
        fi
    fi
    
    # Create table
    cat > /tmp/create_table.sql << EOF
USE ${LOCAL_DB};

CREATE TABLE ${LOCAL_TABLE} (
  id INT NOT NULL AUTO_INCREMENT,
  received_at DATETIME,
  hostname VARCHAR(255),
  facility VARCHAR(50),
  message TEXT,
  port VARCHAR(50),
  PRIMARY KEY (id),
  KEY idx_received_at (received_at),
  KEY idx_hostname (hostname)
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

test_collector_connection() {
    print_info "Testing connection to Collector server..."
    
    # Test network connectivity
    if ping -c 1 -W 2 $COLLECTOR_IP &> /dev/null; then
        print_success "Collector server ($COLLECTOR_IP) is reachable"
    else
        print_warning "Collector server ($COLLECTOR_IP) is not reachable via ping"
    fi
    
    # Test MySQL connection
    mysql -h $COLLECTOR_IP -u $COLLECTOR_USER -p"$COLLECTOR_PASS" -e "SELECT 1;" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        print_success "MySQL connection to Collector successful"
        
        # Get row count
        ROW_COUNT=$(mysql -h $COLLECTOR_IP -u $COLLECTOR_USER -p"$COLLECTOR_PASS" $COLLECTOR_DB -N -e "SELECT COUNT(*) FROM $COLLECTOR_TABLE;" 2>/dev/null)
        print_info "Remote table contains ${ROW_COUNT} rows"
    else
        print_error "Cannot connect to Collector MySQL server"
        print_info "Please ensure Collector setup is complete"
        return 1
    fi
}

create_incremental_sync_script() {
    print_info "Creating incremental_transfer.sh script..."
    
    cat > /root/incremental_transfer.sh << 'SCRIPT_EOF'
#!/bin/bash

# Configuration
REMOTE_HOST="142.91.101.142"
REMOTE_USER="Admin"
REMOTE_PASS="Admin@collector1"
REMOTE_DB="syslog_db"
REMOTE_TABLE="remote_logs"

LOCAL_USER="ruser"
LOCAL_PASS="ruser1@Analyzer"
LOCAL_DB="analyzer"
LOCAL_TABLE="log_mirror"

BATCH_SIZE=5000

echo "=========================================="
echo "Incremental Database Sync"
echo "=========================================="
echo ""

# Test connections
echo "Testing database connections..."
mysql -u $LOCAL_USER -p"$LOCAL_PASS" -e "SELECT 1;" 2>/dev/null
if [ $? -ne 0 ]; then
    echo "ERROR: Cannot connect to local database"
    exit 1
fi

mysql -h $REMOTE_HOST -u $REMOTE_USER -p"$REMOTE_PASS" -e "SELECT 1;" 2>/dev/null
if [ $? -ne 0 ]; then
    echo "ERROR: Cannot connect to remote database"
    exit 1
fi
echo "✓ Connections successful"
echo ""

# Get last ID from local table
LAST_LOCAL_ID=$(mysql -u $LOCAL_USER -p"$LOCAL_PASS" $LOCAL_DB -N -e "SELECT IFNULL(MAX(id), 0) FROM $LOCAL_TABLE;" 2>/dev/null)

if [ -z "$LAST_LOCAL_ID" ]; then
    LAST_LOCAL_ID=0
fi

echo "Last local ID: $LAST_LOCAL_ID"

# Get max ID from remote table
MAX_REMOTE_ID=$(mysql -h $REMOTE_HOST -u $REMOTE_USER -p"$REMOTE_PASS" $REMOTE_DB -N -e "SELECT IFNULL(MAX(id), 0) FROM $REMOTE_TABLE;" 2>/dev/null)

echo "Max remote ID: $MAX_REMOTE_ID"

# Calculate how many new rows
NEW_ROWS=$((MAX_REMOTE_ID - LAST_LOCAL_ID))

if [ $NEW_ROWS -le 0 ]; then
    echo ""
    echo "✓ No new data to sync. Already up to date!"
    exit 0
fi

echo "New rows available: $NEW_ROWS"

# Determine how many rows to fetch (limit to BATCH_SIZE)
if [ $NEW_ROWS -gt $BATCH_SIZE ]; then
    ROWS_TO_FETCH=$BATCH_SIZE
    echo "Fetching first $ROWS_TO_FETCH rows (batch limit)"
else
    ROWS_TO_FETCH=$NEW_ROWS
    echo "Fetching all $ROWS_TO_FETCH new rows"
fi

echo ""
echo "Starting incremental transfer..."
echo "Fetching rows with id > $LAST_LOCAL_ID (limit $ROWS_TO_FETCH)"
echo ""

# Start timing
START_TIME=$(date +%s.%N)

# Export new rows from remote database
mysqldump -h $REMOTE_HOST \
          -u $REMOTE_USER \
          -p"$REMOTE_PASS" \
          --single-transaction \
          --skip-lock-tables \
          $REMOTE_DB \
          $REMOTE_TABLE \
          --where="id > $LAST_LOCAL_ID ORDER BY id LIMIT $ROWS_TO_FETCH" \
          --no-create-info \
          --skip-comments 2>/dev/null \
          | mysql -u $LOCAL_USER -p"$LOCAL_PASS" $LOCAL_DB 2>/dev/null

if [ $? -ne 0 ]; then
    echo "ERROR: Transfer failed"
    exit 1
fi

# End timing
END_TIME=$(date +%s.%N)

# Calculate duration
DURATION=$(echo "$END_TIME - $START_TIME" | bc)

# Verify transfer
NEW_LOCAL_ID=$(mysql -u $LOCAL_USER -p"$LOCAL_PASS" $LOCAL_DB -N -e "SELECT IFNULL(MAX(id), 0) FROM $LOCAL_TABLE;" 2>/dev/null)
TRANSFERRED_ROWS=$((NEW_LOCAL_ID - LAST_LOCAL_ID))

echo "=========================================="
echo "Sync Complete!"
echo "=========================================="
printf "Duration: %.6f seconds\n" $DURATION
echo "Rows transferred: $TRANSFERRED_ROWS"
echo "Previous max ID: $LAST_LOCAL_ID"
echo "New max ID: $NEW_LOCAL_ID"

if [ $(echo "$DURATION > 0" | bc) -eq 1 ]; then
    RATE=$(echo "scale=2; $TRANSFERRED_ROWS / $DURATION" | bc)
    echo "Transfer rate: $RATE rows/second"
fi

# Calculate remaining rows
REMAINING=$((MAX_REMOTE_ID - NEW_LOCAL_ID))
if [ $REMAINING -gt 0 ]; then
    echo ""
    echo "⚠ $REMAINING rows still remaining on remote server"
    echo "Run the script again to fetch more data"
fi

echo ""

# Show sample of newly transferred data
echo "Sample of newly transferred data:"
mysql -u $LOCAL_USER -p"$LOCAL_PASS" $LOCAL_DB -t -e "SELECT id, received_at, hostname, facility, LEFT(message, 50) as message_preview, port FROM $LOCAL_TABLE WHERE id > $LAST_LOCAL_ID ORDER BY id LIMIT 5;" 2>/dev/null

echo ""
echo "=========================================="

# Show sync statistics
TOTAL_LOCAL=$(mysql -u $LOCAL_USER -p"$LOCAL_PASS" $LOCAL_DB -N -e "SELECT COUNT(*) FROM $LOCAL_TABLE;" 2>/dev/null)
TOTAL_REMOTE=$(mysql -h $REMOTE_HOST -u $REMOTE_USER -p"$REMOTE_PASS" $REMOTE_DB -N -e "SELECT COUNT(*) FROM $REMOTE_TABLE;" 2>/dev/null)

echo "Sync Status:"
echo "  Local rows: $TOTAL_LOCAL"
echo "  Remote rows: $TOTAL_REMOTE"
if [ $TOTAL_REMOTE -gt 0 ]; then
    SYNC_PERCENT=$(echo "scale=2; ($TOTAL_LOCAL * 100) / $TOTAL_REMOTE" | bc)
    echo "  Sync progress: $SYNC_PERCENT%"
fi
echo "=========================================="
SCRIPT_EOF

    chmod +x /root/incremental_transfer.sh
    print_success "incremental_transfer.sh created at /root/"
}

create_auto_sync_script() {
    print_info "Creating auto_sync.sh script..."
    
    cat > /root/auto_sync.sh << 'SCRIPT_EOF'
#!/bin/bash

echo "=========================================="
echo "Auto-Sync Service"
echo "=========================================="
echo "Press Ctrl+C to stop"
echo ""

SYNC_COUNT=0

while true; do
    SYNC_COUNT=$((SYNC_COUNT + 1))
    echo "[$SYNC_COUNT] Running sync at $(date '+%Y-%m-%d %H:%M:%S')..."
    
    /root/incremental_transfer.sh | grep -E "(New rows available|No new data|Rows transferred)"
    
    echo "Waiting 60 seconds before next sync..."
    echo ""
    sleep 60
done
SCRIPT_EOF

    chmod +x /root/auto_sync.sh
    print_success "auto_sync.sh created at /root/"
}

create_status_checker_script() {
    print_info "Creating check_sync_status.sh script..."
    
    cat > /root/check_sync_status.sh << 'SCRIPT_EOF'
#!/bin/bash

REMOTE_HOST="142.91.101.142"
REMOTE_USER="Admin"
REMOTE_PASS="Admin@collector1"
REMOTE_DB="syslog_db"
REMOTE_TABLE="remote_logs"

LOCAL_USER="ruser"
LOCAL_PASS="ruser1@Analyzer"
LOCAL_DB="analyzer"
LOCAL_TABLE="log_mirror"

echo "=========================================="
echo "Sync Status Check"
echo "=========================================="

# Local stats
LOCAL_COUNT=$(mysql -u $LOCAL_USER -p"$LOCAL_PASS" $LOCAL_DB -N -e "SELECT COUNT(*) FROM $LOCAL_TABLE;" 2>/dev/null)
LOCAL_MIN=$(mysql -u $LOCAL_USER -p"$LOCAL_PASS" $LOCAL_DB -N -e "SELECT IFNULL(MIN(id), 0) FROM $LOCAL_TABLE;" 2>/dev/null)
LOCAL_MAX=$(mysql -u $LOCAL_USER -p"$LOCAL_PASS" $LOCAL_DB -N -e "SELECT IFNULL(MAX(id), 0) FROM $LOCAL_TABLE;" 2>/dev/null)

# Remote stats
REMOTE_COUNT=$(mysql -h $REMOTE_HOST -u $REMOTE_USER -p"$REMOTE_PASS" $REMOTE_DB -N -e "SELECT COUNT(*) FROM $REMOTE_TABLE;" 2>/dev/null)
REMOTE_MIN=$(mysql -h $REMOTE_HOST -u $REMOTE_USER -p"$REMOTE_PASS" $REMOTE_DB -N -e "SELECT IFNULL(MIN(id), 0) FROM $REMOTE_TABLE;" 2>/dev/null)
REMOTE_MAX=$(mysql -h $REMOTE_HOST -u $REMOTE_USER -p"$REMOTE_PASS" $REMOTE_DB -N -e "SELECT IFNULL(MAX(id), 0) FROM $REMOTE_TABLE;" 2>/dev/null)

echo ""
echo "Local Database (Analyzer - log_mirror):"
echo "  Total rows: $LOCAL_COUNT"
echo "  ID range: $LOCAL_MIN - $LOCAL_MAX"

echo ""
echo "Remote Database (Collector - remote_logs):"
echo "  Total rows: $REMOTE_COUNT"
echo "  ID range: $REMOTE_MIN - $REMOTE_MAX"

echo ""
MISSING=$((REMOTE_COUNT - LOCAL_COUNT))
if [ $MISSING -gt 0 ]; then
    SYNC_PERCENT=$(echo "scale=2; ($LOCAL_COUNT * 100) / $REMOTE_COUNT" | bc)
    echo "Status: ⚠ $MISSING rows missing"
    echo "Sync progress: $SYNC_PERCENT%"
else
    echo "Status: ✓ Fully synchronized!"
fi

echo "=========================================="
SCRIPT_EOF

    chmod +x /root/check_sync_status.sh
    print_success "check_sync_status.sh created at /root/"
}

create_quick_commands() {
    print_info "Creating quick command aliases..."
    
    cat >> /root/.bashrc << 'EOF'

# Analyzer Sync Quick Commands
alias sync-now='/root/incremental_transfer.sh'
alias sync-auto='/root/auto_sync.sh'
alias sync-status='/root/check_sync_status.sh'
alias sync-logs='mysql -u ruser -p"ruser1@Analyzer" analyzer -e "SELECT * FROM log_mirror ORDER BY id DESC LIMIT 10;"'
EOF

    print_success "Quick command aliases added to /root/.bashrc"
}

show_summary() {
    print_header "SETUP COMPLETE - SUMMARY"
    
    echo ""
    echo -e "${GREEN}Analyzer Server Configuration:${NC}"
    echo "  Server IP: $(hostname -I | awk '{print $1}')"
    echo "  Database: $LOCAL_DB"
    echo "  Table: $LOCAL_TABLE"
    echo "  User: $LOCAL_USER"
    echo ""
    echo -e "${GREEN}Collector Connection:${NC}"
    echo "  Collector IP: $COLLECTOR_IP"
    echo "  Database: $COLLECTOR_DB"
    echo "  Table: $COLLECTOR_TABLE"
    echo "  Batch Size: $BATCH_SIZE rows"
    echo ""
    echo -e "${GREEN}Scripts Created (in /root/):${NC}"
    echo "  ✓ incremental_transfer.sh - Sync new data (5000 rows at a time)"
    echo "  ✓ auto_sync.sh - Continuous auto-sync every 60 seconds"
    echo "  ✓ check_sync_status.sh - Check sync progress"
    echo ""
    echo -e "${YELLOW}Quick Commands (reload shell with 'source ~/.bashrc'):${NC}"
    echo "  ${BLUE}sync-now${NC}      - Run single sync"
    echo "  ${BLUE}sync-auto${NC}     - Start auto-sync"
    echo "  ${BLUE}sync-status${NC}   - Check sync status"
    echo "  ${BLUE}sync-logs${NC}     - View latest 10 logs"
    echo ""
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "  1. Test single sync:"
    echo "     ${BLUE}/root/incremental_transfer.sh${NC}"
    echo ""
    echo "  2. Check sync status:"
    echo "     ${BLUE}/root/check_sync_status.sh${NC}"
    echo ""
    echo "  3. Start continuous sync:"
    echo "     ${BLUE}/root/auto_sync.sh${NC}"
    echo ""
    print_success "Analyzer setup completed successfully!"
}

################################################################################
# Main Script Execution
################################################################################

clear
print_header "ANALYZER SERVER SETUP SCRIPT"

echo ""
print_info "This script will configure the Analyzer server for data sync"
print_info "Database: $LOCAL_DB, Table: $LOCAL_TABLE"
echo ""

read -p "$(echo -e ${YELLOW}Do you want to continue? [y/N]: ${NC})" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Setup cancelled"
    exit 0
fi

echo ""

# Run setup steps
check_root
check_mariadb_installed

echo ""
install_bc

echo ""
install_net_tools

echo ""
create_database_user

echo ""
verify_database_exists

echo ""
create_mirror_table

echo ""
test_collector_connection

echo ""
create_incremental_sync_script

echo ""
create_auto_sync_script

echo ""
create_status_checker_script

echo ""
create_quick_commands

echo ""
show_summary

################################################################################
# End of Script
################################################################################
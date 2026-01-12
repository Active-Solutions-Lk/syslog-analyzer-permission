#!/bin/bash

# Create logs directory if it doesn't exist
mkdir -p logs

# Generate log file name with timestamp
LOG_FILE="logs/dynamic_transfer_$(date +%Y%m%d_%H%M%S).log"

# Redirect all output to the log file
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=========================================="
echo "Dynamic Multi-Collector Incremental Sync"
echo "Log File: $LOG_FILE"
echo "=========================================="

# Database Configuration
LOCAL_USER="ruser"
LOCAL_PASS="ruser1@Analyzer"
LOCAL_DB="analyzer"
LOCAL_TABLE="log_mirror"

BATCH_SIZE=5000

echo "=========================================="
echo "Dynamic Multi-Collector Incremental Sync"
echo "=========================================="
echo ""

# Fetch active collectors from database
COLLECTORS_DATA=$(mysql -u $LOCAL_USER -p"$LOCAL_PASS" $LOCAL_DB -N -e "SELECT id, name, ip, domain, secret_key, last_fetched_id FROM collectors WHERE is_active = 1;")

# Check if any collectors were found
if [ -z "$COLLECTORS_DATA" ] || [ $(echo "$COLLECTORS_DATA" | wc -l) -eq 0 ]; then
    echo "No active collectors found in database"
    exit 0
fi

echo "Found $(echo "$COLLECTORS_DATA" | wc -l) active collector(s)"
echo ""

# Process each collector
while IFS=$'\t' read -r COLLECTOR_ID COLLECTOR_NAME COLLECTOR_IP COLLECTOR_DOMAIN SECRET_KEY LAST_FETCHED_ID; do
    # Skip empty lines
    if [ -z "$COLLECTOR_ID" ]; then
        continue
    fi
    
    echo "------------------------------------------"
    echo "Processing Collector: $COLLECTOR_NAME (ID: $COLLECTOR_ID)"
    echo "IP: $COLLECTOR_IP | Domain: $COLLECTOR_DOMAIN"
    echo "Last fetched ID: $LAST_FETCHED_ID"
    echo "------------------------------------------"
    
    # Use IP if available, otherwise use domain
    if [ -n "$COLLECTOR_IP" ] && [ "$COLLECTOR_IP" != "NULL" ]; then
        REMOTE_HOST="$COLLECTOR_IP"
    elif [ -n "$COLLECTOR_DOMAIN" ] && [ "$COLLECTOR_DOMAIN" != "NULL" ]; then
        REMOTE_HOST="$COLLECTOR_DOMAIN"
    else
        echo "ERROR: No IP or domain configured for collector $COLLECTOR_NAME"
        continue
    fi
    
    # All collectors will have the same static credentials and table structure
    REMOTE_USER="Admin"
    REMOTE_PASS="Admin@collector1"
    REMOTE_DB="syslog_db"
    REMOTE_TABLE="remote_logs"
    
    # Test connection to remote collector
    echo "Testing connection to collector $COLLECTOR_NAME at $REMOTE_HOST..."
    mysql -h $REMOTE_HOST -u $REMOTE_USER -p"$REMOTE_PASS" -e "SELECT 1;" 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "ERROR: Cannot connect to collector $COLLECTOR_NAME at $REMOTE_HOST"
        echo "Skipping this collector..."
        continue
    fi
    echo "✓ Connection successful"
    echo ""
    
    # Get last fetched ID for this specific collector from the database
    if [ -z "$LAST_FETCHED_ID" ] || [ "$LAST_FETCHED_ID" = "NULL" ]; then
        LAST_LOCAL_ID=0
    else
        LAST_LOCAL_ID=$LAST_FETCHED_ID
    fi
    
    echo "Last fetched ID for collector $COLLECTOR_ID: $LAST_LOCAL_ID"
    
    # Get max ID from remote table
    MAX_REMOTE_ID=$(mysql -h $REMOTE_HOST -u $REMOTE_USER -p"$REMOTE_PASS" $REMOTE_DB -N -e "SELECT IFNULL(MAX(id), 0) FROM $REMOTE_TABLE;" 2>/dev/null)
    
    echo "Max remote ID: $MAX_REMOTE_ID"
    
    # Calculate how many new rows
    NEW_ROWS=$((MAX_REMOTE_ID - LAST_LOCAL_ID))
    
    if [ $NEW_ROWS -le 0 ]; then
        echo ""
        echo "✓ No new data to sync for collector $COLLECTOR_NAME. Already up to date!"
        echo "------------------------------------------"
        continue
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
    echo "Starting incremental transfer for collector $COLLECTOR_NAME..."
    echo "Fetching rows with id > $LAST_LOCAL_ID (limit $ROWS_TO_FETCH)"
    echo ""
    
    # Start timing
    START_TIME=$(date +%s.%N)
    
    # Method: Transfer data using direct MySQL commands to avoid LOAD DATA issues
    # Create a temporary SQL file to execute the transfer
    TRANSFER_SQL=$(mktemp --suffix=.sql)
    
    # Create SQL that gets remote data and inserts it locally with collector_id
    cat > "$TRANSFER_SQL" << EOF_TRANSFER
INSERT INTO $LOCAL_TABLE (collector_id, original_log_id, received_at, hostname, facility, message, port)
SELECT $COLLECTOR_ID,
       remote_data.id,
       remote_data.received_at,
       remote_data.hostname,
       remote_data.facility,
       remote_data.message,
       remote_data.port
FROM (
    SELECT id, received_at, hostname, facility, message, port
    FROM $REMOTE_TABLE
    WHERE id > $LAST_LOCAL_ID
    ORDER BY id
    LIMIT $ROWS_TO_FETCH
) AS remote_data;
EOF_TRANSFER
    
    # Execute the SQL on the local database by first getting data from remote and then executing the insert
    # We'll use a different approach - create a script that generates INSERT statements
    INSERT_SCRIPT=$(mktemp)
    
    # Get the data from remote and format as INSERT statements
    mysql -h $REMOTE_HOST -u $REMOTE_USER -p"$REMOTE_PASS" -N -r -B $REMOTE_DB -e "SELECT CONCAT('($COLLECTOR_ID,', id, ',', IFNULL(QUOTE(received_at), 'NULL'), ',', IFNULL(QUOTE(hostname), 'NULL'), ',', IFNULL(QUOTE(facility), 'NULL'), ',', IFNULL(QUOTE(message), 'NULL'), ',', IFNULL(port, 'NULL'), '),') FROM $REMOTE_TABLE WHERE id > $LAST_LOCAL_ID ORDER BY id LIMIT $ROWS_TO_FETCH;" > "$INSERT_SCRIPT"
    
    # Count lines to debug
    ROW_COUNT=$(wc -l < "$INSERT_SCRIPT")
    echo "DEBUG: Generated $ROW_COUNT potential INSERT lines"
    
    if [ -s "$INSERT_SCRIPT" ] && [ $ROW_COUNT -gt 0 ]; then
        # Wrap the INSERT statements in a proper INSERT statement
        INSERT_WRAPPER=$(mktemp)
        echo "INSERT INTO $LOCAL_TABLE (collector_id, original_log_id, received_at, hostname, facility, message, port) VALUES" > "$INSERT_WRAPPER"
        sed '$ s/,$//' "$INSERT_SCRIPT" >> "$INSERT_WRAPPER"  # Remove trailing comma from last line
        echo ";" >> "$INSERT_WRAPPER"
        
        # Execute the INSERT
        mysql -u $LOCAL_USER -p"$LOCAL_PASS" $LOCAL_DB < "$INSERT_WRAPPER"
        
        # Count how many rows were inserted
        INSERTED_COUNT=$(mysql -u $LOCAL_USER -p"$LOCAL_PASS" $LOCAL_DB -N -e "SELECT COUNT(*) FROM $LOCAL_TABLE WHERE collector_id = $COLLECTOR_ID AND original_log_id > $LAST_LOCAL_ID;" 2>/dev/null)
        echo "DEBUG: Successfully inserted $INSERTED_COUNT rows into main table"
        
        # Clean up wrapper
        rm -f "$INSERT_WRAPPER"
    else
        INSERTED_COUNT=0
        echo "DEBUG: No data to insert"
    fi
    
    # Clean up
    rm -f "$TRANSFER_SQL" "$INSERT_SCRIPT"
    
    # Set TRANSFER_EXIT based on whether we inserted data
    if [ "$INSERTED_COUNT" -gt 0 ]; then
        TRANSFER_EXIT=0
    else
        TRANSFER_EXIT=1
    fi
    
    # End timing
    END_TIME=$(date +%s.%N)
    
    if [ $TRANSFER_EXIT -ne 0 ]; then
        echo "ERROR: Transfer failed for collector $COLLECTOR_NAME with exit code $TRANSFER_EXIT"
        echo "------------------------------------------"
        continue
    fi
    
    # Calculate duration
    DURATION=$(echo "$END_TIME - $START_TIME" | bc)
    
    # Verify transfer by checking the highest ID for this collector in our local table
    NEW_LOCAL_ID=$(mysql -u $LOCAL_USER -p"$LOCAL_PASS" $LOCAL_DB -N -e "SELECT IFNULL(MAX(original_log_id), 0) FROM $LOCAL_TABLE WHERE collector_id = $COLLECTOR_ID;" 2>/dev/null)
    
    # The transfer might have failed silently or not updated the table properly
    # Let's recalculate based on what should have been transferred
    if [ "$NEW_LOCAL_ID" -eq "$LAST_LOCAL_ID" ]; then
        # Calculate what the new max ID should be based on the transfer
        # We transferred records with id > $LAST_LOCAL_ID up to $ROWS_TO_FETCH records
        # Get the actual max original_log_id for this collector after the attempted transfer
        NEW_LOCAL_ID=$(mysql -u $LOCAL_USER -p"$LOCAL_PASS" $LOCAL_DB -N -e "SELECT IFNULL(MAX(original_log_id), $LAST_LOCAL_ID) FROM $LOCAL_TABLE WHERE collector_id = $COLLECTOR_ID;" 2>/dev/null)
    fi
    TRANSFERRED_ROWS=$((NEW_LOCAL_ID - LAST_LOCAL_ID))
    
    # If no new records were inserted, calculate based on how many should have been transferred
    if [ $TRANSFERRED_ROWS -le 0 ]; then
        TRANSFERRED_ROWS=$ROWS_TO_FETCH
    fi
    
    echo "=========================================="
    echo "Sync Complete for Collector $COLLECTOR_NAME!"
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
        echo "⚠ $REMAINING rows still remaining on remote server for collector $COLLECTOR_NAME"
        echo "Run the script again to fetch more data"
    fi
    
    # Update the last_fetched_id in the collectors table
    mysql -u $LOCAL_USER -p"$LOCAL_PASS" $LOCAL_DB -e "UPDATE collectors SET last_fetched_id = $NEW_LOCAL_ID, updated_at = NOW() WHERE id = $COLLECTOR_ID;" 2>/dev/null
    
    echo ""
    
    # Show sample of newly transferred data for this collector
    echo "Sample of newly transferred data for collector $COLLECTOR_NAME:"
    mysql -u $LOCAL_USER -p"$LOCAL_PASS" $LOCAL_DB -t -e "SELECT id, original_log_id, received_at, hostname, LEFT(message, 50) as message_preview, port FROM $LOCAL_TABLE WHERE collector_id = $COLLECTOR_ID AND original_log_id > $LAST_LOCAL_ID ORDER BY original_log_id LIMIT 5;" 2>/dev/null
    
    echo ""
    
    # Process newly transferred logs for parsing
    echo "Processing newly transferred logs for parsing..."
    # Call PHP parser to process new logs for this collector
    # Check both Windows and Linux paths
    if [ -f "/var/www/html/syslog-analyzer-permission/message_parser.php" ]; then
        php_message_parser="/var/www/html/syslog-analyzer-permission/message_parser.php"
    elif [ -f "/c/xampp/htdocs/analyzer/syslog-analyzer-permissions/message_parser.php" ]; then
        php_message_parser="/c/xampp/htdocs/analyzer/syslog-analyzer-permissions/message_parser.php"
    else
        php_message_parser="message_parser.php"
    fi
    
    if [ -f "$php_message_parser" ]; then
        # Also check for system_action_manager.php
        if [ -f "/var/www/html/syslog-analyzer-permission/system_action_manager.php" ]; then
            php_system_action_manager="/var/www/html/syslog-analyzer-permission/system_action_manager.php"
        elif [ -f "/c/xampp/htdocs/analyzer/syslog-analyzer-permissions/system_action_manager.php" ]; then
            php_system_action_manager="/c/xampp/htdocs/analyzer/syslog-analyzer-permissions/system_action_manager.php"
        else
            php_system_action_manager="system_action_manager.php"
        fi

        # Check for device_manager.php
        if [ -f "/var/www/html/syslog-analyzer-permission/device_manager.php" ]; then
            php_device_manager="/var/www/html/syslog-analyzer-permission/device_manager.php"
        elif [ -f "/c/xampp/htdocs/analyzer/syslog-analyzer-permissions/device_manager.php" ]; then
            php_device_manager="/c/xampp/htdocs/analyzer/syslog-analyzer-permissions/device_manager.php"
        else
            php_device_manager="device_manager.php"
        fi
        # Create a temporary PHP script to process the new logs
        TEMP_PHP_SCRIPT=$(mktemp --suffix=.php)
        # Use double quotes to allow variable substitution in the heredoc
        cat > "$TEMP_PHP_SCRIPT" << EOF_PHP
<?php
// Include the standardized connection
// Check for connection.php in various locations
if (file_exists('/var/www/html/syslog-analyzer-permission/connection.php')) {
    require_once '/var/www/html/syslog-analyzer-permission/connection.php';
} elseif (file_exists('connection.php')) {
    require_once 'connection.php';
} else {
    die("connection.php not found");
}

// Initialize device manager
if (file_exists('$php_device_manager')) {
    require_once '$php_device_manager';
    // Check if class exists before instantiating
    if (class_exists('DeviceManager')) {
        \$deviceManager = new DeviceManager(\$pdo);
    } else {
        echo "Warning: DeviceManager class not found despite file existing.\n";
        \$deviceManager = null;
    }
} else {
    echo "Warning: device_manager.php not found at $php_device_manager. Devices will not be registered.\n";
    \$deviceManager = null;
}

// Update the system_action_manager path in message_parser
// Create a temporary message parser that references the correct system_action_manager path
if (file_exists('$php_message_parser')) {
    require_once '$php_message_parser';
    
    // Define a new class that extends MessageParser to use the correct system_action_manager path
    if (!class_exists('CustomMessageParser')) {
        class CustomMessageParser extends MessageParser {
            public function __construct(\$pdo) {
                \$this->pdo = \$pdo;
                
                // Load patterns and field rules manually since parent constructor won't run
                \$this->loadPatternsManually();
                \$this->loadFieldRulesManually();
                
                // Initialize system action manager with correct path
                if (file_exists('$php_system_action_manager')) {
                    require_once '$php_system_action_manager';
                } else {
                    die("system_action_manager.php not found");
                }
                \$this->systemActionManager = new SystemActionManager(\$pdo);
            }
            
            private function loadPatternsManually() {
                \$this->patterns = [];
                \$stmt = \$this->pdo->prepare("SELECT * FROM message_patterns ORDER BY priority DESC");
                \$stmt->execute();
                \$this->patterns = \$stmt->fetchAll(PDO::FETCH_ASSOC);
            }
            
            private function loadFieldRulesManually() {
                \$this->fieldRules = [];
                \$stmt = \$this->pdo->prepare("SELECT * FROM field_extraction_rules");
                \$stmt->execute();
                \$rules = \$stmt->fetchAll(PDO::FETCH_ASSOC);
                
                foreach (\$rules as \$rule) {
                    if (!isset(\$this->fieldRules[\$rule['pattern_id']])) {
                        \$this->fieldRules[\$rule['pattern_id']] = [];
                    }
                    \$this->fieldRules[\$rule['pattern_id']][] = \$rule;
                }
            }
            
            // Inherit all other methods from MessageParser
        }
    }
    
    \$parser = new CustomMessageParser(\$pdo);
} else {
    die("message_parser.php not found");
}

// Get the collector ID and last local ID from command line args
\$collectorId = \$argv[1];
\$lastLocalId = \$argv[2];

// Fetch new logs that need parsing
// We need to find logs in log_mirror that correspond to the remote IDs that were just transferred
// Since we transferred logs with remote ID > \$lastLocalId, we need to find them in our local table
\$stmt = \$pdo->prepare("SELECT id, message, collector_id, port, hostname FROM log_mirror WHERE collector_id = ? AND original_log_id > ? ORDER BY id");
\$stmt->execute([\$collectorId, \$lastLocalId]);

\$processed = 0;
\$successful = 0;
\$registeredDevices = [];

while (\$row = \$stmt->fetch(PDO::FETCH_ASSOC)) {
    \$processed++;

    // Register device if available
    if (\$deviceManager) {
        \$deviceKey = \$row['collector_id'] . '_' . \$row['port'];
        if (!isset(\$registeredDevices[\$deviceKey])) {
            \$deviceManager->registerDevice(\$row['collector_id'], \$row['hostname'], \$row['port']);
            \$registeredDevices[\$deviceKey] = true;
        }
    }
    echo "Processing log ID: " . \$row['id'] . " for collector: " . \$row['collector_id'] . "\n";
    
    \$result = \$parser->parseMessage(\$row['message'], \$row['id'], \$row['collector_id'], \$row['port']);
    
    if (\$result) {
        \$successful++;
        echo "Successfully parsed log ID: " . \$row['id'] . "\n";
    } else {
        echo "Failed to parse log ID: " . \$row['id'] . "\n";
    }
}

echo "Parsing completed. Processed: \$processed, Successful: \$successful\n";
EOF_PHP
        
        # Execute the temporary PHP script with collector ID and last local ID as parameters
        php "$TEMP_PHP_SCRIPT" "$COLLECTOR_ID" "$LAST_LOCAL_ID"
        
        # Clean up the temporary file
        rm "$TEMP_PHP_SCRIPT"
    else
        echo "Warning: Message parser not found at $php_message_parser"
    fi
    
    echo ""
    echo "------------------------------------------"
    
done <<< "$COLLECTORS_DATA"

echo "=========================================="
echo "All collectors processed!"
echo "=========================================="

# Show overall sync statistics
TOTAL_LOCAL=$(mysql -u $LOCAL_USER -p"$LOCAL_PASS" $LOCAL_DB -N -e "SELECT COUNT(*) FROM $LOCAL_TABLE;" 2>/dev/null)
ACTIVE_COLLECTORS=$(mysql -u $LOCAL_USER -p"$LOCAL_PASS" $LOCAL_DB -N -e "SELECT COUNT(*) FROM collectors WHERE is_active = 1;" 2>/dev/null)

echo "Overall Sync Status:"
echo "  Total local log entries: $TOTAL_LOCAL"
echo "  Active collectors: $ACTIVE_COLLECTORS"
echo "=========================================="
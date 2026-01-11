#!/bin/bash

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
    
    # Method: Generate INSERT statements with collector_id and execute them
    mysql -h $REMOTE_HOST \
          -u $REMOTE_USER \
          -p"$REMOTE_PASS" \
          -N -B \
          $REMOTE_DB << EOF | mysql -u $LOCAL_USER -p"$LOCAL_PASS" $LOCAL_DB 2>&1
SELECT CONCAT(
  'INSERT INTO $LOCAL_TABLE (collector_id, original_log_id, received_at, hostname, facility, message, port) VALUES (',
  '$COLLECTOR_ID', ',',
  id, ',',
  QUOTE(received_at), ',',
  QUOTE(hostname), ',',
  QUOTE(facility), ',',
  QUOTE(message), ',',
  QUOTE(port), ');'
) FROM $REMOTE_TABLE 
WHERE id > $LAST_LOCAL_ID 
ORDER BY id 
LIMIT $ROWS_TO_FETCH;
EOF
    
    TRANSFER_EXIT=$?
    
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
        # Create a temporary PHP script to process the new logs
        TEMP_PHP_SCRIPT=$(mktemp --suffix=.php)
        cat > "$TEMP_PHP_SCRIPT" << EOF
<?php
require_once '$php_message_parser';

// Database connection
try {
    $pdo = new PDO("mysql:host=localhost;dbname=analyzer", "ruser", "ruser1@Analyzer");
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
} catch (PDOException $e) {
    die("Connection failed: " . $e->getMessage());
}

$parser = new MessageParser($pdo);

// Get the collector ID and last local ID from command line args
$collectorId = $argv[1];
$lastLocalId = $argv[2];

// Fetch new logs that need parsing
$stmt = $pdo->prepare("SELECT id, message, collector_id, port FROM log_mirror WHERE collector_id = ? AND original_log_id > ? ORDER BY id");
$stmt->execute([$collectorId, $lastLocalId]);

$processed = 0;
$successful = 0;

while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
    $processed++;
    echo "Processing log ID: " . $row['id'] . " for collector: " . $row['collector_id'] . "\n";
    
    $result = $parser->parseMessage($row['message'], $row['id'], $row['collector_id'], $row['port']);
    
    if ($result) {
        $successful++;
        echo "Successfully parsed log ID: " . $row['id'] . "\n";
    } else {
        echo "Failed to parse log ID: " . $row['id'] . "\n";
    }
}

echo "Parsing completed. Processed: $processed, Successful: $successful\n";
EOF
        
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
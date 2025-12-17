#!/bin/bash

# Configuration
REMOTE_HOST="142.91.101.142"
REMOTE_USER="Admin"
REMOTE_PASS="Admin@collector1"
REMOTE_DB="syslog_db"
REMOTE_TABLE="remote_logs"

LOCAL_USER="ruser"
LOCAL_PASS="ruser1@Analyzer"
LOCAL_DB="test_transfer"
LOCAL_TABLE="remote_logs"

BATCH_SIZE=5000  # Number of rows to fetch per sync

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
SYNC_PERCENT=$(echo "scale=2; ($TOTAL_LOCAL * 100) / $TOTAL_REMOTE" | bc)
echo "  Sync progress: $SYNC_PERCENT%"
echo "=========================================="
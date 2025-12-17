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
    
    ./incremental_transfer.sh | grep -E "(New rows available|No new data|Rows transferred)"
    
    echo "Waiting 60 seconds before next sync..."
    echo ""
    sleep 60
done
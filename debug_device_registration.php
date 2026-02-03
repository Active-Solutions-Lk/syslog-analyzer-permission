<?php
// Diagnostic script to trace device registration process
require_once 'connection.php';
require_once 'device_manager.php';

echo "=== DEVICE REGISTRATION DEBUG TRACE ===\n\n";

$deviceManager = new DeviceManager($pdo);

// 1. Check current state
echo "1. CURRENT DATABASE STATE:\n";
echo "   Devices table count: ";
$stmt = $pdo->prepare("SELECT COUNT(*) as count FROM devices");
$stmt->execute();
$count = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
echo "$count\n";

echo "   Log_mirror table count: ";
$stmt = $pdo->prepare("SELECT COUNT(*) as count FROM log_mirror");
$stmt->execute();
$count = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
echo "$count\n\n";

// 2. Check unique hostnames and ports in log_mirror
echo "2. UNIQUE HOSTNAME + PORT COMBINATIONS IN LOG_MIRROR:\n";
$stmt = $pdo->prepare("
    SELECT hostname, port, collector_id, COUNT(*) as log_count 
    FROM log_mirror 
    GROUP BY hostname, port, collector_id 
    ORDER BY collector_id, port, hostname
");
$stmt->execute();
$combinations = $stmt->fetchAll(PDO::FETCH_ASSOC);

foreach ($combinations as $combo) {
    echo "   Collector: {$combo['collector_id']}, Hostname: {$combo['hostname']}, Port: {$combo['port']}, Logs: {$combo['log_count']}\n";
}
echo "\n";

// 3. Test manual device registration for each combination
echo "3. MANUAL DEVICE REGISTRATION TEST:\n";
$registeredDevices = [];

foreach ($combinations as $combo) {
    $key = "{$combo['collector_id']}_{$combo['hostname']}_{$combo['port']}";
    
    if (!isset($registeredDevices[$key])) {
        echo "   Registering: Collector={$combo['collector_id']}, Hostname={$combo['hostname']}, Port={$combo['port']}\n";
        $result = $deviceManager->registerDevice($combo['collector_id'], $combo['hostname'], $combo['port']);
        if ($result) {
            echo "   ✓ Success - Device ID: $result\n";
            $registeredDevices[$key] = $result;
        } else {
            echo "   ✗ Failed\n";
        }
    }
}
echo "\n";

// 4. Show final device state
echo "4. FINAL DEVICES TABLE STATE:\n";
$stmt = $pdo->prepare("SELECT id, collector_id, port, device_name, status FROM devices ORDER BY collector_id, port, device_name");
$stmt->execute();
$devices = $stmt->fetchAll(PDO::FETCH_ASSOC);

if (empty($devices)) {
    echo "   No devices found!\n";
} else {
    foreach ($devices as $device) {
        echo "   ID: {$device['id']}, Collector: {$device['collector_id']}, Port: {$device['port']}, Device: {$device['device_name']}, Status: {$device['status']}\n";
    }
}
echo "\n";

// 5. Test the processing logic that should happen during normal operation
echo "5. SIMULATING NORMAL PROCESSING LOGIC:\n";
echo "   Clearing device registration cache...\n";
$registeredDevices = []; // Reset cache like in normal processing

$stmt = $pdo->prepare("SELECT DISTINCT collector_id, hostname, port FROM log_mirror ORDER BY id LIMIT 10");
$stmt->execute();
$rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

echo "   Processing first 10 unique log entries:\n";
foreach ($rows as $row) {
    $deviceKey = $row['collector_id'] . '_' . $row['hostname'] . '_' . $row['port'];
    echo "   Row: Collector={$row['collector_id']}, Hostname={$row['hostname']}, Port={$row['port']}\n";
    echo "   DeviceKey: $deviceKey\n";
    
    if (!isset($registeredDevices[$deviceKey])) {
        echo "   → NEW DEVICE - Calling registerDevice()\n";
        $result = $deviceManager->registerDevice($row['collector_id'], $row['hostname'], $row['port']);
        if ($result) {
            echo "   → Registered successfully (ID: $result)\n";
            $registeredDevices[$deviceKey] = $result;
        } else {
            echo "   → Registration FAILED\n";
        }
    } else {
        echo "   → Already registered (cached)\n";
    }
    echo "\n";
}

echo "=== DEBUG COMPLETE ===\n";
?>
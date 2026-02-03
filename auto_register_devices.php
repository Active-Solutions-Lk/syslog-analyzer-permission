<?php
// Automated device registration script - processes all existing logs and registers devices
require_once 'connection.php';
require_once 'device_manager.php';

echo "=== AUTOMATED DEVICE REGISTRATION ===\n\n";

$deviceManager = new DeviceManager($pdo);

// Get all unique hostname+port+collector combinations from existing logs
$stmt = $pdo->prepare("
    SELECT DISTINCT collector_id, hostname, port 
    FROM log_mirror 
    WHERE hostname IS NOT NULL AND hostname != ''
    ORDER BY collector_id, port, hostname
");
$stmt->execute();
$logEntries = $stmt->fetchAll(PDO::FETCH_ASSOC);

echo "Found " . count($logEntries) . " unique device combinations to process:\n\n";

$registeredCount = 0;
$failedCount = 0;

foreach ($logEntries as $entry) {
    echo "Processing: Collector={$entry['collector_id']}, Hostname={$entry['hostname']}, Port={$entry['port']}...";
    
    $result = $deviceManager->registerDevice($entry['collector_id'], $entry['hostname'], $entry['port']);
    
    if ($result) {
        echo " SUCCESS (Device ID: $result)\n";
        $registeredCount++;
    } else {
        echo " FAILED\n";
        $failedCount++;
    }
}

echo "\n=== SUMMARY ===\n";
echo "Successfully registered: $registeredCount devices\n";
echo "Failed to register: $failedCount devices\n";

// Show final device state
echo "\n=== CURRENT DEVICES ===\n";
$stmt = $pdo->prepare("SELECT id, collector_id, port, device_name, status FROM devices ORDER BY collector_id, port, device_name");
$stmt->execute();
$devices = $stmt->fetchAll(PDO::FETCH_ASSOC);

foreach ($devices as $device) {
    echo "ID: {$device['id']}, Collector: {$device['collector_id']}, Port: {$device['port']}, Device: {$device['device_name']}, Status: {$device['status']}\n";
}

echo "\n=== PROCESS COMPLETE ===\n";
?>
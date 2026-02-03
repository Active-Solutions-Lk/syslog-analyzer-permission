<?php
require_once 'connection.php';
require_once 'device_manager.php';

$deviceManager = new DeviceManager($pdo);

echo "=== Testing Device Registration with Same Port, Different Hostnames ===\n\n";

// Test 1: Register first device
echo "Test 1: Registering Active-Com on port 2001\n";
$result1 = $deviceManager->registerDevice(1, 'Active-Com', 2001);
echo "Result: " . ($result1 ? "Success (ID: $result1)" : "Failed") . "\n\n";

// Test 2: Register second device with same port but different hostname
echo "Test 2: Registering DiskStation on port 2001\n";
$result2 = $deviceManager->registerDevice(1, 'DiskStation', 2001);
echo "Result: " . ($result2 ? "Success (ID: $result2)" : "Failed") . "\n\n";

// Test 3: Try to register the same device again (should not create duplicate)
echo "Test 3: Re-registering Active-Com on port 2001 (should detect existing)\n";
$result3 = $deviceManager->registerDevice(1, 'Active-Com', 2001);
echo "Result: " . ($result3 ? "Success (ID: $result3)" : "Failed") . "\n\n";

// Show all devices
echo "=== Current Devices in Database ===\n";
$stmt = $pdo->prepare("SELECT id, collector_id, port, device_name, status FROM devices ORDER BY id");
$stmt->execute();
$devices = $stmt->fetchAll(PDO::FETCH_ASSOC);

foreach ($devices as $device) {
    echo "ID: {$device['id']}, Collector: {$device['collector_id']}, Port: {$device['port']}, Device: {$device['device_name']}, Status: {$device['status']}\n";
}

echo "\n=== Test Complete ===\n";
?>
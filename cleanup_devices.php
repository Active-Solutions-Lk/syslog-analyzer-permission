<?php
require_once 'connection.php';

try {
    // Clean up existing devices to test the new logic
    $stmt = $pdo->prepare("DELETE FROM devices WHERE id = 1");
    $stmt->execute();
    echo "Cleaned up existing device records.\n";
    
    // Also truncate log_mirror to start fresh test
    $stmt = $pdo->prepare("TRUNCATE TABLE log_mirror");
    $stmt->execute();
    echo "Truncated log_mirror table for fresh test.\n";
    
} catch (PDOException $e) {
    echo "Error: " . $e->getMessage() . "\n";
}
?>
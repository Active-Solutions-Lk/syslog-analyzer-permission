<?php
// Database configuration
$host = 'localhost';
$dbname = 'analyzer';
$username = 'ruser';
$password = 'ruser1@Analyzer'; // Replace with your actual MySQL password
define('STATIC_TOKEN', 'I3UYA2HSQPB86XpsdVUb9szDu5tn2W3fOpg8'); // Secret Key for api requests


try {
    // Create PDO connection
    $pdo = new PDO("mysql:host=$host;dbname=$dbname", $username, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
} catch (PDOException $e) {
    die("Database connection failed: " . $e->getMessage() . "\n");
}
?>
<?php

class MessageParser {
    private $pdo;
    private $patterns;
    private $fieldRules;
    private $systemActionManager;

    public function __construct($pdo) {
        $this->pdo = $pdo;
        $this->loadPatterns();
        $this->loadFieldRules();
        
        // Initialize system action manager
        require_once 'system_action_manager.php';
        $this->systemActionManager = new SystemActionManager($pdo);
    }

    private function loadPatterns() {
        $this->patterns = [];
        $stmt = $this->pdo->prepare("SELECT * FROM message_patterns ORDER BY priority DESC");
        $stmt->execute();
        $this->patterns = $stmt->fetchAll(PDO::FETCH_ASSOC);
    }

    private function loadFieldRules() {
        $this->fieldRules = [];
        $stmt = $this->pdo->prepare("SELECT * FROM field_extraction_rules");
        $stmt->execute();
        $rules = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        foreach ($rules as $rule) {
            if (!isset($this->fieldRules[$rule['pattern_id']])) {
                $this->fieldRules[$rule['pattern_id']] = [];
            }
            $this->fieldRules[$rule['pattern_id']][] = $rule;
        }
    }

    public function parseMessage($message, $logMirrorId, $collectorId, $port) {
        $matchedPattern = null;
        $extractedData = [];
        
        // Try to match message against patterns
        foreach ($this->patterns as $pattern) {
            if (preg_match($pattern['pattern_regex'], $message, $matches)) {
                $matchedPattern = $pattern;
                echo "Message matched pattern: " . $pattern['name'] . "\n";
                break;
            }
        }
        
        if (!$matchedPattern) {
            echo "No pattern matched for message: " . substr($message, 0, 100) . "...\n";
            return false;
        }
        
        // Extract fields using field rules
        if (isset($this->fieldRules[$matchedPattern['id']])) {
            foreach ($this->fieldRules[$matchedPattern['id']] as $rule) {
                $value = null;
                
                if (!empty($rule['regex_pattern'])) {
                    if (preg_match($rule['regex_pattern'], $message, $fieldMatches)) {
                        $value = $fieldMatches[$rule['regex_group_index']] ?? null;
                    }
                }
                
                // Use default value if no match and default is set
                if ($value === null && !empty($rule['default_value'])) {
                    $value = $rule['default_value'];
                }
                
                // Check required fields
                if ($rule['is_required'] && empty($value)) {
                    echo "Required field '" . $rule['field_name'] . "' not found\n";
                    return false;
                }
                
                $extractedData[$rule['field_name']] = $value;
            }
        }
        
        // Handle SYSTEM messages specially
        if ($matchedPattern['name'] === 'SYSTEM Message Pattern') {
            return $this->handleSystemMessage($logMirrorId, $collectorId, $port, $extractedData);
        } else {
            // Save regular parsed data
            return $this->saveParsedLog($logMirrorId, $collectorId, $port, $matchedPattern['id'], $extractedData);
        }
    }
    
    private function handleSystemMessage($logMirrorId, $collectorId, $port, $data) {
        // Save to system_actions table
        if (isset($data['action_description'])) {
            $success = $this->systemActionManager->saveSystemAction(
                $logMirrorId, 
                $collectorId, 
                $data['action_description']
            );
            
            if ($success) {
                // Also save to parsed_logs for consistency
                return $this->saveParsedLog($logMirrorId, $collectorId, $port, 3, $data); // Pattern ID 3 is SYSTEM pattern
            }
            return $success;
        }
        
        echo "No action description found in SYSTEM message\n";
        return false;
    }
    
    private function saveParsedLog($logMirrorId, $collectorId, $port, $patternId, $data) {
        try {
            // First, verify that the log_mirror record exists
            $checkLogMirrorStmt = $this->pdo->prepare("SELECT id FROM log_mirror WHERE id = ?");
            $checkLogMirrorStmt->execute([$logMirrorId]);
            
            if (!$checkLogMirrorStmt->fetch()) {
                echo "Error: log_mirror record with ID $logMirrorId does not exist\n";
                return false;
            }
            
            // Verify that the pattern exists (if provided)
            if ($patternId !== null) {
                $checkPatternStmt = $this->pdo->prepare("SELECT id FROM message_patterns WHERE id = ?");
                $checkPatternStmt->execute([$patternId]);
                
                if (!$checkPatternStmt->fetch()) {
                    echo "Warning: message_pattern with ID $patternId does not exist, setting to NULL\n";
                    $patternId = null;
                }
            }
            
            $stmt = $this->pdo->prepare("
                INSERT INTO parsed_logs 
                (log_mirror_id, collector_id, port, pattern_id, event_type, file_path, file_folder_type, file_size, username, user_ip, source_path, destination_path, additional_data) 
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE
                event_type = VALUES(event_type),
                file_path = VALUES(file_path),
                file_folder_type = VALUES(file_folder_type),
                file_size = VALUES(file_size),
                username = VALUES(username),
                user_ip = VALUES(user_ip),
                source_path = VALUES(source_path),
                destination_path = VALUES(destination_path),
                additional_data = VALUES(additional_data)
            ");
            
            // Handle additional data for fields not in main columns
            $additionalData = [];
            $mainFields = ['event_type', 'file_path', 'file_folder_type', 'file_size', 'username', 'user_ip', 'source_path', 'destination_path'];
            
            foreach ($data as $key => $value) {
                if (!in_array($key, $mainFields)) {
                    $additionalData[$key] = $value;
                }
            }
            
            // Ensure source_path is properly set
            $sourcePath = $data['source_path'] ?? $data['file_path'] ?? null;
            
            $stmt->execute([
                $logMirrorId,
                $collectorId,
                $port,
                $patternId,
                $data['event_type'] ?? null,
                $data['file_path'] ?? null,
                $data['file_folder_type'] ?? null,
                $data['file_size'] ?? null,
                $data['username'] ?? null,
                $data['user_ip'] ?? null,
                $sourcePath,
                $data['destination_path'] ?? null,
                json_encode($additionalData)
            ]);
            
            echo "Parsed log saved successfully\n";
            return true;
            
        } catch (PDOException $e) {
            echo "Error saving parsed log: " . $e->getMessage() . "\n";
            return false;
        }
    }
}

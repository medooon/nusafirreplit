<?php
/**
 * Database Configuration and Connection
 * 
 * This file handles the database connection for the Visa Egypt application.
 * It provides functions to connect to the MySQL database and execute queries.
 */

// Database credentials
define('DB_HOST', 'localhost');      // Database host
define('DB_NAME', 'visa_egypt_db');  // Database name
define('DB_USER', 'visa_user');      // Database username
define('DB_PASS', 'your_password');  // Database password - change this in production

// Error reporting
error_reporting(E_ALL);
ini_set('display_errors', 1);

/**
 * Connect to the database
 * 
 * @return mysqli Database connection object
 */
function connect_db() {
    $conn = new mysqli(DB_HOST, DB_USER, DB_PASS, DB_NAME);
    
    // Check connection
    if ($conn->connect_error) {
        header('Content-Type: application/json');
        echo json_encode([
            'status' => 'error',
            'message' => 'Database connection failed',
            'error' => 'Connection failed: ' . $conn->connect_error
        ]);
        exit;
    }
    
    // Set charset to UTF-8
    $conn->set_charset('utf8mb4');
    
    return $conn;
}

/**
 * Execute a SQL query
 * 
 * @param string $sql SQL query to execute
 * @param array $params Parameters to bind (optional)
 * @param string $types Types of parameters (optional)
 * @return mysqli_result|bool Query result or boolean
 */
function query($sql, $params = [], $types = '') {
    $conn = connect_db();
    
    if (empty($params)) {
        $result = $conn->query($sql);
        
        if (!$result) {
            header('Content-Type: application/json');
            echo json_encode([
                'status' => 'error',
                'message' => 'Database query failed',
                'error' => $conn->error,
                'query' => $sql
            ]);
            $conn->close();
            exit;
        }
        
        $conn->close();
        return $result;
    } else {
        $stmt = $conn->prepare($sql);
        
        if (!$stmt) {
            header('Content-Type: application/json');
            echo json_encode([
                'status' => 'error',
                'message' => 'Database prepare statement failed',
                'error' => $conn->error,
                'query' => $sql
            ]);
            $conn->close();
            exit;
        }
        
        if (empty($types)) {
            $types = str_repeat('s', count($params));
        }
        
        $stmt->bind_param($types, ...$params);
        $result = $stmt->execute();
        
        if (!$result) {
            header('Content-Type: application/json');
            echo json_encode([
                'status' => 'error',
                'message' => 'Database execute statement failed',
                'error' => $stmt->error
            ]);
            $stmt->close();
            $conn->close();
            exit;
        }
        
        $queryResult = $stmt->get_result();
        $stmt->close();
        $conn->close();
        return $queryResult;
    }
}

/**
 * Get the ID of the last inserted row
 * 
 * @return int Last inserted ID
 */
function last_insert_id() {
    $conn = connect_db();
    $id = $conn->insert_id;
    $conn->close();
    return $id;
}

/**
 * Sanitize input to prevent SQL injection
 * 
 * @param string $input Input to sanitize
 * @return string Sanitized input
 */
function sanitize($input) {
    $conn = connect_db();
    $sanitized = $conn->real_escape_string($input);
    $conn->close();
    return $sanitized;
}

/**
 * Start a database transaction
 */
function begin_transaction() {
    $conn = connect_db();
    $conn->begin_transaction();
    return $conn;
}

/**
 * Commit a database transaction
 * 
 * @param mysqli $conn Database connection
 */
function commit_transaction($conn) {
    $conn->commit();
    $conn->close();
}

/**
 * Rollback a database transaction
 * 
 * @param mysqli $conn Database connection
 */
function rollback_transaction($conn) {
    $conn->rollback();
    $conn->close();
}
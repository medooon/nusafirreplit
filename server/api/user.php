<?php
/**
 * User API Endpoints
 * 
 * This file handles all user-related API requests:
 * - Login
 * - Registration
 * - User profile
 * - Password reset
 */

require_once '../config/database.php';

// Set headers
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// Get request method
$method = $_SERVER['REQUEST_METHOD'];

// Get endpoint (from URL path or query string)
$endpoint = isset($_GET['endpoint']) ? $_GET['endpoint'] : '';

// Process request based on method and endpoint
switch ($method) {
    case 'GET':
        switch ($endpoint) {
            case 'profile':
                getUserProfile();
                break;
            default:
                sendResponse(404, 'error', 'Endpoint not found');
                break;
        }
        break;
    
    case 'POST':
        switch ($endpoint) {
            case 'login':
                login();
                break;
            case 'register':
                register();
                break;
            case 'reset-password':
                resetPassword();
                break;
            default:
                sendResponse(404, 'error', 'Endpoint not found');
                break;
        }
        break;
    
    case 'PUT':
        switch ($endpoint) {
            case 'profile':
                updateUserProfile();
                break;
            default:
                sendResponse(404, 'error', 'Endpoint not found');
                break;
        }
        break;
    
    default:
        sendResponse(405, 'error', 'Method not allowed');
        break;
}

/**
 * Handle user login
 */
function login() {
    // Get JSON data from request body
    $json = file_get_contents('php://input');
    $data = json_decode($json, true);
    
    // Validate required fields
    if (!isset($data['email']) || !isset($data['password'])) {
        sendResponse(400, 'error', 'Email and password are required');
        return;
    }
    
    $email = $data['email'];
    $password = $data['password'];
    
    // Get user from database
    $sql = "SELECT * FROM users WHERE email = ?";
    $result = query($sql, [$email]);
    
    if ($result->num_rows === 0) {
        sendResponse(401, 'error', 'Invalid email or password');
        return;
    }
    
    $user = $result->fetch_assoc();
    
    // Verify password
    if (!password_verify($password, $user['password_hash'])) {
        sendResponse(401, 'error', 'Invalid email or password');
        return;
    }
    
    // Update last login time
    $updateSql = "UPDATE users SET last_login_at = NOW() WHERE id = ?";
    query($updateSql, [$user['id']]);
    
    // Generate token (in a real app, use JWT or other secure method)
    $token = bin2hex(random_bytes(32));
    
    // Remove sensitive info
    unset($user['password_hash']);
    
    // Return user data with token
    sendResponse(200, 'success', 'Login successful', [
        'user' => $user,
        'token' => $token
    ]);
}

/**
 * Handle user registration
 */
function register() {
    // Get JSON data from request body
    $json = file_get_contents('php://input');
    $data = json_decode($json, true);
    
    // Validate required fields
    if (!isset($data['name']) || !isset($data['email']) || !isset($data['password']) || 
        !isset($data['phone_number']) || !isset($data['user_type'])) {
        sendResponse(400, 'error', 'Missing required fields');
        return;
    }
    
    $name = $data['name'];
    $email = $data['email'];
    $password = $data['password'];
    $phoneNumber = $data['phone_number'];
    $userType = $data['user_type'];
    
    // Validate user type
    $validUserTypes = ['applicant', 'office'];
    if (!in_array($userType, $validUserTypes)) {
        sendResponse(400, 'error', 'Invalid user type');
        return;
    }
    
    // Check if email already exists
    $checkSql = "SELECT * FROM users WHERE email = ?";
    $result = query($checkSql, [$email]);
    
    if ($result->num_rows > 0) {
        sendResponse(409, 'error', 'Email already registered');
        return;
    }
    
    // Hash password
    $passwordHash = password_hash($password, PASSWORD_DEFAULT);
    
    // Generate user ID (UUID)
    $userId = generateUUID();
    
    // Start transaction
    $conn = begin_transaction();
    
    try {
        // Insert user
        $insertSql = "INSERT INTO users (id, name, email, password_hash, phone_number, user_type, created_at) 
                     VALUES (?, ?, ?, ?, ?, ?, NOW())";
        
        $stmt = $conn->prepare($insertSql);
        $stmt->bind_param('ssssss', $userId, $name, $email, $passwordHash, $phoneNumber, $userType);
        $result = $stmt->execute();
        
        if (!$result) {
            throw new Exception("Failed to create user");
        }
        
        // If user type is office, create office profile
        if ($userType === 'office') {
            $address = $data['address'] ?? '';
            
            $officeSql = "INSERT INTO offices (id, address, created_at) VALUES (?, ?, NOW())";
            $stmt = $conn->prepare($officeSql);
            $stmt->bind_param('ss', $userId, $address);
            $result = $stmt->execute();
            
            if (!$result) {
                throw new Exception("Failed to create office profile");
            }
        }
        
        // Commit transaction
        commit_transaction($conn);
        
        // Generate token (in a real app, use JWT or other secure method)
        $token = bin2hex(random_bytes(32));
        
        // Get the created user
        $userSql = "SELECT * FROM users WHERE id = ?";
        $result = query($userSql, [$userId]);
        $user = $result->fetch_assoc();
        
        // Remove sensitive info
        unset($user['password_hash']);
        
        // Return user data with token
        sendResponse(201, 'success', 'Registration successful', [
            'user' => $user,
            'token' => $token
        ]);
    } catch (Exception $e) {
        // Rollback transaction
        rollback_transaction($conn);
        sendResponse(500, 'error', 'Registration failed: ' . $e->getMessage());
    }
}

/**
 * Get user profile
 */
function getUserProfile() {
    // Get user ID from Authorization header (in a real app, validate token)
    $userId = validateToken();
    
    if (!$userId) {
        sendResponse(401, 'error', 'Unauthorized');
        return;
    }
    
    // Get user from database
    $sql = "SELECT * FROM users WHERE id = ?";
    $result = query($sql, [$userId]);
    
    if ($result->num_rows === 0) {
        sendResponse(404, 'error', 'User not found');
        return;
    }
    
    $user = $result->fetch_assoc();
    
    // Remove sensitive info
    unset($user['password_hash']);
    
    // If office, get office details
    if ($user['user_type'] === 'office') {
        $officeSql = "SELECT * FROM offices WHERE id = ?";
        $officeResult = query($officeSql, [$userId]);
        
        if ($officeResult->num_rows > 0) {
            $office = $officeResult->fetch_assoc();
            $user['office_details'] = $office;
        }
    }
    
    // Return user data
    sendResponse(200, 'success', 'Profile retrieved', ['user' => $user]);
}

/**
 * Update user profile
 */
function updateUserProfile() {
    // Get user ID from Authorization header (in a real app, validate token)
    $userId = validateToken();
    
    if (!$userId) {
        sendResponse(401, 'error', 'Unauthorized');
        return;
    }
    
    // Get JSON data from request body
    $json = file_get_contents('php://input');
    $data = json_decode($json, true);
    
    // Start building query
    $updates = [];
    $params = [];
    $types = '';
    
    // Check which fields to update
    if (isset($data['name'])) {
        $updates[] = "name = ?";
        $params[] = $data['name'];
        $types .= 's';
    }
    
    if (isset($data['phone_number'])) {
        $updates[] = "phone_number = ?";
        $params[] = $data['phone_number'];
        $types .= 's';
    }
    
    if (isset($data['profile_image_url'])) {
        $updates[] = "profile_image_url = ?";
        $params[] = $data['profile_image_url'];
        $types .= 's';
    }
    
    // If no fields to update
    if (empty($updates)) {
        sendResponse(400, 'error', 'No fields to update');
        return;
    }
    
    // Add user ID to params
    $params[] = $userId;
    $types .= 's';
    
    // Update user
    $sql = "UPDATE users SET " . implode(', ', $updates) . " WHERE id = ?";
    query($sql, $params, $types);
    
    // If office, update office details if provided
    if (isset($data['office_details']) && is_array($data['office_details'])) {
        $officeUpdates = [];
        $officeParams = [];
        $officeTypes = '';
        
        if (isset($data['office_details']['address'])) {
            $officeUpdates[] = "address = ?";
            $officeParams[] = $data['office_details']['address'];
            $officeTypes .= 's';
        }
        
        if (isset($data['office_details']['logo_url'])) {
            $officeUpdates[] = "logo_url = ?";
            $officeParams[] = $data['office_details']['logo_url'];
            $officeTypes .= 's';
        }
        
        if (!empty($officeUpdates)) {
            // Add user ID to params
            $officeParams[] = $userId;
            $officeTypes .= 's';
            
            // Update office
            $officeSql = "UPDATE offices SET " . implode(', ', $officeUpdates) . " WHERE id = ?";
            query($officeSql, $officeParams, $officeTypes);
        }
    }
    
    // Get updated user profile
    $userSql = "SELECT * FROM users WHERE id = ?";
    $result = query($userSql, [$userId]);
    $user = $result->fetch_assoc();
    
    // Remove sensitive info
    unset($user['password_hash']);
    
    // Return updated user data
    sendResponse(200, 'success', 'Profile updated', ['user' => $user]);
}

/**
 * Handle password reset
 */
function resetPassword() {
    // Get JSON data from request body
    $json = file_get_contents('php://input');
    $data = json_decode($json, true);
    
    // Validate required fields
    if (!isset($data['email'])) {
        sendResponse(400, 'error', 'Email is required');
        return;
    }
    
    $email = $data['email'];
    
    // Check if email exists
    $sql = "SELECT * FROM users WHERE email = ?";
    $result = query($sql, [$email]);
    
    if ($result->num_rows === 0) {
        // For security, always return success even if email not found
        sendResponse(200, 'success', 'If your email is registered, you will receive a password reset link');
        return;
    }
    
    // In a real app, generate a reset token and send an email
    // For now, just return success
    sendResponse(200, 'success', 'If your email is registered, you will receive a password reset link');
}

/**
 * Validate authentication token
 * 
 * In a real app, use JWT or other secure method
 * For now, just get user ID from Authorization header
 * 
 * @return string|null User ID if valid, null otherwise
 */
function validateToken() {
    // Get Authorization header
    $headers = getallheaders();
    $authorization = $headers['Authorization'] ?? '';
    
    // Check if header exists and starts with "Bearer "
    if (empty($authorization) || strpos($authorization, 'Bearer ') !== 0) {
        return null;
    }
    
    // Get token
    $token = substr($authorization, 7);
    
    // In a real app, validate token (JWT, etc.)
    // For now, just simulate with static user ID
    return '12345678-1234-1234-1234-123456789012';
}

/**
 * Generate UUID v4
 * 
 * @return string UUID v4
 */
function generateUUID() {
    return sprintf('%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
        mt_rand(0, 0xffff), mt_rand(0, 0xffff),
        mt_rand(0, 0xffff),
        mt_rand(0, 0x0fff) | 0x4000,
        mt_rand(0, 0x3fff) | 0x8000,
        mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff)
    );
}

/**
 * Send JSON response
 * 
 * @param int $statusCode HTTP status code
 * @param string $status Status (success/error)
 * @param string $message Response message
 * @param array $data Optional data to include
 */
function sendResponse($statusCode, $status, $message, $data = []) {
    http_response_code($statusCode);
    echo json_encode([
        'status' => $status,
        'message' => $message,
        'data' => $data
    ]);
    exit;
}
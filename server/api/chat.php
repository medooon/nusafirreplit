<?php
/**
 * Chat API Endpoints
 * 
 * This file handles all chat-related API endpoints:
 * - Get messages for a visa request
 * - Send a new message
 * - Mark messages as read
 * - Send system notifications
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
            case 'messages':
                getMessages();
                break;
            default:
                sendResponse(404, 'error', 'Endpoint not found');
                break;
        }
        break;
    
    case 'POST':
        switch ($endpoint) {
            case 'send':
                sendMessage();
                break;
            case 'system-notification':
                sendSystemNotification();
                break;
            default:
                sendResponse(404, 'error', 'Endpoint not found');
                break;
        }
        break;
    
    case 'PUT':
        switch ($endpoint) {
            case 'mark-read':
                markAsRead();
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
 * Get messages for a visa request
 */
function getMessages() {
    // Get user ID from Authorization header (in a real app, validate token)
    $userId = validateToken();
    
    if (!$userId) {
        sendResponse(401, 'error', 'Unauthorized');
        return;
    }
    
    // Get request ID from query string
    $requestId = $_GET['visa_request_id'] ?? '';
    
    if (empty($requestId)) {
        sendResponse(400, 'error', 'Visa request ID is required');
        return;
    }
    
    // Get user type
    $userSql = "SELECT user_type FROM users WHERE id = ?";
    $userResult = query($userSql, [$userId]);
    
    if ($userResult->num_rows === 0) {
        sendResponse(404, 'error', 'User not found');
        return;
    }
    
    $user = $userResult->fetch_assoc();
    $userType = $user['user_type'];
    
    // Check if user is authorized to view messages for this request
    $sql = "SELECT * FROM visa_requests WHERE id = ?";
    $result = query($sql, [$requestId]);
    
    if ($result->num_rows === 0) {
        sendResponse(404, 'error', 'Visa request not found');
        return;
    }
    
    $visaRequest = $result->fetch_assoc();
    
    // Check if user is authorized to view this request's messages
    if ($userType === 'applicant' && $visaRequest['applicant_id'] !== $userId) {
        sendResponse(403, 'error', 'Forbidden');
        return;
    }
    
    if ($userType === 'office' && $visaRequest['office_id'] !== $userId) {
        sendResponse(403, 'error', 'Forbidden');
        return;
    }
    
    // Get messages for this request
    $messagesSql = "SELECT * FROM chat_messages 
                   WHERE visa_request_id = ? 
                   ORDER BY timestamp ASC";
    $messagesResult = query($messagesSql, [$requestId]);
    
    $messages = [];
    while ($message = $messagesResult->fetch_assoc()) {
        $messages[] = $message;
    }
    
    // Return messages
    sendResponse(200, 'success', 'Messages retrieved', [
        'messages' => $messages
    ]);
}

/**
 * Send a message
 */
function sendMessage() {
    // Get user ID from Authorization header (in a real app, validate token)
    $userId = validateToken();
    
    if (!$userId) {
        sendResponse(401, 'error', 'Unauthorized');
        return;
    }
    
    // Get JSON data from request body
    $json = file_get_contents('php://input');
    $data = json_decode($json, true);
    
    // Validate required fields
    if (!isset($data['visa_request_id']) || !isset($data['content']) || 
        !isset($data['message_type'])) {
        sendResponse(400, 'error', 'Missing required fields');
        return;
    }
    
    $requestId = $data['visa_request_id'];
    $content = $data['content'];
    $messageType = $data['message_type'];
    $fileUrl = $data['file_url'] ?? null;
    $metadata = $data['metadata'] ?? null;
    
    // Check if message type is valid
    $validTypes = ['text', 'image', 'document'];
    if (!in_array($messageType, $validTypes)) {
        sendResponse(400, 'error', 'Invalid message type');
        return;
    }
    
    // Get user type
    $userSql = "SELECT user_type FROM users WHERE id = ?";
    $userResult = query($userSql, [$userId]);
    
    if ($userResult->num_rows === 0) {
        sendResponse(404, 'error', 'User not found');
        return;
    }
    
    $user = $userResult->fetch_assoc();
    $userType = $user['user_type'];
    
    // Check if user is authorized to send messages for this request
    $sql = "SELECT * FROM visa_requests WHERE id = ?";
    $result = query($sql, [$requestId]);
    
    if ($result->num_rows === 0) {
        sendResponse(404, 'error', 'Visa request not found');
        return;
    }
    
    $visaRequest = $result->fetch_assoc();
    
    // Check if user is authorized to send messages for this request
    if ($userType === 'applicant' && $visaRequest['applicant_id'] !== $userId) {
        sendResponse(403, 'error', 'Forbidden');
        return;
    }
    
    if ($userType === 'office' && $visaRequest['office_id'] !== $userId) {
        sendResponse(403, 'error', 'Forbidden');
        return;
    }
    
    // Check if conversation is still active
    if (in_array($visaRequest['status'], ['completed', 'rejected'])) {
        sendResponse(400, 'error', 'Cannot send messages in a completed or rejected visa request');
        return;
    }
    
    // Generate message ID (UUID)
    $messageId = generateUUID();
    
    // Create message
    $sql = "INSERT INTO chat_messages (
                id,
                visa_request_id,
                sender_id,
                sender_type,
                content,
                message_type,
                file_url,
                is_read,
                timestamp,
                metadata
            ) VALUES (?, ?, ?, ?, ?, ?, ?, 0, NOW(), ?)";
    
    // Convert metadata to JSON if it exists
    $metadataJson = $metadata ? json_encode($metadata) : null;
    
    query($sql, [
        $messageId,
        $requestId,
        $userId,
        $userType,
        $content,
        $messageType,
        $fileUrl,
        $metadataJson
    ]);
    
    // Create notification for recipients
    // For applicant: notify admin and office
    // For admin: notify applicant and office
    // For office: notify applicant and admin
    
    $notificationTitle = 'New message';
    $notificationContent = "New message in visa request #" . substr($requestId, 0, 8);
    
    if ($userType === 'applicant') {
        // Notify admin if assigned
        if (!empty($visaRequest['admin_id'])) {
            createNotification($visaRequest['admin_id'], $notificationTitle, $notificationContent, 'message', $requestId);
        }
        
        // Notify office if assigned
        if (!empty($visaRequest['office_id'])) {
            createNotification($visaRequest['office_id'], $notificationTitle, $notificationContent, 'message', $requestId);
        }
    } else if ($userType === 'admin') {
        // Notify applicant
        createNotification($visaRequest['applicant_id'], $notificationTitle, $notificationContent, 'message', $requestId);
        
        // Notify office if assigned
        if (!empty($visaRequest['office_id'])) {
            createNotification($visaRequest['office_id'], $notificationTitle, $notificationContent, 'message', $requestId);
        }
    } else if ($userType === 'office') {
        // Notify applicant
        createNotification($visaRequest['applicant_id'], $notificationTitle, $notificationContent, 'message', $requestId);
        
        // Notify admin if assigned
        if (!empty($visaRequest['admin_id'])) {
            createNotification($visaRequest['admin_id'], $notificationTitle, $notificationContent, 'message', $requestId);
        }
    }
    
    // Get the created message
    $selectSql = "SELECT * FROM chat_messages WHERE id = ?";
    $result = query($selectSql, [$messageId]);
    $message = $result->fetch_assoc();
    
    // Return the created message
    sendResponse(201, 'success', 'Message sent', [
        'message' => $message
    ]);
}

/**
 * Send a system notification message
 */
function sendSystemNotification() {
    // Get user ID from Authorization header (in a real app, validate token)
    $userId = validateToken();
    
    if (!$userId) {
        sendResponse(401, 'error', 'Unauthorized');
        return;
    }
    
    // Get user type
    $userSql = "SELECT user_type FROM users WHERE id = ?";
    $userResult = query($userSql, [$userId]);
    
    if ($userResult->num_rows === 0) {
        sendResponse(404, 'error', 'User not found');
        return;
    }
    
    $user = $userResult->fetch_assoc();
    $userType = $user['user_type'];
    
    // Only admins and offices can send system notifications
    if (!in_array($userType, ['admin', 'office'])) {
        sendResponse(403, 'error', 'Only admins and offices can send system notifications');
        return;
    }
    
    // Get JSON data from request body
    $json = file_get_contents('php://input');
    $data = json_decode($json, true);
    
    // Validate required fields
    if (!isset($data['visa_request_id']) || !isset($data['content'])) {
        sendResponse(400, 'error', 'Visa request ID and content are required');
        return;
    }
    
    $requestId = $data['visa_request_id'];
    $content = $data['content'];
    
    // Check if visa request exists
    $sql = "SELECT * FROM visa_requests WHERE id = ?";
    $result = query($sql, [$requestId]);
    
    if ($result->num_rows === 0) {
        sendResponse(404, 'error', 'Visa request not found');
        return;
    }
    
    $visaRequest = $result->fetch_assoc();
    
    // If user is an office, check if they are assigned to this request
    if ($userType === 'office' && $visaRequest['office_id'] !== $userId) {
        sendResponse(403, 'error', 'Forbidden');
        return;
    }
    
    // Generate message ID (UUID)
    $messageId = generateUUID();
    
    // Create system message
    $sql = "INSERT INTO chat_messages (
                id,
                visa_request_id,
                sender_id,
                sender_type,
                content,
                message_type,
                is_read,
                timestamp
            ) VALUES (?, ?, 'system', 'system', ?, 'system', 0, NOW())";
    
    query($sql, [
        $messageId,
        $requestId,
        $content
    ]);
    
    // Create notification for applicant
    $notificationTitle = 'Visa Application Update';
    createNotification($visaRequest['applicant_id'], $notificationTitle, $content, 'system', $requestId);
    
    // Notify other participants (admin and office) if they exist and are not the sender
    if (!empty($visaRequest['admin_id']) && $visaRequest['admin_id'] !== $userId) {
        createNotification($visaRequest['admin_id'], $notificationTitle, $content, 'system', $requestId);
    }
    
    if (!empty($visaRequest['office_id']) && $visaRequest['office_id'] !== $userId) {
        createNotification($visaRequest['office_id'], $notificationTitle, $content, 'system', $requestId);
    }
    
    // Get the created message
    $selectSql = "SELECT * FROM chat_messages WHERE id = ?";
    $result = query($selectSql, [$messageId]);
    $message = $result->fetch_assoc();
    
    // Return the created message
    sendResponse(201, 'success', 'System notification sent', [
        'message' => $message
    ]);
}

/**
 * Mark messages as read
 */
function markAsRead() {
    // Get user ID from Authorization header (in a real app, validate token)
    $userId = validateToken();
    
    if (!$userId) {
        sendResponse(401, 'error', 'Unauthorized');
        return;
    }
    
    // Get JSON data from request body
    $json = file_get_contents('php://input');
    $data = json_decode($json, true);
    
    // Validate required fields
    if (!isset($data['visa_request_id'])) {
        sendResponse(400, 'error', 'Visa request ID is required');
        return;
    }
    
    $requestId = $data['visa_request_id'];
    $messageIds = $data['message_ids'] ?? []; // Optional: specific message IDs to mark as read
    
    // Check if visa request exists
    $sql = "SELECT * FROM visa_requests WHERE id = ?";
    $result = query($sql, [$requestId]);
    
    if ($result->num_rows === 0) {
        sendResponse(404, 'error', 'Visa request not found');
        return;
    }
    
    $visaRequest = $result->fetch_assoc();
    
    // Check if user is a participant in this request
    $userType = getUserType($userId);
    
    if ($userType === 'applicant' && $visaRequest['applicant_id'] !== $userId) {
        sendResponse(403, 'error', 'Forbidden');
        return;
    }
    
    if ($userType === 'office' && $visaRequest['office_id'] !== $userId) {
        sendResponse(403, 'error', 'Forbidden');
        return;
    }
    
    // Mark messages as read
    if (empty($messageIds)) {
        // Mark all unread messages for this request and user
        $sql = "UPDATE chat_messages 
                SET is_read = 1 
                WHERE visa_request_id = ? 
                AND sender_id != ? 
                AND is_read = 0";
        
        query($sql, [$requestId, $userId]);
        
        // Add read status for tracking
        $unreadSql = "SELECT id FROM chat_messages 
                     WHERE visa_request_id = ? 
                     AND sender_id != ? 
                     AND id NOT IN (
                         SELECT message_id FROM message_read_status WHERE user_id = ?
                     )";
        
        $unreadResult = query($unreadSql, [$requestId, $userId, $userId]);
        
        while ($row = $unreadResult->fetch_assoc()) {
            $insertSql = "INSERT INTO message_read_status (message_id, user_id, read_at) 
                         VALUES (?, ?, NOW())";
            query($insertSql, [$row['id'], $userId]);
        }
    } else {
        // Mark specific messages as read
        foreach ($messageIds as $messageId) {
            // Update message read status
            $sql = "UPDATE chat_messages 
                    SET is_read = 1 
                    WHERE id = ? 
                    AND visa_request_id = ? 
                    AND sender_id != ?";
            
            query($sql, [$messageId, $requestId, $userId]);
            
            // Add read status for tracking
            $checkSql = "SELECT * FROM message_read_status 
                        WHERE message_id = ? AND user_id = ?";
            $checkResult = query($checkSql, [$messageId, $userId]);
            
            if ($checkResult->num_rows === 0) {
                $insertSql = "INSERT INTO message_read_status (message_id, user_id, read_at) 
                             VALUES (?, ?, NOW())";
                query($insertSql, [$messageId, $userId]);
            }
        }
    }
    
    // Return success
    sendResponse(200, 'success', 'Messages marked as read');
}

/**
 * Create a notification
 * 
 * @param string $userId User ID to notify
 * @param string $title Notification title
 * @param string $content Notification content
 * @param string $type Notification type
 * @param string $referenceId Reference ID (like visa request ID)
 * @return string Notification ID
 */
function createNotification($userId, $title, $content, $type, $referenceId) {
    // Generate notification ID (UUID)
    $notificationId = generateUUID();
    
    // Create notification
    $sql = "INSERT INTO notifications (
                id,
                user_id,
                title,
                content,
                type,
                reference_id,
                is_read,
                created_at
            ) VALUES (?, ?, ?, ?, ?, ?, 0, NOW())";
    
    query($sql, [
        $notificationId,
        $userId,
        $title,
        $content,
        $type,
        $referenceId
    ]);
    
    return $notificationId;
}

/**
 * Get user type from user ID
 * 
 * @param string $userId User ID
 * @return string User type
 */
function getUserType($userId) {
    $sql = "SELECT user_type FROM users WHERE id = ?";
    $result = query($sql, [$userId]);
    
    if ($result->num_rows === 0) {
        return null;
    }
    
    $user = $result->fetch_assoc();
    return $user['user_type'];
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
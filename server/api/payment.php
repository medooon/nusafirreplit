<?php
header('Content-Type: application/json');
require_once '../config/database.php';

// Allow CORS
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");

// Handle preflight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Get database connection
$conn = getConnection();

// Handle API requests
$action = isset($_GET['action']) ? $_GET['action'] : '';

switch ($action) {
    case 'upload':
        uploadPaymentScreenshot($conn);
        break;
    case 'verify':
        verifyPayment($conn);
        break;
    case 'details':
        getPaymentDetails($conn);
        break;
    case 'statistics':
        getPaymentStatistics($conn);
        break;
    default:
        echo json_encode(['success' => false, 'message' => 'Invalid action']);
        break;
}

// Close connection
$conn->close();

/**
 * Upload payment screenshot and update request status
 * 
 * @param mysqli $conn Database connection
 */
function uploadPaymentScreenshot($conn) {
    // Get request body
    $data = json_decode(file_get_contents('php://input'), true);
    
    if (!isset($data['visa_request_id']) || !isset($data['payment_screenshot_url'])) {
        echo json_encode(['success' => false, 'message' => 'Visa request ID and payment screenshot URL are required']);
        return;
    }
    
    $visaRequestId = (int)$data['visa_request_id'];
    $paymentScreenshotUrl = $data['payment_screenshot_url'];
    $updatedAt = date('Y-m-d H:i:s');
    $status = 'payment_pending';
    
    // Start transaction
    $conn->begin_transaction();
    
    try {
        // Update visa request with payment screenshot URL and status
        $updateRequestStmt = $conn->prepare("UPDATE visa_requests SET 
                                            payment_screenshot_url = ?, 
                                            status = ?,
                                            updated_at = ? 
                                            WHERE id = ?");
        $updateRequestStmt->bind_param("sssi", $paymentScreenshotUrl, $status, $updatedAt, $visaRequestId);
        $updateRequestStmt->execute();
        
        // Create payment record
        $createPaymentStmt = $conn->prepare("INSERT INTO payments (
                                            visa_request_id, 
                                            amount, 
                                            payment_screenshot_url,
                                            status,
                                            created_at
                                            ) VALUES (?, ?, ?, ?, ?)");
        $amount = 2500.00; // Default payment amount
        $paymentStatus = 'pending';
        $createPaymentStmt->bind_param("idsss", $visaRequestId, $amount, $paymentScreenshotUrl, $paymentStatus, $updatedAt);
        $createPaymentStmt->execute();
        
        // Get chat ID for the visa request
        $chatStmt = $conn->prepare("SELECT chat_id FROM visa_requests WHERE id = ?");
        $chatStmt->bind_param("i", $visaRequestId);
        $chatStmt->execute();
        $chatResult = $chatStmt->get_result();
        
        if ($chatResult->num_rows > 0) {
            $chatData = $chatResult->fetch_assoc();
            $chatId = $chatData['chat_id'];
            
            if ($chatId) {
                // Add payment message to chat
                $messageStmt = $conn->prepare("INSERT INTO chat_messages (
                                             chat_id, 
                                             sender_id, 
                                             sender_type, 
                                             sender_name, 
                                             content, 
                                             message_type, 
                                             media_url, 
                                             timestamp, 
                                             is_read
                                             ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)");
                
                // Get applicant details
                $userStmt = $conn->prepare("SELECT id, name FROM users WHERE id = (SELECT applicant_id FROM visa_requests WHERE id = ?)");
                $userStmt->bind_param("i", $visaRequestId);
                $userStmt->execute();
                $userResult = $userStmt->get_result();
                $userData = $userResult->fetch_assoc();
                
                $senderId = $userData['id'];
                $senderName = $userData['name'];
                $senderType = 'applicant';
                $content = 'تم رفع إيصال الدفع بقيمة 2500 جنيه، في انتظار التحقق من الإدارة';
                $messageType = 'payment';
                $timestamp = $updatedAt;
                $isRead = 0;
                
                $messageStmt->bind_param("iisssssis", $chatId, $senderId, $senderType, $senderName, $content, $messageType, $paymentScreenshotUrl, $timestamp, $isRead);
                $messageStmt->execute();
                
                // Update chat's updated_at
                $updateChatStmt = $conn->prepare("UPDATE chats SET updated_at = ? WHERE id = ?");
                $updateChatStmt->bind_param("si", $updatedAt, $chatId);
                $updateChatStmt->execute();
            }
        }
        
        // Commit transaction
        $conn->commit();
        
        echo json_encode(['success' => true]);
    } catch (Exception $e) {
        // Roll back transaction on error
        $conn->rollback();
        echo json_encode(['success' => false, 'message' => 'Failed to upload payment: ' . $e->getMessage()]);
    }
}

/**
 * Verify payment for a visa request
 * 
 * @param mysqli $conn Database connection
 */
function verifyPayment($conn) {
    // Get request body
    $data = json_decode(file_get_contents('php://input'), true);
    
    if (!isset($data['visa_request_id'])) {
        echo json_encode(['success' => false, 'message' => 'Visa request ID is required']);
        return;
    }
    
    $visaRequestId = (int)$data['visa_request_id'];
    $paymentVerified = 1;
    $paymentVerifiedAt = date('Y-m-d H:i:s');
    $status = 'payment_verified';
    $updatedAt = date('Y-m-d H:i:s');
    
    // Start transaction
    $conn->begin_transaction();
    
    try {
        // Update visa request
        $updateRequestStmt = $conn->prepare("UPDATE visa_requests SET 
                                            payment_verified = ?, 
                                            payment_verified_at = ?,
                                            status = ?, 
                                            updated_at = ? 
                                            WHERE id = ?");
        $updateRequestStmt->bind_param("isssi", $paymentVerified, $paymentVerifiedAt, $status, $updatedAt, $visaRequestId);
        $updateRequestStmt->execute();
        
        // Update payment record
        $updatePaymentStmt = $conn->prepare("UPDATE payments SET 
                                           status = ?,
                                           verified_at = ?,
                                           updated_at = ?
                                           WHERE visa_request_id = ?");
        $paymentStatus = 'verified';
        $updatePaymentStmt->bind_param("sssi", $paymentStatus, $paymentVerifiedAt, $updatedAt, $visaRequestId);
        $updatePaymentStmt->execute();
        
        // Get chat ID for the visa request
        $chatStmt = $conn->prepare("SELECT chat_id, admin_id FROM visa_requests WHERE id = ?");
        $chatStmt->bind_param("i", $visaRequestId);
        $chatStmt->execute();
        $chatResult = $chatStmt->get_result();
        
        if ($chatResult->num_rows > 0) {
            $chatData = $chatResult->fetch_assoc();
            $chatId = $chatData['chat_id'];
            $adminId = $chatData['admin_id'];
            
            if ($chatId) {
                // Add verification message to chat
                $messageStmt = $conn->prepare("INSERT INTO chat_messages (
                                             chat_id, 
                                             sender_id, 
                                             sender_type, 
                                             sender_name, 
                                             content, 
                                             message_type, 
                                             timestamp, 
                                             is_read
                                             ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)");
                
                // Get admin details
                $adminStmt = $conn->prepare("SELECT name FROM users WHERE id = ?");
                $adminStmt->bind_param("i", $adminId);
                $adminStmt->execute();
                $adminResult = $adminStmt->get_result();
                $adminData = $adminResult->fetch_assoc();
                $adminName = $adminData['name'];
                
                $senderType = 'admin';
                $content = 'تم التحقق من الدفع وقبول الإيصال';
                $messageType = 'system';
                $isRead = 1;
                
                $messageStmt->bind_param("iisssssi", $chatId, $adminId, $senderType, $adminName, $content, $messageType, $paymentVerifiedAt, $isRead);
                $messageStmt->execute();
                
                // Update chat's updated_at
                $updateChatStmt = $conn->prepare("UPDATE chats SET updated_at = ? WHERE id = ?");
                $updateChatStmt->bind_param("si", $updatedAt, $chatId);
                $updateChatStmt->execute();
            }
        }
        
        // Commit transaction
        $conn->commit();
        
        echo json_encode(['success' => true]);
    } catch (Exception $e) {
        // Roll back transaction on error
        $conn->rollback();
        echo json_encode(['success' => false, 'message' => 'Failed to verify payment: ' . $e->getMessage()]);
    }
}

/**
 * Get payment details for a visa request
 * 
 * @param mysqli $conn Database connection
 */
function getPaymentDetails($conn) {
    $visaRequestId = isset($_GET['visa_request_id']) ? (int)$_GET['visa_request_id'] : 0;
    
    if ($visaRequestId <= 0) {
        echo json_encode(['success' => false, 'message' => 'Valid visa request ID is required']);
        return;
    }
    
    // Query payment information
    $stmt = $conn->prepare("SELECT p.*, vr.payment_verified, vr.payment_verified_at
                           FROM payments p
                           JOIN visa_requests vr ON p.visa_request_id = vr.id
                           WHERE p.visa_request_id = ?");
    $stmt->bind_param("i", $visaRequestId);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows > 0) {
        $payment = $result->fetch_assoc();
        echo json_encode(['success' => true, 'payment' => $payment]);
    } else {
        echo json_encode(['success' => false, 'message' => 'Payment not found']);
    }
}

/**
 * Get payment statistics
 * 
 * @param mysqli $conn Database connection
 */
function getPaymentStatistics($conn) {
    // This endpoint is for admin users to see payment statistics
    
    // Check if user is admin (simplified, would normally check auth token)
    $isAdmin = true;
    
    if (!$isAdmin) {
        echo json_encode(['success' => false, 'message' => 'Unauthorized access']);
        return;
    }
    
    // Get total payments
    $totalStmt = $conn->prepare("SELECT 
                               COUNT(*) as total_count,
                               SUM(amount) as total_amount,
                               COUNT(CASE WHEN status = 'verified' THEN 1 END) as verified_count,
                               SUM(CASE WHEN status = 'verified' THEN amount ELSE 0 END) as verified_amount
                               FROM payments");
    $totalStmt->execute();
    $totalResult = $totalStmt->get_result();
    $totalData = $totalResult->fetch_assoc();
    
    // Get monthly statistics for current year
    $yearlyStmt = $conn->prepare("SELECT 
                                 MONTH(created_at) as month,
                                 COUNT(*) as count,
                                 SUM(amount) as amount,
                                 COUNT(CASE WHEN status = 'verified' THEN 1 END) as verified_count,
                                 SUM(CASE WHEN status = 'verified' THEN amount ELSE 0 END) as verified_amount
                                 FROM payments
                                 WHERE YEAR(created_at) = YEAR(CURRENT_DATE())
                                 GROUP BY MONTH(created_at)
                                 ORDER BY month");
    $yearlyStmt->execute();
    $yearlyResult = $yearlyStmt->get_result();
    
    $monthlyStats = [];
    while ($row = $yearlyResult->fetch_assoc()) {
        $monthlyStats[] = $row;
    }
    
    echo json_encode([
        'success' => true,
        'total_statistics' => $totalData,
        'monthly_statistics' => $monthlyStats
    ]);
}
?>

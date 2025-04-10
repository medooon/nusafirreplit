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
    case 'get_available':
        getAvailableOffices($conn);
        break;
    case 'request_join':
        requestToJoinVisaChat($conn);
        break;
    case 'approve':
        approveOfficeForVisaRequest($conn);
        break;
    case 'get_by_id':
        getOfficeById($conn);
        break;
    case 'get_by_governorate':
        getOfficesByGovernorate($conn);
        break;
    default:
        echo json_encode(['success' => false, 'message' => 'Invalid action']);
        break;
}

// Close connection
$conn->close();

// Get available offices (with available slots)
function getAvailableOffices($conn) {
    $stmt = $conn->prepare("SELECT * FROM users WHERE user_type = 'office' AND (visa_limit > active_visa_requests OR active_visa_requests IS NULL)");
    $stmt->execute();
    $result = $stmt->get_result();
    
    $offices = [];
    while ($row = $result->fetch_assoc()) {
        $offices[] = $row;
    }
    
    echo json_encode(['success' => true, 'data' => $offices]);
}

// Request to join a visa chat
function requestToJoinVisaChat($conn) {
    // Get request body
    $data = json_decode(file_get_contents('php://input'), true);
    
    if (!isset($data['visa_request_id']) || !isset($data['office_id'])) {
        echo json_encode(['success' => false, 'message' => 'Visa request ID and office ID are required']);
        return;
    }
    
    $visaRequestId = (int)$data['visa_request_id'];
    $officeId = (int)$data['office_id'];
    $status = 'pending';
    $createdAt = date('Y-m-d H:i:s');
    
    // Check if office has available slots
    $officeStmt = $conn->prepare("SELECT visa_limit, active_visa_requests FROM users WHERE id = ? AND user_type = 'office'");
    $officeStmt->bind_param("i", $officeId);
    $officeStmt->execute();
    $officeResult = $officeStmt->get_result();
    
    if ($officeResult->num_rows > 0) {
        $officeData = $officeResult->fetch_assoc();
        $visaLimit = $officeData['visa_limit'] ?? 5;
        $activeVisaRequests = $officeData['active_visa_requests'] ?? 0;
        
        if ($activeVisaRequests >= $visaLimit) {
            echo json_encode(['success' => false, 'message' => 'Office has reached its visa request limit']);
            return;
        }
        
        // Check if already requested
        $checkStmt = $conn->prepare("SELECT id FROM pending_office_requests WHERE visa_request_id = ? AND office_id = ?");
        $checkStmt->bind_param("ii", $visaRequestId, $officeId);
        $checkStmt->execute();
        $checkResult = $checkStmt->get_result();
        
        if ($checkResult->num_rows > 0) {
            echo json_encode(['success' => false, 'message' => 'Office has already requested to join this visa chat']);
            return;
        }
        
        // Create pending request
        $stmt = $conn->prepare("INSERT INTO pending_office_requests (visa_request_id, office_id, status, created_at) VALUES (?, ?, ?, ?)");
        $stmt->bind_param("iiss", $visaRequestId, $officeId, $status, $createdAt);
        
        if ($stmt->execute()) {
            echo json_encode(['success' => true, 'request_id' => $stmt->insert_id]);
        } else {
            echo json_encode(['success' => false, 'message' => 'Failed to create request: ' . $stmt->error]);
        }
    } else {
        echo json_encode(['success' => false, 'message' => 'Office not found']);
    }
}

// Approve an office for a visa request
function approveOfficeForVisaRequest($conn) {
    // Get request body
    $data = json_decode(file_get_contents('php://input'), true);
    
    if (!isset($data['visa_request_id']) || !isset($data['office_id'])) {
        echo json_encode(['success' => false, 'message' => 'Visa request ID and office ID are required']);
        return;
    }
    
    $visaRequestId = (int)$data['visa_request_id'];
    $officeId = (int)$data['office_id'];
    $status = 'office_assigned';
    $updatedAt = date('Y-m-d H:i:s');
    
    // Start transaction
    $conn->begin_transaction();
    
    try {
        // Update visa request with office ID and status
        $updateRequestStmt = $conn->prepare("UPDATE visa_requests SET office_id = ?, status = ?, updated_at = ? WHERE id = ?");
        $updateRequestStmt->bind_param("issi", $officeId, $status, $updatedAt, $visaRequestId);
        $updateRequestStmt->execute();
        
        // Update office active visa requests count
        $updateOfficeStmt = $conn->prepare("UPDATE users SET active_visa_requests = active_visa_requests + 1 WHERE id = ?");
        $updateOfficeStmt->bind_param("i", $officeId);
        $updateOfficeStmt->execute();
        
        // Update pending_office_requests for this visa request
        $updatePendingStmt = $conn->prepare("UPDATE pending_office_requests SET status = CASE WHEN office_id = ? THEN 'approved' ELSE 'rejected' END WHERE visa_request_id = ?");
        $updatePendingStmt->bind_param("ii", $officeId, $visaRequestId);
        $updatePendingStmt->execute();
        
        // Update chat with office ID
        $updateChatStmt = $conn->prepare("UPDATE chats SET office_id = ?, updated_at = ? WHERE visa_request_id = ?");
        $updateChatStmt->bind_param("isi", $officeId, $updatedAt, $visaRequestId);
        $updateChatStmt->execute();
        
        // Commit transaction
        $conn->commit();
        
        echo json_encode(['success' => true]);
    } catch (Exception $e) {
        // Roll back transaction on error
        $conn->rollback();
        echo json_encode(['success' => false, 'message' => 'Failed to approve office: ' . $e->getMessage()]);
    }
}

// Get office by ID
function getOfficeById($conn) {
    $id = isset($_GET['id']) ? (int)$_GET['id'] : 0;
    
    if ($id <= 0) {
        echo json_encode(['success' => false, 'message' => 'Valid office ID is required']);
        return;
    }
    
    $stmt = $conn->prepare("SELECT * FROM users WHERE id = ? AND user_type = 'office'");
    $stmt->bind_param("i", $id);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows > 0) {
        $office = $result->fetch_assoc();
        echo json_encode(['success' => true, 'data' => $office]);
    } else {
        echo json_encode(['success' => false, 'message' => 'Office not found']);
    }
}

// Get offices by governorate
function getOfficesByGovernorate($conn) {
    $governorate = isset($_GET['governorate']) ? $_GET['governorate'] : '';
    
    if (empty($governorate)) {
        echo json_encode(['success' => false, 'message' => 'Governorate is required']);
        return;
    }
    
    $stmt = $conn->prepare("SELECT * FROM users WHERE user_type = 'office' AND governorate = ? AND (visa_limit > active_visa_requests OR active_visa_requests IS NULL)");
    $stmt->bind_param("s", $governorate);
    $stmt->execute();
    $result = $stmt->get_result();
    
    $offices = [];
    while ($row = $result->fetch_assoc()) {
        $offices[] = $row;
    }
    
    echo json_encode(['success' => true, 'data' => $offices]);
}

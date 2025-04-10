<?php
/**
 * Visa API Endpoints
 * 
 * This file handles all visa request-related API endpoints:
 * - Create new visa request
 * - Update visa request status
 * - Get visa request details
 * - Upload documents
 * - Verify payment
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
            case 'list':
                getVisaRequests();
                break;
            case 'details':
                getVisaRequestDetails();
                break;
            default:
                sendResponse(404, 'error', 'Endpoint not found');
                break;
        }
        break;
    
    case 'POST':
        switch ($endpoint) {
            case 'create':
                createVisaRequest();
                break;
            case 'upload-document':
                uploadDocument();
                break;
            case 'verify-payment':
                verifyPayment();
                break;
            default:
                sendResponse(404, 'error', 'Endpoint not found');
                break;
        }
        break;
    
    case 'PUT':
        switch ($endpoint) {
            case 'update-status':
                updateVisaStatus();
                break;
            case 'assign-office':
                assignOffice();
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
 * Get visa requests for current user
 */
function getVisaRequests() {
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
    
    // Depending on user type, get appropriate visa requests
    switch ($userType) {
        case 'applicant':
            $sql = "SELECT * FROM visa_requests WHERE applicant_id = ? ORDER BY created_at DESC";
            $result = query($sql, [$userId]);
            break;
        
        case 'admin':
            $sql = "SELECT * FROM visa_requests ORDER BY created_at DESC";
            $result = query($sql);
            break;
        
        case 'office':
            $sql = "SELECT * FROM visa_requests WHERE office_id = ? ORDER BY created_at DESC";
            $result = query($sql, [$userId]);
            break;
        
        default:
            sendResponse(403, 'error', 'Forbidden');
            return;
    }
    
    // Convert result to array
    $visaRequests = [];
    while ($row = $result->fetch_assoc()) {
        $visaRequests[] = $row;
    }
    
    // Return visa requests
    sendResponse(200, 'success', 'Visa requests retrieved', [
        'visa_requests' => $visaRequests
    ]);
}

/**
 * Get visa request details
 */
function getVisaRequestDetails() {
    // Get user ID from Authorization header (in a real app, validate token)
    $userId = validateToken();
    
    if (!$userId) {
        sendResponse(401, 'error', 'Unauthorized');
        return;
    }
    
    // Get request ID from query string
    $requestId = $_GET['id'] ?? '';
    
    if (empty($requestId)) {
        sendResponse(400, 'error', 'Request ID is required');
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
    
    // Get visa request
    $sql = "SELECT * FROM visa_requests WHERE id = ?";
    $result = query($sql, [$requestId]);
    
    if ($result->num_rows === 0) {
        sendResponse(404, 'error', 'Visa request not found');
        return;
    }
    
    $visaRequest = $result->fetch_assoc();
    
    // Check if user is authorized to view this request
    if ($userType === 'applicant' && $visaRequest['applicant_id'] !== $userId) {
        sendResponse(403, 'error', 'Forbidden');
        return;
    }
    
    if ($userType === 'office' && $visaRequest['office_id'] !== $userId) {
        sendResponse(403, 'error', 'Forbidden');
        return;
    }
    
    // Get documents for this request
    $docSql = "SELECT * FROM documents WHERE visa_request_id = ?";
    $docResult = query($docSql, [$requestId]);
    
    $documents = [];
    while ($doc = $docResult->fetch_assoc()) {
        $documents[] = $doc;
    }
    
    // Get payment logs
    $paymentSql = "SELECT * FROM payment_logs WHERE visa_request_id = ? ORDER BY created_at DESC";
    $paymentResult = query($paymentSql, [$requestId]);
    
    $payments = [];
    while ($payment = $paymentResult->fetch_assoc()) {
        $payments[] = $payment;
    }
    
    // Get applicant details
    $applicantSql = "SELECT id, name, email, phone_number, profile_image_url FROM users WHERE id = ?";
    $applicantResult = query($applicantSql, [$visaRequest['applicant_id']]);
    $applicant = $applicantResult->fetch_assoc();
    
    // Get office details if assigned
    $office = null;
    if (!empty($visaRequest['office_id'])) {
        $officeSql = "SELECT u.id, u.name, u.email, u.phone_number, o.address, o.logo_url 
                     FROM users u 
                     JOIN offices o ON u.id = o.id 
                     WHERE u.id = ?";
        $officeResult = query($officeSql, [$visaRequest['office_id']]);
        
        if ($officeResult->num_rows > 0) {
            $office = $officeResult->fetch_assoc();
        }
    }
    
    // Get admin details if assigned
    $admin = null;
    if (!empty($visaRequest['admin_id'])) {
        $adminSql = "SELECT id, name, email, phone_number FROM users WHERE id = ?";
        $adminResult = query($adminSql, [$visaRequest['admin_id']]);
        
        if ($adminResult->num_rows > 0) {
            $admin = $adminResult->fetch_assoc();
        }
    }
    
    // Return visa request details with related data
    sendResponse(200, 'success', 'Visa request details retrieved', [
        'visa_request' => $visaRequest,
        'documents' => $documents,
        'payments' => $payments,
        'applicant' => $applicant,
        'office' => $office,
        'admin' => $admin
    ]);
}

/**
 * Create new visa request
 */
function createVisaRequest() {
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
    
    // Only applicants can create visa requests
    if ($user['user_type'] !== 'applicant') {
        sendResponse(403, 'error', 'Only applicants can create visa requests');
        return;
    }
    
    // Get JSON data from request body
    $json = file_get_contents('php://input');
    $data = json_decode($json, true);
    
    // Validate required fields
    if (!isset($data['passport_number'])) {
        sendResponse(400, 'error', 'Passport number is required');
        return;
    }
    
    $passportNumber = $data['passport_number'];
    
    // Check if user already has an active visa request
    $checkSql = "SELECT * FROM visa_requests 
                WHERE applicant_id = ? 
                AND status NOT IN ('completed', 'rejected')";
    $checkResult = query($checkSql, [$userId]);
    
    if ($checkResult->num_rows > 0) {
        sendResponse(409, 'error', 'You already have an active visa request');
        return;
    }
    
    // Get visa fee from system settings
    $feeSql = "SELECT setting_value FROM system_settings WHERE setting_key = 'visa_fee'";
    $feeResult = query($feeSql);
    $fee = 2500; // Default fee
    
    if ($feeResult->num_rows > 0) {
        $feeSetting = $feeResult->fetch_assoc();
        $fee = (float) $feeSetting['setting_value'];
    }
    
    // Generate request ID (UUID)
    $requestId = generateUUID();
    
    // Create visa request
    $sql = "INSERT INTO visa_requests (
                id, 
                applicant_id, 
                passport_number, 
                status, 
                payment_amount, 
                payment_date,
                created_at
            ) VALUES (?, ?, ?, 'pending', ?, NOW(), NOW())";
    
    query($sql, [$requestId, $userId, $passportNumber, $fee]);
    
    // Get the created visa request
    $selectSql = "SELECT * FROM visa_requests WHERE id = ?";
    $result = query($selectSql, [$requestId]);
    $visaRequest = $result->fetch_assoc();
    
    // Return the created visa request
    sendResponse(201, 'success', 'Visa request created', [
        'visa_request' => $visaRequest
    ]);
}

/**
 * Upload document for visa request
 */
function uploadDocument() {
    // Get user ID from Authorization header (in a real app, validate token)
    $userId = validateToken();
    
    if (!$userId) {
        sendResponse(401, 'error', 'Unauthorized');
        return;
    }
    
    // Check if request ID is provided
    if (!isset($_POST['visa_request_id']) || !isset($_POST['document_type'])) {
        sendResponse(400, 'error', 'Visa request ID and document type are required');
        return;
    }
    
    $requestId = $_POST['visa_request_id'];
    $documentType = $_POST['document_type'];
    
    // Check if document type is valid
    $validTypes = ['passport', 'photo', 'university_certificate', 'other'];
    if (!in_array($documentType, $validTypes)) {
        sendResponse(400, 'error', 'Invalid document type');
        return;
    }
    
    // Check if visa request exists and belongs to the user
    $sql = "SELECT * FROM visa_requests WHERE id = ?";
    $result = query($sql, [$requestId]);
    
    if ($result->num_rows === 0) {
        sendResponse(404, 'error', 'Visa request not found');
        return;
    }
    
    $visaRequest = $result->fetch_assoc();
    
    // Only the applicant can upload documents
    if ($visaRequest['applicant_id'] !== $userId) {
        sendResponse(403, 'error', 'Forbidden');
        return;
    }
    
    // Check if visa request is in a valid status
    $validStatuses = ['pending', 'documentsPending'];
    if (!in_array($visaRequest['status'], $validStatuses)) {
        sendResponse(400, 'error', 'Cannot upload documents in current status');
        return;
    }
    
    // Check if file was uploaded
    if (!isset($_FILES['document']) || $_FILES['document']['error'] !== UPLOAD_ERR_OK) {
        sendResponse(400, 'error', 'No file uploaded or upload error');
        return;
    }
    
    // Get file details
    $file = $_FILES['document'];
    $fileName = $file['name'];
    $fileTmpPath = $file['tmp_name'];
    $fileSize = $file['size'];
    $fileType = $file['type'];
    
    // Get max file size from settings
    $maxSizeSql = "SELECT setting_value FROM system_settings WHERE setting_key = 'max_document_size'";
    $maxSizeResult = query($maxSizeSql);
    $maxFileSize = 5242880; // Default 5MB
    
    if ($maxSizeResult->num_rows > 0) {
        $maxSizeSetting = $maxSizeResult->fetch_assoc();
        $maxFileSize = (int) $maxSizeSetting['setting_value'];
    }
    
    // Check file size
    if ($fileSize > $maxFileSize) {
        sendResponse(400, 'error', 'File size exceeds the limit');
        return;
    }
    
    // Get allowed file types from settings
    $allowedTypesSql = "SELECT setting_value FROM system_settings WHERE setting_key = 'allowed_document_types'";
    $allowedTypesResult = query($allowedTypesSql);
    $allowedExtensions = ['pdf', 'jpg', 'jpeg', 'png']; // Default
    
    if ($allowedTypesResult->num_rows > 0) {
        $allowedTypesSetting = $allowedTypesResult->fetch_assoc();
        $allowedExtensions = explode(',', $allowedTypesSetting['setting_value']);
    }
    
    // Get file extension
    $fileExtension = strtolower(pathinfo($fileName, PATHINFO_EXTENSION));
    
    // Check file extension
    if (!in_array($fileExtension, $allowedExtensions)) {
        sendResponse(400, 'error', 'File type not allowed');
        return;
    }
    
    // Generate a unique file name
    $newFileName = uniqid() . '_' . $requestId . '.' . $fileExtension;
    
    // Set upload directory
    $uploadDir = '../../uploads/documents/';
    
    // Create upload directory if it doesn't exist
    if (!is_dir($uploadDir)) {
        mkdir($uploadDir, 0755, true);
    }
    
    $uploadPath = $uploadDir . $newFileName;
    
    // Move uploaded file
    if (!move_uploaded_file($fileTmpPath, $uploadPath)) {
        sendResponse(500, 'error', 'Failed to upload file');
        return;
    }
    
    // Generate document URL
    $documentUrl = '/uploads/documents/' . $newFileName;
    
    // Generate document ID
    $documentId = generateUUID();
    
    // Save document in database
    $insertSql = "INSERT INTO documents (
                    id,
                    visa_request_id,
                    document_type,
                    document_url,
                    document_name,
                    uploaded_at
                ) VALUES (?, ?, ?, ?, ?, NOW())";
    
    query($insertSql, [$documentId, $requestId, $documentType, $documentUrl, $fileName]);
    
    // Update visa request status if it's the first document
    $countSql = "SELECT COUNT(*) as count FROM documents WHERE visa_request_id = ?";
    $countResult = query($countSql, [$requestId]);
    $count = $countResult->fetch_assoc()['count'];
    
    if ($count === 1 && $visaRequest['status'] === 'pending') {
        $updateSql = "UPDATE visa_requests SET status = 'documentsPending', updated_at = NOW() WHERE id = ?";
        query($updateSql, [$requestId]);
    }
    
    // Check if all required documents are uploaded
    $requiredDocCount = 3; // Passport, photo, university certificate
    if ($count >= $requiredDocCount && $visaRequest['status'] === 'documentsPending') {
        $updateSql = "UPDATE visa_requests SET status = 'paymentPending', updated_at = NOW() WHERE id = ?";
        query($updateSql, [$requestId]);
    }
    
    // Get the document
    $selectSql = "SELECT * FROM documents WHERE id = ?";
    $result = query($selectSql, [$documentId]);
    $document = $result->fetch_assoc();
    
    // Return success response
    sendResponse(201, 'success', 'Document uploaded successfully', [
        'document' => $document
    ]);
}

/**
 * Verify payment for visa request
 */
function verifyPayment() {
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
    
    // Get JSON data from request body
    $json = file_get_contents('php://input');
    $data = json_decode($json, true);
    
    // Validate required fields
    if (!isset($data['visa_request_id']) || !isset($data['reference_number']) || 
        !isset($data['screenshot_url'])) {
        sendResponse(400, 'error', 'Missing required fields');
        return;
    }
    
    $requestId = $data['visa_request_id'];
    $referenceNumber = $data['reference_number'];
    $screenshotUrl = $data['screenshot_url'];
    
    // Check if visa request exists
    $sql = "SELECT * FROM visa_requests WHERE id = ?";
    $result = query($sql, [$requestId]);
    
    if ($result->num_rows === 0) {
        sendResponse(404, 'error', 'Visa request not found');
        return;
    }
    
    $visaRequest = $result->fetch_assoc();
    
    // Handle based on user type
    if ($userType === 'applicant') {
        // Applicants can only submit payment
        if ($visaRequest['applicant_id'] !== $userId) {
            sendResponse(403, 'error', 'Forbidden');
            return;
        }
        
        if ($visaRequest['status'] !== 'paymentPending') {
            sendResponse(400, 'error', 'Visa request is not waiting for payment');
            return;
        }
        
        // Submit payment for verification
        $paymentId = generateUUID();
        
        $insertSql = "INSERT INTO payment_logs (
                        id,
                        visa_request_id,
                        amount,
                        payment_method,
                        status,
                        reference_number,
                        screenshot_url,
                        created_at
                    ) VALUES (?, ?, ?, 'instapay', 'pending', ?, ?, NOW())";
        
        query($insertSql, [
            $paymentId,
            $requestId,
            $visaRequest['payment_amount'],
            $referenceNumber,
            $screenshotUrl
        ]);
        
        // Update visa request with payment details
        $updateSql = "UPDATE visa_requests SET 
                        payment_reference = ?,
                        payment_screenshot_url = ?,
                        updated_at = NOW()
                     WHERE id = ?";
        
        query($updateSql, [
            $referenceNumber,
            $screenshotUrl,
            $requestId
        ]);
        
        // Return success
        sendResponse(200, 'success', 'Payment submitted for verification');
    } elseif ($userType === 'admin') {
        // Admins can verify payments
        $action = $data['action'] ?? '';
        $note = $data['note'] ?? '';
        
        if (!in_array($action, ['verify', 'reject'])) {
            sendResponse(400, 'error', 'Invalid action');
            return;
        }
        
        if ($action === 'verify') {
            // Verify payment
            $updateSql = "UPDATE visa_requests SET 
                            is_paid = 1,
                            status = 'paymentVerified',
                            updated_at = NOW()
                         WHERE id = ?";
            
            query($updateSql, [$requestId]);
            
            // Update payment log
            $updateLogSql = "UPDATE payment_logs SET 
                                status = 'verified',
                                verified_by = ?,
                                note = ?,
                                updated_at = NOW()
                             WHERE visa_request_id = ? AND status = 'pending'";
            
            query($updateLogSql, [
                $userId,
                $note,
                $requestId
            ]);
            
            sendResponse(200, 'success', 'Payment verified');
        } else {
            // Reject payment
            // Update payment log
            $updateLogSql = "UPDATE payment_logs SET 
                                status = 'rejected',
                                verified_by = ?,
                                note = ?,
                                updated_at = NOW()
                             WHERE visa_request_id = ? AND status = 'pending'";
            
            query($updateLogSql, [
                $userId,
                $note,
                $requestId
            ]);
            
            sendResponse(200, 'success', 'Payment rejected');
        }
    } else {
        sendResponse(403, 'error', 'Unauthorized user type');
    }
}

/**
 * Update visa request status
 */
function updateVisaStatus() {
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
    
    // Only admins and offices can update status
    if (!in_array($userType, ['admin', 'office'])) {
        sendResponse(403, 'error', 'Unauthorized user type');
        return;
    }
    
    // Get JSON data from request body
    $json = file_get_contents('php://input');
    $data = json_decode($json, true);
    
    // Validate required fields
    if (!isset($data['visa_request_id']) || !isset($data['status'])) {
        sendResponse(400, 'error', 'Visa request ID and status are required');
        return;
    }
    
    $requestId = $data['visa_request_id'];
    $status = $data['status'];
    
    // Check if status is valid
    $validStatuses = [
        'pending', 'documentsPending', 'paymentPending', 
        'paymentVerified', 'assigned', 'processing', 
        'completed', 'rejected'
    ];
    
    if (!in_array($status, $validStatuses)) {
        sendResponse(400, 'error', 'Invalid status');
        return;
    }
    
    // Get visa request
    $sql = "SELECT * FROM visa_requests WHERE id = ?";
    $result = query($sql, [$requestId]);
    
    if ($result->num_rows === 0) {
        sendResponse(404, 'error', 'Visa request not found');
        return;
    }
    
    $visaRequest = $result->fetch_assoc();
    
    // Check permissions based on user type
    if ($userType === 'office') {
        // Offices can only update their assigned requests
        if ($visaRequest['office_id'] !== $userId) {
            sendResponse(403, 'error', 'Forbidden');
            return;
        }
        
        // Offices can only change to processing or completed
        if (!in_array($status, ['processing', 'completed'])) {
            sendResponse(403, 'error', 'Offices can only change status to processing or completed');
            return;
        }
    }
    
    // Update visa request status
    $updateSql = "UPDATE visa_requests SET status = ?, updated_at = NOW() WHERE id = ?";
    query($updateSql, [$status, $requestId]);
    
    // If status is completed, handle visa document URL if provided
    if ($status === 'completed' && isset($data['visa_document_url'])) {
        $visaDocUrl = $data['visa_document_url'];
        $updateDocSql = "UPDATE visa_requests SET visa_document_url = ? WHERE id = ?";
        query($updateDocSql, [$visaDocUrl, $requestId]);
    }
    
    // Get updated visa request
    $selectSql = "SELECT * FROM visa_requests WHERE id = ?";
    $result = query($selectSql, [$requestId]);
    $updatedRequest = $result->fetch_assoc();
    
    // Return success response
    sendResponse(200, 'success', 'Visa request status updated', [
        'visa_request' => $updatedRequest
    ]);
}

/**
 * Assign office to visa request
 */
function assignOffice() {
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
    
    // Only admins can assign offices
    if ($user['user_type'] !== 'admin') {
        sendResponse(403, 'error', 'Only admins can assign offices');
        return;
    }
    
    // Get JSON data from request body
    $json = file_get_contents('php://input');
    $data = json_decode($json, true);
    
    // Validate required fields
    if (!isset($data['visa_request_id']) || !isset($data['office_id'])) {
        sendResponse(400, 'error', 'Visa request ID and office ID are required');
        return;
    }
    
    $requestId = $data['visa_request_id'];
    $officeId = $data['office_id'];
    
    // Get visa request
    $sql = "SELECT * FROM visa_requests WHERE id = ?";
    $result = query($sql, [$requestId]);
    
    if ($result->num_rows === 0) {
        sendResponse(404, 'error', 'Visa request not found');
        return;
    }
    
    $visaRequest = $result->fetch_assoc();
    
    // Check if visa request is paid and verified
    if ($visaRequest['status'] !== 'paymentVerified') {
        sendResponse(400, 'error', 'Visa request must be paid and verified before assigning an office');
        return;
    }
    
    // Check if office exists
    $officeSql = "SELECT * FROM offices WHERE id = ?";
    $officeResult = query($officeSql, [$officeId]);
    
    if ($officeResult->num_rows === 0) {
        sendResponse(404, 'error', 'Office not found');
        return;
    }
    
    $office = $officeResult->fetch_assoc();
    
    // Check if office has capacity
    if ($office['current_active_applications'] >= $office['max_active_applications']) {
        sendResponse(400, 'error', 'Office has reached maximum capacity');
        return;
    }
    
    // Start transaction
    $conn = begin_transaction();
    
    try {
        // Update visa request
        $updateSql = "UPDATE visa_requests SET 
                        office_id = ?,
                        admin_id = ?,
                        status = 'assigned',
                        updated_at = NOW()
                     WHERE id = ?";
        
        $stmt = $conn->prepare($updateSql);
        $stmt->bind_param('sss', $officeId, $userId, $requestId);
        $result = $stmt->execute();
        
        if (!$result) {
            throw new Exception("Failed to update visa request");
        }
        
        // Increment office's active applications count
        $incrementSql = "UPDATE offices SET 
                            current_active_applications = current_active_applications + 1,
                            last_active_at = NOW()
                         WHERE id = ?";
        
        $stmt = $conn->prepare($incrementSql);
        $stmt->bind_param('s', $officeId);
        $result = $stmt->execute();
        
        if (!$result) {
            throw new Exception("Failed to update office capacity");
        }
        
        // Commit transaction
        commit_transaction($conn);
        
        // Get updated visa request
        $selectSql = "SELECT * FROM visa_requests WHERE id = ?";
        $result = query($selectSql, [$requestId]);
        $updatedRequest = $result->fetch_assoc();
        
        // Return success response
        sendResponse(200, 'success', 'Office assigned to visa request', [
            'visa_request' => $updatedRequest
        ]);
    } catch (Exception $e) {
        // Rollback transaction
        rollback_transaction($conn);
        sendResponse(500, 'error', 'Failed to assign office: ' . $e->getMessage());
    }
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
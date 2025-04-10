<?php
header('Content-Type: application/json');
require_once '../config/database.php';

// Allow CORS
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");
header("Access-Control-Allow-Methods: POST, OPTIONS");

// Handle preflight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Check if this is a file upload request
if ($_SERVER['REQUEST_METHOD'] === 'POST' && !isset($_GET['action'])) {
    handleFileUpload();
} else {
    // Handle other actions
    $action = isset($_GET['action']) ? $_GET['action'] : '';
    
    switch ($action) {
        case 'delete':
            deleteFile();
            break;
        default:
            echo json_encode(['success' => false, 'message' => 'Invalid action']);
            break;
    }
}

/**
 * Handle file upload
 */
function handleFileUpload() {
    // Check if a file was uploaded
    if (!isset($_FILES['file']) || $_FILES['file']['error'] !== UPLOAD_ERR_OK) {
        $error = isset($_FILES['file']) ? getUploadErrorMessage($_FILES['file']['error']) : 'No file uploaded';
        echo json_encode(['success' => false, 'message' => $error]);
        return;
    }
    
    // Get the file and directory information
    $file = $_FILES['file'];
    $directory = isset($_POST['directory']) ? trim($_POST['directory']) : 'uploads';
    
    // Validate file
    $validationResult = validateFile($file);
    if (!$validationResult['valid']) {
        echo json_encode(['success' => false, 'message' => $validationResult['message']]);
        return;
    }
    
    // Create upload directory if it doesn't exist
    $uploadDir = "../../uploads/{$directory}/";
    if (!file_exists($uploadDir)) {
        mkdir($uploadDir, 0755, true);
    }
    
    // Generate a unique filename
    $extension = pathinfo($file['name'], PATHINFO_EXTENSION);
    $filename = uniqid() . '_' . time() . '.' . $extension;
    $filepath = $uploadDir . $filename;
    
    // Move the uploaded file
    if (move_uploaded_file($file['tmp_name'], $filepath)) {
        // Generate the URL for the file
        $fileUrl = getFileUrl($directory, $filename);
        
        // Log the upload to the database
        logFileUpload($fileUrl, $file['name'], $directory);
        
        echo json_encode([
            'success' => true,
            'file_url' => $fileUrl,
            'original_name' => $file['name'],
            'size' => $file['size']
        ]);
    } else {
        echo json_encode([
            'success' => false,
            'message' => 'Failed to move uploaded file'
        ]);
    }
}

/**
 * Delete a file
 */
function deleteFile() {
    // Get request body
    $data = json_decode(file_get_contents('php://input'), true);
    
    if (!isset($data['file_url'])) {
        echo json_encode(['success' => false, 'message' => 'File URL is required']);
        return;
    }
    
    $fileUrl = $data['file_url'];
    
    // Extract path from URL
    $path = extractPathFromUrl($fileUrl);
    
    if (!$path) {
        echo json_encode(['success' => false, 'message' => 'Invalid file URL']);
        return;
    }
    
    // Check if file exists
    if (!file_exists($path)) {
        echo json_encode(['success' => false, 'message' => 'File not found']);
        return;
    }
    
    // Remove the file
    if (unlink($path)) {
        // Remove from database log
        removeFileFromLog($fileUrl);
        
        echo json_encode(['success' => true]);
    } else {
        echo json_encode(['success' => false, 'message' => 'Failed to delete file']);
    }
}

/**
 * Validate uploaded file
 * 
 * @param array $file Uploaded file information
 * @return array Validation result
 */
function validateFile($file) {
    // Maximum file size (5MB)
    $maxSize = 5 * 1024 * 1024;
    
    // Allowed file types
    $allowedTypes = [
        'image/jpeg',
        'image/jpg',
        'image/png',
        'application/pdf'
    ];
    
    // Allowed extensions
    $allowedExtensions = ['jpg', 'jpeg', 'png', 'pdf'];
    
    // Check file size
    if ($file['size'] > $maxSize) {
        return [
            'valid' => false,
            'message' => 'File is too large. Maximum size is 5MB'
        ];
    }
    
    // Check file type
    $finfo = new finfo(FILEINFO_MIME_TYPE);
    $fileType = $finfo->file($file['tmp_name']);
    
    if (!in_array($fileType, $allowedTypes)) {
        return [
            'valid' => false,
            'message' => 'Invalid file type. Allowed types: JPEG, PNG, PDF'
        ];
    }
    
    // Check file extension
    $extension = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
    
    if (!in_array($extension, $allowedExtensions)) {
        return [
            'valid' => false,
            'message' => 'Invalid file extension. Allowed extensions: jpg, jpeg, png, pdf'
        ];
    }
    
    return [
        'valid' => true
    ];
}

/**
 * Get upload error message
 * 
 * @param int $errorCode Upload error code
 * @return string Error message
 */
function getUploadErrorMessage($errorCode) {
    switch ($errorCode) {
        case UPLOAD_ERR_INI_SIZE:
        case UPLOAD_ERR_FORM_SIZE:
            return 'File is too large';
        case UPLOAD_ERR_PARTIAL:
            return 'File was only partially uploaded';
        case UPLOAD_ERR_NO_FILE:
            return 'No file was uploaded';
        case UPLOAD_ERR_NO_TMP_DIR:
            return 'Missing temporary folder';
        case UPLOAD_ERR_CANT_WRITE:
            return 'Failed to write file to disk';
        case UPLOAD_ERR_EXTENSION:
            return 'A PHP extension stopped the file upload';
        default:
            return 'Unknown upload error';
    }
}

/**
 * Generate file URL
 * 
 * @param string $directory Upload directory
 * @param string $filename Filename
 * @return string File URL
 */
function getFileUrl($directory, $filename) {
    // Base URL for uploads
    $baseUrl = 'https://visaegypt.com/uploads';
    
    return "{$baseUrl}/{$directory}/{$filename}";
}

/**
 * Extract file path from URL
 * 
 * @param string $url File URL
 * @return string|bool File path or false if URL is invalid
 */
function extractPathFromUrl($url) {
    // Base URL for uploads
    $baseUrl = 'https://visaegypt.com/uploads';
    
    if (strpos($url, $baseUrl) !== 0) {
        return false;
    }
    
    $relativePath = substr($url, strlen($baseUrl));
    return '../../uploads' . $relativePath;
}

/**
 * Log file upload to database
 * 
 * @param string $fileUrl File URL
 * @param string $originalName Original filename
 * @param string $directory Upload directory
 */
function logFileUpload($fileUrl, $originalName, $directory) {
    // Get database connection
    $conn = getConnection();
    
    // Insert file information
    $stmt = $conn->prepare("INSERT INTO file_uploads (file_url, original_name, directory, upload_date) VALUES (?, ?, ?, NOW())");
    $stmt->bind_param("sss", $fileUrl, $originalName, $directory);
    $stmt->execute();
    
    // Close connection
    $conn->close();
}

/**
 * Remove file from database log
 * 
 * @param string $fileUrl File URL
 */
function removeFileFromLog($fileUrl) {
    // Get database connection
    $conn = getConnection();
    
    // Delete file information
    $stmt = $conn->prepare("DELETE FROM file_uploads WHERE file_url = ?");
    $stmt->bind_param("s", $fileUrl);
    $stmt->execute();
    
    // Close connection
    $conn->close();
}
?>

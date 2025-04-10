-- Database: visa_egypt_db
-- This SQL script creates all tables required for the Visa Egypt application

-- Drop database if exists (uncomment only if you want to reset)
-- DROP DATABASE IF EXISTS `visa_egypt_db`;

-- Create database
CREATE DATABASE IF NOT EXISTS `visa_egypt_db` 
CHARACTER SET utf8mb4 
COLLATE utf8mb4_unicode_ci;

-- Use the database
USE `visa_egypt_db`;

-- Create users table
CREATE TABLE IF NOT EXISTS `users` (
  `id` VARCHAR(36) NOT NULL PRIMARY KEY,
  `name` VARCHAR(100) NOT NULL,
  `email` VARCHAR(100) NOT NULL UNIQUE,
  `password_hash` VARCHAR(255) NOT NULL,
  `phone_number` VARCHAR(20) NOT NULL,
  `user_type` ENUM('applicant', 'admin', 'office') NOT NULL,
  `profile_image_url` VARCHAR(255) DEFAULT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `last_login_at` TIMESTAMP NULL DEFAULT NULL,
  `is_active` BOOLEAN DEFAULT TRUE
) ENGINE=InnoDB;

-- Create offices table (extends users table for office-specific data)
CREATE TABLE IF NOT EXISTS `offices` (
  `id` VARCHAR(36) NOT NULL PRIMARY KEY,
  `address` VARCHAR(255) NOT NULL,
  `logo_url` VARCHAR(255) DEFAULT NULL,
  `max_active_applications` INT DEFAULT 5,
  `current_active_applications` INT DEFAULT 0,
  `is_verified` BOOLEAN DEFAULT FALSE,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `last_active_at` TIMESTAMP NULL DEFAULT NULL,
  FOREIGN KEY (`id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Create visa_requests table
CREATE TABLE IF NOT EXISTS `visa_requests` (
  `id` VARCHAR(36) NOT NULL PRIMARY KEY,
  `applicant_id` VARCHAR(36) NOT NULL,
  `admin_id` VARCHAR(36) DEFAULT NULL,
  `office_id` VARCHAR(36) DEFAULT NULL,
  `passport_number` VARCHAR(50) NOT NULL,
  `status` ENUM('pending', 'documentsPending', 'paymentPending', 'paymentVerified', 'assigned', 'processing', 'completed', 'rejected') NOT NULL DEFAULT 'pending',
  `is_paid` BOOLEAN DEFAULT FALSE,
  `payment_amount` DECIMAL(10,2) NOT NULL,
  `payment_reference` VARCHAR(100) DEFAULT NULL,
  `payment_screenshot_url` VARCHAR(255) DEFAULT NULL,
  `payment_date` TIMESTAMP NULL DEFAULT NULL,
  `visa_document_url` VARCHAR(255) DEFAULT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (`applicant_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  FOREIGN KEY (`admin_id`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  FOREIGN KEY (`office_id`) REFERENCES `offices` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB;

-- Create documents table
CREATE TABLE IF NOT EXISTS `documents` (
  `id` VARCHAR(36) NOT NULL PRIMARY KEY,
  `visa_request_id` VARCHAR(36) NOT NULL,
  `document_type` ENUM('passport', 'photo', 'university_certificate', 'other') NOT NULL,
  `document_url` VARCHAR(255) NOT NULL,
  `document_name` VARCHAR(100) NOT NULL,
  `uploaded_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `is_verified` BOOLEAN DEFAULT FALSE,
  FOREIGN KEY (`visa_request_id`) REFERENCES `visa_requests` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Create chat_messages table
CREATE TABLE IF NOT EXISTS `chat_messages` (
  `id` VARCHAR(36) NOT NULL PRIMARY KEY,
  `visa_request_id` VARCHAR(36) NOT NULL,
  `sender_id` VARCHAR(36) NOT NULL,
  `sender_type` ENUM('applicant', 'admin', 'office', 'system') NOT NULL,
  `content` TEXT NOT NULL,
  `message_type` ENUM('text', 'image', 'document', 'system') NOT NULL DEFAULT 'text',
  `file_url` VARCHAR(255) DEFAULT NULL,
  `is_read` BOOLEAN DEFAULT FALSE,
  `timestamp` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `metadata` JSON DEFAULT NULL,
  FOREIGN KEY (`visa_request_id`) REFERENCES `visa_requests` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Create message_read_status table
CREATE TABLE IF NOT EXISTS `message_read_status` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `message_id` VARCHAR(36) NOT NULL,
  `user_id` VARCHAR(36) NOT NULL,
  `read_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY `message_user_unique` (`message_id`, `user_id`),
  FOREIGN KEY (`message_id`) REFERENCES `chat_messages` (`id`) ON DELETE CASCADE,
  FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Create notifications table
CREATE TABLE IF NOT EXISTS `notifications` (
  `id` VARCHAR(36) NOT NULL PRIMARY KEY,
  `user_id` VARCHAR(36) NOT NULL,
  `title` VARCHAR(100) NOT NULL,
  `content` TEXT NOT NULL,
  `type` VARCHAR(50) NOT NULL,
  `reference_id` VARCHAR(36) DEFAULT NULL,
  `is_read` BOOLEAN DEFAULT FALSE,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Create payment_logs table
CREATE TABLE IF NOT EXISTS `payment_logs` (
  `id` VARCHAR(36) NOT NULL PRIMARY KEY,
  `visa_request_id` VARCHAR(36) NOT NULL,
  `amount` DECIMAL(10,2) NOT NULL,
  `payment_method` VARCHAR(50) NOT NULL,
  `status` ENUM('pending', 'verified', 'rejected') NOT NULL,
  `reference_number` VARCHAR(100) DEFAULT NULL,
  `screenshot_url` VARCHAR(255) DEFAULT NULL,
  `verified_by` VARCHAR(36) DEFAULT NULL,
  `note` TEXT DEFAULT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (`visa_request_id`) REFERENCES `visa_requests` (`id`) ON DELETE CASCADE,
  FOREIGN KEY (`verified_by`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB;

-- Create system_settings table
CREATE TABLE IF NOT EXISTS `system_settings` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `setting_key` VARCHAR(50) NOT NULL UNIQUE,
  `setting_value` TEXT NOT NULL,
  `setting_group` VARCHAR(50) DEFAULT 'general',
  `is_public` BOOLEAN DEFAULT FALSE,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by` VARCHAR(36) DEFAULT NULL,
  FOREIGN KEY (`updated_by`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB;

-- Insert default system settings
INSERT INTO `system_settings` (`setting_key`, `setting_value`, `setting_group`, `is_public`) VALUES
('visa_fee', '2500', 'payment', TRUE),
('currency', 'EGP', 'payment', TRUE),
('max_document_size', '5242880', 'uploads', TRUE),  -- 5MB in bytes
('allowed_document_types', 'pdf,jpg,jpeg,png', 'uploads', TRUE),
('site_name', 'Visa Egypt', 'general', TRUE),
('support_email', 'support@visaegypt.com', 'general', TRUE),
('support_phone', '+201234567890', 'general', TRUE);

-- Create audit_logs table
CREATE TABLE IF NOT EXISTS `audit_logs` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `user_id` VARCHAR(36) DEFAULT NULL,
  `action` VARCHAR(100) NOT NULL,
  `entity_type` VARCHAR(50) NOT NULL,
  `entity_id` VARCHAR(36) DEFAULT NULL,
  `details` JSON DEFAULT NULL,
  `ip_address` VARCHAR(45) DEFAULT NULL,
  `user_agent` TEXT DEFAULT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB;

-- Create admin user (password: admin123)
-- INSERT INTO `users` (`id`, `name`, `email`, `password_hash`, `phone_number`, `user_type`, `created_at`)
-- VALUES (UUID(), 'Admin User', 'admin@visaegypt.com', '$2y$10$hHGX4WVyLG8aPDB1aFy1wejPjkqwNj9cB5YnNpV5y9vRX42s8zNBO', '+201122334455', 'admin', NOW());

-- Indexes for better performance
CREATE INDEX `idx_visa_requests_status` ON `visa_requests` (`status`);
CREATE INDEX `idx_visa_requests_applicant` ON `visa_requests` (`applicant_id`);
CREATE INDEX `idx_visa_requests_office` ON `visa_requests` (`office_id`);
CREATE INDEX `idx_chat_messages_visa_request` ON `chat_messages` (`visa_request_id`);
CREATE INDEX `idx_chat_messages_sender` ON `chat_messages` (`sender_id`);
CREATE INDEX `idx_chat_messages_timestamp` ON `chat_messages` (`timestamp`);
CREATE INDEX `idx_documents_visa_request` ON `documents` (`visa_request_id`);
CREATE INDEX `idx_notifications_user` ON `notifications` (`user_id`);
CREATE INDEX `idx_notifications_is_read` ON `notifications` (`is_read`);
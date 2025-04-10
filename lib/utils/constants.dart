import 'package:flutter/material.dart';

// Colors
class AppColors {
  static const Color primary = Colors.blue;
  static const Color success = Colors.green;
  static const Color warning = Colors.orange;
  static const Color error = Colors.red;
  static const Color info = Colors.blueAccent;
  static const Color background = Colors.white;
  static const Color textPrimary = Colors.black87;
  static const Color textSecondary = Colors.black54;
}

// Sizing and spacing
class AppSizes {
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double borderRadius = 8.0;
  static const double buttonHeight = 48.0;
  static const double iconSize = 24.0;
  static const double avatarSizeSmall = 32.0;
  static const double avatarSizeMedium = 48.0;
  static const double avatarSizeLarge = 64.0;
}

// Utility functions
class AppUtils {
  // Format price in EGP
  static String formatCurrency(double amount) {
    return 'EGP ${amount.toStringAsFixed(2)}';
  }
  
  // Format date to local string
  static String formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }
  
  // Format datetime to local string
  static String formatDateTime(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year.toString();
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }
}

// API endpoints
class ApiEndpoints {
  static const String baseUrl = 'https://visaegypt.com/api';
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String resetPassword = '/auth/reset-password';
  static const String users = '/users';
  static const String visaRequests = '/visa-requests';
  static const String offices = '/offices';
  static const String chat = '/chat';
  static const String payments = '/payments';
  static const String uploads = '/uploads';
}

// User types
class UserTypes {
  static const String applicant = 'applicant';
  static const String admin = 'admin';
  static const String office = 'office';
}

// Payment info
class PaymentInfo {
  static const double visaFee = 2500.0; // EGP
  static const String paymentInstructions = 'Please make a payment of EGP 2,500 to the account below, then upload a screenshot of the payment receipt.';
  static const String paymentAccount = 'Account Name: Visa Egypt\nBank: Egypt Bank\nAccount Number: 123456789\nIBAN: EG123456789';
}

// Error messages
class ErrorMessages {
  static const String networkError = 'Network error. Please check your internet connection and try again.';
  static const String serverError = 'Server error. Please try again later.';
  static const String authError = 'Authentication failed. Please check your credentials.';
  static const String inputError = 'Please check your input and try again.';
  static const String paymentError = 'Payment verification failed. Please try again or contact support.';
  static const String uploadError = 'File upload failed. Please try again.';
  static const String permissionError = 'You do not have permission to perform this action.';
}

// Document types
class DocumentTypes {
  static const String passport = 'passport';
  static const String universityDegree = 'university_degree';
  static const String personalPhoto = 'personal_photo';
  static const String paymentReceipt = 'payment_receipt';
  static const String visa = 'visa';
}

// App texts
class AppTexts {
  static const String appName = 'Visa Mediation';
  static const String welcome = 'Welcome to Visa Mediation';
  static const String welcomeSubtitle = 'Connect with visa offices and get your visa faster';
  static const String loginPrompt = 'Login to continue';
  static const String registerPrompt = 'Create an account to get started';
  static const String adminDashboardTitle = 'Admin Dashboard';
  static const String applicantDashboardTitle = 'Applicant Dashboard';
  static const String officeDashboardTitle = 'Office Dashboard';
  static const String newRequestTitle = 'New Visa Request';
  static const String chatTitle = 'Visa Request Chat';
  static const String noMessagesYet = 'No messages yet. Start the conversation!';
  static const String noRequestsYet = 'No visa requests yet. Create a new request to get started.';
  static const String paymentTitle = 'Payment Details';
  static const String documentUploadTitle = 'Upload Documents';
  static const String documentRequirements = 'Please upload the following documents:\n- Passport scan\n- University degree\n- Personal photo';
  static const String completedVisaMessage = 'Congratulations! Your visa has been issued. You can download it below.';
  static const String rejectedVisaMessage = 'We regret to inform you that your visa application has been rejected.';
}
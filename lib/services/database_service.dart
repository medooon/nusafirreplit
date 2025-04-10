import 'package:visa_mediation_app/models/user.dart';
import 'package:visa_mediation_app/models/visa_request.dart';
import 'package:visa_mediation_app/models/office.dart';

// Mock DatabaseService for now
class DatabaseService {
  // Get user by ID
  Future<User> getUserById(String userId) async {
    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));
    throw Exception('Database service not implemented yet');
  }

  // Get visa request by ID
  Future<VisaRequest> getVisaRequest(String visaRequestId) async {
    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));
    throw Exception('Database service not implemented yet');
  }

  // Create new visa request
  Future<VisaRequest> createVisaRequest({
    required String applicantId,
    required String passportNumber,
  }) async {
    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));
    throw Exception('Database service not implemented yet');
  }

  // Update visa request
  Future<VisaRequest> updateVisaRequest({
    required String visaRequestId,
    String? adminId,
    String? officeId,
    VisaStatus? status,
    bool? isPaid,
    String? paymentReference,
    String? paymentScreenshotUrl,
    String? visaDocumentUrl,
    List<String>? documents,
  }) async {
    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));
    throw Exception('Database service not implemented yet');
  }

  // Get all visa requests (for admin)
  Future<List<VisaRequest>> getAllVisaRequests() async {
    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));
    return [];
  }

  // Get visa requests for an applicant
  Future<List<VisaRequest>> getApplicantVisaRequests(String applicantId) async {
    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));
    return [];
  }

  // Get visa requests for an office
  Future<List<VisaRequest>> getOfficeVisaRequests(String officeId) async {
    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));
    return [];
  }

  // Get all offices (for admin)
  Future<List<Office>> getAllOffices() async {
    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));
    return [];
  }

  // Get available offices (that can accept applications)
  Future<List<Office>> getAvailableOffices() async {
    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));
    return [];
  }

  // Create office profile
  Future<Office> createOfficeProfile({
    required String officeId,
    required String address,
    String logoUrl = '',
    int maxActiveApplications = 5,
  }) async {
    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));
    throw Exception('Database service not implemented yet');
  }
}
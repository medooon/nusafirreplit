import '../models/chat_message.dart';

// Mock ChatService for now
class ChatService {
  // Get messages for a visa request
  Future<List<ChatMessage>> getMessagesForVisaRequest(String visaRequestId) async {
    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));
    return [];
  }

  // Send a message
  Future<ChatMessage> sendMessage({
    required String visaRequestId,
    required String senderId,
    required String senderType,
    required String content,
    required MessageType type,
    String? fileUrl,
    Map<String, dynamic>? metadata,
  }) async {
    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));
    throw Exception('Chat service not implemented yet');
  }

  // Mark messages as read
  Future<void> markMessagesAsRead({
    required String visaRequestId,
    required String userId,
    List<String>? messageIds,
  }) async {
    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));
  }

  // Create system notification
  Future<ChatMessage> createSystemNotification({
    required String visaRequestId,
    required String content,
  }) async {
    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));
    throw Exception('Chat service not implemented yet');
  }
}
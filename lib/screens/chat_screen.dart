import 'dart:io';
import 'package:flutter/material.dart';
import 'package:visa_mediation_app/models/chat_message.dart';
import 'package:visa_mediation_app/models/user.dart';
import 'package:visa_mediation_app/models/visa_request.dart';
import 'package:visa_mediation_app/services/auth_service.dart';
import 'package:visa_mediation_app/services/chat_service.dart';
import 'package:visa_mediation_app/services/database_service.dart';
import 'package:visa_mediation_app/services/storage_service.dart';
import 'package:visa_mediation_app/widgets/chat_bubble.dart';

class ChatScreen extends StatefulWidget {
  final String visaRequestId;

  const ChatScreen({Key? key, required this.visaRequestId}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AuthService _authService = AuthService();
  final ChatService _chatService = ChatService();
  final DatabaseService _databaseService = DatabaseService();
  final StorageService _storageService = StorageService();

  User? _currentUser;
  VisaRequest? _visaRequest;
  List<ChatMessage> _messages = [];
  Map<String, User> _participants = {};
  bool _isLoading = true;
  bool _isSending = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadChatData();
  }

  Future<void> _loadChatData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      // Load current user
      _currentUser = await _authService.getCurrentUser();
      
      if (_currentUser == null) {
        // User not logged in, redirect to login
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      // Load visa request details
      _visaRequest = await _databaseService.getVisaRequest(widget.visaRequestId);
      
      // Load messages
      final messages = await _chatService.getMessagesForVisaRequest(widget.visaRequestId);
      
      // Load participants info
      final participantsIds = <String>{};
      
      // Add applicant ID
      participantsIds.add(_visaRequest!.applicantId);
      
      // Add admin ID if assigned
      if (_visaRequest!.adminId != null) {
        participantsIds.add(_visaRequest!.adminId!);
      }
      
      // Add office ID if assigned
      if (_visaRequest!.officeId != null) {
        participantsIds.add(_visaRequest!.officeId!);
      }
      
      // Add other participant IDs from messages
      for (final message in messages) {
        if (message.senderType != 'system') {
          participantsIds.add(message.senderId);
        }
      }
      
      // Load user data for all participants
      final participants = <String, User>{};
      for (final userId in participantsIds) {
        try {
          final user = await _databaseService.getUserById(userId);
          participants[userId] = user;
        } catch (e) {
          print('Error loading user $userId: $e');
        }
      }

      // Mark messages as read
      await _chatService.markMessagesAsRead(
        visaRequestId: widget.visaRequestId,
        userId: _currentUser!.id,
      );

      setState(() {
        _messages = messages;
        _participants = participants;
        _isLoading = false;
      });

      // Scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load chat data: $e';
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    setState(() {
      _isSending = true;
      _errorMessage = '';
    });

    try {
      await _chatService.sendMessage(
        visaRequestId: widget.visaRequestId,
        senderId: _currentUser!.id,
        senderType: _currentUser!.userType,
        content: messageText,
        type: MessageType.text,
      );

      // Clear text field and reload messages
      _messageController.clear();
      await _loadChatData();
      
      // Scroll to bottom
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to send message: $e';
      });
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  Future<void> _sendFileMessage(File file, MessageType type) async {
    setState(() {
      _isSending = true;
      _errorMessage = '';
    });

    try {
      String fileUrl;
      if (type == MessageType.image) {
        fileUrl = await _storageService.uploadChatFile(file);
      } else {
        fileUrl = await _storageService.uploadChatFile(file);
      }

      await _chatService.sendMessage(
        visaRequestId: widget.visaRequestId,
        senderId: _currentUser!.id,
        senderType: _currentUser!.userType,
        content: type == MessageType.image ? 'Image' : 'Document',
        type: type,
        fileUrl: fileUrl,
      );

      // Reload messages
      await _loadChatData();
      
      // Scroll to bottom
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to send file: $e';
      });
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _buildAppBarTitle(),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showVisaRequestDetails,
          ),
        ],
      ),
      body: Column(
        children: [
          // Status banner
          _buildStatusBanner(),
          
          // Error message if any
          if (_errorMessage.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(8.0),
              color: Colors.red[100],
              width: double.infinity,
              child: Text(
                _errorMessage,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          
          // Messages list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Text(
                          'No messages yet.\nStart the conversation!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(8.0),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final sender = message.senderType != 'system'
                              ? _participants[message.senderId]
                              : null;
                          
                          return ChatBubble(
                            message: message,
                            currentUser: _currentUser!,
                            senderUser: sender,
                          );
                        },
                      ),
          ),
          
          // Message input
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildAppBarTitle() {
    if (_isLoading) {
      return const Text('Loading...');
    }

    if (_visaRequest == null) {
      return const Text('Chat');
    }

    final applicant = _participants[_visaRequest!.applicantId];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(applicant?.name ?? 'Visa Request'),
        Text(
          'Visa Application #${widget.visaRequestId.substring(0, 8)}',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBanner() {
    if (_isLoading || _visaRequest == null) {
      return const SizedBox.shrink();
    }

    Color backgroundColor;
    IconData icon;
    String statusText;

    switch (_visaRequest!.status) {
      case VisaStatus.pending:
        backgroundColor = Colors.orange[100]!;
        icon = Icons.hourglass_empty;
        statusText = 'Pending review';
        break;
      case VisaStatus.documentsPending:
        backgroundColor = Colors.orange[100]!;
        icon = Icons.description_outlined;
        statusText = 'Documents required';
        break;
      case VisaStatus.paymentPending:
        backgroundColor = Colors.orange[100]!;
        icon = Icons.payment;
        statusText = 'Payment pending';
        break;
      case VisaStatus.paymentVerified:
        backgroundColor = Colors.blue[100]!;
        icon = Icons.check_circle_outline;
        statusText = 'Payment verified';
        break;
      case VisaStatus.assigned:
        backgroundColor = Colors.blue[100]!;
        icon = Icons.person_outline;
        statusText = 'Assigned to office';
        break;
      case VisaStatus.processing:
        backgroundColor = Colors.blue[100]!;
        icon = Icons.sync;
        statusText = 'Processing';
        break;
      case VisaStatus.completed:
        backgroundColor = Colors.green[100]!;
        icon = Icons.check_circle;
        statusText = 'Completed';
        break;
      case VisaStatus.rejected:
        backgroundColor = Colors.red[100]!;
        icon = Icons.cancel;
        statusText = 'Rejected';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      color: backgroundColor,
      child: Row(
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 8),
          Text('Status: $statusText'),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    final isDisabled = _isLoading || _isSending || _currentUser == null;

    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        children: [
          // Attachment button
          IconButton(
            icon: const Icon(Icons.attach_file),
            onPressed: isDisabled ? null : _showAttachmentOptions,
          ),
          // Text field
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(24.0)),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              enabled: !isDisabled,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          // Send button
          IconButton(
            icon: _isSending
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            onPressed: isDisabled ? null : _sendMessage,
          ),
        ],
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Send Image'),
              onTap: () {
                Navigator.pop(context);
                // This is just a mock for now, would use image_picker in a real app
                // _pickImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file),
              title: const Text('Send Document'),
              onTap: () {
                Navigator.pop(context);
                // This is just a mock for now, would use file_picker in a real app
                // _pickDocument();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showVisaRequestDetails() {
    if (_visaRequest == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Visa Request Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailsRow('Passport:', _visaRequest!.passportNumber),
            const SizedBox(height: 8),
            _buildDetailsRow('Status:', _visaRequest!.status.toString().split('.').last),
            const SizedBox(height: 8),
            _buildDetailsRow('Created:', _formatDate(_visaRequest!.createdAt)),
            const SizedBox(height: 8),
            _buildDetailsRow('Payment:', _visaRequest!.isPaid ? 'Paid' : 'Not paid'),
            if (_visaRequest!.isPaid) ...[
              const SizedBox(height: 8),
              _buildDetailsRow('Amount:', 'EGP ${_visaRequest!.paymentAmount}'),
            ],
            const SizedBox(height: 16),
            const Text('Participants:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            for (final participant in _participants.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Text('${participant.name} (${participant.userType})'),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
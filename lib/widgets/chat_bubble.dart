import 'package:flutter/material.dart';
import 'package:visa_mediation_app/models/chat_message.dart';
import 'package:visa_mediation_app/models/user.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final User currentUser;
  final User? senderUser; // The user who sent the message (might be null for system messages)

  const ChatBubble({
    Key? key,
    required this.message,
    required this.currentUser,
    this.senderUser,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isCurrentUser = message.senderId == currentUser.id;
    final isSystemMessage = message.type == MessageType.system;
    
    if (isSystemMessage) {
      return _buildSystemMessage(context);
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
      child: Row(
        mainAxisAlignment: isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isCurrentUser) _buildAvatar(),
          const SizedBox(width: 8),
          _buildMessageContent(context, isCurrentUser),
          const SizedBox(width: 8),
          if (isCurrentUser) _buildAvatar(),
        ],
      ),
    );
  }

  Widget _buildSystemMessage(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 12.0),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            message.content,
            style: TextStyle(
              color: Colors.grey[800],
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    if (message.senderType == 'system') {
      return const CircleAvatar(
        radius: 16,
        backgroundColor: Colors.grey,
        child: Icon(Icons.info, size: 16, color: Colors.white),
      );
    }

    final userInitial = senderUser?.name.isNotEmpty == true
        ? senderUser!.name[0].toUpperCase()
        : '?';
    
    Color avatarColor;
    switch (message.senderType) {
      case 'admin':
        avatarColor = Colors.red;
        break;
      case 'office':
        avatarColor = Colors.green;
        break;
      case 'applicant':
        avatarColor = Colors.blue;
        break;
      default:
        avatarColor = Colors.grey;
    }

    return CircleAvatar(
      radius: 16,
      backgroundColor: avatarColor,
      backgroundImage: senderUser?.profileImageUrl.isNotEmpty == true
          ? NetworkImage(senderUser!.profileImageUrl)
          : null,
      child: senderUser?.profileImageUrl.isNotEmpty != true
          ? Text(
              userInitial,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            )
          : null,
    );
  }

  Widget _buildMessageContent(BuildContext context, bool isCurrentUser) {
    final maxWidth = MediaQuery.of(context).size.width * 0.7;
    final bubbleColor = isCurrentUser ? Colors.blue[100] : Colors.grey[200];
    final textColor = isCurrentUser ? Colors.blue[900] : Colors.black87;

    Widget content;
    
    switch (message.type) {
      case MessageType.image:
        content = _buildImageContent();
        break;
      case MessageType.document:
        content = _buildDocumentContent();
        break;
      default:
        content = Text(
          message.content,
          style: TextStyle(color: textColor),
        );
    }

    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sender name
          if (!isCurrentUser && senderUser != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Text(
                senderUser!.name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  fontSize: 12,
                ),
              ),
            ),
          
          // Message content
          content,
          
          // Timestamp
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTimestamp(message.timestamp),
                  style: TextStyle(
                    color: textColor?.withOpacity(0.7),
                    fontSize: 10,
                  ),
                ),
                const SizedBox(width: 4),
                if (isCurrentUser)
                  Icon(
                    message.isRead ? Icons.done_all : Icons.done,
                    size: 12,
                    color: message.isRead ? Colors.blue : Colors.grey,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: message.fileUrl != null
              ? Image.network(
                  message.fileUrl!,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 150,
                      width: double.infinity,
                      color: Colors.grey[300],
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 150,
                      width: double.infinity,
                      color: Colors.grey[300],
                      child: const Center(
                        child: Icon(Icons.error, color: Colors.red),
                      ),
                    );
                  },
                )
              : Container(
                  height: 150,
                  width: double.infinity,
                  color: Colors.grey[300],
                  child: const Center(
                    child: Icon(Icons.image_not_supported, color: Colors.grey),
                  ),
                ),
        ),
        if (message.content.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(message.content),
          ),
      ],
    );
  }

  Widget _buildDocumentContent() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          const Icon(Icons.attach_file, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.content,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (message.fileUrl != null)
                  Text(
                    'Tap to view document',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inDays > 7) {
      // Format as date if older than a week
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    } else if (difference.inDays > 0) {
      // Format as day of week if within a week
      return _getDayOfWeek(timestamp);
    } else {
      // Format as time if today
      return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }

  String _getDayOfWeek(DateTime date) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }
}
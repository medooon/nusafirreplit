enum MessageType {
  text,
  image,
  document,
  system,
}

class ChatMessage {
  final String id;
  final String visaRequestId;
  final String senderId;
  final String senderType;
  final String content;
  final MessageType type;
  final String? fileUrl;
  final bool isRead;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  ChatMessage({
    required this.id,
    required this.visaRequestId,
    required this.senderId,
    required this.senderType,
    required this.content,
    required this.type,
    this.fileUrl,
    this.isRead = false,
    required this.timestamp,
    this.metadata,
  });

  ChatMessage copyWith({
    String? id,
    String? visaRequestId,
    String? senderId,
    String? senderType,
    String? content,
    MessageType? type,
    String? fileUrl,
    bool? isRead,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      visaRequestId: visaRequestId ?? this.visaRequestId,
      senderId: senderId ?? this.senderId,
      senderType: senderType ?? this.senderType,
      content: content ?? this.content,
      type: type ?? this.type,
      fileUrl: fileUrl ?? this.fileUrl,
      isRead: isRead ?? this.isRead,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'visaRequestId': visaRequestId,
      'senderId': senderId,
      'senderType': senderType,
      'content': content,
      'type': type.toString().split('.').last,
      'fileUrl': fileUrl,
      'isRead': isRead,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'metadata': metadata,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    MessageType getType(String typeStr) {
      switch (typeStr) {
        case 'text':
          return MessageType.text;
        case 'image':
          return MessageType.image;
        case 'document':
          return MessageType.document;
        case 'system':
          return MessageType.system;
        default:
          return MessageType.text;
      }
    }

    return ChatMessage(
      id: map['id'] ?? '',
      visaRequestId: map['visaRequestId'] ?? '',
      senderId: map['senderId'] ?? '',
      senderType: map['senderType'] ?? '',
      content: map['content'] ?? '',
      type: getType(map['type'] ?? 'text'),
      fileUrl: map['fileUrl'],
      isRead: map['isRead'] ?? false,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      metadata: map['metadata'],
    );
  }
}
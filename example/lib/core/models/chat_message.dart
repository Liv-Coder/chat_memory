enum MessageSender { user, assistant, system }

class ChatMessage {
  final String content;
  final MessageSender sender;
  final DateTime timestamp;
  final String? id;

  ChatMessage({
    required this.content,
    required this.sender,
    required this.timestamp,
    this.id,
  });

  ChatMessage copyWith({
    String? content,
    MessageSender? sender,
    DateTime? timestamp,
    String? id,
  }) {
    return ChatMessage(
      content: content ?? this.content,
      sender: sender ?? this.sender,
      timestamp: timestamp ?? this.timestamp,
      id: id ?? this.id,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'sender': sender.name,
      'timestamp': timestamp.toIso8601String(),
      'id': id,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      content: json['content'] as String,
      sender: MessageSender.values.firstWhere(
        (e) => e.name == json['sender'],
        orElse: () => MessageSender.user,
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
      id: json['id'] as String?,
    );
  }
}

import 'dart:convert';

/// Role of a message in the conversation.
///
/// Values:
/// - `user`: message authored by end-user
/// - `assistant`: message authored by the LLM/assistant
/// - `system`: system prompt or environment message
enum MessageRole { user, assistant, system, summary }

/// Immutable message model used by `chat_memory`.
///
/// Instances are intended to be small, serializable, and immutable. Use
/// `copyWith` to create modified copies when needed.
class Message {
  final String id;
  final MessageRole role;
  final String content;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  const Message({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.metadata,
  });

  /// Return a new `Message` with updated fields.
  ///
  /// Only `content` and `metadata` are supported for brevity; `id`, `role`, and
  /// `timestamp` are preserved to maintain identity semantics.
  Message copyWith({String? content, Map<String, dynamic>? metadata}) {
    return Message(
      id: id,
      role: role,
      content: content ?? this.content,
      timestamp: timestamp,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role.toString().split('.').last,
      'content': content,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'metadata': metadata,
    };
  }

  static Message fromJson(Map<String, dynamic> json) {
    final roleStr = (json['role'] as String?) ?? 'user';
    final role = MessageRole.values.firstWhere(
      (r) => r.toString().split('.').last == roleStr,
      orElse: () => MessageRole.user,
    );
    return Message(
      id: json['id'] as String,
      role: role,
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String).toUtc(),
      metadata: (json['metadata'] as Map?)?.cast<String, dynamic>(),
    );
  }

  @override
  String toString() => jsonEncode(toJson());
}

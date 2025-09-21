import '../errors.dart';
import '../logging/chat_memory_logger.dart';
import '../models/message.dart';

/// Utility class for message creation, manipulation, and validation
///
/// This class provides comprehensive message-related operations including
/// factory methods, validation, transformation, filtering, and batch processing
/// that can be reused across different conversation managers.
class MessageOperations {
  static final _logger = ChatMemoryLogger.loggerFor('utils.message_operations');

  // Counter for unique ID generation
  static int _idCounter = 0;

  /// Create a user message with automatic ID and timestamp
  static Message createUserMessage({
    required String content,
    Map<String, dynamic>? metadata,
    DateTime? timestamp,
  }) {
    return _createMessage(
      role: MessageRole.user,
      content: content,
      metadata: metadata,
      timestamp: timestamp,
    );
  }

  /// Create an assistant message with automatic ID and timestamp
  static Message createAssistantMessage({
    required String content,
    Map<String, dynamic>? metadata,
    DateTime? timestamp,
  }) {
    return _createMessage(
      role: MessageRole.assistant,
      content: content,
      metadata: metadata,
      timestamp: timestamp,
    );
  }

  /// Create a system message with automatic ID and timestamp
  static Message createSystemMessage({
    required String content,
    Map<String, dynamic>? metadata,
    DateTime? timestamp,
  }) {
    return _createMessage(
      role: MessageRole.system,
      content: content,
      metadata: metadata,
      timestamp: timestamp,
    );
  }

  /// Create a summary message with automatic ID and timestamp
  static Message createSummaryMessage({
    required String content,
    Map<String, dynamic>? metadata,
    DateTime? timestamp,
  }) {
    return _createMessage(
      role: MessageRole.summary,
      content: content,
      metadata: metadata,
      timestamp: timestamp,
    );
  }

  /// Create a message with specified role and automatic ID generation
  static Message _createMessage({
    required MessageRole role,
    required String content,
    Map<String, dynamic>? metadata,
    DateTime? timestamp,
  }) {
    final opCtx = ErrorContext(
      component: 'MessageOperations',
      operation: '_createMessage',
      params: {'role': role.toString(), 'contentLength': content.length},
    );

    try {
      Validation.validateNonEmptyString('content', content, context: opCtx);

      final messageId = _generateUniqueId();
      final messageTimestamp = timestamp ?? DateTime.now().toUtc();

      final message = Message(
        id: messageId,
        role: role,
        content: content,
        timestamp: messageTimestamp,
        metadata: metadata,
      );

      _logger.fine('Message created', {
        ...opCtx.toMap(),
        'messageId': messageId,
        'timestamp': messageTimestamp.toIso8601String(),
      });

      return message;
    } catch (e, st) {
      ChatMemoryLogger.logError(
        _logger,
        '_createMessage',
        e,
        stackTrace: st,
        params: opCtx.toMap(),
        shouldRethrow: true,
      );
      rethrow;
    }
  }

  /// Generate a unique message ID with timestamp and counter
  static String _generateUniqueId() {
    final now = DateTime.now().toUtc();
    final timestamp = now.microsecondsSinceEpoch;
    final counter = ++_idCounter;
    return 'msg_${timestamp}_$counter';
  }

  /// Validate a message for required fields and integrity
  static bool validateMessage(Message message) {
    final opCtx = ErrorContext(
      component: 'MessageOperations',
      operation: 'validateMessage',
      params: {'messageId': message.id, 'role': message.role.toString()},
    );

    try {
      Validation.validateNonEmptyString(
        'message.id',
        message.id,
        context: opCtx,
      );
      Validation.validateNonEmptyString(
        'message.content',
        message.content,
        context: opCtx,
      );

      // Validate timestamp is not in the future (with small tolerance)
      final now = DateTime.now().toUtc();
      if (message.timestamp.isAfter(now.add(Duration(minutes: 5)))) {
        throw ConfigurationException.invalid(
          'message.timestamp',
          'cannot be significantly in the future',
          context: opCtx,
        );
      }

      _logger.fine('Message validation successful', opCtx.toMap());
      return true;
    } catch (e, st) {
      ChatMemoryLogger.logError(
        _logger,
        'validateMessage',
        e,
        stackTrace: st,
        params: opCtx.toMap(),
        shouldRethrow: false,
      );
      return false;
    }
  }

  /// Create multiple messages in batch with consistent timestamps
  static List<Message> createMessageBatch({
    required List<Map<String, dynamic>> messageSpecs,
    DateTime? baseTimestamp,
  }) {
    final opCtx = ErrorContext(
      component: 'MessageOperations',
      operation: 'createMessageBatch',
      params: {'count': messageSpecs.length},
    );

    try {
      Validation.validateListNotEmpty(
        'messageSpecs',
        messageSpecs,
        context: opCtx,
      );

      final messages = <Message>[];
      final baseTime = baseTimestamp ?? DateTime.now().toUtc();

      for (int i = 0; i < messageSpecs.length; i++) {
        final spec = messageSpecs[i];
        final role = _parseRole(spec['role'] as String?);
        final content = spec['content'] as String? ?? '';
        final metadata = spec['metadata'] as Map<String, dynamic>?;

        // Increment timestamp slightly for each message to maintain order
        final timestamp = baseTime.add(Duration(microseconds: i));

        final message = _createMessage(
          role: role,
          content: content,
          metadata: metadata,
          timestamp: timestamp,
        );
        messages.add(message);
      }

      _logger.fine('Message batch created', {
        ...opCtx.toMap(),
        'createdCount': messages.length,
      });

      return messages;
    } catch (e, st) {
      ChatMemoryLogger.logError(
        _logger,
        'createMessageBatch',
        e,
        stackTrace: st,
        params: opCtx.toMap(),
        shouldRethrow: true,
      );
      rethrow;
    }
  }

  /// Filter messages by role
  static List<Message> filterByRole(List<Message> messages, MessageRole role) {
    return messages.where((message) => message.role == role).toList();
  }

  /// Filter messages by multiple roles
  static List<Message> filterByRoles(
    List<Message> messages,
    Set<MessageRole> roles,
  ) {
    return messages.where((message) => roles.contains(message.role)).toList();
  }

  /// Filter messages by timestamp range
  static List<Message> filterByTimeRange({
    required List<Message> messages,
    DateTime? startTime,
    DateTime? endTime,
  }) {
    return messages.where((message) {
      if (startTime != null && message.timestamp.isBefore(startTime)) {
        return false;
      }
      if (endTime != null && message.timestamp.isAfter(endTime)) {
        return false;
      }
      return true;
    }).toList();
  }

  /// Filter messages by content pattern
  static List<Message> filterByContentPattern(
    List<Message> messages,
    Pattern pattern,
  ) {
    return messages.where((message) {
      return pattern.allMatches(message.content).isNotEmpty;
    }).toList();
  }

  /// Filter messages by metadata criteria
  static List<Message> filterByMetadata(
    List<Message> messages,
    bool Function(Map<String, dynamic>?) predicate,
  ) {
    return messages.where((message) => predicate(message.metadata)).toList();
  }

  /// Search messages by content containing specified terms
  static List<Message> searchByContent({
    required List<Message> messages,
    required String searchTerm,
    bool caseSensitive = false,
  }) {
    final pattern = RegExp(
      RegExp.escape(searchTerm),
      caseSensitive: caseSensitive,
    );
    return filterByContentPattern(messages, pattern);
  }

  /// Get the most recent message of a specific role
  static Message? getLastMessageByRole(
    List<Message> messages,
    MessageRole role,
  ) {
    final filtered = filterByRole(messages, role);
    if (filtered.isEmpty) return null;

    // Sort by timestamp descending and return first
    filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return filtered.first;
  }

  /// Get the last user message from a conversation
  static Message? getLastUserMessage(List<Message> messages) {
    return getLastMessageByRole(messages, MessageRole.user);
  }

  /// Transform message content using a provided function
  static Message transformContent(
    Message message,
    String Function(String) transformer,
  ) {
    return message.copyWith(
      content: transformer(message.content),
      metadata: {
        ...?message.metadata,
        'transformed': true,
        'transformedAt': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  /// Create a copy of a message with a new role
  static Message changeRole(Message message, MessageRole newRole) {
    return Message(
      id: message.id,
      role: newRole,
      content: message.content,
      timestamp: message.timestamp,
      metadata: {
        ...?message.metadata,
        'originalRole': message.role.toString(),
        'roleChangedAt': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  /// Add metadata to an existing message
  static Message addMetadata(
    Message message,
    Map<String, dynamic> additionalMetadata,
  ) {
    return message.copyWith(
      metadata: {...?message.metadata, ...additionalMetadata},
    );
  }

  /// Parse role string to MessageRole enum
  static MessageRole _parseRole(String? roleStr) {
    if (roleStr == null) return MessageRole.user;

    switch (roleStr.toLowerCase()) {
      case 'system':
        return MessageRole.system;
      case 'assistant':
        return MessageRole.assistant;
      case 'summary':
        return MessageRole.summary;
      case 'user':
      default:
        return MessageRole.user;
    }
  }

  /// Convert messages to JSON serializable format
  static List<Map<String, dynamic>> toJsonList(List<Message> messages) {
    return messages.map((message) => message.toJson()).toList();
  }

  /// Create messages from JSON list
  static List<Message> fromJsonList(List<Map<String, dynamic>> jsonList) {
    return jsonList.map((json) => Message.fromJson(json)).toList();
  }

  /// Get message statistics
  static Map<String, dynamic> getMessageStats(List<Message> messages) {
    if (messages.isEmpty) {
      return {
        'totalMessages': 0,
        'roleDistribution': <String, int>{},
        'averageLength': 0.0,
        'totalLength': 0,
      };
    }

    final roleDistribution = <MessageRole, int>{};
    var totalLength = 0;

    for (final message in messages) {
      roleDistribution[message.role] =
          (roleDistribution[message.role] ?? 0) + 1;
      totalLength += message.content.length;
    }

    return {
      'totalMessages': messages.length,
      'roleDistribution': roleDistribution.map(
        (k, v) => MapEntry(k.toString(), v),
      ),
      'averageLength': totalLength / messages.length,
      'totalLength': totalLength,
    };
  }

  /// Reset the ID counter (useful for testing)
  static void resetIdCounter() {
    _idCounter = 0;
    _logger.fine('Message ID counter reset');
  }
}

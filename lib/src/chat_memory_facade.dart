import 'dart:async';

import 'conversation/enhanced_conversation_manager.dart';
import 'chat_memory_config.dart';
import 'chat_context.dart';
import 'chat_memory_builder.dart';
import 'core/models/message.dart';
import 'core/errors.dart';
import 'core/logging/chat_memory_logger.dart';
import 'memory/hybrid_memory_factory.dart';

/// Simplified facade for chat memory management.
///
/// Provides a clean, declarative API for managing conversation history with
/// semantic memory and summarization capabilities. Hides the complexity of
/// the underlying memory management system while providing full functionality.
///
/// Example usage:
/// ```dart
/// // Quick setup with presets
/// final chatMemory = await ChatMemory.development();
///
/// // Add messages to the conversation
/// await chatMemory.addMessage('Hello!', role: 'user');
/// await chatMemory.addMessage('Hi there! How can I help?', role: 'assistant');
///
/// // Get context for LLM prompts
/// final context = await chatMemory.getContext(query: 'What greeting did the user use?');
/// print('Prompt: ${context.promptText}');
/// print('Token count: ${context.estimatedTokens}');
///
/// // Clear conversation history
/// await chatMemory.clear();
/// ```
class ChatMemory {
  final EnhancedConversationManager _conversationManager;
  final ChatMemoryConfig _config;
  final _logger = ChatMemoryLogger.loggerFor('chat_memory.facade');

  /// Private constructor used by the builder.
  ChatMemory._({
    required EnhancedConversationManager conversationManager,
    required ChatMemoryConfig config,
  }) : _conversationManager = conversationManager,
       _config = config;

  /// Create a ChatMemory instance with development preset.
  ///
  /// Optimized for fast iteration:
  /// - In-memory storage for quick startup
  /// - Lower token limits for faster processing
  /// - Enhanced logging enabled
  /// - Semantic memory enabled with moderate settings
  static Future<ChatMemory> development() async {
    final conversationManager = await EnhancedConversationManager.create(
      preset: MemoryPreset.development,
      maxTokens: 2000,
    );

    return ChatMemory._(
      conversationManager: conversationManager,
      config: ChatMemoryConfig.development(),
    );
  }

  /// Create a ChatMemory instance with production preset.
  ///
  /// Optimized for performance and reliability:
  /// - Persistent local storage
  /// - Higher token limits for better context
  /// - Logging optimized for performance
  /// - Full semantic memory features enabled
  static Future<ChatMemory> production() async {
    final conversationManager = await EnhancedConversationManager.create(
      preset: MemoryPreset.production,
      maxTokens: 8000,
    );

    return ChatMemory._(
      conversationManager: conversationManager,
      config: ChatMemoryConfig.production(),
    );
  }

  /// Create a ChatMemory instance with minimal preset.
  ///
  /// Minimal resource usage:
  /// - No persistent storage
  /// - Lower token limits
  /// - Basic summarization only
  /// - No semantic memory features
  static Future<ChatMemory> minimal() async {
    final conversationManager = await EnhancedConversationManager.create(
      preset: MemoryPreset.minimal,
      maxTokens: 1000,
    );

    return ChatMemory._(
      conversationManager: conversationManager,
      config: ChatMemoryConfig.minimal(),
    );
  }

  /// Create a builder for custom configuration.
  static ChatMemoryBuilder builder() {
    return ChatMemoryBuilder();
  }

  /// Add a message to the conversation.
  ///
  /// The message will be stored in memory and used for future context retrieval.
  /// Messages are automatically assigned IDs and timestamps if not provided.
  ///
  /// [content] - The text content of the message (required)
  /// [role] - The role of the message sender (default: 'user')
  /// [metadata] - Optional metadata to attach to the message
  ///
  /// Throws [ValidationError] if content is empty or role is invalid.
  /// Throws [MemoryException] if storage fails.
  Future<void> addMessage(
    String content, {
    String role = 'user',
    Map<String, dynamic>? metadata,
  }) async {
    final ctx = ErrorContext(
      component: 'ChatMemory',
      operation: 'addMessage',
      params: {
        'role': role,
        'contentLength': content.length,
        'hasMetadata': metadata != null,
      },
    );

    try {
      // Validate input
      if (content.trim().isEmpty) {
        throw ConfigurationException.invalid(
          'content',
          'Message content cannot be empty',
          context: ctx,
        );
      }

      // Parse role
      final messageRole = _parseMessageRole(role);

      // Create message with auto-generated ID and timestamp
      final message = Message(
        id: _generateMessageId(),
        role: messageRole,
        content: content.trim(),
        timestamp: DateTime.now().toUtc(),
        metadata: metadata,
      );

      // Store message via conversation manager
      if (messageRole == MessageRole.user) {
        await _conversationManager.appendUserMessage(
          content.trim(),
          metadata: metadata,
        );
      } else if (messageRole == MessageRole.assistant) {
        await _conversationManager.appendAssistantMessage(
          content.trim(),
          metadata: metadata,
        );
      } else {
        // For system and other roles, store directly
        await _conversationManager.appendMessage(message);
      }

      _logger.fine('Message added successfully', {
        ...ctx.toMap(),
        'messageId': message.id,
      });
    } catch (e, st) {
      ChatMemoryLogger.logError(
        _logger,
        'addMessage',
        e,
        stackTrace: st,
        params: ctx.toMap(),
        shouldRethrow: true,
      );
      rethrow;
    }
  }

  /// Get conversation context for LLM prompts.
  ///
  /// Retrieves relevant conversation history based on the query and current
  /// configuration. Applies summarization and semantic retrieval as needed
  /// to stay within token limits while maximizing relevant context.
  ///
  /// [query] - Optional query to focus context retrieval (if not provided,
  ///           uses recent conversation history)
  /// [maxTokens] - Optional token limit override (uses config default if not provided)
  ///
  /// Returns a [ChatContext] with the prompt text and metadata.
  ///
  /// Throws [MemoryException] if context retrieval fails.
  Future<ChatContext> getContext({String? query, int? maxTokens}) async {
    final ctx = ErrorContext(
      component: 'ChatMemory',
      operation: 'getContext',
      params: {
        'hasQuery': query != null,
        'queryLength': query?.length ?? 0,
        'maxTokens': maxTokens ?? _config.maxTokens,
      },
    );

    try {
      final effectiveQuery = query ?? '';
      final effectiveMaxTokens = maxTokens ?? _config.maxTokens;

      // Get enhanced prompt from conversation manager
      final promptPayload = await _conversationManager.buildEnhancedPrompt(
        clientTokenBudget: effectiveMaxTokens,
        userQuery: effectiveQuery.isNotEmpty ? effectiveQuery : null,
      );

      // Convert to simplified ChatContext (EnhancedPromptPayload extends PromptPayload)
      final chatContext = ChatContext.fromPromptPayload(promptPayload);

      _logger.fine('Context retrieved successfully', {
        ...ctx.toMap(),
        'messageCount': chatContext.messageCount,
        'estimatedTokens': chatContext.estimatedTokens,
        'hasMemory': chatContext.hasMemory,
      });

      return chatContext;
    } catch (e, st) {
      ChatMemoryLogger.logError(
        _logger,
        'getContext',
        e,
        stackTrace: st,
        params: ctx.toMap(),
        shouldRethrow: false, // Return error context instead of throwing
      );

      // Return error context instead of throwing
      return ChatContext.error(
        error: 'Failed to retrieve context: ${e.toString()}',
        partialPrompt: query,
      );
    }
  }

  /// Clear all conversation history.
  ///
  /// Removes all messages and associated memory data. This operation cannot
  /// be undone. Use with caution in production environments.
  ///
  /// Throws [MemoryException] if clearing fails.
  Future<void> clear() async {
    final ctx = ErrorContext(component: 'ChatMemory', operation: 'clear');

    try {
      await _conversationManager.clear();

      _logger.info('Conversation history cleared', ctx.toMap());
    } catch (e, st) {
      ChatMemoryLogger.logError(
        _logger,
        'clear',
        e,
        stackTrace: st,
        params: ctx.toMap(),
        shouldRethrow: true,
      );
      rethrow;
    }
  }

  /// Get conversation statistics.
  ///
  /// Returns information about the current conversation including message
  /// counts, token estimates, and memory usage.
  Future<Map<String, dynamic>> getStats() async {
    final ctx = ErrorContext(component: 'ChatMemory', operation: 'getStats');

    try {
      final messages = await _conversationManager.persistence.loadMessages();

      return {
        'messageCount': messages.length,
        'userMessages': messages
            .where((m) => m.role == MessageRole.user)
            .length,
        'assistantMessages': messages
            .where((m) => m.role == MessageRole.assistant)
            .length,
        'systemMessages': messages
            .where((m) => m.role == MessageRole.system)
            .length,
        'totalCharacters': messages.fold<int>(
          0,
          (sum, m) => sum + m.content.length,
        ),
        'hasMemory': _config.enableMemory,
        'hasSummarization': _config.enableSummarization,
        'maxTokens': _config.maxTokens,
        'preset': _config.preset.name,
      };
    } catch (e, st) {
      ChatMemoryLogger.logError(
        _logger,
        'getStats',
        e,
        stackTrace: st,
        params: ctx.toMap(),
        shouldRethrow: false,
      );

      return {'error': e.toString(), 'messageCount': 0};
    }
  }

  /// Get the current configuration.
  ChatMemoryConfig get config => _config;

  /// Check if the instance is properly initialized.
  bool get isInitialized =>
      true; // Always true since _conversationManager is non-nullable

  /// Parse string role to MessageRole enum.
  MessageRole _parseMessageRole(String role) {
    switch (role.toLowerCase()) {
      case 'user':
        return MessageRole.user;
      case 'assistant':
      case 'ai':
      case 'bot':
        return MessageRole.assistant;
      case 'system':
        return MessageRole.system;
      case 'summary':
        return MessageRole.summary;
      default:
        throw ConfigurationException.invalid(
          'role',
          'Invalid message role: $role. Valid roles are: user, assistant, system, summary',
        );
    }
  }

  /// Generate a unique message ID.
  String _generateMessageId() {
    return 'msg_${DateTime.now().microsecondsSinceEpoch}';
  }
}

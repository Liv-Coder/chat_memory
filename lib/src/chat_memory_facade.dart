import 'dart:async';

import 'conversation/enhanced_conversation_manager.dart';
import 'chat_memory_config.dart';
import 'chat_context.dart';
import 'chat_memory_builder.dart';
import 'core/models/message.dart';
import 'core/errors.dart';
import 'core/logging/chat_memory_logger.dart';
import 'core/utils/system_prompt_manager.dart';
import 'memory/hybrid_memory_factory.dart';

/// Simplified facade for chat memory management.
///
/// Provides a clean, declarative API for managing conversation history with
/// semantic memory, summarization, and automatic system prompt management.
/// Hides the complexity of the underlying memory management system while
/// providing full functionality.
///
/// Example usage:
/// ```dart
/// // Quick setup with presets (system prompt automatically injected)
/// final chatMemory = await ChatMemory.development();
///
/// // Add messages to the conversation
/// await chatMemory.addMessage('Hello!', role: 'user');
/// await chatMemory.addMessage('Hi there! How can I help?', role: 'assistant');
///
/// // Get context for LLM prompts (includes system prompt)
/// final context = await chatMemory.getContext(query: 'What greeting did the user use?');
/// print('Prompt: ${context.promptText}');
/// print('Token count: ${context.estimatedTokens}');
///
/// // Manage system prompts
/// await chatMemory.updateSystemPrompt('You are a supportive financial coach.');
/// print('Current system prompt: ${await chatMemory.getSystemPrompt()}');
///
/// // Clear conversation history
/// await chatMemory.clear();
/// ```
class ChatMemory {
  final EnhancedConversationManager _conversationManager;
  final ChatMemoryConfig _config;
  final _logger = ChatMemoryLogger.loggerFor('chat_memory.facade');
  bool _systemPromptInjected = false;

  /// Private constructor used by the builder.
  ChatMemory._({
    required EnhancedConversationManager conversationManager,
    required ChatMemoryConfig config,
  }) : _conversationManager = conversationManager,
       _config = config {
    // Schedule system prompt injection after construction
    Timer.run(() => _injectSystemPromptIfNeeded());
  }

  /// Create a ChatMemory instance with development preset.
  ///
  /// Optimized for fast iteration:
  /// - In-memory storage for quick startup
  /// - Lower token limits for faster processing
  /// - Enhanced logging enabled
  /// - Semantic memory enabled with moderate settings
  /// - System prompt enabled with default friendly assistant behavior
  static Future<ChatMemory> development() async {
    final config = ChatMemoryConfig.development();
    final conversationManager = await EnhancedConversationManager.create(
      preset: MemoryPreset.development,
      maxTokens: config.maxTokens,
    );

    final chatMemory = ChatMemory._(
      conversationManager: conversationManager,
      config: config,
    );

    return chatMemory;
  }

  /// Create a ChatMemory instance with production preset.
  ///
  /// Optimized for performance and reliability:
  /// - Persistent local storage
  /// - Higher token limits for better context
  /// - Logging optimized for performance
  /// - Full semantic memory features enabled
  /// - System prompt enabled with default friendly assistant behavior
  static Future<ChatMemory> production() async {
    final config = ChatMemoryConfig.production();
    final conversationManager = await EnhancedConversationManager.create(
      preset: MemoryPreset.production,
      maxTokens: config.maxTokens,
    );

    final chatMemory = ChatMemory._(
      conversationManager: conversationManager,
      config: config,
    );

    return chatMemory;
  }

  /// Create a ChatMemory instance with minimal preset.
  ///
  /// Minimal resource usage:
  /// - No persistent storage
  /// - Lower token limits
  /// - Basic summarization only
  /// - No semantic memory features
  /// - System prompt disabled for minimal resource usage
  static Future<ChatMemory> minimal() async {
    final config = ChatMemoryConfig.minimal();
    final conversationManager = await EnhancedConversationManager.create(
      preset: MemoryPreset.minimal,
      maxTokens: config.maxTokens,
    );

    final chatMemory = ChatMemory._(
      conversationManager: conversationManager,
      config: config,
    );

    return chatMemory;
  }

  /// Create a builder for custom configuration.
  static ChatMemoryBuilder builder() {
    return ChatMemoryBuilder();
  }

  /// Internal factory method for ChatMemoryBuilder.
  ///
  /// This method is used by ChatMemoryBuilder to create ChatMemory instances
  /// with the configured settings.
  static ChatMemory fromBuilder({
    required EnhancedConversationManager conversationManager,
    required ChatMemoryConfig config,
  }) {
    return ChatMemory._(
      conversationManager: conversationManager,
      config: config,
    );
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
    // Inject system prompt if needed before adding user messages
    await _injectSystemPromptIfNeeded();

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

  /// Get access to the underlying conversation manager for advanced operations.
  ///
  /// This provides access to advanced features not exposed through the simplified facade.
  EnhancedConversationManager get conversationManager => _conversationManager;

  /// Update the system prompt for the current conversation.
  ///
  /// Replaces the existing system prompt with a new one. The system prompt
  /// provides context and instructions to the AI about how it should behave.
  ///
  /// [prompt] - The new system prompt text
  ///
  /// Throws [ArgumentError] if the prompt is invalid.
  /// Throws [MemoryException] if update fails.
  Future<void> updateSystemPrompt(String prompt) async {
    final ctx = ErrorContext(
      component: 'ChatMemory',
      operation: 'updateSystemPrompt',
      params: {'promptLength': prompt.length},
    );

    try {
      await SystemPromptManager.updateSystemPrompt(
        _conversationManager,
        prompt,
      );
      _systemPromptInjected = true;

      _logger.info('System prompt updated', ctx.toMap());
    } catch (e, st) {
      ChatMemoryLogger.logError(
        _logger,
        'updateSystemPrompt',
        e,
        stackTrace: st,
        params: ctx.toMap(),
        shouldRethrow: true,
      );
      rethrow;
    }
  }

  /// Get the current system prompt.
  ///
  /// Returns the system prompt text if available, null if no system
  /// prompt is configured or system prompts are disabled.
  Future<String?> getSystemPrompt() async {
    final ctx = ErrorContext(
      component: 'ChatMemory',
      operation: 'getSystemPrompt',
    );

    try {
      if (!_config.useSystemPrompt) {
        return null;
      }

      return await SystemPromptManager.getSystemPrompt(_conversationManager);
    } catch (e, st) {
      ChatMemoryLogger.logError(
        _logger,
        'getSystemPrompt',
        e,
        stackTrace: st,
        params: ctx.toMap(),
        shouldRethrow: false,
      );
      return null;
    }
  }

  /// Check if a system prompt is currently active.
  ///
  /// Returns true if system prompts are enabled and a prompt has been injected.
  bool hasSystemPrompt() {
    return _config.useSystemPrompt && _systemPromptInjected;
  }

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

  /// Inject system prompt if needed and not already done.
  Future<void> _injectSystemPromptIfNeeded() async {
    if (!_config.useSystemPrompt || _systemPromptInjected) {
      return;
    }

    final ctx = ErrorContext(
      component: 'ChatMemory',
      operation: '_injectSystemPromptIfNeeded',
    );

    try {
      final prompt =
          _config.systemPrompt ?? ChatMemoryConfig.defaultSystemPrompt;
      await SystemPromptManager.injectSystemPrompt(
        _conversationManager,
        prompt,
      );
      _systemPromptInjected = true;

      _logger.fine('System prompt injected automatically', ctx.toMap());
    } catch (e, st) {
      ChatMemoryLogger.logError(
        _logger,
        '_injectSystemPromptIfNeeded',
        e,
        stackTrace: st,
        params: ctx.toMap(),
        shouldRethrow: false, // Don't fail the entire operation
      );
    }
  }

  /// Generate a unique message ID.
  String _generateMessageId() {
    return 'msg_${DateTime.now().microsecondsSinceEpoch}';
  }
}

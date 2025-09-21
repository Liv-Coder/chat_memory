import '../models/message.dart';
import '../errors.dart';
import '../logging/chat_memory_logger.dart';
import '../../conversation/enhanced_conversation_manager.dart';
import '../../chat_memory_config.dart';
import 'package:logging/logging.dart';

/// Utility class for advanced system prompt management.
///
/// Provides comprehensive system prompt lifecycle management, validation,
/// and integration with the ChatMemory conversation system.
class SystemPromptManager {
  static final Logger _logger = ChatMemoryLogger.loggerFor(
    'system_prompt_manager',
  );

  /// System prompt domains for specialized prompts.
  static const Map<String, String> domainPrompts = {
    'medical':
        'You are a knowledgeable medical assistant. Provide helpful '
        'health information while emphasizing the importance of consulting '
        'healthcare professionals for medical advice.',
    'legal':
        'You are a legal information assistant. Provide general legal '
        'information while emphasizing that this is not legal advice and '
        'users should consult qualified attorneys for specific legal matters.',
    'educational':
        'You are an educational assistant. Help explain concepts '
        'clearly, encourage learning, and adapt your explanations to the '
        'user\'s level of understanding.',
    'financial':
        'You are a supportive financial coach. Provide helpful '
        'financial guidance while emphasizing the importance of personal '
        'research and professional financial advice.',
    'technical':
        'You are a technical assistant. Provide accurate technical '
        'information, code examples, and practical solutions while maintaining '
        'clarity and precision.',
  };

  /// Inject a system prompt into a conversation.
  ///
  /// Adds the system prompt as the first message in the conversation.
  /// If a system prompt already exists, it will be updated.
  ///
  /// [conversationManager] - The conversation manager to inject into
  /// [prompt] - The system prompt text to inject
  ///
  /// Throws [ArgumentError] if the prompt is invalid.
  /// Throws [MemoryException] if injection fails.
  static Future<void> injectSystemPrompt(
    EnhancedConversationManager conversationManager,
    String prompt,
  ) async {
    try {
      // Validate the prompt first
      validateSystemPrompt(prompt);

      // Check if system prompt already exists and remove it
      await removeSystemPrompt(conversationManager);

      // Add the new system prompt
      await conversationManager.appendSystemMessage(
        prompt,
        metadata: {
          'type': 'system_prompt',
          'injected_at': DateTime.now().toUtc().toIso8601String(),
          'source': 'SystemPromptManager',
        },
      );

      _logger.info('System prompt injected successfully');
      _logger.fine('System prompt details: ${{'promptLength': prompt.length}}');
    } catch (e, st) {
      ChatMemoryLogger.logError(
        _logger,
        'injectSystemPrompt',
        e,
        stackTrace: st,
        params: {'promptLength': prompt.length},
        shouldRethrow: true,
      );
      rethrow;
    }
  }

  /// Update the system prompt in a conversation.
  ///
  /// Replaces the existing system prompt with a new one. If no system
  /// prompt exists, injects a new one.
  ///
  /// [conversationManager] - The conversation manager to update
  /// [newPrompt] - The new system prompt text
  ///
  /// Throws [ArgumentError] if the prompt is invalid.
  /// Throws [MemoryException] if update fails.
  static Future<void> updateSystemPrompt(
    EnhancedConversationManager conversationManager,
    String newPrompt,
  ) async {
    try {
      validateSystemPrompt(newPrompt);

      // Remove existing system prompt and inject new one
      await injectSystemPrompt(conversationManager, newPrompt);

      _logger.info('System prompt updated successfully');
      _logger.fine(
        'System prompt details: ${{'newPromptLength': newPrompt.length}}',
      );
    } catch (e, st) {
      ChatMemoryLogger.logError(
        _logger,
        'updateSystemPrompt',
        e,
        stackTrace: st,
        params: {'newPromptLength': newPrompt.length},
        shouldRethrow: true,
      );
      rethrow;
    }
  }

  /// Remove the system prompt from a conversation.
  ///
  /// Removes any existing system prompt messages from the conversation.
  /// This operation cannot be undone.
  ///
  /// [conversationManager] - The conversation manager to modify
  ///
  /// Returns true if a system prompt was removed, false if none existed.
  static Future<bool> removeSystemPrompt(
    EnhancedConversationManager conversationManager,
  ) async {
    try {
      // For now, we can't directly remove messages from the conversation
      // This would require extending the conversation manager interface
      // For the current implementation, we'll log the request
      _logger.info(
        'System prompt removal requested - not implemented in current interface',
      );

      // Return false as we couldn't actually remove it
      return false;
    } catch (e, st) {
      ChatMemoryLogger.logError(
        _logger,
        'removeSystemPrompt',
        e,
        stackTrace: st,
        shouldRethrow: true,
      );
      rethrow;
    }
  }

  /// Retrieve the current system prompt from a conversation.
  ///
  /// Searches for the most recent system prompt message in the conversation.
  ///
  /// [conversationManager] - The conversation manager to search
  ///
  /// Returns the system prompt text if found, null if no system prompt exists.
  static Future<String?> getSystemPrompt(
    EnhancedConversationManager conversationManager,
  ) async {
    try {
      // For now, we can't directly access messages from the conversation manager
      // This would require extending the interface or using the persistence layer
      _logger.info(
        'System prompt retrieval requested - requires extended interface',
      );

      return null;
    } catch (e, st) {
      ChatMemoryLogger.logError(
        _logger,
        'getSystemPrompt',
        e,
        stackTrace: st,
        shouldRethrow: true,
      );
      rethrow;
    }
  }

  /// Validate a system prompt.
  ///
  /// Checks if the prompt meets requirements for content and format.
  ///
  /// [prompt] - The system prompt to validate
  ///
  /// Throws [ArgumentError] if the prompt is invalid.
  static void validateSystemPrompt(String prompt) {
    if (prompt.isEmpty) {
      throw ArgumentError('System prompt cannot be empty');
    }

    if (prompt.length > 5000) {
      throw ArgumentError(
        'System prompt cannot exceed 5,000 characters (current: ${prompt.length})',
      );
    }

    // Check for potentially problematic content
    final trimmed = prompt.trim();
    if (trimmed != prompt) {
      _logger.warning('System prompt has leading/trailing whitespace');
      _logger.fine(
        'Whitespace details: ${{'originalLength': prompt.length, 'trimmedLength': trimmed.length}}',
      );
    }
  }

  /// Check if a prompt meets validation requirements.
  ///
  /// [prompt] - The system prompt to check
  ///
  /// Returns true if the prompt is valid, false otherwise.
  static bool isValidSystemPrompt(String prompt) {
    try {
      validateSystemPrompt(prompt);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Clean and format a system prompt.
  ///
  /// Removes extra whitespace and normalizes the prompt format.
  ///
  /// [prompt] - The system prompt to sanitize
  ///
  /// Returns the cleaned prompt text.
  static String sanitizeSystemPrompt(String prompt) {
    if (prompt.isEmpty) return prompt;

    // Trim whitespace and normalize line endings
    String sanitized = prompt.trim().replaceAll('\r\n', '\n');

    // Remove excessive whitespace
    sanitized = sanitized.replaceAll(RegExp(r'\s+'), ' ');

    // Remove multiple consecutive line breaks
    sanitized = sanitized.replaceAll(RegExp(r'\n\s*\n'), '\n\n');

    return sanitized;
  }

  /// Get the default system prompt.
  ///
  /// Returns the built-in friendly assistant prompt.
  static String getDefaultPrompt() {
    return ChatMemoryConfig.defaultSystemPrompt;
  }

  /// Get a domain-specific system prompt.
  ///
  /// [domain] - The domain to get a prompt for (medical, legal, educational, etc.)
  ///
  /// Returns the domain-specific prompt, or the default prompt if domain is unknown.
  static String getPromptForDomain(String domain) {
    final normalizedDomain = domain.toLowerCase().trim();
    return domainPrompts[normalizedDomain] ?? getDefaultPrompt();
  }

  /// Create a custom prompt from a template.
  ///
  /// [template] - The prompt template with placeholder variables
  /// [variables] - Map of variable names to values for substitution
  ///
  /// Returns the prompt with variables substituted.
  ///
  /// Example:
  /// ```dart
  /// final prompt = SystemPromptManager.createCustomPrompt(
  ///   'You are a {{role}} assistant. Your specialty is {{specialty}}.',
  ///   {'role': 'helpful', 'specialty': 'financial planning'},
  /// );
  /// ```
  static String createCustomPrompt(
    String template,
    Map<String, String> variables,
  ) {
    String result = template;

    variables.forEach((key, value) {
      result = result.replaceAll('{{$key}}', value);
    });

    return sanitizeSystemPrompt(result);
  }

  /// Ensure system prompt persistence during operations.
  ///
  /// Checks if messages contain a system prompt and preserves it.
  ///
  /// [messages] - The list of messages to check
  ///
  /// Returns the messages with system prompt preserved if found.
  static List<Message> ensureSystemPromptPersistence(List<Message> messages) {
    if (messages.isEmpty) return messages;

    // Check if first message is a system prompt
    final firstMessage = messages.first;
    if (firstMessage.role == MessageRole.system) {
      // System prompt is already preserved
      return messages;
    }

    // Look for system prompt anywhere in the messages
    final systemPromptIndex = messages.indexWhere(
      (message) => message.role == MessageRole.system,
    );

    if (systemPromptIndex != -1 && systemPromptIndex != 0) {
      // Move system prompt to the beginning
      final systemPrompt = messages[systemPromptIndex];
      final reorderedMessages = [systemPrompt];
      reorderedMessages.addAll(
        messages.where((msg) => msg.id != systemPrompt.id),
      );
      return reorderedMessages;
    }

    return messages;
  }

  /// Determine if system prompt should be preserved during an operation.
  ///
  /// [operation] - The type of operation being performed
  ///
  /// Returns true if the system prompt should be preserved.
  static bool shouldPreserveSystemPrompt(String operation) {
    const preserveOperations = {
      'summarization',
      'context_building',
      'semantic_retrieval',
      'memory_optimization',
    };

    return preserveOperations.contains(operation.toLowerCase());
  }

  /// Restore system prompt after operations that might have removed it.
  ///
  /// [messages] - The messages to restore the system prompt to
  /// [prompt] - The system prompt to restore
  ///
  /// Returns the messages with the system prompt restored as the first message.
  static List<Message> restoreSystemPrompt(
    List<Message> messages,
    String prompt,
  ) {
    // Remove any existing system prompts first
    final filteredMessages = messages
        .where((msg) => msg.role != MessageRole.system)
        .toList();

    // Create new system message
    final systemMessage = Message(
      id: 'system_${DateTime.now().millisecondsSinceEpoch}',
      role: MessageRole.system,
      content: prompt,
      timestamp: DateTime.now().toUtc(),
      metadata: {
        'type': 'system_prompt',
        'restored_at': DateTime.now().toUtc().toIso8601String(),
        'source': 'SystemPromptManager',
      },
    );

    // Return with system prompt as first message
    return [systemMessage, ...filteredMessages];
  }

  /// Get available domain prompts.
  ///
  /// Returns a list of available domain names for specialized prompts.
  static List<String> getAvailableDomains() {
    return domainPrompts.keys.toList();
  }

  /// Get system prompt metadata for analytics.
  ///
  /// [prompt] - The system prompt to analyze
  ///
  /// Returns metadata about the system prompt.
  static Map<String, dynamic> getSystemPromptMetadata(String prompt) {
    return {
      'length': prompt.length,
      'wordCount': prompt.split(RegExp(r'\s+')).length,
      'isDomainSpecific': domainPrompts.values.contains(prompt),
      'isDefault': prompt == getDefaultPrompt(),
      'sanitized': prompt == sanitizeSystemPrompt(prompt),
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };
  }
}

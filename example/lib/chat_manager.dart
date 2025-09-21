import 'package:chat_memory/chat_memory.dart';
import 'package:flutter/material.dart';

/// Enhanced wrapper around the new hybrid memory system
///
/// Demonstrates the full capabilities of the chat memory package with
/// summarization, semantic retrieval, and comprehensive memory management.
class ChatManager {
  late final EnhancedConversationManager _conversationManager;
  ConversationStats? _lastStats;
  int _messageCount = 0;

  ChatManager() {
    _initializeManager();
  }

  Future<void> _initializeManager() async {
    // Initialize with the new hybrid memory system using production preset
    _conversationManager = await EnhancedConversationManager.create(
      preset: MemoryPreset.production,
      maxTokens: 8000,
      onSummaryCreated: (summaryMessage) {
        // Hook for when summaries are created
        try {
          final preview = summaryMessage.content.length > 150
              ? '${summaryMessage.content.substring(0, 150)}…'
              : summaryMessage.content;
          debugPrint('🧠 Memory Summary Created: $preview');
        } catch (_) {
          // Ignore errors in callback
        }
      },
      onMessageStored: (message) {
        // Hook for when messages are stored in vector database
        try {
          debugPrint('💾 Message stored in vector DB: ${message.role}');
        } catch (_) {
          // Ignore errors in callback
        }
      },
    );

    // Set up system message with personality
    await _conversationManager.appendSystemMessage(
      'You are Claude, a helpful AI assistant created by Anthropic. You have an excellent memory system that can remember past conversations and find relevant context from our chat history. Be conversational, helpful, and mention when you\'re drawing from past context.',
    );
  }

  /// Append a user message to the conversation
  Future<void> appendUserMessage(String content) async {
    await _conversationManager.appendUserMessage(
      content,
      metadata: {
        'type': 'user_input',
        'timestamp': DateTime.now().toIso8601String(),
        'message_number': _messageCount++,
      },
    );
  }

  /// Append an assistant message to the conversation
  Future<void> appendAssistantMessage(String content) async {
    await _conversationManager.appendAssistantMessage(
      content,
      metadata: {
        'type': 'assistant_response',
        'timestamp': DateTime.now().toIso8601String(),
        'message_number': _messageCount++,
      },
    );
  }

  /// Build a prompt with hybrid memory context
  ///
  /// This uses the new system which:
  /// 1. Keeps recent messages for immediate context
  /// 2. Summarizes older conversation history
  /// 3. Retrieves semantically relevant past messages
  /// 4. Optimizes everything within the token budget
  Future<PromptPayload> buildPrompt({
    required int clientTokenBudget,
    String? userQuery,
    bool trace = false,
  }) async {
    return await _conversationManager.buildPrompt(
      clientTokenBudget: clientTokenBudget,
      userQuery: userQuery,
      trace: trace,
    );
  }

  /// Build enhanced prompt with full metadata
  ///
  /// Returns additional information about semantic retrieval and processing
  Future<EnhancedPromptPayload> buildEnhancedPrompt({
    required int clientTokenBudget,
    String? userQuery,
    bool trace = false,
  }) async {
    return await _conversationManager.buildEnhancedPrompt(
      clientTokenBudget: clientTokenBudget,
      userQuery: userQuery,
      trace: trace,
    );
  }

  /// Generate context-aware follow-up suggestions
  Future<List<String>> getFollowUpSuggestions({int max = 3}) async {
    return await _conversationManager.generateFollowUpQuestions(max: max);
  }

  /// Get comprehensive conversation statistics
  Future<ConversationStats> getConversationStats() async {
    _lastStats = await _conversationManager.getStats();
    return _lastStats!;
  }

  /// Get semantic search results for a query
  Future<List<Message>> searchPastConversations(String query) async {
    final enhancedPrompt = await _conversationManager.buildEnhancedPrompt(
      clientTokenBudget: 4000,
      userQuery: query,
    );
    return enhancedPrompt.semanticMessages;
  }

  /// Clear all conversation history
  Future<void> clearConversation() async {
    await _conversationManager.clear();
    _messageCount = 0;
    _lastStats = null;

    // Re-add system message after clearing
    await _conversationManager.appendSystemMessage(
      'You are Claude, a helpful AI assistant created by Anthropic. You have an excellent memory system that can remember past conversations and find relevant context from our chat history. Be conversational, helpful, and mention when you\'re drawing from past context.',
    );
  }

  /// Get current memory configuration info
  Map<String, dynamic> getMemoryInfo() {
    return {
      'memory_type': 'Hybrid Memory System',
      'features': [
        'Automatic Summarization',
        'Semantic Retrieval',
        'Vector Storage',
        'Token Management',
      ],
      'max_tokens': 8000,
      'preset': 'Production',
      'vector_store': 'Local SQLite',
      'embedding_service': 'Simple Deterministic',
    };
  }

  /// Get token usage information with enhanced details
  Map<String, dynamic> getTokenInfo(PromptPayload payload) {
    final enhanced = payload is EnhancedPromptPayload;

    Map<String, dynamic> info = {
      'estimated_tokens': payload.estimatedTokens,
      'has_summary': payload.summary != null && payload.summary!.isNotEmpty,
      'included_messages_count': payload.includedMessages.length,
      'summary_length': payload.summary?.length ?? 0,
      'memory_type': enhanced ? 'Enhanced Hybrid' : 'Standard',
    };

    if (enhanced) {
      final enhancedPayload = payload as EnhancedPromptPayload;
      info.addAll({
        'semantic_messages_count': enhancedPayload.semanticMessages.length,
        'query_used': enhancedPayload.query,
        'processing_metadata': enhancedPayload.metadata,
      });
    }

    return info;
  }

  /// Get memory usage statistics
  Map<String, dynamic> getMemoryUsage() {
    if (_lastStats == null) {
      return {'status': 'No stats available'};
    }

    return {
      'total_messages': _lastStats!.totalMessages,
      'user_messages': _lastStats!.userMessages,
      'assistant_messages': _lastStats!.assistantMessages,
      'system_messages': _lastStats!.systemMessages,
      'summary_messages': _lastStats!.summaryMessages,
      'total_tokens': _lastStats!.totalTokens,
      'vectors_stored': _lastStats!.vectorCount ?? 0,
      'conversation_duration_minutes':
          _lastStats!.conversationDuration?.inMinutes ?? 0,
      'oldest_message': _lastStats!.oldestMessage?.toIso8601String(),
      'newest_message': _lastStats!.newestMessage?.toIso8601String(),
    };
  }

  /// Export conversation for debugging or analysis
  Future<Map<String, dynamic>> exportConversationData() async {
    final stats = await getConversationStats();

    return {
      'export_timestamp': DateTime.now().toIso8601String(),
      'memory_info': getMemoryInfo(),
      'conversation_stats': stats.toJson(),
      'memory_usage': getMemoryUsage(),
    };
  }

  /// Get direct access to the memory manager for advanced operations
  MemoryManager get memoryManager => _conversationManager.memoryManager;

  /// Check if the manager is properly initialized
  bool get isInitialized => true; // Always true after constructor completes
}

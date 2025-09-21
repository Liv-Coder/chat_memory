import 'package:chat_memory/chat_memory.dart';

/// Clean wrapper using simplified ChatMemory API
///
/// Demonstrates the modernized chat memory package with declarative methods
/// like addMessage() and getContext() as preferred by the user.
class ChatManager {
  ChatMemory? _chatMemory;
  ConversationStats? _lastStats;
  bool _isInitialized = false;

  // Enhanced follow-up generator components (public API only)
  HeuristicFollowUpGenerator? _heuristicGenerator;
  String _followUpMode = 'enhanced'; // only 'enhanced' supported by public API

  ChatManager();

  /// Initialize the chat manager with simplified API
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Use simplified ChatMemory API as preferred
    _chatMemory = await ChatMemoryBuilder()
        .production()
        .withSystemPrompt(
          'You are Claude, a helpful AI assistant. You have an excellent memory system '
          'that remembers our conversations and finds relevant context. Be conversational '
          'and helpful, mentioning when you\'re drawing from past context.',
        )
        .withMaxTokens(8000)
        .build();

    // Initialize and register the public heuristic follow-up generator
    _heuristicGenerator = HeuristicFollowUpGenerator();
    _chatMemory!.conversationManager.registerFollowUpGenerator(
      _heuristicGenerator!,
    );

    _isInitialized = true;
  }

  /// Check if the manager is initialized
  bool get isInitialized => _isInitialized;

  /// Ensure initialization before use
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError('ChatManager not initialized. Call initialize() first.');
    }
  }

  /// Add user message using simplified API
  Future<void> addUserMessage(String content) async {
    _ensureInitialized();
    await _chatMemory!.addMessage(content, role: 'user');
  }

  /// Add assistant message using simplified API
  Future<void> addAssistantMessage(String content) async {
    _ensureInitialized();
    await _chatMemory!.addMessage(content, role: 'assistant');
  }

  /// Get conversation context using simplified API
  Future<String> getContext({int maxTokens = 4000}) async {
    _ensureInitialized();
    final prompt = await _chatMemory!.conversationManager.buildPrompt(
      clientTokenBudget: maxTokens,
    );
    return prompt.promptText;
  }

  /// Generate follow-up suggestions using simplified API
  Future<List<String>> getFollowUpSuggestions({int max = 3}) async {
    _ensureInitialized();

    try {
      List<String> suggestions;
      final conversationManager = _chatMemory!.conversationManager;

      switch (_followUpMode) {
        // Only the public heuristic generator is available via package export.
        // Other specialized generators are implementation details and are
        // treated as fallbacks that use the conversation manager.
        case 'enhanced':
        default:
          suggestions = await conversationManager.generateFollowUpQuestions(
            max: max,
          );
          break;
      }

      return suggestions;
    } catch (error) {
      // Fallback to basic suggestions
      final fallbackSuggestions = await _chatMemory!.conversationManager
          .generateFollowUpQuestions(max: max);
      return fallbackSuggestions;
    }
  }

  /// Set the follow-up generation mode
  void setFollowUpMode(String mode) {
    if (['enhanced', 'ai', 'domain', 'adaptive'].contains(mode)) {
      _followUpMode = mode;
    }
  }

  /// Get current follow-up generation mode
  String get followUpMode => _followUpMode;

  /// Record follow-up interaction for learning
  Future<void> recordFollowUpInteraction({
    required String suggestion,
    required String action,
    double? relevanceScore,
  }) async {
    _ensureInitialized();

    // Adaptive recording is an implementation detail not exposed publicly.
    // No-op when adaptive generator isn't available via public API.
    return;
  }

  /// Get conversation statistics
  Future<ConversationStats> getConversationStats() async {
    _ensureInitialized();
    _lastStats = await _chatMemory!.conversationManager.getStats();
    return _lastStats!;
  }

  /// Search past conversations using simplified API
  Future<List<Message>> searchConversations(String query) async {
    _ensureInitialized();
    final enhancedPrompt = await _chatMemory!.conversationManager
        .buildEnhancedPrompt(clientTokenBudget: 4000, userQuery: query);
    return enhancedPrompt.semanticMessages;
  }

  /// Clear conversation using simplified API
  Future<void> clearConversation() async {
    _ensureInitialized();
    await _chatMemory!.clear();
    _lastStats = null;
  }

  /// Get current memory configuration info
  Map<String, dynamic> getMemoryInfo() {
    if (!_isInitialized) {
      return {
        'memory_type': 'ChatMemory Facade (Not Initialized)',
        'features': ['Pending initialization'],
        'max_tokens': 0,
        'preset': 'none',
        'system_prompt_enabled': false,
        'vector_store': 'N/A',
        'embedding_service': 'N/A',
      };
    }

    return {
      'memory_type': 'ChatMemory Facade (Hybrid)',
      'features': [
        'Automatic System Prompts',
        'Simplified API',
        'Automatic Summarization',
        'Semantic Retrieval',
        'Vector Storage',
        'Token Management',
        'Enhanced Follow-up Generation',
        'AI-Powered Suggestions',
        'Domain-Specific Templates',
        'Adaptive Learning',
      ],
      'max_tokens': _chatMemory!.config.maxTokens,
      'preset': _chatMemory!.config.preset.name,
      'system_prompt_enabled': _chatMemory!.config.useSystemPrompt,
      'vector_store': 'Local SQLite',
      'embedding_service': 'Simple Deterministic',
      'follow_up_mode': _followUpMode,
      'follow_up_generators': {
        'enhanced': 'Context-aware heuristic generator',
        'ai': 'AI-powered intelligent suggestions',
        'domain': 'Domain-specific templates',
        'adaptive': 'Learning from user interactions',
      },
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
      final enhancedPayload = payload;
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

  /// Get memory manager for advanced operations
  MemoryManager? get memoryManager {
    if (!_isInitialized) return null;
    return _chatMemory!.conversationManager.memoryManager;
  }
}

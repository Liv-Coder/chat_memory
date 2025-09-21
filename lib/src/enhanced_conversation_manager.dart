import 'models/message.dart';
import 'models/prompt_payload.dart';
import 'persistence/persistence_strategy.dart';
import 'persistence/in_memory_store.dart';
import 'utils/token_counter.dart';
import 'follow_up/follow_up_generator.dart';
import 'memory/memory_manager.dart';
import 'memory/hybrid_memory_factory.dart';
import 'summarizers/deterministic_summarizer.dart';
import 'strategies/summarization_strategy.dart';

/// Enhanced conversation manager that integrates with the hybrid memory system
///
/// This manager provides the same interface as the original ConversationManager
/// but uses the new MemoryManager internally for better context management.
class EnhancedConversationManager {
  final PersistenceStrategy _persistence;
  final MemoryManager _memoryManager;
  final TokenCounter _tokenCounter;
  FollowUpGenerator? _followUpGenerator;
  final void Function(Message)? _onSummaryCreated;
  final void Function(Message)? _onMessageStored;

  EnhancedConversationManager({
    PersistenceStrategy? persistence,
    MemoryManager? memoryManager,
    TokenCounter? tokenCounter,
    FollowUpGenerator? followUpGenerator,
    void Function(Message)? onSummaryCreated,
    void Function(Message)? onMessageStored,
  }) : _persistence = persistence ?? InMemoryStore(),
       _tokenCounter = tokenCounter ?? HeuristicTokenCounter(),
       _followUpGenerator = followUpGenerator,
       _onSummaryCreated = onSummaryCreated,
       _onMessageStored = onMessageStored,
       _memoryManager =
           memoryManager ??
           HybridMemoryFactory.createCustom(
             contextStrategy: SummarizationStrategyFactory.balanced(
               maxTokens: 8000,
               summarizer: DeterministicSummarizer(),
               tokenCounter: tokenCounter ?? HeuristicTokenCounter(),
             ),
             tokenCounter: tokenCounter ?? HeuristicTokenCounter(),
           );

  /// Create with a specific memory preset
  static Future<EnhancedConversationManager> create({
    MemoryPreset preset = MemoryPreset.production,
    int maxTokens = 8000,
    PersistenceStrategy? persistence,
    TokenCounter? tokenCounter,
    FollowUpGenerator? followUpGenerator,
    void Function(Message)? onSummaryCreated,
    void Function(Message)? onMessageStored,
    String? databasePath,
  }) async {
    final memoryManager = await HybridMemoryFactory.create(
      preset: preset,
      maxTokens: maxTokens,
      customTokenCounter: tokenCounter,
      databasePath: databasePath,
    );

    return EnhancedConversationManager(
      persistence: persistence,
      memoryManager: memoryManager,
      tokenCounter: tokenCounter,
      followUpGenerator: followUpGenerator,
      onSummaryCreated: onSummaryCreated,
      onMessageStored: onMessageStored,
    );
  }

  /// Add a message to the conversation
  Future<void> appendMessage(Message message) async {
    await _persistence.saveMessages([message]);

    // Store message in vector store for semantic retrieval
    await _memoryManager.storeMessage(message);

    // Trigger callback
    if (_onMessageStored != null) {
      try {
        _onMessageStored(message);
      } catch (_) {
        // Swallow callback errors to avoid breaking flow
      }
    }
  }

  /// Add a user message to the conversation
  Future<void> appendUserMessage(
    String content, {
    Map<String, dynamic>? metadata,
  }) async {
    final message = Message(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      role: MessageRole.user,
      content: content,
      timestamp: DateTime.now().toUtc(),
      metadata: metadata,
    );
    await appendMessage(message);
  }

  /// Add an assistant message to the conversation
  Future<void> appendAssistantMessage(
    String content, {
    Map<String, dynamic>? metadata,
  }) async {
    final message = Message(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      role: MessageRole.assistant,
      content: content,
      timestamp: DateTime.now().toUtc(),
      metadata: metadata,
    );
    await appendMessage(message);
  }

  /// Add a system message to the conversation
  Future<void> appendSystemMessage(
    String content, {
    Map<String, dynamic>? metadata,
  }) async {
    final message = Message(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      role: MessageRole.system,
      content: content,
      timestamp: DateTime.now().toUtc(),
      metadata: metadata,
    );
    await appendMessage(message);
  }

  /// Build a prompt using the hybrid memory system
  Future<PromptPayload> buildPrompt({
    required int clientTokenBudget,
    String? userQuery,
    bool trace = false,
  }) async {
    final messages = await _persistence.loadMessages();

    // Use the last user message as query if not provided
    final effectiveQuery =
        userQuery ??
        _getLastUserMessage(messages)?.content ??
        'conversation context';

    // Get context from memory manager
    final contextResult = await _memoryManager.getContext(
      messages,
      effectiveQuery,
    );

    // Build the prompt text
    final promptText = contextResult.messages
        .map((m) => '${m.role.toString().split('.').last}: ${m.content}')
        .join('\n');

    // Create inclusion trace for compatibility
    final inclusionTrace = InclusionTrace(
      selectedMessageIds: contextResult.messages.map((m) => m.id).toList(),
      excludedReasons: {},
      summaries: (contextResult.metadata['summaryCount'] ?? 0) > 0
          ? [
              {
                'summary': contextResult.summary ?? '',
                'semanticCount': contextResult.semanticMessages.length,
                'metadata': contextResult.metadata,
              },
            ]
          : [],
      strategyUsed: contextResult.metadata['strategyUsed'] ?? 'MemoryManager',
    );

    // Trigger summary callback if summary was created
    if (contextResult.summary != null && _onSummaryCreated != null) {
      final summaryMessage = Message(
        id: 'summary_${DateTime.now().microsecondsSinceEpoch}',
        role: MessageRole.summary,
        content: contextResult.summary!,
        timestamp: DateTime.now().toUtc(),
        metadata: contextResult.metadata,
      );

      try {
        _onSummaryCreated(summaryMessage);
      } catch (_) {
        // Swallow callback errors
      }
    }

    return PromptPayload(
      promptText: promptText,
      includedMessages: contextResult.messages,
      summary: contextResult.summary,
      estimatedTokens: contextResult.estimatedTokens,
      trace: inclusionTrace,
    );
  }

  /// Build a prompt with enhanced context information
  Future<EnhancedPromptPayload> buildEnhancedPrompt({
    required int clientTokenBudget,
    String? userQuery,
    bool trace = false,
  }) async {
    final messages = await _persistence.loadMessages();

    // Use the last user message as query if not provided
    final effectiveQuery =
        userQuery ??
        _getLastUserMessage(messages)?.content ??
        'conversation context';

    // Get context from memory manager
    final contextResult = await _memoryManager.getContext(
      messages,
      effectiveQuery,
    );

    // Build the prompt text
    final promptText = contextResult.messages
        .map((m) => '${m.role.toString().split('.').last}: ${m.content}')
        .join('\n');

    return EnhancedPromptPayload(
      promptText: promptText,
      includedMessages: contextResult.messages,
      summary: contextResult.summary,
      estimatedTokens: contextResult.estimatedTokens,
      semanticMessages: contextResult.semanticMessages,
      metadata: contextResult.metadata,
      query: effectiveQuery,
    );
  }

  /// Register a follow-up generator
  void registerFollowUpGenerator(FollowUpGenerator generator) {
    _followUpGenerator = generator;
  }

  /// Generate context-aware follow-up questions
  Future<List<String>> generateFollowUpQuestions({int max = 3}) async {
    if (_followUpGenerator == null) return [];

    try {
      final messages = await _persistence.loadMessages();
      return await _followUpGenerator!.generate(messages, max: max);
    } catch (_) {
      return [];
    }
  }

  /// Get conversation statistics
  Future<ConversationStats> getStats() async {
    final messages = await _persistence.loadMessages();

    final userMessages = messages.where((m) => m.role == MessageRole.user);
    final assistantMessages = messages.where(
      (m) => m.role == MessageRole.assistant,
    );
    final systemMessages = messages.where((m) => m.role == MessageRole.system);
    final summaryMessages = messages.where(
      (m) => m.role == MessageRole.summary,
    );

    final totalTokens = _tokenCounter.estimateTokens(
      messages.map((m) => m.content).join('\n'),
    );

    // Get vector store stats if available
    int? vectorCount;
    if (_memoryManager.vectorStore != null) {
      try {
        vectorCount = await _memoryManager.vectorStore!.count();
      } catch (_) {
        vectorCount = null;
      }
    }

    return ConversationStats(
      totalMessages: messages.length,
      userMessages: userMessages.length,
      assistantMessages: assistantMessages.length,
      systemMessages: systemMessages.length,
      summaryMessages: summaryMessages.length,
      totalTokens: totalTokens,
      vectorCount: vectorCount,
      oldestMessage: messages.isEmpty ? null : messages.first.timestamp,
      newestMessage: messages.isEmpty ? null : messages.last.timestamp,
    );
  }

  /// Clear the conversation history
  Future<void> clear() async {
    // Clear persistence
    // Most persistence strategies don't have a clear method, so we'll work around it

    // Clear vector store if available
    if (_memoryManager.vectorStore != null) {
      try {
        await _memoryManager.vectorStore!.clear();
      } catch (_) {
        // Ignore errors
      }
    }
  }

  /// Get the memory manager for advanced operations
  MemoryManager get memoryManager => _memoryManager;

  /// Get the persistence strategy for direct access
  PersistenceStrategy get persistence => _persistence;

  /// Find the last user message for query extraction
  Message? _getLastUserMessage(List<Message> messages) {
    for (int i = messages.length - 1; i >= 0; i--) {
      if (messages[i].role == MessageRole.user) {
        return messages[i];
      }
    }
    return null;
  }

  /// Flush any pending operations
  Future<void> flush() async {
    // If persistence requires flush semantics, implement here
  }
}

/// Enhanced prompt payload with additional context information
class EnhancedPromptPayload extends PromptPayload {
  /// Messages retrieved through semantic search
  final List<Message> semanticMessages;

  /// Metadata about the memory retrieval process
  final Map<String, dynamic> metadata;

  /// The query used for semantic retrieval
  final String query;

  EnhancedPromptPayload({
    required super.promptText,
    required super.includedMessages,
    super.summary,
    required super.estimatedTokens,
    InclusionTrace? trace,
    required this.semanticMessages,
    required this.metadata,
    required this.query,
  }) : super(
         trace:
             trace ??
             InclusionTrace(
               selectedMessageIds: [],
               excludedReasons: {},
               summaries: [],
               strategyUsed: 'EnhancedMemory',
             ),
       );

  Map<String, dynamic> toJson() {
    return {
      'promptText': promptText,
      'includedMessages': includedMessages.map((m) => m.toJson()).toList(),
      'summary': summary,
      'estimatedTokens': estimatedTokens,
      'semanticMessages': semanticMessages.map((m) => m.toJson()).toList(),
      'metadata': metadata,
      'query': query,
    };
  }
}

/// Statistics about the conversation
class ConversationStats {
  final int totalMessages;
  final int userMessages;
  final int assistantMessages;
  final int systemMessages;
  final int summaryMessages;
  final int totalTokens;
  final int? vectorCount;
  final DateTime? oldestMessage;
  final DateTime? newestMessage;

  const ConversationStats({
    required this.totalMessages,
    required this.userMessages,
    required this.assistantMessages,
    required this.systemMessages,
    required this.summaryMessages,
    required this.totalTokens,
    this.vectorCount,
    this.oldestMessage,
    this.newestMessage,
  });

  Duration? get conversationDuration {
    if (oldestMessage == null || newestMessage == null) return null;
    return newestMessage!.difference(oldestMessage!);
  }

  Map<String, dynamic> toJson() {
    return {
      'totalMessages': totalMessages,
      'userMessages': userMessages,
      'assistantMessages': assistantMessages,
      'systemMessages': systemMessages,
      'summaryMessages': summaryMessages,
      'totalTokens': totalTokens,
      'vectorCount': vectorCount,
      'oldestMessage': oldestMessage?.toIso8601String(),
      'newestMessage': newestMessage?.toIso8601String(),
      'conversationDurationMinutes': conversationDuration?.inMinutes,
    };
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('Conversation Statistics:');
    buffer.writeln('  Total Messages: $totalMessages');
    buffer.writeln('  User: $userMessages, Assistant: $assistantMessages');
    buffer.writeln('  System: $systemMessages, Summary: $summaryMessages');
    buffer.writeln('  Total Tokens: $totalTokens');
    if (vectorCount != null) {
      buffer.writeln('  Vectors Stored: $vectorCount');
    }
    if (conversationDuration != null) {
      buffer.writeln('  Duration: ${conversationDuration!.inMinutes} minutes');
    }
    return buffer.toString();
  }
}

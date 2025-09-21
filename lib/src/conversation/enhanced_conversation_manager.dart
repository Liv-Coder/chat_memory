import '../core/models/message.dart';
import '../core/models/prompt_payload.dart';
import '../core/persistence/persistence_strategy.dart';
import '../core/persistence/in_memory_store.dart';
import '../core/utils/token_counter.dart';
import 'follow_up/follow_up_generator.dart';
import '../memory/memory_manager.dart';
import '../memory/hybrid_memory_factory.dart';
import '../memory/summarizers/deterministic_summarizer.dart';
import '../memory/strategies/summarization_strategy.dart';
import 'callbacks/callback_manager.dart';
import 'analytics/conversation_analytics.dart';
import '../core/utils/message_operations.dart';

import '../core/logging/chat_memory_logger.dart';
import 'package:logging/logging.dart';

/// Enhanced conversation manager that integrates with the hybrid memory system
///
/// This manager provides the same interface as the original ConversationManager
/// but uses the new MemoryManager internally for better context management.
/// It delegates specialized operations to focused components for improved
/// maintainability and testability.
class EnhancedConversationManager {
  final PersistenceStrategy _persistence;
  final MemoryManager _memoryManager;
  FollowUpGenerator? _followUpGenerator;

  // Specialized components
  final CallbackManager _callbackManager;
  final ConversationAnalytics _analytics;

  // Logger for manager-level events and errors
  final Logger _logger = ChatMemoryLogger.loggerFor(
    'enhanced_conversation_manager',
  );

  EnhancedConversationManager({
    PersistenceStrategy? persistence,
    MemoryManager? memoryManager,
    TokenCounter? tokenCounter,
    FollowUpGenerator? followUpGenerator,
    void Function(Message)? onSummaryCreated,
    void Function(Message)? onMessageStored,
  }) : _persistence = persistence ?? InMemoryStore(),
       _followUpGenerator = followUpGenerator,
       _callbackManager = CallbackManager(
         onMessageStored: onMessageStored,
         onSummaryCreated: onSummaryCreated,
       ),
       _analytics = ConversationAnalytics(
         tokenCounter: tokenCounter ?? HeuristicTokenCounter(),
       ),
       // If a MemoryManager wasn't provided, construct a safe default without
       // semantic memory enabled to avoid requiring vector stores at construction time.
       _memoryManager =
           memoryManager ??
           MemoryManager(
             contextStrategy: SummarizationStrategyFactory.balanced(
               maxTokens: 8000,
               summarizer: DeterministicSummarizer(),
               tokenCounter: tokenCounter ?? HeuristicTokenCounter(),
             ),
             tokenCounter: tokenCounter ?? HeuristicTokenCounter(),
             config: MemoryConfig(
               maxTokens: 8000,
               enableSemanticMemory: false,
               enableSummarization: true,
             ),
             vectorStore: null,
             embeddingService: null,
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
    try {
      await _memoryManager.storeMessage(message);
    } catch (e, st) {
      ChatMemoryLogger.logError<void>(
        _logger,
        'appendMessage.memoryStore',
        e,
        stackTrace: st,
        params: {'messageId': message.id},
      );
      // continue; do not fail the append operation
    }

    // Trigger callback via CallbackManager
    await _callbackManager.executeMessageStoredCallback(message);
  }

  /// Add a user message to the conversation
  Future<void> appendUserMessage(
    String content, {
    Map<String, dynamic>? metadata,
  }) async {
    final message = MessageOperations.createUserMessage(
      content: content,
      metadata: metadata,
    );
    await appendMessage(message);
  }

  /// Add an assistant message to the conversation
  Future<void> appendAssistantMessage(
    String content, {
    Map<String, dynamic>? metadata,
  }) async {
    final message = MessageOperations.createAssistantMessage(
      content: content,
      metadata: metadata,
    );
    await appendMessage(message);
  }

  /// Add a system message to the conversation
  Future<void> appendSystemMessage(
    String content, {
    Map<String, dynamic>? metadata,
  }) async {
    final message = MessageOperations.createSystemMessage(
      content: content,
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

    // Trigger summary callback via CallbackManager if summary was created
    if (contextResult.summary != null) {
      final summaryMessage = Message(
        id: 'summary_${DateTime.now().microsecondsSinceEpoch}',
        role: MessageRole.summary,
        content: contextResult.summary!,
        timestamp: DateTime.now().toUtc(),
        metadata: contextResult.metadata,
      );
      await _callbackManager.executeSummaryCreatedCallback(summaryMessage);
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
    } catch (e, st) {
      ChatMemoryLogger.logError<void>(
        _logger,
        'generateFollowUpQuestions',
        e,
        stackTrace: st,
        params: {'max': max},
      );
      return [];
    }
  }

  /// Get conversation statistics via ConversationAnalytics
  Future<ConversationStats> getStats() async {
    final messages = await _persistence.loadMessages();
    return _analytics.calculateStats(
      messages: messages,
      memoryManager: _memoryManager,
    );
  }

  /// Clear the conversation history
  Future<void> clear() async {
    // Clear persistence
    // Most persistence strategies don't have a clear method, so we'll work around it

    // Clear vector store if available
    final vs2 = _memoryManager.vectorStore;
    if (vs2 != null) {
      try {
        await vs2.clear();
      } catch (e, st) {
        ChatMemoryLogger.logError<void>(
          _logger,
          'clear.vectorStore',
          e,
          stackTrace: st,
        );
      }
    }
  }

  /// Get the memory manager for advanced operations
  MemoryManager get memoryManager => _memoryManager;

  /// Get the persistence strategy for direct access
  PersistenceStrategy get persistence => _persistence;

  /// Find the last user message for query extraction
  Message? _getLastUserMessage(List<Message> messages) {
    return MessageOperations.getLastUserMessage(messages);
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

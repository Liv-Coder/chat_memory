import 'dart:async';

import 'package:logging/logging.dart';

import '../models/message.dart';
import '../utils/token_counter.dart';
import '../strategies/context_strategy.dart';
import '../vector_stores/vector_store.dart';
import '../embeddings/embedding_service.dart';
import '../errors.dart';
import '../logging/chat_memory_logger.dart';
import 'session_store.dart';
import 'memory_summarizer.dart';
import 'semantic_retriever.dart';

/// Configuration for the MemoryManager
class MemoryConfig {
  /// Maximum tokens allowed in the final context
  final int maxTokens;

  /// Number of semantically similar messages to retrieve
  final int semanticTopK;

  /// Minimum similarity score for semantic retrieval
  final double minSimilarity;

  /// Whether to enable semantic memory layer
  final bool enableSemanticMemory;

  /// Whether to enable summarization layer
  final bool enableSummarization;

  /// Weight for combining token-based recency and semantic similarity
  final double recencyWeight;

  const MemoryConfig({
    this.maxTokens = 8000,
    this.semanticTopK = 5,
    this.minSimilarity = 0.3,
    this.enableSemanticMemory = true,
    this.enableSummarization = true,
    this.recencyWeight = 0.3,
  });
}

/// Result from memory context retrieval
class MemoryContextResult {
  /// Final messages to include in the prompt
  final List<Message> messages;

  /// Estimated total tokens
  final int estimatedTokens;

  /// Summary of excluded content (if any)
  final String? summary;

  /// Semantically retrieved messages
  final List<Message> semanticMessages;

  /// Metadata about the memory retrieval process
  final Map<String, dynamic> metadata;

  const MemoryContextResult({
    required this.messages,
    required this.estimatedTokens,
    this.summary,
    required this.semanticMessages,
    required this.metadata,
  });
}

/// Lightweight facade that orchestrates specialized memory components
///
/// This refactored MemoryManager delegates operations to focused components:
/// - SessionStore: Message persistence and vector storage
/// - MemorySummarizer: Summarization logic and strategy application
/// - SemanticRetriever: Vector search and semantic retrieval
/// - MemoryCleaner: Cleanup operations and memory optimization
class MemoryManager {
  final MemoryConfig config;
  final ContextStrategy contextStrategy;
  final TokenCounter tokenCounter;
  final VectorStore? vectorStore;
  final EmbeddingService? embeddingService;

  // Specialized components
  final SessionStore _sessionStore;
  final MemorySummarizer _memorySummarizer;
  final SemanticRetriever _semanticRetriever;

  final Logger _logger = ChatMemoryLogger.loggerFor('memory_manager');

  MemoryManager({
    required this.contextStrategy,
    required this.tokenCounter,
    this.config = const MemoryConfig(),
    this.vectorStore,
    this.embeddingService,
  }) : _sessionStore = SessionStore(
         vectorStore: vectorStore,
         embeddingService: embeddingService,
         config: config,
       ),
       _memorySummarizer = MemorySummarizer(
         contextStrategy: contextStrategy,
         tokenCounter: tokenCounter,
         config: config,
       ),
       _semanticRetriever = SemanticRetriever(
         vectorStore: vectorStore,
         embeddingService: embeddingService,
         config: config,
       ) {
    // Validate configuration early and fail fast with descriptive errors.
    final ctx = ErrorContext(
      component: 'MemoryManager',
      operation: 'constructor',
      params: {
        'maxTokens': config.maxTokens,
        'semanticTopK': config.semanticTopK,
        'minSimilarity': config.minSimilarity,
        'recencyWeight': config.recencyWeight,
      },
    );

    try {
      Validation.validatePositive('maxTokens', config.maxTokens, context: ctx);
      Validation.validateNonNegative(
        'semanticTopK',
        config.semanticTopK,
        context: ctx,
      );
      Validation.validateRange(
        'minSimilarity',
        config.minSimilarity,
        min: 0.0,
        max: 1.0,
        context: ctx,
      );
      Validation.validateRange(
        'recencyWeight',
        config.recencyWeight,
        min: 0.0,
        max: 1.0,
        context: ctx,
      );
    } catch (e, st) {
      ChatMemoryLogger.logError<void>(
        _logger,
        'constructor.validation',
        e,
        stackTrace: st,
        params: ctx.toMap(),
        shouldRethrow: true,
      );
    }

    _logger.fine('MemoryManager initialized with config=${config.toString()}');
  }

  /// Main entry point: Get context from messages and user query
  ///
  /// This implements the hybrid memory flow using specialized components:
  /// 1. Pre-checks for token compliance
  /// 2. Apply summarization strategy via MemorySummarizer
  /// 3. Perform semantic retrieval via SemanticRetriever
  /// 4. Construct final prompt with all memory layers
  Future<MemoryContextResult> getContext(
    List<Message> messages,
    String userQuery,
  ) async {
    final correlationId = DateTime.now().microsecondsSinceEpoch.toString();
    final opParams = {
      'correlationId': correlationId,
      'messageCount': messages.length,
    };
    final sw = ChatMemoryLogger.logOperationStart(
      _logger,
      'getContext',
      params: opParams,
    );

    try {
      // Step 1: Pre-checks
      final preCheckResult = await _performPreChecks(messages);
      if (preCheckResult != null) {
        ChatMemoryLogger.logOperationEnd(
          _logger,
          'getContext',
          sw,
          result: {
            'path': 'preCheck',
            'finalCount': preCheckResult.messages.length,
          },
        );
        return preCheckResult;
      }

      // Step 2: Apply summarization strategy via MemorySummarizer
      final strategyResult = await _memorySummarizer.applySummarization(
        messages: messages,
        tokenBudget: config.maxTokens,
      );

      // Step 3: Semantic retrieval via SemanticRetriever
      final semanticMessages = await _semanticRetriever
          .retrieveSemanticMessages(query: userQuery, recentMessages: messages);

      // Step 4: Construct final prompt
      final finalMessages = await _constructFinalPrompt(
        strategyResult,
        semanticMessages,
        messages,
      );

      // Calculate final token estimate
      final finalTokens = _calculateTokens(finalMessages);

      // Create metadata
      final metadata = {
        'processingTimeMs': DateTime.now()
            .difference(
              DateTime.fromMillisecondsSinceEpoch(
                int.parse(correlationId) ~/ 1000,
              ),
            )
            .inMilliseconds,
        'originalMessageCount': messages.length,
        'finalMessageCount': finalMessages.length,
        'summarizedMessageCount': strategyResult.excluded.length,
        'semanticRetrievalCount': semanticMessages.length,
        'strategyUsed': strategyResult.name,
        'summaryCount': strategyResult.summaries.length,
        'correlationId': correlationId,
      };

      ChatMemoryLogger.logOperationEnd(
        _logger,
        'getContext',
        sw,
        result: {
          'finalMessages': finalMessages.length,
          'estimatedTokens': finalTokens,
        },
      );
      return MemoryContextResult(
        messages: finalMessages,
        estimatedTokens: finalTokens,
        summary: strategyResult.summaries.isNotEmpty
            ? strategyResult.summaries.map((s) => s.summary).join('\n\n')
            : null,
        semanticMessages: semanticMessages,
        metadata: metadata,
      );
    } catch (e, st) {
      ChatMemoryLogger.logError<void>(
        _logger,
        'getContext',
        e,
        stackTrace: st,
        params: opParams,
      );
      // In the rare event of a top-level failure, return a minimal safe result instead of throwing.
      final fallback = MemoryContextResult(
        messages: messages.take(1).toList(),
        estimatedTokens: _calculateTokens(messages.take(1).toList()),
        semanticMessages: [],
        metadata: {'error': e.toString(), 'correlationId': correlationId},
      );
      ChatMemoryLogger.logOperationEnd(
        _logger,
        'getContext',
        sw,
        result: {'path': 'fallback', 'finalMessages': fallback.messages.length},
      );
      return fallback;
    }
  }

  /// Store a message via SessionStore
  Future<void> storeMessage(Message message) async {
    await _sessionStore.storeMessage(message);
  }

  /// Store multiple messages via SessionStore
  Future<void> storeMessageBatch(List<Message> messages) async {
    await _sessionStore.storeMessageBatch(messages);
  }

  /// Step 1: Pre-checks - return early if within token budget
  Future<MemoryContextResult?> _performPreChecks(List<Message> messages) async {
    if (messages.isEmpty) {
      return MemoryContextResult(
        messages: [],
        estimatedTokens: 0,
        semanticMessages: [],
        metadata: {'preCheck': 'empty'},
      );
    }

    final totalTokens = _calculateTokens(messages);

    if (totalTokens <= config.maxTokens) {
      // Within budget, return messages untouched
      return MemoryContextResult(
        messages: messages,
        estimatedTokens: totalTokens,
        semanticMessages: [],
        metadata: {'preCheck': 'withinBudget', 'originalTokens': totalTokens},
      );
    }

    return null; // Continue with full processing
  }

  /// Step 4: Construct final prompt combining all memory layers
  Future<List<Message>> _constructFinalPrompt(
    StrategyResult strategyResult,
    List<Message> semanticMessages,
    List<Message> originalMessages,
  ) async {
    final finalMessages = <Message>[];

    // Get system message if it exists
    final systemMessage = originalMessages
        .where((m) => m.role == MessageRole.system)
        .firstOrNull;

    // Add system message first
    if (systemMessage != null) {
      finalMessages.add(systemMessage);
    }

    // Add existing summary messages from strategy result
    final summaryMessages = strategyResult.summaries
        .map(
          (s) => Message(
            id: s.chunkId,
            role: MessageRole.summary,
            content: s.summary,
            timestamp: DateTime.now().toUtc(),
            metadata: {
              'tokensBefore': s.tokenEstimateBefore,
              'tokensAfter': s.tokenEstimateAfter,
              'type': 'generated_summary',
            },
          ),
        )
        .toList();
    finalMessages.addAll(summaryMessages);

    // Add semantically retrieved messages as summary-type messages
    final semanticSummaryMessages = semanticMessages
        .map(
          (m) => Message(
            id: '${m.id}_semantic',
            role: MessageRole.summary,
            content: 'Fact: ${m.content}',
            timestamp: m.timestamp,
            metadata: {...?m.metadata, 'type': 'semantic_retrieval'},
          ),
        )
        .toList();
    finalMessages.addAll(semanticSummaryMessages);

    // Add recent messages from strategy
    finalMessages.addAll(strategyResult.included);

    return finalMessages;
  }

  /// Calculate total tokens for a list of messages
  int _calculateTokens(List<Message> messages) {
    final text = messages.map((m) => m.content).join('\n');
    return tokenCounter.estimateTokens(text);
  }
}

/// Extension to add firstOrNull functionality
extension on Iterable<Message> {
  Message? get firstOrNull => isEmpty ? null : first;
}

import 'dart:async';

import 'package:logging/logging.dart';

import '../models/message.dart';
import '../utils/token_counter.dart';
import '../strategies/context_strategy.dart';
import '../vector_stores/vector_store.dart';
import '../embeddings/embedding_service.dart';
import '../errors.dart';
import '../logging/chat_memory_logger.dart';

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

/// Main orchestrator for hybrid memory management
///
/// Implements the enhanced summarization flow with:
/// 1. Pre-checks for token budget compliance
/// 2. Summarization layer (compression memory)
/// 3. Embedding layer (semantic memory)
/// 4. Final prompt construction
class MemoryManager {
  final MemoryConfig config;
  final ContextStrategy contextStrategy;
  final TokenCounter tokenCounter;
  final VectorStore? vectorStore;
  final EmbeddingService? embeddingService;

  final Logger _logger = ChatMemoryLogger.loggerFor('memory_manager');

  // Simple circuit-breaker counters for semantic failures (per instance).
  int _semanticFailureCount = 0;
  DateTime? _lastSemanticFailure;

  MemoryManager({
    required this.contextStrategy,
    required this.tokenCounter,
    this.config = const MemoryConfig(),
    this.vectorStore,
    this.embeddingService,
  }) {
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
  /// This implements the hybrid memory flow described in the design:
  /// 1. Pre-checks for token compliance
  /// 2. Apply summarization strategy if needed
  /// 3. Perform semantic retrieval if enabled
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

      // Step 2: Apply context strategy (summarization layer)
      final strategyResult = await contextStrategy.apply(
        messages: messages,
        tokenBudget: config.maxTokens,
        tokenCounter: tokenCounter,
      );

      // Step 3: Semantic retrieval (if enabled)
      final semanticMessages = config.enableSemanticMemory
          ? await _performSemanticRetrieval(
              userQuery,
              messages,
              correlationId: correlationId,
            )
          : <Message>[];

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

  /// Store a message in the vector store for semantic retrieval
  Future<void> storeMessage(Message message) async {
    if (!config.enableSemanticMemory ||
        vectorStore == null ||
        embeddingService == null) {
      return;
    }

    // Skip system and summary messages from semantic storage
    if (message.role == MessageRole.system ||
        message.role == MessageRole.summary) {
      return;
    }

    final opCtx = ErrorContext(
      component: 'MemoryManager',
      operation: 'storeMessage',
      params: {'messageId': message.id},
    );
    final logger = _logger;
    const maxRetries = 2;
    int attempt = 0;
    while (true) {
      attempt++;
      try {
        final embedding = await embeddingService!.embed(message.content);
        Validation.validateEmbeddingVector(
          'embedding',
          embedding,
          context: opCtx,
        );
        final vectorEntry = message.toVectorEntry(embedding);
        await vectorStore!.store(vectorEntry);
        logger.fine('Stored message=${message.id} in vector store');
        return;
      } catch (e, st) {
        // If embedding specifically failed, log and disable semantic for this operation
        if (e is EmbeddingException) {
          ChatMemoryLogger.logError<void>(
            logger,
            'storeMessage.embed',
            e,
            stackTrace: st,
            params: opCtx.toMap(),
          );
          return;
        }

        // On other errors, retry a small number of times for transient issues.
        ChatMemoryLogger.logError<void>(
          logger,
          'storeMessage.attempt',
          e,
          stackTrace: st,
          params: {'attempt': attempt, ...opCtx.toMap()},
        );
        if (attempt > maxRetries) {
          // escalate as VectorStoreException after retries
          final vsEx = VectorStoreException.storageFailure(
            'Failed to store message ${message.id} after $attempt attempts',
            cause: e,
            stackTrace: st,
            context: opCtx,
          );
          ChatMemoryLogger.logError<void>(
            logger,
            'storeMessage.failure',
            vsEx,
            stackTrace: st,
            params: opCtx.toMap(),
            shouldRethrow: false,
          );
          // Throw to allow upstream to decide if this is fatal.
          throw vsEx;
        }
        // small backoff
        await Future.delayed(Duration(milliseconds: 100 * attempt));
      }
    }
  }

  /// Store multiple messages in batch
  Future<void> storeMessageBatch(List<Message> messages) async {
    if (!config.enableSemanticMemory ||
        vectorStore == null ||
        embeddingService == null) {
      return;
    }

    final toStore = messages
        .where(
          (m) => m.role != MessageRole.system && m.role != MessageRole.summary,
        )
        .toList();
    if (toStore.isEmpty) return;

    final opCtx = ErrorContext(
      component: 'MemoryManager',
      operation: 'storeMessageBatch',
      params: {'count': toStore.length},
    );
    final logger = _logger;

    try {
      // Validate inputs
      Validation.validateListNotEmpty('messages', toStore, context: opCtx);

      // Get embeddings for all messages (with basic retry for embedding service)
      final texts = toStore.map((m) => m.content).toList();
      List<List<double>> embeddings;
      try {
        embeddings = await embeddingService!.embedBatch(texts);
      } catch (e, st) {
        ChatMemoryLogger.logError<void>(
          logger,
          'storeMessageBatch.embedBatch',
          e,
          stackTrace: st,
          params: opCtx.toMap(),
        );
        // Fail fast for embedding failures since we cannot create vector entries
        // Use the embedding service's EmbeddingException signature (message, [cause])
        throw EmbeddingException('Batch embedding failed', e);
      }

      // Create vector entries
      final vectorEntries = <VectorEntry>[];
      for (int i = 0; i < toStore.length; i++) {
        Validation.validateEmbeddingVector(
          'embedding[$i]',
          embeddings[i],
          context: opCtx,
        );
        vectorEntries.add(toStore[i].toVectorEntry(embeddings[i]));
      }

      await vectorStore!.storeBatch(vectorEntries);
      logger.fine(
        'Stored batch of ${vectorEntries.length} entries in vector store',
      );
    } catch (e, st) {
      // Log and rethrow a VectorStoreException to make failure explicit to callers.
      ChatMemoryLogger.logError<void>(
        logger,
        'storeMessageBatch',
        e,
        stackTrace: st,
        params: opCtx.toMap(),
      );
      throw VectorStoreException.storageFailure(
        'Batch storage failed',
        cause: e,
        stackTrace: st,
        context: opCtx,
      );
    }
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

  /// Step 3: Semantic retrieval from vector store
  Future<List<Message>> _performSemanticRetrieval(
    String userQuery,
    List<Message> messages, {
    String? correlationId,
  }) async {
    final opCtx = ErrorContext(
      component: 'MemoryManager',
      operation: '_performSemanticRetrieval',
      params: {'correlationId': correlationId},
    );
    final logger = _logger;

    if (vectorStore == null || embeddingService == null) {
      logger.fine('Semantic retrieval disabled or not configured', {
        'correlationId': correlationId,
      });
      return [];
    }

    // Simple circuit breaker: if repeated failures occurred recently, skip semantic retrieval for a while.
    if (_semanticFailureCount >= 3 && _lastSemanticFailure != null) {
      final since = DateTime.now().difference(_lastSemanticFailure!);
      if (since.inMinutes < 5) {
        logger.warning(
          'Semantic retrieval circuit open - skipping semantic ops',
          {'correlationId': correlationId},
        );
        return [];
      } else {
        // reset after cooldown
        _semanticFailureCount = 0;
      }
    }

    try {
      // Get embedding for user query
      final queryEmbedding = await embeddingService!.embed(userQuery);
      Validation.validateEmbeddingVector(
        'queryEmbedding',
        queryEmbedding,
        context: opCtx,
      );

      // Search for similar messages
      final searchResults = await vectorStore!.search(
        queryEmbedding: queryEmbedding,
        topK: config.semanticTopK,
        minSimilarity: config.minSimilarity,
      );

      // Convert results back to messages and filter out recent ones
      final recentMessageIds = messages.take(10).map((m) => m.id).toSet();

      final semanticMessages = <Message>[];
      for (final result in searchResults) {
        // Skip if this message is already in recent messages
        if (recentMessageIds.contains(result.entry.id)) continue;

        // Convert vector entry back to message
        final message = Message(
          id: result.entry.id,
          role: _parseRole(result.entry.metadata['role'] as String?),
          content: result.entry.content,
          timestamp: result.entry.timestamp,
          metadata: {
            ...result.entry.metadata,
            'similarity': result.similarity,
            'retrievalType': 'semantic',
          },
        );

        semanticMessages.add(message);
      }

      // Reset failure counter on success
      _semanticFailureCount = 0;
      _lastSemanticFailure = null;

      return semanticMessages;
    } catch (e, st) {
      // Increment failure counter and record time to enable circuit-breaker fallback
      _semanticFailureCount++;
      _lastSemanticFailure = DateTime.now();
      ChatMemoryLogger.logError<void>(
        logger,
        '_performSemanticRetrieval',
        e,
        stackTrace: st,
        params: opCtx.toMap(),
      );
      // Graceful degradation: return empty list so caller can continue without semantic augmentation.
      return [];
    }
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

  /// Parse role string back to MessageRole enum
  MessageRole _parseRole(String? roleStr) {
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
}

/// Extension to add firstOrNull functionality
extension on Iterable<Message> {
  Message? get firstOrNull => isEmpty ? null : first;
}

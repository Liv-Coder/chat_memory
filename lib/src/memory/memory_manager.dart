import '../models/message.dart';
import '../utils/token_counter.dart';
import '../strategies/context_strategy.dart';
import '../strategies/summarization_strategy.dart';
import '../summarizers/summarizer.dart';
import '../vector_stores/vector_store.dart';
import '../embeddings/embedding_service.dart';

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

  MemoryManager({
    required this.contextStrategy,
    required this.tokenCounter,
    this.config = const MemoryConfig(),
    this.vectorStore,
    this.embeddingService,
  });

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
    final startTime = DateTime.now();

    // Step 1: Pre-checks
    final preCheckResult = await _performPreChecks(messages);
    if (preCheckResult != null) {
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
        ? await _performSemanticRetrieval(userQuery, messages)
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
      'processingTimeMs': DateTime.now().difference(startTime).inMilliseconds,
      'originalMessageCount': messages.length,
      'finalMessageCount': finalMessages.length,
      'summarizedMessageCount': strategyResult.excluded.length,
      'semanticRetrievalCount': semanticMessages.length,
      'strategyUsed': strategyResult.name,
      'summaryCount': strategyResult.summaries.length,
    };

    return MemoryContextResult(
      messages: finalMessages,
      estimatedTokens: finalTokens,
      summary: strategyResult.summaries.isNotEmpty
          ? strategyResult.summaries.map((s) => s.summary).join('\n\n')
          : null,
      semanticMessages: semanticMessages,
      metadata: metadata,
    );
  }

  /// Store a message in the vector store for semantic retrieval
  Future<void> storeMessage(Message message) async {
    if (!config.enableSemanticMemory ||
        vectorStore == null ||
        embeddingService == null) {
      return;
    }

    try {
      // Skip system and summary messages from semantic storage
      if (message.role == MessageRole.system ||
          message.role == MessageRole.summary) {
        return;
      }

      final embedding = await embeddingService!.embed(message.content);
      final vectorEntry = message.toVectorEntry(embedding);
      await vectorStore!.store(vectorEntry);
    } catch (e) {
      // Log error but don't fail the operation
      // In production, you might want to use a proper logging framework
    }
  }

  /// Store multiple messages in batch
  Future<void> storeMessageBatch(List<Message> messages) async {
    if (!config.enableSemanticMemory ||
        vectorStore == null ||
        embeddingService == null) {
      return;
    }

    try {
      // Filter out system and summary messages
      final messagesToStore = messages
          .where(
            (m) =>
                m.role != MessageRole.system && m.role != MessageRole.summary,
          )
          .toList();

      if (messagesToStore.isEmpty) return;

      // Get embeddings for all messages
      final texts = messagesToStore.map((m) => m.content).toList();
      final embeddings = await embeddingService!.embedBatch(texts);

      // Create vector entries
      final vectorEntries = <VectorEntry>[];
      for (int i = 0; i < messagesToStore.length; i++) {
        final entry = messagesToStore[i].toVectorEntry(embeddings[i]);
        vectorEntries.add(entry);
      }

      // Store in batch
      await vectorStore!.storeBatch(vectorEntries);
    } catch (e) {
      // Log error but don't fail the operation
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
    List<Message> messages,
  ) async {
    if (vectorStore == null || embeddingService == null) {
      return [];
    }

    try {
      // Get embedding for user query
      final queryEmbedding = await embeddingService!.embed(userQuery);

      // Search for similar messages
      final searchResults = await vectorStore!.search(
        queryEmbedding: queryEmbedding,
        topK: config.semanticTopK,
        minSimilarity: config.minSimilarity,
      );

      // Convert results back to messages and filter out recent ones
      final recentMessageIds = messages
          .take(10) // Consider last 10 messages as "recent"
          .map((m) => m.id)
          .toSet();

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

      return semanticMessages;
    } catch (e) {
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

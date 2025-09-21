import '../errors.dart';
import '../logging/chat_memory_logger.dart';
import '../models/message.dart';
import '../vector_stores/vector_store.dart';
import '../embeddings/embedding_service.dart';
import 'memory_manager.dart';

/// Handles vector search and semantic retrieval with circuit breaker pattern
///
/// This class provides robust semantic retrieval capabilities with built-in
/// resilience patterns and detailed observability for failure recovery.
class SemanticRetriever {
  final VectorStore? _vectorStore;
  final EmbeddingService? _embeddingService;
  final MemoryConfig _config;
  final _logger = ChatMemoryLogger.loggerFor('memory.semantic_retriever');

  // Circuit breaker state
  int _failureCount = 0;
  DateTime? _lastFailureTime;
  static const int _maxFailures = 3;
  static const Duration _cooldownPeriod = Duration(minutes: 5);

  SemanticRetriever({
    VectorStore? vectorStore,
    EmbeddingService? embeddingService,
    required MemoryConfig config,
  }) : _vectorStore = vectorStore,
       _embeddingService = embeddingService,
       _config = config;

  /// Retrieve semantically relevant messages based on query
  Future<List<Message>> retrieveSemanticMessages({
    required String? query,
    required List<Message> recentMessages,
  }) async {
    final opCtx = ErrorContext(
      component: 'SemanticRetriever',
      operation: 'retrieveSemanticMessages',
      params: {
        'hasQuery': query != null,
        'recentMessageCount': recentMessages.length,
      },
    );

    try {
      // Early return if semantic memory is disabled or query is null/empty
      if (!_config.enableSemanticMemory ||
          query == null ||
          query.trim().isEmpty ||
          _vectorStore == null ||
          _embeddingService == null) {
        _logger.fine('Semantic retrieval skipped', opCtx.toMap());
        return <Message>[];
      }

      // Check circuit breaker
      if (_isCircuitBreakerOpen()) {
        _logger.warning(
          'Circuit breaker open, skipping semantic retrieval',
          opCtx.toMap(),
        );
        return <Message>[];
      }

      return await _performSemanticRetrieval(query, recentMessages, opCtx);
    } catch (e, st) {
      _recordFailure();
      ChatMemoryLogger.logError(
        _logger,
        'retrieveSemanticMessages',
        e,
        stackTrace: st,
        params: opCtx.toMap(),
        shouldRethrow: false,
      );

      // Graceful degradation - return empty list instead of throwing
      _logger.warning('Semantic retrieval failed, returning empty results', {
        ...opCtx.toMap(),
        'error': e.toString(),
      });
      return <Message>[];
    }
  }

  /// Perform the actual semantic retrieval operation
  Future<List<Message>> _performSemanticRetrieval(
    String query,
    List<Message> recentMessages,
    ErrorContext opCtx,
  ) async {
    try {
      // Generate query embedding
      final queryEmbedding = await _embeddingService!.embed(query);
      if (queryEmbedding.isEmpty) {
        throw VectorStoreException(
          'Empty query embedding generated',
          context: opCtx,
        );
      }

      // Get recent message IDs to exclude from semantic search
      final recentMessageIds = recentMessages
          .take(10) // Consider last 10 messages as "recent"
          .map((m) => m.id)
          .toSet();

      // Perform vector similarity search
      final searchResults = await _vectorStore!.search(
        queryEmbedding: queryEmbedding,
        topK: _config.semanticTopK,
        minSimilarity: _config.minSimilarity,
      );

      // Convert search results to messages and filter duplicates
      final semanticMessages = <Message>[];
      for (final result in searchResults) {
        final originalId = result.entry.id.replaceAll('_semantic', '');

        // Skip if this message is in recent messages
        if (recentMessageIds.contains(originalId) ||
            recentMessageIds.contains(result.entry.id)) {
          continue;
        }

        // Create message from vector entry with similarity metadata
        final message = _createMessageFromVectorEntry(result);
        semanticMessages.add(message);
      }

      _recordSuccess();
      _logger.fine('Semantic retrieval completed', {
        ...opCtx.toMap(),
        'resultsFound': searchResults.length,
        'messagesReturned': semanticMessages.length,
        'topK': _config.semanticTopK,
        'minSimilarity': _config.minSimilarity,
      });

      return semanticMessages;
    } catch (e, st) {
      _recordFailure();
      throw VectorStoreException(
        'Semantic retrieval operation failed',
        cause: e,
        stackTrace: st,
        context: opCtx,
      );
    }
  }

  /// Create a message object from a vector search result
  Message _createMessageFromVectorEntry(SimilaritySearchResult result) {
    final entry = result.entry;
    final roleString = entry.metadata['role'] as String? ?? 'user';
    final role = _parseRole(roleString);

    return Message(
      id: '${entry.id}_semantic',
      role: role,
      content: entry.content,
      timestamp: entry.timestamp,
      metadata: {
        'similarity': result.similarity,
        'retrievalType': 'semantic',
        'originalId': entry.id,
        ...entry.metadata,
      },
    );
  }

  /// Parse role string back to MessageRole enum
  MessageRole _parseRole(String roleString) {
    switch (roleString.toLowerCase()) {
      case 'user':
        return MessageRole.user;
      case 'assistant':
        return MessageRole.assistant;
      case 'system':
        return MessageRole.system;
      case 'summary':
        return MessageRole.summary;
      default:
        return MessageRole.user; // Default fallback
    }
  }

  /// Check if circuit breaker is open
  bool _isCircuitBreakerOpen() {
    if (_failureCount < _maxFailures) {
      return false;
    }

    final lastFailure = _lastFailureTime;
    if (lastFailure == null) {
      return false;
    }

    final now = DateTime.now();
    final timeSinceLastFailure = now.difference(lastFailure);

    if (timeSinceLastFailure > _cooldownPeriod) {
      // Reset circuit breaker after cooldown
      _failureCount = 0;
      _lastFailureTime = null;
      _logger.info('Circuit breaker reset after cooldown', {
        'cooldownPeriod': _cooldownPeriod.toString(),
        'timeSinceLastFailure': timeSinceLastFailure.toString(),
      });
      return false;
    }

    return true;
  }

  /// Record a successful operation
  void _recordSuccess() {
    if (_failureCount > 0) {
      _logger.info('Semantic retrieval recovered', {
        'previousFailureCount': _failureCount,
      });
      _failureCount = 0;
      _lastFailureTime = null;
    }
  }

  /// Record a failed operation
  void _recordFailure() {
    _failureCount++;
    _lastFailureTime = DateTime.now();

    _logger.warning('Semantic retrieval failure recorded', {
      'failureCount': _failureCount,
      'maxFailures': _maxFailures,
      'circuitBreakerOpen': _failureCount >= _maxFailures,
    });
  }

  /// Get current circuit breaker status
  Map<String, dynamic> getCircuitBreakerStatus() {
    return {
      'failureCount': _failureCount,
      'maxFailures': _maxFailures,
      'isOpen': _isCircuitBreakerOpen(),
      'lastFailureTime': _lastFailureTime?.toIso8601String(),
      'cooldownPeriod': _cooldownPeriod.toString(),
    };
  }

  /// Check if semantic retrieval is available
  bool get isAvailable {
    return _config.enableSemanticMemory &&
        _vectorStore != null &&
        _embeddingService != null &&
        !_isCircuitBreakerOpen();
  }
}

import '../core/errors.dart';
import '../core/logging/chat_memory_logger.dart';
import '../core/models/message.dart';
import 'vector_stores/vector_store.dart';

/// Manages cleanup operations and memory optimization
///
/// This class provides the foundation for automatic memory management
/// and cleanup workflows with configurable retention policies and
/// batch cleanup operations for efficient memory usage.
class MemoryCleaner {
  final VectorStore? _vectorStore;
  final _logger = ChatMemoryLogger.loggerFor('memory.cleaner');

  MemoryCleaner({VectorStore? vectorStore}) : _vectorStore = vectorStore;

  /// Remove old messages based on age threshold
  Future<CleanupResult> cleanupByAge({
    required List<Message> messages,
    required Duration maxAge,
  }) async {
    final opCtx = ErrorContext(
      component: 'MemoryCleaner',
      operation: 'cleanupByAge',
      params: {'messageCount': messages.length, 'maxAge': maxAge.toString()},
    );

    try {
      _logger.fine('Starting cleanup by age', opCtx.toMap());

      final cutoffTime = DateTime.now().toUtc().subtract(maxAge);
      final messagesToRemove = messages
          .where((message) => message.timestamp.isBefore(cutoffTime))
          .toList();

      if (messagesToRemove.isEmpty) {
        _logger.fine('No messages to clean up by age', opCtx.toMap());
        return const CleanupResult(
          removedMessages: 0,
          removedVectors: 0,
          freedTokens: 0,
        );
      }

      final result = await _performCleanup(messagesToRemove, opCtx);

      _logger.info('Cleanup by age completed', {
        ...opCtx.toMap(),
        'removedMessages': result.removedMessages,
        'removedVectors': result.removedVectors,
      });

      return result;
    } catch (e, st) {
      ChatMemoryLogger.logError(
        _logger,
        'cleanupByAge',
        e,
        stackTrace: st,
        params: opCtx.toMap(),
        shouldRethrow: false,
      );
      throw MemoryException(
        'Failed to cleanup messages by age',
        cause: e,
        stackTrace: st,
        context: opCtx,
      );
    }
  }

  /// Remove messages to maintain maximum count threshold
  Future<CleanupResult> cleanupByCount({
    required List<Message> messages,
    required int maxCount,
  }) async {
    final opCtx = ErrorContext(
      component: 'MemoryCleaner',
      operation: 'cleanupByCount',
      params: {'messageCount': messages.length, 'maxCount': maxCount},
    );

    try {
      _logger.fine('Starting cleanup by count', opCtx.toMap());

      if (messages.length <= maxCount) {
        _logger.fine('No messages to clean up by count', opCtx.toMap());
        return const CleanupResult(
          removedMessages: 0,
          removedVectors: 0,
          freedTokens: 0,
        );
      }

      // Sort messages by timestamp (oldest first)
      final sortedMessages = List<Message>.from(messages)
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // Calculate how many to remove
      final excessCount = messages.length - maxCount;
      final messagesToRemove = sortedMessages.take(excessCount).toList();

      final result = await _performCleanup(messagesToRemove, opCtx);

      _logger.info('Cleanup by count completed', {
        ...opCtx.toMap(),
        'removedMessages': result.removedMessages,
        'removedVectors': result.removedVectors,
      });

      return result;
    } catch (e, st) {
      ChatMemoryLogger.logError(
        _logger,
        'cleanupByCount',
        e,
        stackTrace: st,
        params: opCtx.toMap(),
        shouldRethrow: false,
      );
      throw MemoryException(
        'Failed to cleanup messages by count',
        cause: e,
        stackTrace: st,
        context: opCtx,
      );
    }
  }

  /// Remove low-relevance messages based on similarity threshold
  Future<CleanupResult> cleanupByRelevance({
    required List<Message> messages,
    required double minRelevanceScore,
  }) async {
    final opCtx = ErrorContext(
      component: 'MemoryCleaner',
      operation: 'cleanupByRelevance',
      params: {
        'messageCount': messages.length,
        'minRelevanceScore': minRelevanceScore,
      },
    );

    try {
      _logger.fine('Starting cleanup by relevance', opCtx.toMap());

      final messagesToRemove = messages.where((message) {
        final similarity = message.metadata?['similarity'] as double?;
        return similarity != null && similarity < minRelevanceScore;
      }).toList();

      if (messagesToRemove.isEmpty) {
        _logger.fine('No messages to clean up by relevance', opCtx.toMap());
        return const CleanupResult(
          removedMessages: 0,
          removedVectors: 0,
          freedTokens: 0,
        );
      }

      final result = await _performCleanup(messagesToRemove, opCtx);

      _logger.info('Cleanup by relevance completed', {
        ...opCtx.toMap(),
        'removedMessages': result.removedMessages,
        'removedVectors': result.removedVectors,
      });

      return result;
    } catch (e, st) {
      ChatMemoryLogger.logError(
        _logger,
        'cleanupByRelevance',
        e,
        stackTrace: st,
        params: opCtx.toMap(),
        shouldRethrow: false,
      );
      throw MemoryException(
        'Failed to cleanup messages by relevance',
        cause: e,
        stackTrace: st,
        context: opCtx,
      );
    }
  }

  /// Optimize vector storage by removing duplicate or outdated vectors
  Future<OptimizationResult> optimizeVectorStorage() async {
    const opCtx = ErrorContext(
      component: 'MemoryCleaner',
      operation: 'optimizeVectorStorage',
    );

    try {
      if (_vectorStore == null) {
        _logger.fine(
          'No vector store available for optimization',
          opCtx.toMap(),
        );
        return const OptimizationResult(optimizedVectors: 0, reclaimedSpace: 0);
      }

      _logger.fine('Starting vector storage optimization', opCtx.toMap());

      // Get all vector entries
      final allEntries = await _vectorStore.getAll();
      final initialCount = allEntries.length;

      // For now, this is a placeholder for future optimization logic
      // Future implementations could include:
      // - Remove duplicate vectors
      // - Remove vectors for deleted messages
      // - Compress vector storage
      // - Rebalance vector indices

      _logger.info('Vector storage optimization completed', {
        ...opCtx.toMap(),
        'totalVectors': initialCount,
        'optimizedVectors': 0,
      });

      return const OptimizationResult(optimizedVectors: 0, reclaimedSpace: 0);
    } catch (e, st) {
      ChatMemoryLogger.logError(
        _logger,
        'optimizeVectorStorage',
        e,
        stackTrace: st,
        params: opCtx.toMap(),
        shouldRethrow: false,
      );
      throw MemoryException(
        'Failed to optimize vector storage',
        cause: e,
        stackTrace: st,
        context: opCtx,
      );
    }
  }

  /// Perform the actual cleanup operation on a list of messages
  Future<CleanupResult> _performCleanup(
    List<Message> messagesToRemove,
    ErrorContext opCtx,
  ) async {
    var removedVectors = 0;
    var freedTokens = 0;

    // Calculate freed tokens
    for (final message in messagesToRemove) {
      freedTokens += message.content.length ~/ 4; // Rough token estimate
    }

    // Remove from vector store if available
    if (_vectorStore != null && messagesToRemove.isNotEmpty) {
      try {
        final idsToRemove = messagesToRemove.map((m) => m.id).toList();
        await _vectorStore.deleteBatch(idsToRemove);
        removedVectors = messagesToRemove.length;

        _logger.fine('Removed vectors from store', {
          ...opCtx.toMap(),
          'removedVectorCount': removedVectors,
        });
      } catch (e) {
        _logger.warning('Failed to remove some vectors', {
          ...opCtx.toMap(),
          'error': e.toString(),
        });
        // Continue with partial success
      }
    }

    return CleanupResult(
      removedMessages: messagesToRemove.length,
      removedVectors: removedVectors,
      freedTokens: freedTokens,
    );
  }

  /// Check if cleanup is needed based on memory usage thresholds
  bool isCleanupNeeded({
    required int currentMessageCount,
    required int maxMessageCount,
    Duration? maxMessageAge,
    List<Message>? messages,
  }) {
    // Check message count threshold
    if (currentMessageCount > maxMessageCount) {
      return true;
    }

    // Check age threshold if provided
    if (maxMessageAge != null && messages != null) {
      final cutoffTime = DateTime.now().toUtc().subtract(maxMessageAge);
      final hasOldMessages = messages.any(
        (message) => message.timestamp.isBefore(cutoffTime),
      );
      if (hasOldMessages) {
        return true;
      }
    }

    return false;
  }
}

/// Result of a cleanup operation
class CleanupResult {
  final int removedMessages;
  final int removedVectors;
  final int freedTokens;

  const CleanupResult({
    required this.removedMessages,
    required this.removedVectors,
    required this.freedTokens,
  });

  @override
  String toString() {
    return 'CleanupResult(messages: $removedMessages, vectors: $removedVectors, tokens: $freedTokens)';
  }
}

/// Result of a storage optimization operation
class OptimizationResult {
  final int optimizedVectors;
  final int reclaimedSpace;

  const OptimizationResult({
    required this.optimizedVectors,
    required this.reclaimedSpace,
  });

  @override
  String toString() {
    return 'OptimizationResult(vectors: $optimizedVectors, space: $reclaimedSpace)';
  }
}

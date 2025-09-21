import 'dart:math';

import '../../core/errors.dart';
import '../../core/logging/chat_memory_logger.dart';
import 'vector_store.dart';

/// In-memory implementation of VectorStore for testing and lightweight usage.
///
/// Enhanced with validation, logging, and basic memory pressure protection.
/// Optional `expectedDimension` enforces embedding size consistency.
/// Optional `maxEntries` enables a simple LRU eviction policy to avoid
/// unbounded memory growth in long-running processes.
class InMemoryVectorStore implements VectorStore {
  final Map<String, VectorEntry> _entries = {};
  final int? _expectedDimension;
  final int? _maxEntries;
  final _lru = <String, DateTime>{};

  final _logger = ChatMemoryLogger.loggerFor('vector_store.in_memory');

  InMemoryVectorStore({int? expectedDimension, int? maxEntries})
    : _expectedDimension = expectedDimension,
      _maxEntries = maxEntries {
    final ctx = ErrorContext(
      component: 'InMemoryVectorStore',
      operation: 'constructor',
      params: {
        'expectedDimension': _expectedDimension,
        'maxEntries': _maxEntries,
      },
    );

    try {
      if (_expectedDimension != null) {
        Validation.validatePositive(
          'expectedDimension',
          _expectedDimension,
          context: ctx,
        );
      }
      if (_maxEntries != null) {
        Validation.validatePositive('maxEntries', _maxEntries, context: ctx);
      }
      _logger.fine('Initialized InMemoryVectorStore', ctx.toMap());
    } catch (e, st) {
      ChatMemoryLogger.logError(
        _logger,
        'constructor',
        e,
        stackTrace: st,
        params: ctx.toMap(),
        shouldRethrow: true,
      );
    }
  }

  void _maybeEvict() {
    if (_maxEntries == null) return;
    while (_entries.length > _maxEntries) {
      // Evict least recently used
      final oldestKey = _lru.keys.first;
      _entries.remove(oldestKey);
      _lru.remove(oldestKey);
      _logger.warning('Evicted LRU entry', {
        'evictedId': oldestKey,
        'currentSize': _entries.length,
      });
    }
  }

  void _touch(String id) {
    _lru.remove(id);
    _lru[id] = DateTime.now();
  }

  @override
  Future<void> store(VectorEntry entry) async {
    final opCtx = ErrorContext(
      component: 'InMemoryVectorStore',
      operation: 'store',
      params: {'id': entry.id},
    );
    try {
      Validation.validateNonEmptyString('entry.id', entry.id, context: opCtx);
      Validation.validateEmbeddingVector(
        'entry.embedding',
        entry.embedding,
        expectedDim: _expectedDimension,
        context: opCtx,
      );

      _entries[entry.id] = entry;
      _touch(entry.id);
      _maybeEvict();

      _logger.fine('Stored vector entry', opCtx.toMap());
    } catch (e, st) {
      ChatMemoryLogger.logError(
        _logger,
        'store',
        e,
        stackTrace: st,
        params: opCtx.toMap(),
        shouldRethrow: false,
      );
      throw VectorStoreException.storageFailure(
        'Failed to store entry ${entry.id}',
        cause: e,
        stackTrace: st,
        context: opCtx,
      );
    }
  }

  @override
  Future<void> storeBatch(List<VectorEntry> entries) async {
    final opCtx = ErrorContext(
      component: 'InMemoryVectorStore',
      operation: 'storeBatch',
      params: {'count': entries.length},
    );
    try {
      Validation.validateListNotEmpty('entries', entries, context: opCtx);
      for (final entry in entries) {
        Validation.validateNonEmptyString('entry.id', entry.id, context: opCtx);
        Validation.validateEmbeddingVector(
          'entry.embedding',
          entry.embedding,
          expectedDim: _expectedDimension,
          context: opCtx,
        );
        _entries[entry.id] = entry;
        _touch(entry.id);
      }
      _maybeEvict();
      _logger.fine('Stored batch of vector entries', opCtx.toMap());
    } catch (e, st) {
      ChatMemoryLogger.logError(
        _logger,
        'storeBatch',
        e,
        stackTrace: st,
        params: opCtx.toMap(),
        shouldRethrow: false,
      );
      throw VectorStoreException.storageFailure(
        'Failed to store batch',
        cause: e,
        stackTrace: st,
        context: opCtx,
      );
    }
  }

  @override
  Future<List<SimilaritySearchResult>> search({
    required List<double> queryEmbedding,
    required int topK,
    double minSimilarity = 0.0,
    Map<String, dynamic>? metadataFilter,
  }) async {
    final opCtx = ErrorContext(
      component: 'InMemoryVectorStore',
      operation: 'search',
      params: {
        'topK': topK,
        'minSimilarity': minSimilarity,
        'metadataFilter': metadataFilter,
      },
    );
    try {
      Validation.validatePositive('topK', topK, context: opCtx);
      Validation.validateRange(
        'minSimilarity',
        minSimilarity,
        min: 0.0,
        max: 1.0,
        context: opCtx,
      );
      Validation.validateEmbeddingVector(
        'queryEmbedding',
        queryEmbedding,
        expectedDim: _expectedDimension,
        context: opCtx,
      );

      if (_entries.isEmpty) {
        _logger.fine('Search requested but store is empty', opCtx.toMap());
        return <SimilaritySearchResult>[];
      }

      final similarities = <SimilaritySearchResult>[];

      for (final entry in _entries.values) {
        if (metadataFilter != null &&
            !_matchesFilter(entry.metadata, metadataFilter)) {
          continue;
        }

        if (entry.embedding.length != queryEmbedding.length) {
          final mismatchCtx = ErrorContext(
            component: 'InMemoryVectorStore',
            operation: 'search.dimensionMismatch',
            params: {
              'entryId': entry.id,
              'expected': queryEmbedding.length,
              'actual': entry.embedding.length,
            },
          );
          // Log a warning for dimension mismatch and treat similarity as 0.0
          // Avoid constructing/throwing exceptions here to preserve graceful degradation.
          _logger.warning(
            'Dimension mismatch for entry ${entry.id}: expected=${queryEmbedding.length} actual=${entry.embedding.length}',
            mismatchCtx.toMap(),
          );
          continue;
        }

        final similarity = _cosineSimilarity(queryEmbedding, entry.embedding);
        if (similarity >= minSimilarity) {
          similarities.add(
            SimilaritySearchResult(entry: entry, similarity: similarity),
          );
        }
      }

      similarities.sort((a, b) => b.similarity.compareTo(a.similarity));
      final results = similarities.take(topK).toList();
      _logger.fine('Search completed', {
        ...opCtx.toMap(),
        'returned': results.length,
      });
      return results;
    } catch (e, st) {
      ChatMemoryLogger.logError(
        _logger,
        'search',
        e,
        stackTrace: st,
        params: opCtx.toMap(),
        shouldRethrow: false,
      );
      return <SimilaritySearchResult>[];
    }
  }

  @override
  Future<VectorEntry?> get(String id) async {
    final opCtx = ErrorContext(
      component: 'InMemoryVectorStore',
      operation: 'get',
      params: {'id': id},
    );
    try {
      Validation.validateNonEmptyString('id', id, context: opCtx);
      final entry = _entries[id];
      if (entry != null) _touch(id);
      return entry;
    } catch (e, st) {
      ChatMemoryLogger.logError(
        _logger,
        'get',
        e,
        stackTrace: st,
        params: opCtx.toMap(),
        shouldRethrow: false,
      );
      throw VectorStoreException.storageFailure(
        'Failed to get entry $id',
        cause: e,
        stackTrace: st,
        context: opCtx,
      );
    }
  }

  @override
  Future<void> delete(String id) async {
    final opCtx = ErrorContext(
      component: 'InMemoryVectorStore',
      operation: 'delete',
      params: {'id': id},
    );
    try {
      Validation.validateNonEmptyString('id', id, context: opCtx);
      _entries.remove(id);
      _lru.remove(id);
      _logger.fine('Deleted entry', opCtx.toMap());
    } catch (e, st) {
      ChatMemoryLogger.logError(
        _logger,
        'delete',
        e,
        stackTrace: st,
        params: opCtx.toMap(),
        shouldRethrow: false,
      );
      throw VectorStoreException.storageFailure(
        'Failed to delete entry $id',
        cause: e,
        stackTrace: st,
        context: opCtx,
      );
    }
  }

  @override
  Future<void> deleteBatch(List<String> ids) async {
    final opCtx = ErrorContext(
      component: 'InMemoryVectorStore',
      operation: 'deleteBatch',
      params: {'count': ids.length},
    );
    try {
      Validation.validateListNotEmpty('ids', ids, context: opCtx);
      for (final id in ids) {
        _entries.remove(id);
        _lru.remove(id);
      }
      _logger.fine('Deleted batch of entries', opCtx.toMap());
    } catch (e, st) {
      ChatMemoryLogger.logError(
        _logger,
        'deleteBatch',
        e,
        stackTrace: st,
        params: opCtx.toMap(),
        shouldRethrow: false,
      );
      throw VectorStoreException.storageFailure(
        'Failed to delete batch',
        cause: e,
        stackTrace: st,
        context: opCtx,
      );
    }
  }

  @override
  Future<List<VectorEntry>> getAll() async {
    final opCtx = ErrorContext(
      component: 'InMemoryVectorStore',
      operation: 'getAll',
    );
    try {
      final entries = _entries.values.toList();
      entries.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      _logger.fine('Retrieved all entries', opCtx.toMap());
      return entries;
    } catch (e, st) {
      ChatMemoryLogger.logError(
        _logger,
        'getAll',
        e,
        stackTrace: st,
        params: opCtx.toMap(),
        shouldRethrow: false,
      );
      throw VectorStoreException.storageFailure(
        'Failed to retrieve all entries',
        cause: e,
        stackTrace: st,
        context: opCtx,
      );
    }
  }

  @override
  Future<void> clear() async {
    final opCtx = ErrorContext(
      component: 'InMemoryVectorStore',
      operation: 'clear',
    );
    try {
      _entries.clear();
      _lru.clear();
      _logger.fine('Cleared all entries', opCtx.toMap());
    } catch (e, st) {
      ChatMemoryLogger.logError(
        _logger,
        'clear',
        e,
        stackTrace: st,
        params: opCtx.toMap(),
        shouldRethrow: false,
      );
      throw VectorStoreException.storageFailure(
        'Failed to clear entries',
        cause: e,
        stackTrace: st,
        context: opCtx,
      );
    }
  }

  @override
  Future<int> count() async {
    final opCtx = ErrorContext(
      component: 'InMemoryVectorStore',
      operation: 'count',
    );
    try {
      final c = _entries.length;
      _logger.fine('Counted entries', opCtx.toMap());
      return c;
    } catch (e, st) {
      ChatMemoryLogger.logError(
        _logger,
        'count',
        e,
        stackTrace: st,
        params: opCtx.toMap(),
        shouldRethrow: false,
      );
      throw VectorStoreException.storageFailure(
        'Failed to count entries',
        cause: e,
        stackTrace: st,
        context: opCtx,
      );
    }
  }

  bool _matchesFilter(
    Map<String, dynamic> metadata,
    Map<String, dynamic> filter,
  ) {
    for (final entry in filter.entries) {
      if (metadata[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;

    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < a.length; i++) {
      final ai = a[i];
      final bi = b[i];
      if (ai.isNaN || bi.isNaN || ai.isInfinite || bi.isInfinite) {
        return 0.0;
      }
      dotProduct += ai * bi;
      normA += ai * ai;
      normB += bi * bi;
    }

    if (normA == 0.0 || normB == 0.0) return 0.0;

    return dotProduct / (sqrt(normA) * sqrt(normB));
  }
}

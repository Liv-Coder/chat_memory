import 'dart:math';

import '../../core/errors.dart';
import '../../core/logging/chat_memory_logger.dart';
import 'vector_store.dart';

/// Local vector store implementation that behaves like a simple persistent
/// vector store but operates in-memory. Enhanced with validation, logging,
/// and robust error handling to avoid silent failures.
class LocalVectorStore implements VectorStore {
  final Map<String, VectorEntry> _entries = {};
  final String _databasePath;
  final String _tableName;
  final int? _expectedDimension;

  final _logger = ChatMemoryLogger.loggerFor('vector_store.local');

  LocalVectorStore({
    String? databasePath,
    String tableName = 'vector_embeddings',
    int? expectedDimension,
  }) : _databasePath = databasePath ?? 'chat_memory_vectors.db',
       _tableName = tableName,
       _expectedDimension = expectedDimension {
    final ctx = ErrorContext(
      component: 'LocalVectorStore',
      operation: 'constructor',
      params: {
        'databasePath': _databasePath,
        'tableName': _tableName,
        'expectedDimension': _expectedDimension,
      },
    );

    try {
      Validation.validateNonEmptyString('tableName', _tableName, context: ctx);
      if (_expectedDimension != null) {
        Validation.validatePositive(
          'expectedDimension',
          _expectedDimension,
          context: ctx,
        );
      }
      // Log initialization at a fine level so it can be enabled in debug scenarios.
      _logger.fine('Initialized LocalVectorStore', ctx.toMap());
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

  @override
  Future<void> store(VectorEntry entry) async {
    final opCtx = ErrorContext(
      component: 'LocalVectorStore',
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

      // Basic duplicate handling: update existing entry (acts as upsert).
      _entries[entry.id] = entry;

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
      component: 'LocalVectorStore',
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
      }

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
      component: 'LocalVectorStore',
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
        // Apply metadata filter if provided
        if (metadataFilter != null &&
            !_matchesFilter(entry.metadata, metadataFilter)) {
          continue;
        }

        // Validate embedding dimensions for each entry before similarity calc
        if (entry.embedding.length != queryEmbedding.length) {
          // Do not throw here for a single mismatch; log and skip the entry.
          final mismatchCtx = ErrorContext(
            component: 'LocalVectorStore',
            operation: 'search.dimensionMismatch',
            params: {
              'entryId': entry.id,
              'expected': queryEmbedding.length,
              'actual': entry.embedding.length,
            },
          );
          ChatMemoryLogger.logError(
            _logger,
            'search.dimensionMismatch',
            VectorStoreException.dimensionMismatch(
              expected: queryEmbedding.length,
              actual: entry.embedding.length,
              context: mismatchCtx,
            ),
            params: mismatchCtx.toMap(),
            shouldRethrow: false,
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
      // Graceful degradation: return empty results for recoverable vector-store/search issues.
      return <SimilaritySearchResult>[];
    }
  }

  @override
  Future<VectorEntry?> get(String id) async {
    final opCtx = ErrorContext(
      component: 'LocalVectorStore',
      operation: 'get',
      params: {'id': id},
    );
    try {
      Validation.validateNonEmptyString('id', id, context: opCtx);
      return _entries[id];
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
      component: 'LocalVectorStore',
      operation: 'delete',
      params: {'id': id},
    );
    try {
      Validation.validateNonEmptyString('id', id, context: opCtx);
      _entries.remove(id);
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
      component: 'LocalVectorStore',
      operation: 'deleteBatch',
      params: {'count': ids.length},
    );
    try {
      Validation.validateListNotEmpty('ids', ids, context: opCtx);
      for (final id in ids) {
        _entries.remove(id);
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
    const opCtx = ErrorContext(
      component: 'LocalVectorStore',
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
    const opCtx = ErrorContext(
      component: 'LocalVectorStore',
      operation: 'clear',
    );
    try {
      _entries.clear();
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
    const opCtx = ErrorContext(
      component: 'LocalVectorStore',
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

  /// Check if entry metadata matches the filter criteria
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

  /// Calculate cosine similarity between two vectors
  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;

    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < a.length; i++) {
      final ai = a[i];
      final bi = b[i];
      if (ai.isNaN || bi.isNaN || ai.isInfinite || bi.isInfinite) {
        // Invalid values: treat as non-similar
        return 0.0;
      }
      dotProduct += ai * bi;
      normA += ai * ai;
      normB += bi * bi;
    }

    if (normA == 0.0 || normB == 0.0) return 0.0;

    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  /// Get the database path (for compatibility)
  String get databasePath => _databasePath;

  /// Get the table name (for compatibility)
  String get tableName => _tableName;
}

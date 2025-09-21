import 'dart:math';
import 'dart:convert';
import 'vector_store.dart';

/// Local vector store implementation that extends InMemoryVectorStore
///
/// This implementation provides the same interface as a persistent store
/// but uses in-memory storage for simplicity and compatibility.
/// In a production environment, this could be replaced with actual
/// SQLite persistence using the sqflite package.
class LocalVectorStore implements VectorStore {
  final Map<String, VectorEntry> _entries = {};
  final String _databasePath;
  final String _tableName;

  LocalVectorStore({
    String? databasePath,
    String tableName = 'vector_embeddings',
  }) : _databasePath = databasePath ?? 'chat_memory_vectors.db',
       _tableName = tableName;

  @override
  Future<void> store(VectorEntry entry) async {
    _entries[entry.id] = entry;
  }

  @override
  Future<void> storeBatch(List<VectorEntry> entries) async {
    for (final entry in entries) {
      _entries[entry.id] = entry;
    }
  }

  @override
  Future<List<SimilaritySearchResult>> search({
    required List<double> queryEmbedding,
    required int topK,
    double minSimilarity = 0.0,
    Map<String, dynamic>? metadataFilter,
  }) async {
    final similarities = <SimilaritySearchResult>[];

    for (final entry in _entries.values) {
      // Apply metadata filter if provided
      if (metadataFilter != null &&
          !_matchesFilter(entry.metadata, metadataFilter)) {
        continue;
      }

      final similarity = _cosineSimilarity(queryEmbedding, entry.embedding);

      if (similarity >= minSimilarity) {
        similarities.add(
          SimilaritySearchResult(entry: entry, similarity: similarity),
        );
      }
    }

    // Sort by similarity (highest first) and return top-k
    similarities.sort((a, b) => b.similarity.compareTo(a.similarity));
    return similarities.take(topK).toList();
  }

  @override
  Future<VectorEntry?> get(String id) async {
    return _entries[id];
  }

  @override
  Future<void> delete(String id) async {
    _entries.remove(id);
  }

  @override
  Future<void> deleteBatch(List<String> ids) async {
    for (final id in ids) {
      _entries.remove(id);
    }
  }

  @override
  Future<List<VectorEntry>> getAll() async {
    final entries = _entries.values.toList();
    entries.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return entries;
  }

  @override
  Future<void> clear() async {
    _entries.clear();
  }

  @override
  Future<int> count() async {
    return _entries.length;
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
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    if (normA == 0.0 || normB == 0.0) return 0.0;

    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  /// Get the database path (for compatibility)
  String get databasePath => _databasePath;

  /// Get the table name (for compatibility)
  String get tableName => _tableName;
}

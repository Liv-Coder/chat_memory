import '../models/message.dart';

/// Represents a vector embedding with associated metadata
class VectorEntry {
  final String id;
  final List<double> embedding;
  final String content;
  final Map<String, dynamic> metadata;
  final DateTime timestamp;

  const VectorEntry({
    required this.id,
    required this.embedding,
    required this.content,
    required this.metadata,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'embedding': embedding,
      'content': content,
      'metadata': metadata,
      'timestamp': timestamp.toUtc().toIso8601String(),
    };
  }

  static VectorEntry fromJson(Map<String, dynamic> json) {
    return VectorEntry(
      id: json['id'] as String,
      embedding: (json['embedding'] as List).cast<double>(),
      content: json['content'] as String,
      metadata: (json['metadata'] as Map).cast<String, dynamic>(),
      timestamp: DateTime.parse(json['timestamp'] as String).toUtc(),
    );
  }
}

/// Result from a vector similarity search
class SimilaritySearchResult {
  final VectorEntry entry;
  final double similarity;

  const SimilaritySearchResult({required this.entry, required this.similarity});
}

/// Abstract interface for vector storage and retrieval
///
/// Implementations can use local databases (SQLite), in-memory storage,
/// or remote vector databases (Pinecone, Qdrant, etc.)
abstract class VectorStore {
  /// Store a vector entry
  Future<void> store(VectorEntry entry);

  /// Store multiple vector entries in batch
  Future<void> storeBatch(List<VectorEntry> entries);

  /// Search for similar vectors using cosine similarity
  /// Returns top-k results ordered by similarity (highest first)
  Future<List<SimilaritySearchResult>> search({
    required List<double> queryEmbedding,
    required int topK,
    double minSimilarity = 0.0,
    Map<String, dynamic>? metadataFilter,
  });

  /// Retrieve a specific entry by ID
  Future<VectorEntry?> get(String id);

  /// Delete an entry by ID
  Future<void> delete(String id);

  /// Delete multiple entries by IDs
  Future<void> deleteBatch(List<String> ids);

  /// Get all entries (useful for small datasets or debugging)
  Future<List<VectorEntry>> getAll();

  /// Clear all stored vectors
  Future<void> clear();

  /// Get the total count of stored vectors
  Future<int> count();
}

/// Helper extension to convert Messages to VectorEntry format
extension MessageToVectorEntry on Message {
  VectorEntry toVectorEntry(List<double> embedding) {
    return VectorEntry(
      id: id,
      embedding: embedding,
      content: content,
      metadata: {
        'role': role.toString().split('.').last,
        'messageTimestamp': timestamp.toUtc().toIso8601String(),
        ...?metadata,
      },
      timestamp: timestamp,
    );
  }
}

/// Abstract interface for text embedding services
///
/// Implementations can use various embedding models like OpenAI, Google AI,
/// Ollama, or local models to convert text into vector embeddings for semantic search.
abstract class EmbeddingService {
  /// Convert a single text string into a vector embedding
  Future<List<double>> embed(String text);

  /// Convert multiple text strings into vector embeddings
  /// Returns embeddings in the same order as input texts
  Future<List<List<double>>> embedBatch(List<String> texts);

  /// Get the dimension size of embeddings produced by this service
  int get dimensions;

  /// Get a human-readable name/identifier for this embedding service
  String get name;
}

/// Exception thrown when embedding generation fails
class EmbeddingException implements Exception {
  final String message;
  final dynamic cause;

  const EmbeddingException(this.message, [this.cause]);

  @override
  String toString() =>
      'EmbeddingException: $message${cause != null ? ' (caused by: $cause)' : ''}';
}

/// Configuration for embedding services
class EmbeddingConfig {
  /// Maximum number of texts to process in a single batch request
  final int maxBatchSize;

  /// Timeout for embedding requests
  final Duration timeout;

  /// Whether to normalize embeddings to unit vectors
  final bool normalize;

  const EmbeddingConfig({
    this.maxBatchSize = 100,
    this.timeout = const Duration(seconds: 30),
    this.normalize = true,
  });
}

import 'dart:convert';
import 'dart:math';
import 'embedding_service.dart';

/// Simple deterministic embedding service for testing and development
///
/// Generates consistent embeddings based on text content using hash-based
/// vector generation. While not semantically meaningful like real embedding models,
/// it provides consistent results for testing and can capture some basic similarity.
class SimpleEmbeddingService implements EmbeddingService {
  final int _dimensions;
  final EmbeddingConfig _config;

  SimpleEmbeddingService({int dimensions = 384, EmbeddingConfig? config})
    : _dimensions = dimensions,
      _config = config ?? const EmbeddingConfig();

  @override
  int get dimensions => _dimensions;

  @override
  String get name => 'SimpleEmbedding';

  @override
  Future<List<double>> embed(String text) async {
    if (text.isEmpty) {
      return List.filled(_dimensions, 0.0);
    }

    // Generate deterministic embedding based on text content
    final embedding = _generateEmbedding(text);

    return _config.normalize ? _normalizeVector(embedding) : embedding;
  }

  @override
  Future<List<List<double>>> embedBatch(List<String> texts) async {
    final embeddings = <List<double>>[];

    // Process in batches to respect maxBatchSize
    for (int i = 0; i < texts.length; i += _config.maxBatchSize) {
      final batchEnd = min(i + _config.maxBatchSize, texts.length);
      final batch = texts.sublist(i, batchEnd);

      for (final text in batch) {
        embeddings.add(await embed(text));
      }
    }

    return embeddings;
  }

  /// Generate a deterministic embedding vector from text
  List<double> _generateEmbedding(String text) {
    final normalized = text.toLowerCase().trim();
    final bytes = utf8.encode(normalized);

    final embedding = List<double>.filled(_dimensions, 0.0);
    final random = Random(normalized.hashCode);

    // Use character frequencies and positions to influence embedding
    final charFreq = <int, int>{};
    for (int i = 0; i < bytes.length; i++) {
      charFreq[bytes[i]] = (charFreq[bytes[i]] ?? 0) + 1;
    }

    // Generate base embedding using seeded random
    for (int i = 0; i < _dimensions; i++) {
      embedding[i] = random.nextGaussian();
    }

    // Modify embedding based on character frequencies
    for (final entry in charFreq.entries) {
      final charCode = entry.key;
      final frequency = entry.value;
      final index = charCode % _dimensions;

      embedding[index] += frequency * 0.1;
    }

    // Add word-level features for slightly better semantic approximation
    final words = normalized.split(RegExp(r'\s+'));
    for (int i = 0; i < words.length && i < _dimensions; i++) {
      final word = words[i];
      if (word.isNotEmpty) {
        final wordHash = word.hashCode;
        final index = wordHash.abs() % _dimensions;
        embedding[index] += words.length * 0.05;
      }
    }

    return embedding;
  }

  /// Normalize vector to unit length
  List<double> _normalizeVector(List<double> vector) {
    final magnitude = sqrt(
      vector.fold<double>(0.0, (sum, value) => sum + value * value),
    );

    if (magnitude == 0.0) {
      return List.filled(_dimensions, 0.0);
    }

    return vector.map((value) => value / magnitude).toList();
  }
}

/// Extension to add Gaussian random number generation
extension on Random {
  static double? _spare;

  double nextGaussian() {
    // Box-Muller transformation for Gaussian distribution

    if (_spare != null) {
      final result = _spare!;
      _spare = null;
      return result;
    }

    final u = nextDouble();
    final v = nextDouble();
    final mag = 0.5 * log(1.0 - u);
    final angle = 2.0 * pi * v;

    _spare = mag * sin(angle);
    return mag * cos(angle);
  }
}

import 'dart:convert';
import 'dart:math';

import '../../core/errors.dart';
import '../../core/logging/chat_memory_logger.dart';
import 'embedding_service.dart';

/// Simple deterministic embedding service for testing and development
///
/// Generates consistent embeddings based on text content using hash-based
/// vector generation. While not semantically meaningful like real embedding models,
/// it provides consistent results for testing and can capture some basic similarity.
class SimpleEmbeddingService implements EmbeddingService {
  final int _dimensions;
  final EmbeddingConfig _config;
  final _logger = ChatMemoryLogger.loggerFor('embedding.simple');

  SimpleEmbeddingService({int dimensions = 384, EmbeddingConfig? config})
    : _dimensions = dimensions,
      _config = config ?? const EmbeddingConfig() {
    final ctx = ErrorContext(
      component: 'SimpleEmbeddingService',
      operation: 'constructor',
      params: {'dimensions': _dimensions, 'maxBatchSize': _config.maxBatchSize},
    );

    try {
      Validation.validatePositive('dimensions', _dimensions, context: ctx);
      Validation.validatePositive(
        'embeddingConfig.maxBatchSize',
        _config.maxBatchSize,
        context: ctx,
      );
      _logger.fine('Initialized SimpleEmbeddingService', ctx.toMap());
    } catch (e, st) {
      ChatMemoryLogger.logError(
        _logger,
        'constructor',
        e,
        stackTrace: st,
        params: ctx.toMap(),
        shouldRethrow: true,
      );
      rethrow;
    }
  }

  @override
  int get dimensions => _dimensions;

  @override
  String get name => 'SimpleEmbedding';

  @override
  Future<List<double>> embed(String text) async {
    final opCtx = ErrorContext(
      component: 'SimpleEmbeddingService',
      operation: 'embed',
      params: {'textLength': text.length},
    );

    final sw = Stopwatch()..start();
    try {
      if (text.trim().isEmpty) {
        _logger.warning(
          'Received empty or whitespace-only text for embedding; returning zero vector',
          opCtx.toMap(),
        );
        return List.filled(_dimensions, 0.0);
      }

      final embedding = _generateEmbedding(text);
      final normalized = _config.normalize
          ? _normalizeVector(embedding)
          : embedding;

      // Validate produced embedding
      if (normalized.any((v) => v.isNaN || v.isInfinite)) {
        throw const EmbeddingException(
          'Generated embedding contains NaN or infinite values',
        );
      }

      _logger.fine('embed completed', {
        ...opCtx.toMap(),
        'durationMs': sw.elapsedMilliseconds,
      });
      return normalized;
    } catch (e, st) {
      ChatMemoryLogger.logError(
        _logger,
        'embed',
        e,
        stackTrace: st,
        params: opCtx.toMap(),
        shouldRethrow: false,
      );
      throw EmbeddingException('Failed to generate embedding', e);
    } finally {
      sw.stop();
    }
  }

  @override
  Future<List<List<double>>> embedBatch(List<String> texts) async {
    final opCtx = ErrorContext(
      component: 'SimpleEmbeddingService',
      operation: 'embedBatch',
      params: {'count': texts.length, 'maxBatchSize': _config.maxBatchSize},
    );

    final sw = Stopwatch()..start();
    try {
      Validation.validateListNotEmpty('texts', texts, context: opCtx);

      final result = <List<double>>[];

      for (int i = 0; i < texts.length; i += _config.maxBatchSize) {
        final batchEnd = min(i + _config.maxBatchSize, texts.length);
        final batch = texts.sublist(i, batchEnd);

        for (final text in batch) {
          try {
            final emb = await embed(text);
            result.add(emb);
          } catch (e, st) {
            // Log per-item failure and fail the whole batch as embedding correctness is critical.
            final itemCtx = ErrorContext(
              component: 'SimpleEmbeddingService',
              operation: 'embedBatch.item',
              params: {
                'textSample': text.length > 64 ? text.substring(0, 64) : text,
              },
            );
            ChatMemoryLogger.logError(
              _logger,
              'embedBatch.item',
              e,
              stackTrace: st,
              params: itemCtx.toMap(),
              shouldRethrow: false,
            );
            throw EmbeddingException('Failed to embed batch item', e);
          }
        }
      }

      _logger.fine('embedBatch completed', {
        ...opCtx.toMap(),
        'durationMs': sw.elapsedMilliseconds,
      });
      return result;
    } catch (e, st) {
      ChatMemoryLogger.logError(
        _logger,
        'embedBatch',
        e,
        stackTrace: st,
        params: opCtx.toMap(),
        shouldRethrow: false,
      );
      throw EmbeddingException('Batch embedding failed', e);
    } finally {
      sw.stop();
    }
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
    // Use Box-Muller; protect against log(0).
    final r = sqrt(-2.0 * log(max(u, 1e-12)));
    final theta = 2.0 * pi * v;

    _spare = r * sin(theta);
    return r * cos(theta);
  }
}

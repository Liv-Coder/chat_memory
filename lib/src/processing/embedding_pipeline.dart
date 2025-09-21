import 'dart:async';
import 'dart:math';

import '../memory/embeddings/embedding_service.dart';
import '../core/errors.dart';
import '../core/logging/chat_memory_logger.dart';
import 'message_chunker.dart';

/// Processing modes for embedding pipeline
enum ProcessingMode { sequential, parallel, adaptive }

/// Circuit breaker states
enum CircuitBreakerState { closed, open, halfOpen }

/// Retry strategies for failed operations
enum RetryStrategy { immediate, linear, exponential, none }

/// Configuration for circuit breaker behavior
class CircuitBreakerConfig {
  final int maxFailures;
  final Duration timeout;
  final int maxHalfOpenAttempts;
  final bool enabled;

  const CircuitBreakerConfig({
    this.maxFailures = 5,
    this.timeout = const Duration(minutes: 1),
    this.maxHalfOpenAttempts = 3,
    this.enabled = true,
  });
}

/// Configuration for retry behavior
class RetryConfig {
  final int maxRetries;
  final RetryStrategy strategy;
  final Duration baseDelay;
  final Duration maxDelay;
  final bool useJitter;

  const RetryConfig({
    this.maxRetries = 3,
    this.strategy = RetryStrategy.exponential,
    this.baseDelay = const Duration(milliseconds: 100),
    this.maxDelay = const Duration(seconds: 30),
    this.useJitter = true,
  });
}

/// Configuration for embedding pipeline behavior
class EmbeddingConfig {
  final ProcessingMode processingMode;
  final int maxBatchSize;
  final int minBatchSize;
  final double maxRequestsPerSecond;
  final CircuitBreakerConfig circuitBreaker;
  final RetryConfig retryConfig;
  final bool enableCaching;
  final int cacheMaxSize;
  final int cacheTtlSeconds;
  final bool enableValidation;
  final double qualityThreshold;
  final bool normalize;

  const EmbeddingConfig({
    this.processingMode = ProcessingMode.parallel,
    this.maxBatchSize = 50,
    this.minBatchSize = 1,
    this.maxRequestsPerSecond = 10.0,
    this.circuitBreaker = const CircuitBreakerConfig(),
    this.retryConfig = const RetryConfig(),
    this.enableCaching = true,
    this.cacheMaxSize = 1000,
    this.cacheTtlSeconds = 3600,
    this.enableValidation = true,
    this.qualityThreshold = 0.5,
    this.normalize = true,
  });
}

/// Information about a processed embedding
class EmbeddingInfo {
  final String content;
  final List<double> embedding;
  final double qualityScore;
  final int processingTimeMs;

  const EmbeddingInfo({
    required this.content,
    required this.embedding,
    required this.qualityScore,
    required this.processingTimeMs,
  });
}

/// Information about a failed embedding operation
class EmbeddingFailure {
  final String content;
  final Object error;
  final StackTrace? stackTrace;
  final int retryAttempts;

  const EmbeddingFailure({
    required this.content,
    required this.error,
    this.stackTrace,
    required this.retryAttempts,
  });
}

/// Statistics about embedding operations
class EmbeddingStats {
  final int totalItems;
  final int successfulItems;
  final int failedItems;
  final int totalTimeMs;
  final double averageTimePerItem;
  final int peakBatchSize;
  final int totalRetries;
  final double cacheHitRate;

  const EmbeddingStats({
    required this.totalItems,
    required this.successfulItems,
    required this.failedItems,
    required this.totalTimeMs,
    required this.averageTimePerItem,
    required this.peakBatchSize,
    required this.totalRetries,
    required this.cacheHitRate,
  });
}

/// Result of embedding pipeline processing
class EmbeddingResult {
  final List<EmbeddingInfo> embeddings;
  final List<EmbeddingFailure> failures;
  final EmbeddingStats stats;
  final Map<String, dynamic> metadata;

  const EmbeddingResult({
    required this.embeddings,
    required this.failures,
    required this.stats,
    this.metadata = const {},
  });

  bool get isSuccess => failures.isEmpty;

  double get successRate {
    final total = embeddings.length + failures.length;
    return total > 0 ? embeddings.length / total : 0.0;
  }
}

/// Cache entry for embeddings
class _CacheEntry {
  final List<double> embedding;
  final DateTime timestamp;
  final double qualityScore;

  const _CacheEntry({
    required this.embedding,
    required this.timestamp,
    required this.qualityScore,
  });
}

/// Advanced embedding pipeline with resilience patterns and optimization
class EmbeddingPipeline {
  final EmbeddingService _embeddingService;
  final _logger = ChatMemoryLogger.loggerFor('processing.embedding_pipeline');

  // Circuit breaker state
  CircuitBreakerState _circuitState = CircuitBreakerState.closed;
  int _failureCount = 0;
  DateTime? _lastFailureTime;
  int _halfOpenCallCount = 0;

  // Rate limiting
  final List<DateTime> _requestTimes = [];

  // Caching
  final Map<String, _CacheEntry> _cache = {};

  // Performance tracking
  final List<int> _recentBatchSizes = [];
  final List<double> _recentProcessingTimes = [];
  int _totalProcessed = 0;
  int _totalRetries = 0;
  int _cacheHits = 0;

  EmbeddingPipeline({required EmbeddingService embeddingService})
    : _embeddingService = embeddingService;

  /// Process a batch of message chunks through the embedding pipeline
  Future<EmbeddingResult> processChunks(
    List<MessageChunk> chunks,
    EmbeddingConfig config,
  ) async {
    final opCtx = ErrorContext(
      component: 'EmbeddingPipeline',
      operation: 'processChunks',
      params: {
        'chunkCount': chunks.length,
        'processingMode': config.processingMode.toString(),
      },
    );

    final stopwatch = Stopwatch()..start();

    try {
      _logger.fine('Starting chunk processing', opCtx.toMap());
      Validation.validateListNotEmpty('chunks', chunks, context: opCtx);

      final contents = chunks.map((chunk) => chunk.content).toList();
      final result = await _processContents(contents, config, opCtx);

      stopwatch.stop();
      _logger.fine('Chunk processing completed', {
        ...opCtx.toMap(),
        'successfulEmbeddings': result.embeddings.length,
        'failures': result.failures.length,
        'processingTimeMs': stopwatch.elapsedMilliseconds,
      });

      return result;
    } catch (e, st) {
      stopwatch.stop();
      ChatMemoryLogger.logError(
        _logger,
        'processChunks',
        e,
        stackTrace: st,
        params: opCtx.toMap(),
        shouldRethrow: true,
      );
      rethrow;
    }
  }

  /// Process raw text messages through the embedding pipeline
  Future<EmbeddingResult> processMessages(
    List<String> messages,
    EmbeddingConfig config,
  ) async {
    final opCtx = ErrorContext(
      component: 'EmbeddingPipeline',
      operation: 'processMessages',
      params: {
        'messageCount': messages.length,
        'processingMode': config.processingMode.toString(),
      },
    );

    try {
      Validation.validateListNotEmpty('messages', messages, context: opCtx);
      return await _processContents(messages, config, opCtx);
    } catch (e, st) {
      ChatMemoryLogger.logError(
        _logger,
        'processMessages',
        e,
        stackTrace: st,
        params: opCtx.toMap(),
        shouldRethrow: true,
      );
      rethrow;
    }
  }

  /// Get current circuit breaker status
  Map<String, dynamic> getCircuitBreakerStatus() {
    return {
      'state': _circuitState.toString(),
      'failureCount': _failureCount,
      'lastFailureTime': _lastFailureTime?.toString(),
      'halfOpenCallCount': _halfOpenCallCount,
    };
  }

  /// Get processing statistics
  EmbeddingStats getStatistics() {
    final totalItems = _totalProcessed;
    final averageTime = _recentProcessingTimes.isNotEmpty
        ? _recentProcessingTimes.reduce((a, b) => a + b) /
              _recentProcessingTimes.length
        : 0.0;
    final peakBatch = _recentBatchSizes.isNotEmpty
        ? _recentBatchSizes.reduce(max)
        : 0;
    final cacheHitRate = totalItems > 0 ? _cacheHits / totalItems : 0.0;

    return EmbeddingStats(
      totalItems: totalItems,
      successfulItems: totalItems - _totalRetries,
      failedItems: _totalRetries,
      totalTimeMs: (_recentProcessingTimes.fold<double>(
        0.0,
        (sum, time) => sum + time,
      )).round(),
      averageTimePerItem: averageTime,
      peakBatchSize: peakBatch,
      totalRetries: _totalRetries,
      cacheHitRate: cacheHitRate,
    );
  }

  /// Reset all statistics
  void resetStatistics() {
    _totalProcessed = 0;
    _totalRetries = 0;
    _cacheHits = 0;
    _recentBatchSizes.clear();
    _recentProcessingTimes.clear();
  }

  // Private implementation methods

  Future<EmbeddingResult> _processContents(
    List<String> contents,
    EmbeddingConfig config,
    ErrorContext opCtx,
  ) async {
    final embeddings = <EmbeddingInfo>[];
    final failures = <EmbeddingFailure>[];
    final processedItems = <String, bool>{};

    // Check cache first if enabled
    if (config.enableCaching) {
      _cleanExpiredCache(config);
      for (final content in contents) {
        final cached = _getCachedEmbedding(content);
        if (cached != null) {
          embeddings.add(
            EmbeddingInfo(
              content: content,
              embedding: cached.embedding,
              qualityScore: cached.qualityScore,
              processingTimeMs: 0,
            ),
          );
          processedItems[content] = true;
          _cacheHits++;
        }
      }
    }

    final toProcess = contents
        .where((content) => !processedItems.containsKey(content))
        .toList();

    if (toProcess.isEmpty) {
      return _buildResult(embeddings, failures, config);
    }

    switch (config.processingMode) {
      case ProcessingMode.sequential:
        await _processSequential(
          toProcess,
          embeddings,
          failures,
          config,
          opCtx,
        );
        break;
      case ProcessingMode.parallel:
        await _processParallel(toProcess, embeddings, failures, config, opCtx);
        break;
      case ProcessingMode.adaptive:
        await _processAdaptive(toProcess, embeddings, failures, config, opCtx);
        break;
    }

    return _buildResult(embeddings, failures, config);
  }

  Future<void> _processSequential(
    List<String> contents,
    List<EmbeddingInfo> embeddings,
    List<EmbeddingFailure> failures,
    EmbeddingConfig config,
    ErrorContext opCtx,
  ) async {
    for (final content in contents) {
      await _processWithRateLimit(config);

      if (!_checkCircuitBreaker(config)) {
        failures.add(
          EmbeddingFailure(
            content: content,
            error: MemoryException('Circuit breaker is open'),
            retryAttempts: 0,
          ),
        );
        continue;
      }

      await _processSingleContent(content, embeddings, failures, config, opCtx);
    }
  }

  Future<void> _processParallel(
    List<String> contents,
    List<EmbeddingInfo> embeddings,
    List<EmbeddingFailure> failures,
    EmbeddingConfig config,
    ErrorContext opCtx,
  ) async {
    final batches = _createBatches(contents, config.maxBatchSize);

    for (final batch in batches) {
      await _processWithRateLimit(config);

      if (!_checkCircuitBreaker(config)) {
        for (final content in batch) {
          failures.add(
            EmbeddingFailure(
              content: content,
              error: MemoryException('Circuit breaker is open'),
              retryAttempts: 0,
            ),
          );
        }
        continue;
      }

      await _processBatch(batch, embeddings, failures, config, opCtx);
    }
  }

  Future<void> _processAdaptive(
    List<String> contents,
    List<EmbeddingInfo> embeddings,
    List<EmbeddingFailure> failures,
    EmbeddingConfig config,
    ErrorContext opCtx,
  ) async {
    var currentBatchSize = config.minBatchSize;

    for (var i = 0; i < contents.length; i += currentBatchSize) {
      final end = min(i + currentBatchSize, contents.length);
      final batch = contents.sublist(i, end);

      await _processWithRateLimit(config);

      if (!_checkCircuitBreaker(config)) {
        for (final content in batch) {
          failures.add(
            EmbeddingFailure(
              content: content,
              error: MemoryException('Circuit breaker is open'),
              retryAttempts: 0,
            ),
          );
        }
        continue;
      }

      final stopwatch = Stopwatch()..start();
      await _processBatch(batch, embeddings, failures, config, opCtx);
      stopwatch.stop();

      // Adapt batch size based on performance
      final processingTime = stopwatch.elapsedMilliseconds;
      if (processingTime < 1000 && currentBatchSize < config.maxBatchSize) {
        currentBatchSize = min(currentBatchSize * 2, config.maxBatchSize);
      } else if (processingTime > 5000 &&
          currentBatchSize > config.minBatchSize) {
        currentBatchSize = max(currentBatchSize ~/ 2, config.minBatchSize);
      }
    }
  }

  Future<void> _processSingleContent(
    String content,
    List<EmbeddingInfo> embeddings,
    List<EmbeddingFailure> failures,
    EmbeddingConfig config,
    ErrorContext opCtx,
  ) async {
    var retryCount = 0;
    var lastError = '';
    StackTrace? lastStackTrace;

    while (retryCount <= config.retryConfig.maxRetries) {
      try {
        final stopwatch = Stopwatch()..start();
        final embedding = await _embeddingService.embed(content);
        stopwatch.stop();

        if (config.enableValidation) {
          _validateEmbedding(content, embedding, config);
        }

        final finalEmbedding = config.normalize
            ? _normalizeEmbedding(embedding)
            : embedding;
        final qualityScore = _calculateQualityScore(embedding);

        if (qualityScore < config.qualityThreshold) {
          throw MemoryException('Quality score below threshold');
        }

        final embeddingInfo = EmbeddingInfo(
          content: content,
          embedding: finalEmbedding,
          qualityScore: qualityScore,
          processingTimeMs: stopwatch.elapsedMilliseconds,
        );

        embeddings.add(embeddingInfo);

        if (config.enableCaching) {
          _cacheEmbedding(content, finalEmbedding, qualityScore, config);
        }

        _recordSuccess();
        _totalProcessed++;
        return;
      } catch (e, st) {
        lastError = e.toString();
        lastStackTrace = st;
        _recordFailure(config);

        if (retryCount < config.retryConfig.maxRetries) {
          retryCount++;
          _totalRetries++;
          await _waitForRetry(retryCount, config.retryConfig);
        } else {
          break;
        }
      }
    }

    failures.add(
      EmbeddingFailure(
        content: content,
        error: MemoryException(lastError),
        stackTrace: lastStackTrace,
        retryAttempts: retryCount,
      ),
    );
    _totalProcessed++;
  }

  Future<void> _processBatch(
    List<String> batch,
    List<EmbeddingInfo> embeddings,
    List<EmbeddingFailure> failures,
    EmbeddingConfig config,
    ErrorContext opCtx,
  ) async {
    _recentBatchSizes.add(batch.length);
    if (_recentBatchSizes.length > 100) {
      _recentBatchSizes.removeAt(0);
    }

    var retryCount = 0;

    while (retryCount <= config.retryConfig.maxRetries) {
      try {
        final stopwatch = Stopwatch()..start();
        final batchEmbeddings = await _embeddingService.embedBatch(batch);
        stopwatch.stop();

        final processingTime = stopwatch.elapsedMilliseconds;
        _recentProcessingTimes.add(processingTime.toDouble());
        if (_recentProcessingTimes.length > 100) {
          _recentProcessingTimes.removeAt(0);
        }

        for (var i = 0; i < batch.length; i++) {
          final content = batch[i];
          final embedding = batchEmbeddings[i];

          try {
            if (config.enableValidation) {
              _validateEmbedding(content, embedding, config);
            }

            final finalEmbedding = config.normalize
                ? _normalizeEmbedding(embedding)
                : embedding;
            final qualityScore = _calculateQualityScore(embedding);

            if (qualityScore < config.qualityThreshold) {
              throw MemoryException('Quality score below threshold');
            }

            final embeddingInfo = EmbeddingInfo(
              content: content,
              embedding: finalEmbedding,
              qualityScore: qualityScore,
              processingTimeMs: processingTime ~/ batch.length,
            );

            embeddings.add(embeddingInfo);

            if (config.enableCaching) {
              _cacheEmbedding(content, finalEmbedding, qualityScore, config);
            }
          } catch (e, st) {
            failures.add(
              EmbeddingFailure(
                content: content,
                error: e,
                stackTrace: st,
                retryAttempts: retryCount,
              ),
            );
          }
        }

        _recordSuccess();
        _totalProcessed += batch.length;
        return;
      } catch (e) {
        _recordFailure(config);

        if (retryCount < config.retryConfig.maxRetries) {
          retryCount++;
          _totalRetries += batch.length;
          await _waitForRetry(retryCount, config.retryConfig);
        } else {
          break;
        }
      }
    }

    for (final content in batch) {
      failures.add(
        EmbeddingFailure(
          content: content,
          error: MemoryException('Batch processing failed'),
          stackTrace: null,
          retryAttempts: retryCount,
        ),
      );
    }
    _totalProcessed += batch.length;
  }

  List<List<String>> _createBatches(List<String> items, int batchSize) {
    final batches = <List<String>>[];
    for (var i = 0; i < items.length; i += batchSize) {
      final end = min(i + batchSize, items.length);
      batches.add(items.sublist(i, end));
    }
    return batches;
  }

  bool _checkCircuitBreaker(EmbeddingConfig config) {
    if (!config.circuitBreaker.enabled) return true;

    final now = DateTime.now();

    switch (_circuitState) {
      case CircuitBreakerState.closed:
        return true;

      case CircuitBreakerState.open:
        if (_lastFailureTime != null &&
            now.difference(_lastFailureTime!) > config.circuitBreaker.timeout) {
          _circuitState = CircuitBreakerState.halfOpen;
          _halfOpenCallCount = 0;
          _logger.info('Circuit breaker transitioning to half-open');
          return true;
        }
        return false;

      case CircuitBreakerState.halfOpen:
        return _halfOpenCallCount < config.circuitBreaker.maxHalfOpenAttempts;
    }
  }

  void _recordSuccess() {
    if (_circuitState == CircuitBreakerState.halfOpen) {
      _circuitState = CircuitBreakerState.closed;
      _failureCount = 0;
      _logger.info('Circuit breaker closed after successful operation');
    }
  }

  void _recordFailure(EmbeddingConfig config) {
    if (!config.circuitBreaker.enabled) return;

    _failureCount++;
    _lastFailureTime = DateTime.now();

    if (_circuitState == CircuitBreakerState.halfOpen) {
      _halfOpenCallCount++;
      if (_halfOpenCallCount >= config.circuitBreaker.maxHalfOpenAttempts) {
        _circuitState = CircuitBreakerState.open;
        _logger.warning('Circuit breaker opened from half-open state');
      }
    } else if (_circuitState == CircuitBreakerState.closed &&
        _failureCount >= config.circuitBreaker.maxFailures) {
      _circuitState = CircuitBreakerState.open;
      _logger.warning('Circuit breaker opened due to failure threshold');
    }
  }

  Future<void> _processWithRateLimit(EmbeddingConfig config) async {
    if (config.maxRequestsPerSecond <= 0) return;

    final now = DateTime.now();
    final windowStart = now.subtract(const Duration(seconds: 1));

    _requestTimes.removeWhere((time) => time.isBefore(windowStart));

    if (_requestTimes.length >= config.maxRequestsPerSecond) {
      final oldestRequest = _requestTimes.first;
      final waitTime =
          const Duration(seconds: 1) - now.difference(oldestRequest);
      if (waitTime.isNegative == false) {
        await Future.delayed(waitTime);
      }
    }

    _requestTimes.add(now);
  }

  Future<void> _waitForRetry(int attempt, RetryConfig config) async {
    Duration delay;

    switch (config.strategy) {
      case RetryStrategy.immediate:
        return;
      case RetryStrategy.linear:
        delay = Duration(
          milliseconds: config.baseDelay.inMilliseconds * attempt,
        );
        break;
      case RetryStrategy.exponential:
        delay = Duration(
          milliseconds:
              config.baseDelay.inMilliseconds * pow(2, attempt - 1).toInt(),
        );
        break;
      case RetryStrategy.none:
        return;
    }

    if (delay > config.maxDelay) {
      delay = config.maxDelay;
    }

    if (config.useJitter) {
      final jitter = Random().nextDouble() * 0.3;
      delay = Duration(
        milliseconds: (delay.inMilliseconds * (1 + jitter)).round(),
      );
    }

    await Future.delayed(delay);
  }

  void _validateEmbedding(
    String content,
    List<double> embedding,
    EmbeddingConfig config,
  ) {
    Validation.validateEmbeddingVector(
      'embedding',
      embedding,
      expectedDim: _embeddingService.dimensions,
      context: ErrorContext(
        component: 'EmbeddingPipeline',
        operation: '_validateEmbedding',
        params: {'contentLength': content.length},
      ),
    );
  }

  List<double> _normalizeEmbedding(List<double> embedding) {
    final magnitude = sqrt(
      embedding.fold<double>(0.0, (sum, val) => sum + val * val),
    );
    if (magnitude == 0.0) return embedding;
    return embedding.map((val) => val / magnitude).toList();
  }

  double _calculateQualityScore(List<double> embedding) {
    final magnitude = sqrt(
      embedding.fold<double>(0.0, (sum, val) => sum + val * val),
    );
    final variance = _calculateVariance(embedding);
    return min(1.0, (magnitude + variance) / 2.0);
  }

  double _calculateVariance(List<double> values) {
    if (values.isEmpty) return 0.0;

    final mean = values.reduce((a, b) => a + b) / values.length;
    final squaredDiffs = values.map((val) => pow(val - mean, 2));
    return squaredDiffs.reduce((a, b) => a + b) / values.length;
  }

  _CacheEntry? _getCachedEmbedding(String content) {
    return _cache[content];
  }

  void _cacheEmbedding(
    String content,
    List<double> embedding,
    double qualityScore,
    EmbeddingConfig config,
  ) {
    if (_cache.length >= config.cacheMaxSize) {
      final oldestKey = _cache.keys.first;
      _cache.remove(oldestKey);
    }

    _cache[content] = _CacheEntry(
      embedding: List<double>.from(embedding),
      timestamp: DateTime.now(),
      qualityScore: qualityScore,
    );
  }

  void _cleanExpiredCache(EmbeddingConfig config) {
    final cutoff = DateTime.now().subtract(
      Duration(seconds: config.cacheTtlSeconds),
    );
    _cache.removeWhere((key, entry) => entry.timestamp.isBefore(cutoff));
  }

  EmbeddingResult _buildResult(
    List<EmbeddingInfo> embeddings,
    List<EmbeddingFailure> failures,
    EmbeddingConfig config,
  ) {
    final stats = getStatistics();

    return EmbeddingResult(
      embeddings: embeddings,
      failures: failures,
      stats: stats,
      metadata: {
        'processingMode': config.processingMode.toString(),
        'circuitBreakerState': _circuitState.toString(),
        'cacheSize': _cache.length,
      },
    );
  }
}

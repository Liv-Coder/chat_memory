import 'package:test/test.dart';
import 'package:chat_memory/src/processing/processing_config.dart';
import 'package:chat_memory/src/processing/message_processor.dart';
import 'package:chat_memory/src/processing/message_chunker.dart';
import 'package:chat_memory/src/processing/embedding_pipeline.dart';

void main() {
  group('ProcessingPipelineConfig', () {
    test('creates default configuration', () {
      const config = ProcessingPipelineConfig();

      expect(config.processingConfig.stages.length, greaterThan(0));
      expect(config.chunkingConfig.maxChunkTokens, greaterThan(0));
      expect(config.embeddingConfig.maxBatchSize, greaterThan(0));
      expect(config.storageConfig.enableVectorStorage, isTrue);
      expect(config.monitoringConfig.enableMetrics, isTrue);
      expect(config.performanceConfig.memoryLimit, greaterThan(0));
    });

    test('creates development preset configuration', () {
      final config = ProcessingPipelineConfig.fromPreset(
        ProcessingPreset.development,
      );

      expect(config.processingConfig.mode, equals(ProcessingMode.sequential));
      expect(config.processingConfig.continueOnError, isTrue);
      expect(config.processingConfig.maxConcurrency, equals(2));
      expect(config.chunkingConfig.maxChunkTokens, equals(200));
      expect(
        config.chunkingConfig.strategy,
        equals(ChunkingStrategy.fixedToken),
      );
      expect(config.embeddingConfig.maxBatchSize, equals(10));
      expect(
        config.embeddingConfig.processingMode,
        equals(ProcessingMode.sequential),
      );
      expect(config.performanceConfig.prioritizeLatency, isTrue);
    });

    test('creates production preset configuration', () {
      final config = ProcessingPipelineConfig.fromPreset(
        ProcessingPreset.production,
      );

      expect(config.processingConfig.mode, equals(ProcessingMode.parallel));
      expect(config.processingConfig.continueOnError, isFalse);
      expect(config.processingConfig.maxConcurrency, equals(10));
      expect(config.chunkingConfig.maxChunkTokens, equals(500));
      expect(
        config.chunkingConfig.strategy,
        equals(ChunkingStrategy.sentenceBoundary),
      );
      expect(config.chunkingConfig.preserveSentences, isTrue);
      expect(config.embeddingConfig.maxBatchSize, equals(50));
      expect(
        config.embeddingConfig.processingMode,
        equals(ProcessingMode.parallel),
      );
      expect(config.embeddingConfig.circuitBreaker.enabled, isTrue);
      expect(config.storageConfig.enableVectorStorage, isTrue);
      expect(config.storageConfig.enablePersistentStorage, isTrue);
      expect(config.performanceConfig.enableGarbageCollection, isTrue);
    });

    test('creates high throughput preset configuration', () {
      final config = ProcessingPipelineConfig.fromPreset(
        ProcessingPreset.highThroughput,
      );

      expect(config.processingConfig.maxConcurrency, equals(50));
      expect(config.chunkingConfig.maxChunkTokens, equals(1000));
      expect(
        config.chunkingConfig.strategy,
        equals(ChunkingStrategy.fixedToken),
      );
      expect(config.chunkingConfig.preserveWords, isFalse);
      expect(config.embeddingConfig.maxBatchSize, equals(200));
      expect(config.embeddingConfig.maxRequestsPerSecond, equals(100.0));
      expect(config.embeddingConfig.cacheMaxSize, equals(5000));
      expect(config.performanceConfig.memoryLimit, greaterThan(1000000000));
      expect(config.performanceConfig.enablePreallocation, isTrue);
    });

    test('creates low latency preset configuration', () {
      final config = ProcessingPipelineConfig.fromPreset(
        ProcessingPreset.lowLatency,
      );

      expect(config.processingConfig.mode, equals(ProcessingMode.sequential));
      expect(config.processingConfig.maxConcurrency, equals(1));
      expect(config.chunkingConfig.maxChunkTokens, equals(100));
      expect(config.chunkingConfig.preserveWords, isFalse);
      expect(config.embeddingConfig.maxBatchSize, equals(1));
      expect(config.embeddingConfig.retryConfig.maxRetries, equals(1));
      expect(config.performanceConfig.prioritizeLatency, isTrue);
    });

    test('creates memory optimized preset configuration', () {
      final config = ProcessingPipelineConfig.fromPreset(
        ProcessingPreset.memoryOptimized,
      );

      expect(config.processingConfig.maxConcurrency, equals(2));
      expect(config.chunkingConfig.maxChunkTokens, equals(50));
      expect(
        config.chunkingConfig.strategy,
        equals(ChunkingStrategy.slidingWindow),
      );
      expect(config.chunkingConfig.overlapRatio, equals(0.05));
      expect(config.embeddingConfig.maxBatchSize, equals(5));
      expect(config.embeddingConfig.enableCaching, isFalse);
      expect(config.embeddingConfig.cacheMaxSize, equals(100));
      expect(config.performanceConfig.memoryLimit, lessThan(100000000));
      expect(config.performanceConfig.enableGarbageCollection, isTrue);
    });

    test('validates configuration successfully for valid config', () {
      const config = ProcessingPipelineConfig();

      // Should not throw
      expect(() => config.validate(), returnsNormally);
    });

    test('validates and rejects invalid chunking config', () {
      const config = ProcessingPipelineConfig(
        chunkingConfig: ChunkingConfig(
          maxChunkTokens: -1, // Invalid
        ),
      );

      expect(() => config.validate(), throwsA(isA<Exception>()));
    });

    test('validates cross-configuration relationships', () {
      const config = ProcessingPipelineConfig(
        chunkingConfig: ChunkingConfig(maxChunkTokens: 10),
        embeddingConfig: EmbeddingConfig(
          maxBatchSize: 1000,
        ), // Too large relative to chunk size
      );

      expect(() => config.validate(), throwsA(isA<Exception>()));
    });

    test('copyWith creates modified configuration', () {
      const originalConfig = ProcessingPipelineConfig();

      final modifiedConfig = originalConfig.copyWith(
        processingConfig: ProcessingConfig(maxConcurrency: 20),
        chunkingConfig: ChunkingConfig(maxChunkTokens: 1000),
      );

      expect(modifiedConfig.processingConfig.maxConcurrency, equals(20));
      expect(modifiedConfig.chunkingConfig.maxChunkTokens, equals(1000));
      // Other values should remain unchanged
      expect(
        modifiedConfig.embeddingConfig.maxBatchSize,
        equals(originalConfig.embeddingConfig.maxBatchSize),
      );
    });

    test('serializes to and from JSON correctly', () {
      final originalConfig = ProcessingPipelineConfig.fromPreset(
        ProcessingPreset.production,
      );

      final json = originalConfig.toJson();
      final restoredConfig = ProcessingPipelineConfig.fromJson(json);

      expect(
        restoredConfig.processingConfig.mode,
        equals(originalConfig.processingConfig.mode),
      );
      expect(
        restoredConfig.chunkingConfig.maxChunkTokens,
        equals(originalConfig.chunkingConfig.maxChunkTokens),
      );
      expect(
        restoredConfig.chunkingConfig.strategy,
        equals(originalConfig.chunkingConfig.strategy),
      );
      expect(
        restoredConfig.embeddingConfig.maxBatchSize,
        equals(originalConfig.embeddingConfig.maxBatchSize),
      );
      expect(
        restoredConfig.embeddingConfig.enableValidation,
        equals(originalConfig.embeddingConfig.enableValidation),
      );
    });

    test('handles partial JSON correctly', () {
      final partialJson = {
        'chunkingConfig': {
          'maxChunkTokens': 300,
          'strategy': 'ChunkingStrategy.wordBoundary',
        },
        'embeddingConfig': {'maxBatchSize': 25},
      };

      final config = ProcessingPipelineConfig.fromJson(partialJson);

      expect(config.chunkingConfig.maxChunkTokens, equals(300));
      expect(
        config.chunkingConfig.strategy,
        equals(ChunkingStrategy.wordBoundary),
      );
      expect(config.embeddingConfig.maxBatchSize, equals(25));

      // Defaults should be used for missing values
      expect(config.processingConfig.mode, equals(ProcessingMode.parallel));
      expect(config.embeddingConfig.enableValidation, isTrue);
    });
  });

  group('StorageConfig', () {
    test('creates default storage configuration', () {
      const config = StorageConfig();

      expect(config.enableVectorStorage, isTrue);
      expect(config.enablePersistentStorage, isTrue);
      expect(config.storageBatchSize, equals(100));
      expect(config.storageTimeoutMs, equals(30000));
      expect(config.enableCompression, isFalse);
    });

    test('creates custom storage configuration', () {
      const config = StorageConfig(
        enableVectorStorage: false,
        enablePersistentStorage: false,
        storageBatchSize: 50,
        enableCompression: true,
      );

      expect(config.enableVectorStorage, isFalse);
      expect(config.enablePersistentStorage, isFalse);
      expect(config.storageBatchSize, equals(50));
      expect(config.enableCompression, isTrue);
    });
  });

  group('MonitoringConfig', () {
    test('creates default monitoring configuration', () {
      const config = MonitoringConfig();

      expect(config.enableMetrics, isTrue);
      expect(config.enableDetailedLogging, isFalse);
      expect(config.enableProfiling, isFalse);
      expect(config.metricsIntervalSeconds, equals(60));
      expect(config.maxMetricsHistory, equals(1000));
    });

    test('creates custom monitoring configuration', () {
      const config = MonitoringConfig(
        enableDetailedLogging: true,
        enableProfiling: true,
        metricsIntervalSeconds: 30,
        maxMetricsHistory: 500,
      );

      expect(config.enableDetailedLogging, isTrue);
      expect(config.enableProfiling, isTrue);
      expect(config.metricsIntervalSeconds, equals(30));
      expect(config.maxMetricsHistory, equals(500));
    });
  });

  group('PerformanceConfig', () {
    test('creates default performance configuration', () {
      const config = PerformanceConfig();

      expect(config.memoryLimit, equals(500000000));
      expect(config.prioritizeLatency, isFalse);
      expect(config.enablePreallocation, isFalse);
      expect(config.enableGarbageCollection, isFalse);
      expect(config.threadPoolSize, equals(4));
    });

    test('creates custom performance configuration', () {
      const config = PerformanceConfig(
        memoryLimit: 1000000000,
        prioritizeLatency: true,
        enablePreallocation: true,
        enableGarbageCollection: true,
        threadPoolSize: 8,
      );

      expect(config.memoryLimit, equals(1000000000));
      expect(config.prioritizeLatency, isTrue);
      expect(config.enablePreallocation, isTrue);
      expect(config.enableGarbageCollection, isTrue);
      expect(config.threadPoolSize, equals(8));
    });
  });
}

import '../core/errors.dart';
import 'message_chunker.dart';
import 'embedding_pipeline.dart';
import 'message_processor.dart';

/// Preset configurations for common use cases
enum ProcessingPreset {
  /// Fast development setup with minimal processing
  development,

  /// Production setup with full pipeline
  production,

  /// High-throughput processing for large datasets
  highThroughput,

  /// Low-latency processing for real-time applications
  lowLatency,

  /// Memory-optimized processing for resource-constrained environments
  memoryOptimized,
}

/// Storage configuration options
class StorageConfig {
  /// Whether to enable vector storage
  final bool enableVectorStorage;

  /// Whether to enable persistent storage
  final bool enablePersistentStorage;

  /// Batch size for storage operations
  final int storageBatchSize;

  /// Storage timeout in milliseconds
  final int storageTimeoutMs;

  /// Whether to compress stored data
  final bool enableCompression;

  const StorageConfig({
    this.enableVectorStorage = true,
    this.enablePersistentStorage = true,
    this.storageBatchSize = 100,
    this.storageTimeoutMs = 30000,
    this.enableCompression = false,
  });
}

/// Monitoring and observability configuration
class MonitoringConfig {
  /// Whether to collect detailed metrics
  final bool enableMetrics;

  /// Whether to enable performance profiling
  final bool enableProfiling;

  /// Metrics collection interval in seconds
  final int metricsIntervalSeconds;

  /// Whether to log detailed processing information
  final bool enableDetailedLogging;

  /// Maximum number of metrics to retain
  final int maxMetricsHistory;

  const MonitoringConfig({
    this.enableMetrics = true,
    this.enableProfiling = false,
    this.metricsIntervalSeconds = 60,
    this.enableDetailedLogging = false,
    this.maxMetricsHistory = 1000,
  });
}

/// Performance optimization configuration
class PerformanceConfig {
  /// Maximum memory usage in bytes
  final int memoryLimit;

  /// Whether to enable garbage collection optimization
  final bool enableGarbageCollection;

  /// Whether to prioritize latency over throughput
  final bool prioritizeLatency;

  /// Whether to enable memory preallocation
  final bool enablePreallocation;

  /// Thread pool size for parallel operations
  final int threadPoolSize;

  const PerformanceConfig({
    this.memoryLimit = 500000000, // 500MB default
    this.enableGarbageCollection = false,
    this.prioritizeLatency = false,
    this.enablePreallocation = false,
    this.threadPoolSize = 4,
  });
}

/// Comprehensive configuration for the processing pipeline
class ProcessingPipelineConfig {
  /// Pipeline execution configuration
  final ProcessingConfig processingConfig;

  /// Message chunking configuration
  final ChunkingConfig chunkingConfig;

  /// Embedding processing configuration
  final EmbeddingConfig embeddingConfig;

  /// Storage configuration
  final StorageConfig storageConfig;

  /// Monitoring configuration
  final MonitoringConfig monitoringConfig;

  /// Performance configuration
  final PerformanceConfig performanceConfig;

  const ProcessingPipelineConfig({
    this.processingConfig = const ProcessingConfig(),
    this.chunkingConfig = const ChunkingConfig(),
    this.embeddingConfig = const EmbeddingConfig(),
    this.storageConfig = const StorageConfig(),
    this.monitoringConfig = const MonitoringConfig(),
    this.performanceConfig = const PerformanceConfig(),
  });

  /// Create configuration from a preset
  factory ProcessingPipelineConfig.fromPreset(ProcessingPreset preset) {
    switch (preset) {
      case ProcessingPreset.development:
        return ProcessingPipelineConfig(
          processingConfig: ProcessingConfig(
            mode: ProcessingMode.sequential,
            maxConcurrency: 2,
            continueOnError: true,
          ),
          chunkingConfig: ChunkingConfig(
            maxChunkTokens: 200,
            strategy: ChunkingStrategy.fixedToken,
            preserveWords: true,
          ),
          embeddingConfig: EmbeddingConfig(
            processingMode: ProcessingMode.sequential,
            maxBatchSize: 10,
            enableCaching: true,
            enableValidation: false,
          ),
          storageConfig: StorageConfig(
            enableVectorStorage: true,
            enablePersistentStorage: false,
            storageBatchSize: 20,
          ),
          monitoringConfig: MonitoringConfig(
            enableMetrics: false,
            enableDetailedLogging: true,
          ),
          performanceConfig: PerformanceConfig(
            memoryLimit: 100000000, // 100MB
            prioritizeLatency: true,
          ),
        );

      case ProcessingPreset.production:
        return ProcessingPipelineConfig(
          processingConfig: ProcessingConfig(
            mode: ProcessingMode.parallel,
            maxConcurrency: 10,
            continueOnError: false,
          ),
          chunkingConfig: ChunkingConfig(
            maxChunkTokens: 500,
            strategy: ChunkingStrategy.sentenceBoundary,
            preserveWords: true,
            preserveSentences: true,
          ),
          embeddingConfig: EmbeddingConfig(
            processingMode: ProcessingMode.parallel,
            maxBatchSize: 50,
            enableCaching: true,
            enableValidation: true,
            circuitBreaker: CircuitBreakerConfig(enabled: true),
            retryConfig: RetryConfig(maxRetries: 3),
          ),
          storageConfig: StorageConfig(
            enableVectorStorage: true,
            enablePersistentStorage: true,
            storageBatchSize: 100,
            enableCompression: true,
          ),
          monitoringConfig: MonitoringConfig(
            enableMetrics: true,
            enableProfiling: true,
            enableDetailedLogging: false,
          ),
          performanceConfig: PerformanceConfig(
            memoryLimit: 1000000000, // 1GB
            enableGarbageCollection: true,
          ),
        );

      case ProcessingPreset.highThroughput:
        return ProcessingPipelineConfig(
          processingConfig: ProcessingConfig(
            mode: ProcessingMode.parallel,
            maxConcurrency: 50,
            continueOnError: true,
          ),
          chunkingConfig: ChunkingConfig(
            maxChunkTokens: 1000,
            strategy: ChunkingStrategy.fixedToken,
            preserveWords: false,
          ),
          embeddingConfig: EmbeddingConfig(
            processingMode: ProcessingMode.parallel,
            maxBatchSize: 200,
            maxRequestsPerSecond: 100.0,
            enableCaching: true,
            cacheMaxSize: 5000,
          ),
          storageConfig: StorageConfig(
            storageBatchSize: 500,
            enableCompression: true,
          ),
          monitoringConfig: MonitoringConfig(
            enableMetrics: true,
            metricsIntervalSeconds: 30,
          ),
          performanceConfig: PerformanceConfig(
            memoryLimit: 2000000000, // 2GB
            enablePreallocation: true,
            threadPoolSize: 16,
          ),
        );

      case ProcessingPreset.lowLatency:
        return ProcessingPipelineConfig(
          processingConfig: ProcessingConfig(
            mode: ProcessingMode.sequential,
            maxConcurrency: 1,
          ),
          chunkingConfig: ChunkingConfig(
            maxChunkTokens: 100,
            strategy: ChunkingStrategy.fixedToken,
            preserveWords: false,
          ),
          embeddingConfig: EmbeddingConfig(
            processingMode: ProcessingMode.sequential,
            maxBatchSize: 1,
            enableCaching: true,
            retryConfig: RetryConfig(maxRetries: 1),
          ),
          storageConfig: StorageConfig(
            storageBatchSize: 1,
            enableCompression: false,
          ),
          monitoringConfig: MonitoringConfig(
            enableMetrics: false,
            enableDetailedLogging: false,
          ),
          performanceConfig: PerformanceConfig(
            memoryLimit: 200000000, // 200MB
            prioritizeLatency: true,
            threadPoolSize: 1,
          ),
        );

      case ProcessingPreset.memoryOptimized:
        return ProcessingPipelineConfig(
          processingConfig: ProcessingConfig(
            mode: ProcessingMode.sequential,
            maxConcurrency: 2,
          ),
          chunkingConfig: ChunkingConfig(
            maxChunkTokens: 50,
            strategy: ChunkingStrategy.slidingWindow,
            overlapRatio: 0.05,
          ),
          embeddingConfig: EmbeddingConfig(
            processingMode: ProcessingMode.sequential,
            maxBatchSize: 5,
            enableCaching: false,
            cacheMaxSize: 100,
          ),
          storageConfig: StorageConfig(
            storageBatchSize: 10,
            enableCompression: true,
          ),
          monitoringConfig: MonitoringConfig(
            enableMetrics: false,
            maxMetricsHistory: 100,
          ),
          performanceConfig: PerformanceConfig(
            memoryLimit: 50000000, // 50MB
            enableGarbageCollection: true,
            threadPoolSize: 1,
          ),
        );
    }
  }

  /// Create a copy with modified parameters
  ProcessingPipelineConfig copyWith({
    ProcessingConfig? processingConfig,
    ChunkingConfig? chunkingConfig,
    EmbeddingConfig? embeddingConfig,
    StorageConfig? storageConfig,
    MonitoringConfig? monitoringConfig,
    PerformanceConfig? performanceConfig,
  }) {
    return ProcessingPipelineConfig(
      processingConfig: processingConfig ?? this.processingConfig,
      chunkingConfig: chunkingConfig ?? this.chunkingConfig,
      embeddingConfig: embeddingConfig ?? this.embeddingConfig,
      storageConfig: storageConfig ?? this.storageConfig,
      monitoringConfig: monitoringConfig ?? this.monitoringConfig,
      performanceConfig: performanceConfig ?? this.performanceConfig,
    );
  }

  /// Validate the configuration for consistency and compatibility
  void validate() {
    final opCtx = ErrorContext(
      component: 'ProcessingPipelineConfig',
      operation: 'validate',
    );

    // Validate chunking config
    _validateChunkingConfig(opCtx);

    // Validate embedding config
    _validateEmbeddingConfig(opCtx);

    // Validate cross-configuration relationships
    _validateCrossConfigurations(opCtx);

    // Validate resource limits
    _validateResourceLimits(opCtx);
  }

  /// Serialize configuration to JSON
  Map<String, dynamic> toJson() {
    return {
      'processingConfig': _processingConfigToJson(processingConfig),
      'chunkingConfig': _chunkingConfigToJson(chunkingConfig),
      'embeddingConfig': _embeddingConfigToJson(embeddingConfig),
      'storageConfig': _storageConfigToJson(storageConfig),
      'monitoringConfig': _monitoringConfigToJson(monitoringConfig),
      'performanceConfig': _performanceConfigToJson(performanceConfig),
    };
  }

  /// Deserialize configuration from JSON
  factory ProcessingPipelineConfig.fromJson(Map<String, dynamic> json) {
    return ProcessingPipelineConfig(
      processingConfig: _processingConfigFromJson(
        json['processingConfig'] ?? {},
      ),
      chunkingConfig: _chunkingConfigFromJson(json['chunkingConfig'] ?? {}),
      embeddingConfig: _embeddingConfigFromJson(json['embeddingConfig'] ?? {}),
      storageConfig: _storageConfigFromJson(json['storageConfig'] ?? {}),
      monitoringConfig: _monitoringConfigFromJson(
        json['monitoringConfig'] ?? {},
      ),
      performanceConfig: _performanceConfigFromJson(
        json['performanceConfig'] ?? {},
      ),
    );
  }

  // Private validation methods

  void _validateChunkingConfig(ErrorContext opCtx) {
    Validation.validatePositive(
      'maxChunkTokens',
      chunkingConfig.maxChunkTokens,
      context: opCtx,
    );
    Validation.validatePositive(
      'maxChunkChars',
      chunkingConfig.maxChunkChars,
      context: opCtx,
    );
    Validation.validateRange(
      'overlapRatio',
      chunkingConfig.overlapRatio,
      min: 0.0,
      max: 1.0,
      context: opCtx,
    );
    Validation.validatePositive(
      'maxChunksPerMessage',
      chunkingConfig.maxChunksPerMessage,
      context: opCtx,
    );
  }

  void _validateEmbeddingConfig(ErrorContext opCtx) {
    Validation.validatePositive(
      'maxBatchSize',
      embeddingConfig.maxBatchSize,
      context: opCtx,
    );
    Validation.validatePositive(
      'minBatchSize',
      embeddingConfig.minBatchSize,
      context: opCtx,
    );
    Validation.validateNonNegative(
      'maxRequestsPerSecond',
      embeddingConfig.maxRequestsPerSecond,
      context: opCtx,
    );
    Validation.validateRange(
      'qualityThreshold',
      embeddingConfig.qualityThreshold,
      min: 0.0,
      max: 1.0,
      context: opCtx,
    );

    if (embeddingConfig.minBatchSize > embeddingConfig.maxBatchSize) {
      throw ConfigurationException.invalid(
        'embeddingConfig',
        'minBatchSize cannot be greater than maxBatchSize',
        context: opCtx,
      );
    }
  }

  void _validateCrossConfigurations(ErrorContext opCtx) {
    // Check if batch size is reasonable relative to chunk size
    if (embeddingConfig.maxBatchSize > chunkingConfig.maxChunkTokens * 10) {
      throw ConfigurationException.invalid(
        'configuration',
        'embedding batch size is too large relative to chunk size',
        context: opCtx,
      );
    }

    // Check memory limits vs batch sizes
    final estimatedMemoryUsage =
        embeddingConfig.maxBatchSize *
        chunkingConfig.maxChunkChars *
        8; // Rough estimate
    if (estimatedMemoryUsage > performanceConfig.memoryLimit * 0.8) {
      throw ConfigurationException.invalid(
        'configuration',
        'estimated memory usage exceeds 80% of memory limit',
        context: opCtx,
      );
    }
  }

  void _validateResourceLimits(ErrorContext opCtx) {
    Validation.validatePositive(
      'memoryLimit',
      performanceConfig.memoryLimit,
      context: opCtx,
    );
    Validation.validatePositive(
      'threadPoolSize',
      performanceConfig.threadPoolSize,
      context: opCtx,
    );
    Validation.validatePositive(
      'storageBatchSize',
      storageConfig.storageBatchSize,
      context: opCtx,
    );
  }

  // JSON serialization helpers

  static Map<String, dynamic> _processingConfigToJson(ProcessingConfig config) {
    return {
      'stages': config.stages.map((s) => s.toString()).toList(),
      'mode': config.mode.toString(),
      'continueOnError': config.continueOnError,
      'maxConcurrency': config.maxConcurrency,
    };
  }

  static Map<String, dynamic> _chunkingConfigToJson(ChunkingConfig config) {
    return {
      'maxChunkTokens': config.maxChunkTokens,
      'maxChunkChars': config.maxChunkChars,
      'strategy': config.strategy.toString(),
      'preserveWords': config.preserveWords,
      'overlapRatio': config.overlapRatio,
    };
  }

  static Map<String, dynamic> _embeddingConfigToJson(EmbeddingConfig config) {
    return {
      'processingMode': config.processingMode.toString(),
      'maxBatchSize': config.maxBatchSize,
      'enableCaching': config.enableCaching,
      'enableValidation': config.enableValidation,
      'qualityThreshold': config.qualityThreshold,
    };
  }

  static Map<String, dynamic> _storageConfigToJson(StorageConfig config) {
    return {
      'enableVectorStorage': config.enableVectorStorage,
      'enablePersistentStorage': config.enablePersistentStorage,
      'storageBatchSize': config.storageBatchSize,
      'enableCompression': config.enableCompression,
    };
  }

  static Map<String, dynamic> _monitoringConfigToJson(MonitoringConfig config) {
    return {
      'enableMetrics': config.enableMetrics,
      'enableProfiling': config.enableProfiling,
      'enableDetailedLogging': config.enableDetailedLogging,
    };
  }

  static Map<String, dynamic> _performanceConfigToJson(
    PerformanceConfig config,
  ) {
    return {
      'memoryLimit': config.memoryLimit,
      'enableGarbageCollection': config.enableGarbageCollection,
      'prioritizeLatency': config.prioritizeLatency,
      'threadPoolSize': config.threadPoolSize,
    };
  }

  static ProcessingConfig _processingConfigFromJson(Map<String, dynamic> json) {
    return ProcessingConfig(
      mode: _parseProcessingMode(json['mode']),
      continueOnError: json['continueOnError'] ?? false,
      maxConcurrency: json['maxConcurrency'] ?? 10,
    );
  }

  static ChunkingConfig _chunkingConfigFromJson(Map<String, dynamic> json) {
    return ChunkingConfig(
      maxChunkTokens: json['maxChunkTokens'] ?? 500,
      maxChunkChars: json['maxChunkChars'] ?? 2000,
      strategy: _parseChunkingStrategy(json['strategy']),
      preserveWords: json['preserveWords'] ?? true,
      overlapRatio: (json['overlapRatio'] ?? 0.1).toDouble(),
    );
  }

  static EmbeddingConfig _embeddingConfigFromJson(Map<String, dynamic> json) {
    return EmbeddingConfig(
      processingMode: _parseProcessingMode(json['processingMode']),
      maxBatchSize: json['maxBatchSize'] ?? 50,
      enableCaching: json['enableCaching'] ?? true,
      enableValidation: json['enableValidation'] ?? true,
      qualityThreshold: (json['qualityThreshold'] ?? 0.5).toDouble(),
    );
  }

  static StorageConfig _storageConfigFromJson(Map<String, dynamic> json) {
    return StorageConfig(
      enableVectorStorage: json['enableVectorStorage'] ?? true,
      enablePersistentStorage: json['enablePersistentStorage'] ?? true,
      storageBatchSize: json['storageBatchSize'] ?? 100,
      enableCompression: json['enableCompression'] ?? false,
    );
  }

  static MonitoringConfig _monitoringConfigFromJson(Map<String, dynamic> json) {
    return MonitoringConfig(
      enableMetrics: json['enableMetrics'] ?? true,
      enableProfiling: json['enableProfiling'] ?? false,
      enableDetailedLogging: json['enableDetailedLogging'] ?? false,
    );
  }

  static PerformanceConfig _performanceConfigFromJson(
    Map<String, dynamic> json,
  ) {
    return PerformanceConfig(
      memoryLimit: json['memoryLimit'] ?? 500000000,
      enableGarbageCollection: json['enableGarbageCollection'] ?? false,
      prioritizeLatency: json['prioritizeLatency'] ?? false,
      threadPoolSize: json['threadPoolSize'] ?? 4,
    );
  }

  static ProcessingMode _parseProcessingMode(String? mode) {
    switch (mode) {
      case 'ProcessingMode.sequential':
        return ProcessingMode.sequential;
      case 'ProcessingMode.parallel':
        return ProcessingMode.parallel;
      case 'ProcessingMode.adaptive':
        return ProcessingMode.adaptive;
      default:
        return ProcessingMode.parallel;
    }
  }

  static ChunkingStrategy _parseChunkingStrategy(String? strategy) {
    switch (strategy) {
      case 'ChunkingStrategy.fixedToken':
        return ChunkingStrategy.fixedToken;
      case 'ChunkingStrategy.fixedChar':
        return ChunkingStrategy.fixedChar;
      case 'ChunkingStrategy.wordBoundary':
        return ChunkingStrategy.wordBoundary;
      case 'ChunkingStrategy.sentenceBoundary':
        return ChunkingStrategy.sentenceBoundary;
      case 'ChunkingStrategy.paragraphBoundary':
        return ChunkingStrategy.paragraphBoundary;
      case 'ChunkingStrategy.slidingWindow':
        return ChunkingStrategy.slidingWindow;
      case 'ChunkingStrategy.delimiter':
        return ChunkingStrategy.delimiter;
      case 'ChunkingStrategy.semantic':
        return ChunkingStrategy.semantic;
      default:
        return ChunkingStrategy.fixedToken;
    }
  }
}

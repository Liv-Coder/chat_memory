import '../core/utils/token_counter.dart';
import 'summarizers/summarizer.dart';
import 'summarizers/deterministic_summarizer.dart';
import 'strategies/context_strategy.dart';
import 'strategies/summarization_strategy.dart';
import 'vector_stores/vector_store.dart';
import 'vector_stores/local_vector_store.dart';
import 'vector_stores/in_memory_vector_store.dart';
import 'embeddings/embedding_service.dart';
import 'embeddings/simple_embedding_service.dart';
import '../core/errors.dart';
import '../core/logging/chat_memory_logger.dart';
import 'memory_manager.dart';

/// Configuration preset for different use cases
enum MemoryPreset {
  /// Lightweight setup with in-memory storage, good for development/testing
  development,

  /// Production setup with persistent storage and semantic search
  production,

  /// Minimal setup with just summarization, no semantic search
  minimal,

  /// High-performance setup optimized for large conversations
  performance,
}

/// Factory for creating pre-configured hybrid memory systems
///
/// Provides easy setup methods for common use cases while allowing
/// full customization when needed.
class HybridMemoryFactory {
  static final _logger = ChatMemoryLogger.loggerFor('factory.hybrid_memory');

  /// Create a memory manager with preset configuration
  static Future<MemoryManager> create({
    required MemoryPreset preset,
    int maxTokens = 8000,
    Summarizer? customSummarizer,
    EmbeddingService? customEmbeddingService,
    VectorStore? customVectorStore,
    TokenCounter? customTokenCounter,
    String? databasePath,
  }) async {
    final ctx = ErrorContext(
      component: 'HybridMemoryFactory',
      operation: 'create',
      params: {
        'preset': preset.toString(),
        'maxTokens': maxTokens,
        'hasCustomSummarizer': customSummarizer != null,
        'hasCustomEmbedding': customEmbeddingService != null,
        'hasCustomVectorStore': customVectorStore != null,
      },
    );

    try {
      Validation.validatePositive('maxTokens', maxTokens, context: ctx);

      final tokenCounter = customTokenCounter ?? HeuristicTokenCounter();

      switch (preset) {
        case MemoryPreset.development:
          return _createDevelopmentSetup(
            maxTokens: maxTokens,
            summarizer: customSummarizer,
            tokenCounter: tokenCounter,
          );

        case MemoryPreset.production:
          return await _createProductionSetup(
            maxTokens: maxTokens,
            summarizer: customSummarizer,
            embeddingService: customEmbeddingService,
            vectorStore: customVectorStore,
            tokenCounter: tokenCounter,
            databasePath: databasePath,
          );

        case MemoryPreset.minimal:
          return _createMinimalSetup(
            maxTokens: maxTokens,
            summarizer: customSummarizer,
            tokenCounter: tokenCounter,
          );

        case MemoryPreset.performance:
          return await _createPerformanceSetup(
            maxTokens: maxTokens,
            summarizer: customSummarizer,
            embeddingService: customEmbeddingService,
            vectorStore: customVectorStore,
            tokenCounter: tokenCounter,
            databasePath: databasePath,
          );
      }
    } catch (e, st) {
      ChatMemoryLogger.logError(
        _logger,
        'create',
        e,
        stackTrace: st,
        params: ctx.toMap(),
        shouldRethrow: true,
      );
      rethrow;
    }
  }

  /// Create a fully customized memory manager
  static MemoryManager createCustom({
    required ContextStrategy contextStrategy,
    required TokenCounter tokenCounter,
    MemoryConfig? memoryConfig,
    VectorStore? vectorStore,
    EmbeddingService? embeddingService,
  }) {
    final ctx = ErrorContext(
      component: 'HybridMemoryFactory',
      operation: 'createCustom',
      params: {
        'hasVectorStore': vectorStore != null,
        'hasEmbeddingService': embeddingService != null,
      },
    );

    try {
      final config = memoryConfig ?? const MemoryConfig();
      // If semantic memory is enabled, ensure required components are present at construction time.
      if (config.enableSemanticMemory) {
        if (vectorStore == null) {
          throw ConfigurationException.missing('vectorStore', context: ctx);
        }
        if (embeddingService == null) {
          throw ConfigurationException.missing(
            'embeddingService',
            context: ctx,
          );
        }
      }

      return MemoryManager(
        contextStrategy: contextStrategy,
        tokenCounter: tokenCounter,
        config: config,
        vectorStore: vectorStore,
        embeddingService: embeddingService,
      );
    } catch (e, st) {
      ChatMemoryLogger.logError(
        _logger,
        'createCustom',
        e,
        stackTrace: st,
        params: ctx.toMap(),
        shouldRethrow: true,
      );
      rethrow;
    }
  }

  /// Development preset: Fast setup with in-memory storage
  static MemoryManager _createDevelopmentSetup({
    required int maxTokens,
    Summarizer? summarizer,
    required TokenCounter tokenCounter,
  }) {
    final ctx = ErrorContext(
      component: 'HybridMemoryFactory',
      operation: '_createDevelopmentSetup',
      params: {'maxTokens': maxTokens},
    );

    try {
      final effectiveSummarizer = summarizer ?? DeterministicSummarizer();

      final strategy = SummarizationStrategyFactory.balanced(
        maxTokens: maxTokens,
        summarizer: effectiveSummarizer,
        tokenCounter: tokenCounter,
      );

      final config = MemoryConfig(
        maxTokens: maxTokens,
        semanticTopK: 3,
        minSimilarity: 0.5,
        enableSemanticMemory: true,
        enableSummarization: true,
      );

      return MemoryManager(
        contextStrategy: strategy,
        tokenCounter: tokenCounter,
        config: config,
        vectorStore: InMemoryVectorStore(),
        embeddingService: SimpleEmbeddingService(),
      );
    } catch (e, st) {
      ChatMemoryLogger.logError(
        _logger,
        '_createDevelopmentSetup',
        e,
        stackTrace: st,
        params: ctx.toMap(),
        shouldRethrow: true,
      );
      rethrow;
    }
  }

  /// Production preset: Persistent storage with semantic search
  static Future<MemoryManager> _createProductionSetup({
    required int maxTokens,
    Summarizer? summarizer,
    EmbeddingService? embeddingService,
    VectorStore? vectorStore,
    required TokenCounter tokenCounter,
    String? databasePath,
  }) async {
    final ctx = ErrorContext(
      component: 'HybridMemoryFactory',
      operation: '_createProductionSetup',
      params: {'maxTokens': maxTokens},
    );

    try {
      final effectiveSummarizer = summarizer ?? DeterministicSummarizer();
      final effectiveEmbeddingService =
          embeddingService ?? SimpleEmbeddingService();

      // If given vector store is null, create a LocalVectorStore and pass embedding dim when available.
      final effectiveVectorStore =
          vectorStore ??
          LocalVectorStore(
            databasePath: databasePath,
            expectedDimension: effectiveEmbeddingService.dimensions,
          );

      final strategy = SummarizationStrategyFactory.balanced(
        maxTokens: maxTokens,
        summarizer: effectiveSummarizer,
        tokenCounter: tokenCounter,
      );

      final config = MemoryConfig(
        maxTokens: maxTokens,
        semanticTopK: 5,
        minSimilarity: 0.3,
        enableSemanticMemory: true,
        enableSummarization: true,
        recencyWeight: 0.3,
      );

      return MemoryManager(
        contextStrategy: strategy,
        tokenCounter: tokenCounter,
        config: config,
        vectorStore: effectiveVectorStore,
        embeddingService: effectiveEmbeddingService,
      );
    } catch (e, st) {
      ChatMemoryLogger.logError(
        _logger,
        '_createProductionSetup',
        e,
        stackTrace: st,
        params: ctx.toMap(),
        shouldRethrow: true,
      );
      rethrow;
    }
  }

  /// Minimal preset: Only summarization, no semantic search
  static MemoryManager _createMinimalSetup({
    required int maxTokens,
    Summarizer? summarizer,
    required TokenCounter tokenCounter,
  }) {
    final ctx = ErrorContext(
      component: 'HybridMemoryFactory',
      operation: '_createMinimalSetup',
      params: {'maxTokens': maxTokens},
    );

    try {
      final effectiveSummarizer = summarizer ?? DeterministicSummarizer();

      final strategy = SummarizationStrategyFactory.aggressive(
        maxTokens: maxTokens,
        summarizer: effectiveSummarizer,
        tokenCounter: tokenCounter,
      );

      final config = MemoryConfig(
        maxTokens: maxTokens,
        enableSemanticMemory: false,
        enableSummarization: true,
      );

      return MemoryManager(
        contextStrategy: strategy,
        tokenCounter: tokenCounter,
        config: config,
        vectorStore: null,
        embeddingService: null,
      );
    } catch (e, st) {
      ChatMemoryLogger.logError(
        _logger,
        '_createMinimalSetup',
        e,
        stackTrace: st,
        params: ctx.toMap(),
        shouldRethrow: true,
      );
      rethrow;
    }
  }

  /// Performance preset: Optimized for large conversations
  static Future<MemoryManager> _createPerformanceSetup({
    required int maxTokens,
    Summarizer? summarizer,
    EmbeddingService? embeddingService,
    VectorStore? vectorStore,
    required TokenCounter tokenCounter,
    String? databasePath,
  }) async {
    final ctx = ErrorContext(
      component: 'HybridMemoryFactory',
      operation: '_createPerformanceSetup',
      params: {'maxTokens': maxTokens},
    );

    try {
      final effectiveSummarizer = summarizer ?? DeterministicSummarizer();
      final effectiveEmbeddingService =
          embeddingService ?? SimpleEmbeddingService();

      final effectiveVectorStore =
          vectorStore ??
          LocalVectorStore(
            databasePath: databasePath,
            tableName: 'perf_vectors',
            expectedDimension: effectiveEmbeddingService.dimensions,
          );

      final strategy = SummarizationStrategyFactory.aggressive(
        maxTokens: maxTokens,
        summarizer: effectiveSummarizer,
        tokenCounter: tokenCounter,
      );

      final config = MemoryConfig(
        maxTokens: maxTokens,
        semanticTopK: 8,
        minSimilarity: 0.25,
        enableSemanticMemory: true,
        enableSummarization: true,
        recencyWeight: 0.4,
      );

      return MemoryManager(
        contextStrategy: strategy,
        tokenCounter: tokenCounter,
        config: config,
        vectorStore: effectiveVectorStore,
        embeddingService: effectiveEmbeddingService,
      );
    } catch (e, st) {
      ChatMemoryLogger.logError(
        _logger,
        '_createPerformanceSetup',
        e,
        stackTrace: st,
        params: ctx.toMap(),
        shouldRethrow: true,
      );
      rethrow;
    }
  }

  /// Helper method to create a memory manager with Google AI services
  /// (Requires additional dependencies)
  static Future<MemoryManager> createWithGoogleAI({
    required int maxTokens,
    required String apiKey,
    MemoryPreset preset = MemoryPreset.production,
    String? databasePath,
  }) async {
    final ctx = ErrorContext(
      component: 'HybridMemoryFactory',
      operation: 'createWithGoogleAI',
      params: {'maxTokens': maxTokens, 'preset': preset.toString()},
    );
    try {
      Validation.validatePositive('maxTokens', maxTokens, context: ctx);
      return create(
        preset: preset,
        maxTokens: maxTokens,
        databasePath: databasePath,
      );
    } catch (e, st) {
      ChatMemoryLogger.logError(
        _logger,
        'createWithGoogleAI',
        e,
        stackTrace: st,
        params: ctx.toMap(),
        shouldRethrow: true,
      );
      rethrow;
    }
  }

  /// Helper method to create a memory manager with OpenAI services
  /// (Requires additional dependencies)
  static Future<MemoryManager> createWithOpenAI({
    required int maxTokens,
    required String apiKey,
    MemoryPreset preset = MemoryPreset.production,
    String? databasePath,
  }) async {
    final ctx = ErrorContext(
      component: 'HybridMemoryFactory',
      operation: 'createWithOpenAI',
      params: {'maxTokens': maxTokens, 'preset': preset.toString()},
    );
    try {
      Validation.validatePositive('maxTokens', maxTokens, context: ctx);
      return create(
        preset: preset,
        maxTokens: maxTokens,
        databasePath: databasePath,
      );
    } catch (e, st) {
      ChatMemoryLogger.logError(
        _logger,
        'createWithOpenAI',
        e,
        stackTrace: st,
        params: ctx.toMap(),
        shouldRethrow: true,
      );
      rethrow;
    }
  }
}

/// Builder pattern for more complex memory manager configuration
class MemoryManagerBuilder {
  int _maxTokens = 8000;
  MemoryConfig? _config;
  ContextStrategy? _strategy;
  TokenCounter? _tokenCounter;
  VectorStore? _vectorStore;
  EmbeddingService? _embeddingService;
  Summarizer? _summarizer;

  MemoryManagerBuilder();

  MemoryManagerBuilder withMaxTokens(int maxTokens) {
    final ctx = ErrorContext(
      component: 'MemoryManagerBuilder',
      operation: 'withMaxTokens',
      params: {'maxTokens': maxTokens},
    );
    Validation.validatePositive('maxTokens', maxTokens, context: ctx);
    _maxTokens = maxTokens;
    return this;
  }

  MemoryManagerBuilder withConfig(MemoryConfig config) {
    _config = config;
    return this;
  }

  MemoryManagerBuilder withStrategy(ContextStrategy strategy) {
    _strategy = strategy;
    return this;
  }

  MemoryManagerBuilder withTokenCounter(TokenCounter tokenCounter) {
    _tokenCounter = tokenCounter;
    return this;
  }

  MemoryManagerBuilder withVectorStore(VectorStore vectorStore) {
    _vectorStoreCompatibilityCheck(vectorStore);
    _vectorStore = vectorStore;
    return this;
  }

  MemoryManagerBuilder withEmbeddingService(EmbeddingService embeddingService) {
    _embeddingService = embeddingService;
    return this;
  }

  MemoryManagerBuilder withSummarizer(Summarizer summarizer) {
    _summarizer = summarizer;
    return this;
  }

  MemoryManagerBuilder withLocalVectorStore({String? databasePath}) {
    _vectorStore = LocalVectorStore(
      databasePath: databasePath,
      expectedDimension: _embeddingService?.dimensions,
    );
    return this;
  }

  MemoryManagerBuilder withInMemoryVectorStore() {
    _vectorStore = InMemoryVectorStore(
      expectedDimension: _embeddingService?.dimensions,
    );
    return this;
  }

  MemoryManagerBuilder withSimpleEmbedding({int dimensions = 384}) {
    _embeddingService = SimpleEmbeddingService(dimensions: dimensions);
    return this;
  }

  MemoryManagerBuilder enableSemanticMemory({
    int topK = 5,
    double minSimilarity = 0.3,
  }) {
    _config = (_config ?? const MemoryConfig()).copyWith(
      enableSemanticMemory: true,
      semanticTopK: topK,
      minSimilarity: minSimilarity,
    );
    return this;
  }

  MemoryManagerBuilder disableSemanticMemory() {
    _config = (_config ?? const MemoryConfig()).copyWith(
      enableSemanticMemory: false,
    );
    return this;
  }

  MemoryManager build() {
    final ctx = ErrorContext(
      component: 'MemoryManagerBuilder',
      operation: 'build',
      params: {'maxTokens': _maxTokens},
    );
    try {
      final tokenCounter = _tokenCounter ?? HeuristicTokenCounter();
      final summarizer = _summarizer ?? DeterministicSummarizer();

      final strategy =
          _strategy ??
          SummarizationStrategyFactory.balanced(
            maxTokens: _maxTokens,
            summarizer: summarizer,
            tokenCounter: tokenCounter,
          );

      final config = _config ?? MemoryConfig(maxTokens: _maxTokens);

      // If semantic memory is requested, ensure components are present
      if (config.enableSemanticMemory) {
        if (_vectorStore == null) {
          throw ConfigurationException.missing('vectorStore', context: ctx);
        }
        if (_embeddingService == null) {
          throw ConfigurationException.missing(
            'embeddingService',
            context: ctx,
          );
        }
      }

      return MemoryManager(
        contextStrategy: strategy,
        tokenCounter: tokenCounter,
        config: config,
        vectorStore: _vectorStore,
        embeddingService: _embeddingService,
      );
    } catch (e, st) {
      ChatMemoryLogger.logError(
        ChatMemoryLogger.loggerFor('factory.hybrid_memory'),
        'build',
        e,
        stackTrace: st,
        params: ctx.toMap(),
        shouldRethrow: true,
      );
      rethrow;
    }
  }

  void _vectorStoreCompatibilityCheck(VectorStore vs) {
    // Basic compatibility check placeholder: can be extended.
    // If embedding service is known, ensure the vector store can accept the dimension.
    if (_embeddingService != null) {
      final ctx = ErrorContext(
        component: 'MemoryManagerBuilder',
        operation: 'vectorStoreCompatibilityCheck',
        params: {'hasEmbeddingService': true},
      );
      try {
        // LocalVectorStore and InMemoryVectorStore accept expectedDimension in constructors;
        // if a custom VectorStore was provided, we only log a warning.
        if (vs is LocalVectorStore || vs is InMemoryVectorStore) {
          // Nothing to validate here because expectedDimension is passed on construction path.
          return;
        } else {
          ChatMemoryLogger.loggerFor('factory.hybrid_memory').warning(
            'Custom VectorStore provided; ensure embedding dimensionality compatibility with embeddingService',
            ctx.toMap(),
          );
        }
      } catch (e, st) {
        ChatMemoryLogger.logError(
          ChatMemoryLogger.loggerFor('factory.hybrid_memory'),
          '_vectorStoreCompatibilityCheck',
          e,
          stackTrace: st,
          params: ctx.toMap(),
          shouldRethrow: false,
        );
      }
    }
  }
}

/// Extension to add copyWith functionality to MemoryConfig
extension MemoryConfigExtension on MemoryConfig {
  MemoryConfig copyWith({
    int? maxTokens,
    int? semanticTopK,
    double? minSimilarity,
    bool? enableSemanticMemory,
    bool? enableSummarization,
    double? recencyWeight,
  }) {
    return MemoryConfig(
      maxTokens: maxTokens ?? this.maxTokens,
      semanticTopK: semanticTopK ?? this.semanticTopK,
      minSimilarity: minSimilarity ?? this.minSimilarity,
      enableSemanticMemory: enableSemanticMemory ?? this.enableSemanticMemory,
      enableSummarization: enableSummarization ?? this.enableSummarization,
      recencyWeight: recencyWeight ?? this.recencyWeight,
    );
  }
}

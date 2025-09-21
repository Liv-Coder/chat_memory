import '../models/message.dart';
import '../utils/token_counter.dart';
import '../summarizers/summarizer.dart';
import '../summarizers/deterministic_summarizer.dart';
import '../strategies/context_strategy.dart';
import '../strategies/summarization_strategy.dart';
import '../vector_stores/vector_store.dart';
import '../vector_stores/local_vector_store.dart';
import '../vector_stores/in_memory_vector_store.dart';
import '../embeddings/embedding_service.dart';
import '../embeddings/simple_embedding_service.dart';
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
  }

  /// Create a fully customized memory manager
  static MemoryManager createCustom({
    required ContextStrategy contextStrategy,
    required TokenCounter tokenCounter,
    MemoryConfig? memoryConfig,
    VectorStore? vectorStore,
    EmbeddingService? embeddingService,
  }) {
    return MemoryManager(
      contextStrategy: contextStrategy,
      tokenCounter: tokenCounter,
      config: memoryConfig ?? const MemoryConfig(),
      vectorStore: vectorStore,
      embeddingService: embeddingService,
    );
  }

  /// Development preset: Fast setup with in-memory storage
  static MemoryManager _createDevelopmentSetup({
    required int maxTokens,
    Summarizer? summarizer,
    required TokenCounter tokenCounter,
  }) {
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
    final effectiveSummarizer = summarizer ?? DeterministicSummarizer();
    final effectiveEmbeddingService =
        embeddingService ?? SimpleEmbeddingService();
    final effectiveVectorStore =
        vectorStore ?? LocalVectorStore(databasePath: databasePath);

    // Vector store will be initialized on first use

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
  }

  /// Minimal preset: Only summarization, no semantic search
  static MemoryManager _createMinimalSetup({
    required int maxTokens,
    Summarizer? summarizer,
    required TokenCounter tokenCounter,
  }) {
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
    final effectiveSummarizer = summarizer ?? DeterministicSummarizer();
    final effectiveEmbeddingService =
        embeddingService ?? SimpleEmbeddingService();
    final effectiveVectorStore =
        vectorStore ??
        LocalVectorStore(databasePath: databasePath, tableName: 'perf_vectors');

    // Vector store will be initialized on first use

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
  }

  /// Helper method to create a memory manager with Google AI services
  /// (Requires additional dependencies)
  static Future<MemoryManager> createWithGoogleAI({
    required int maxTokens,
    required String apiKey,
    MemoryPreset preset = MemoryPreset.production,
    String? databasePath,
  }) async {
    // This would require implementing GoogleAISummarizer and GoogleAIEmbeddingService
    // For now, falls back to standard services
    return create(
      preset: preset,
      maxTokens: maxTokens,
      databasePath: databasePath,
    );
  }

  /// Helper method to create a memory manager with OpenAI services
  /// (Requires additional dependencies)
  static Future<MemoryManager> createWithOpenAI({
    required int maxTokens,
    required String apiKey,
    MemoryPreset preset = MemoryPreset.production,
    String? databasePath,
  }) async {
    // This would require implementing OpenAISummarizer and OpenAIEmbeddingService
    // For now, falls back to standard services
    return create(
      preset: preset,
      maxTokens: maxTokens,
      databasePath: databasePath,
    );
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
    _vectorStore = LocalVectorStore(databasePath: databasePath);
    return this;
  }

  MemoryManagerBuilder withInMemoryVectorStore() {
    _vectorStore = InMemoryVectorStore();
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

    return MemoryManager(
      contextStrategy: strategy,
      tokenCounter: tokenCounter,
      config: config,
      vectorStore: _vectorStore,
      embeddingService: _embeddingService,
    );
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

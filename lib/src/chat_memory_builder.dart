import 'memory/hybrid_memory_factory.dart';
import 'conversation/enhanced_conversation_manager.dart';
import 'conversation/callbacks/callback_manager.dart';
import 'chat_memory_config.dart';
import 'chat_memory_facade.dart';
import 'core/errors.dart';
import 'core/logging/chat_memory_logger.dart';
import 'core/utils/token_counter.dart';
import 'memory/embeddings/embedding_service.dart';
import 'memory/vector_stores/vector_store.dart';
import 'memory/summarizers/summarizer.dart';
import 'memory/memory_manager.dart';

/// Builder class for fluent configuration of ChatMemory instances.
///
/// Provides a simple way to create ChatMemory instances with sensible defaults
/// while allowing customization for advanced use cases. Uses preset configurations
/// that hide the complexity of the underlying memory management system.
///
/// Example usage:
/// ```dart
/// // Quick setup with presets
/// final chatMemory = await ChatMemory.development();
/// final chatMemory = await ChatMemory.production();
/// final chatMemory = await ChatMemory.minimal();
///
/// // Custom configuration with system prompts
/// final chatMemory = await ChatMemoryBuilder()
///     .development()
///     .withSystemPrompt('You are a supportive financial coach.')
///     .withMaxTokens(4000)
///     .build();
///
/// // Disable system prompt
/// final chatMemory = await ChatMemoryBuilder()
///     .minimal()
///     .withoutSystemPrompt()
///     .build();
/// ```
class ChatMemoryBuilder {
  ChatMemoryConfig _config = ChatMemoryConfig.development();

  // Advanced options
  EmbeddingService? _customEmbeddingService;
  VectorStore? _customVectorStore;
  Summarizer? _customSummarizer;
  TokenCounter? _customTokenCounter;
  String? _databasePath;

  // Callback options
  SummaryCreatedCallback? _onSummaryCreated;
  MessageStoredCallback? _onMemoryOptimized;

  /// Creates a new ChatMemoryBuilder with development defaults.
  ChatMemoryBuilder();

  /// Factory method for development preset.
  ///
  /// Optimized for fast iteration with in-memory storage and enhanced logging.
  factory ChatMemoryBuilder.development() {
    return ChatMemoryBuilder()..development();
  }

  /// Factory method for production preset.
  ///
  /// Optimized for performance and reliability with persistent storage.
  factory ChatMemoryBuilder.production() {
    return ChatMemoryBuilder()..production();
  }

  /// Factory method for minimal preset.
  ///
  /// Basic functionality with minimal resource usage.
  factory ChatMemoryBuilder.minimal() {
    return ChatMemoryBuilder()..minimal();
  }

  /// Configure for development environment.
  ///
  /// - In-memory storage for fast startup
  /// - Lower token limits for faster processing
  /// - Enhanced logging enabled
  /// - Semantic memory enabled
  /// - System prompt enabled with default
  ChatMemoryBuilder development() {
    _config = ChatMemoryConfig.development();
    return this;
  }

  /// Configure for production environment.
  ///
  /// - Persistent local storage
  /// - Higher token limits for better context
  /// - Logging optimized for performance
  /// - Full semantic memory features
  /// - System prompt enabled with default
  ChatMemoryBuilder production() {
    _config = ChatMemoryConfig.production();
    return this;
  }

  /// Configure for minimal resource usage.
  ///
  /// - No persistent storage
  /// - Minimal token limits
  /// - Basic summarization only
  /// - No semantic memory
  /// - System prompt disabled for minimal resource usage
  ChatMemoryBuilder minimal() {
    _config = ChatMemoryConfig.minimal();
    return this;
  }

  /// Set maximum token limit for context.
  ///
  /// This controls how much conversation history can be included in the
  /// prompt sent to the LLM. Higher values provide more context but
  /// consume more tokens and may be slower.
  ///
  /// Valid range: 100 - 100,000 tokens
  ChatMemoryBuilder withMaxTokens(int maxTokens) {
    _config = _config.copyWith(maxTokens: maxTokens);
    return this;
  }

  /// Set a custom system prompt.
  ///
  /// The system prompt provides context and instructions to the AI about
  /// how it should behave in the conversation. It's automatically injected
  /// as the first message in every conversation.
  ///
  /// [prompt] - The custom system prompt text
  ///
  /// Example:
  /// ```dart
  /// .withSystemPrompt('You are a supportive financial coach.')
  /// ```
  ChatMemoryBuilder withSystemPrompt(String prompt) {
    _config = _config.copyWith(useSystemPrompt: true, systemPrompt: prompt);
    return this;
  }

  /// Use the default system prompt.
  ///
  /// Enables system prompt with the built-in friendly assistant behavior.
  /// This is the default for most presets.
  ///
  /// Example:
  /// ```dart
  /// .withDefaultSystemPrompt()
  /// ```
  ChatMemoryBuilder withDefaultSystemPrompt() {
    _config = _config.copyWith(
      useSystemPrompt: true,
      systemPrompt: null, // Use default
    );
    return this;
  }

  /// Disable system prompt injection.
  ///
  /// Prevents any system prompt from being automatically added to
  /// conversations. Useful for minimal setups or when you want to
  /// handle system prompts manually.
  ///
  /// Example:
  /// ```dart
  /// .withoutSystemPrompt()
  /// ```
  ChatMemoryBuilder withoutSystemPrompt() {
    _config = _config.copyWith(useSystemPrompt: false);
    return this;
  }

  /// Enable or disable system prompt.
  ///
  /// Provides programmatic control over system prompt behavior.
  ///
  /// [enabled] - Whether to enable system prompt injection
  ///
  /// Example:
  /// ```dart
  /// .withSystemPromptEnabled(shouldUseSystemPrompt)
  /// ```
  ChatMemoryBuilder withSystemPromptEnabled(bool enabled) {
    _config = _config.copyWith(useSystemPrompt: enabled);
    return this;
  }

  /// Configure semantic memory and retrieval.
  ///
  /// When enabled, the system can retrieve relevant past messages based on
  /// semantic similarity to the current query, even if they're not recent.
  ///
  /// [enabled] - Whether to enable semantic memory
  /// [topK] - Number of similar messages to retrieve (default: 5)
  /// [minSimilarity] - Minimum similarity threshold (0.0-1.0, default: 0.3)
  ChatMemoryBuilder withSemanticMemory({
    required bool enabled,
    int topK = 5,
    double minSimilarity = 0.3,
  }) {
    _config = _config.copyWith(enableMemory: enabled);
    // Additional semantic configuration would be stored separately
    // for passing to the underlying factory
    return this;
  }

  /// Configure conversation summarization.
  ///
  /// When enabled, old conversation history is automatically summarized
  /// to fit within token limits while preserving important information.
  ///
  /// [enabled] - Whether to enable summarization
  ChatMemoryBuilder withSummarization({required bool enabled}) {
    _config = _config.copyWith(enableSummarization: enabled);
    return this;
  }

  /// Configure detailed logging.
  ///
  /// Useful for debugging and monitoring the memory system's behavior.
  /// Should generally be disabled in production for performance.
  ///
  /// [enabled] - Whether to enable detailed logging
  ChatMemoryBuilder withLogging({required bool enabled}) {
    _config = _config.copyWith(enableLogging: enabled);
    return this;
  }

  /// Configure data persistence.
  ///
  /// When enabled, conversation history and embeddings are saved to disk
  /// and restored between sessions.
  ///
  /// [enabled] - Whether to enable persistence
  /// [databasePath] - Optional custom path for the database file
  ChatMemoryBuilder withPersistence({
    required bool enabled,
    String? databasePath,
  }) {
    _config = _config.copyWith(enablePersistence: enabled);
    _databasePath = databasePath;
    return this;
  }

  /// Set custom embedding service for semantic memory.
  ///
  /// The embedding service converts text into numerical vectors for
  /// semantic similarity comparison. Only used if semantic memory is enabled.
  ///
  /// [embeddingService] - Custom embedding service implementation
  ChatMemoryBuilder withEmbeddingService(EmbeddingService embeddingService) {
    _customEmbeddingService = embeddingService;
    return this;
  }

  /// Set custom vector store for semantic memory.
  ///
  /// The vector store saves and retrieves embeddings for similarity search.
  /// Only used if semantic memory is enabled.
  ///
  /// [vectorStore] - Custom vector store implementation
  ChatMemoryBuilder withVectorStore(VectorStore vectorStore) {
    _customVectorStore = vectorStore;
    return this;
  }

  /// Set custom summarizer for conversation history.
  ///
  /// The summarizer condenses old conversation history when token limits
  /// are exceeded. Only used if summarization is enabled.
  ///
  /// [summarizer] - Custom summarizer implementation
  ChatMemoryBuilder withSummarizer(Summarizer summarizer) {
    _customSummarizer = summarizer;
    return this;
  }

  /// Set custom token counter for accurate token estimation.
  ///
  /// The token counter estimates how many tokens text will consume when
  /// sent to an LLM. Used for staying within token limits.
  ///
  /// [tokenCounter] - Custom token counter implementation
  ChatMemoryBuilder withTokenCounter(TokenCounter tokenCounter) {
    _customTokenCounter = tokenCounter;
    return this;
  }

  /// Set callback for when conversation summaries are created.
  ///
  /// Called whenever the system automatically summarizes old conversation
  /// history. Useful for logging or taking custom actions.
  ///
  /// [callback] - Function to call when summaries are created
  ChatMemoryBuilder withSummaryCallback(SummaryCreatedCallback callback) {
    _onSummaryCreated = callback;
    return this;
  }

  /// Set callback for when memory is optimized.
  ///
  /// Called when the system performs cleanup operations like removing
  /// old messages or optimizing storage. Useful for monitoring.
  ///
  /// [callback] - Function to call when memory is optimized
  ChatMemoryBuilder withMemoryCallback(MessageStoredCallback callback) {
    _onMemoryOptimized = callback;
    return this;
  }

  /// Set callback for when context is built for LLM prompts.
  ///
  /// Called each time the system builds context for an LLM prompt.
  /// Useful for debugging or custom processing.
  ///
  /// [callback] - Function to call when context is built
  ChatMemoryBuilder withContextCallback(MessageStoredCallback callback) {
    // Context callback not currently supported in simplified API
    return this;
  }

  /// Set multiple callbacks at once for convenience.
  ///
  /// [onSummaryCreated] - Called when summaries are created
  /// [onMemoryOptimized] - Called when memory is optimized
  /// [onContextBuilt] - Called when context is built
  ChatMemoryBuilder withCallbacks({
    SummaryCreatedCallback? onSummaryCreated,
    MessageStoredCallback? onMemoryOptimized,
    MessageStoredCallback? onContextBuilt,
  }) {
    if (onSummaryCreated != null) _onSummaryCreated = onSummaryCreated;
    if (onMemoryOptimized != null) _onMemoryOptimized = onMemoryOptimized;
    // onContextBuilt is not currently supported in simplified API
    return this;
  }

  /// Build the ChatMemory instance with the current configuration.
  ///
  /// This creates all the underlying components (memory manager, conversation
  /// manager, etc.) and wires them together according to the configuration.
  ///
  /// Returns a ready-to-use ChatMemory instance.
  ///
  /// Throws [ConfigurationException] if the configuration is invalid.
  /// Throws [MemoryException] if initialization fails.
  Future<ChatMemory> build() async {
    final ctx = ErrorContext(
      component: 'ChatMemoryBuilder',
      operation: 'build',
      params: {
        'preset': _config.preset.name,
        'maxTokens': _config.maxTokens,
        'enableMemory': _config.enableMemory,
        'useSystemPrompt': _config.useSystemPrompt,
        'systemPromptLength':
            _config.systemPrompt?.length ??
            (_config.useSystemPrompt
                ? ChatMemoryConfig.defaultSystemPrompt.length
                : 0),
      },
    );

    try {
      // Validate configuration including system prompt
      _config.validate();

      // Create memory manager using HybridMemoryFactory
      final memoryManager = await _createMemoryManager();

      // Create enhanced conversation manager
      final conversationManager = EnhancedConversationManager(
        memoryManager: memoryManager,
        onSummaryCreated: _onSummaryCreated,
        onMessageStored: _onMemoryOptimized,
      );

      // Create and return ChatMemory facade
      return ChatMemory.fromBuilder(
        conversationManager: conversationManager,
        config: _config,
      );
    } catch (e, st) {
      ChatMemoryLogger.logError(
        ChatMemoryLogger.loggerFor('chat_memory.builder'),
        'build',
        e,
        stackTrace: st,
        params: ctx.toMap(),
        shouldRethrow: true,
      );
      rethrow;
    }
  }

  /// Create the memory manager based on configuration.
  Future<MemoryManager> _createMemoryManager() async {
    return await HybridMemoryFactory.create(
      preset: _config.toMemoryPreset(),
      maxTokens: _config.maxTokens,
      customSummarizer: _customSummarizer,
      customEmbeddingService: _customEmbeddingService,
      customVectorStore: _customVectorStore,
      customTokenCounter: _customTokenCounter,
      databasePath: _databasePath,
    );
  }
}

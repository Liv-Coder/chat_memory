import 'dart:async';

import 'message_chunker.dart';
import 'embedding_pipeline.dart';
import '../memory/vector_stores/vector_store.dart';
import '../memory/session_store.dart';
import '../core/models/message.dart';
import '../core/errors.dart';
import '../core/logging/chat_memory_logger.dart';

/// Processing stages that can be executed by the pipeline.
enum ProcessingStage {
  validation,
  chunking,
  embedding,
  storage,
  postProcessing,
}

/// Configuration for pipeline processing.
class ProcessingConfig {
  /// Stages to execute in order.
  final List<ProcessingStage> stages;

  /// Chunking configuration
  final ChunkingConfig chunkingConfig;

  /// Embedding configuration
  final EmbeddingConfig embeddingConfig;

  /// Processing mode
  final ProcessingMode mode;

  /// Whether to continue on errors
  final bool continueOnError;

  /// Maximum concurrent operations
  final int maxConcurrency;

  const ProcessingConfig({
    this.stages = const [
      ProcessingStage.validation,
      ProcessingStage.chunking,
      ProcessingStage.embedding,
      ProcessingStage.storage,
    ],
    this.chunkingConfig = const ChunkingConfig(),
    this.embeddingConfig = const EmbeddingConfig(),
    this.mode = ProcessingMode.parallel,
    this.continueOnError = false,
    this.maxConcurrency = 10,
  });
}

/// Error information for processing failures.
class ProcessingError {
  /// Stage where the error occurred.
  final ProcessingStage stage;

  /// Error message
  final String message;

  /// Original exception
  final Object? exception;

  /// Stack trace if available
  final StackTrace? stackTrace;

  /// Additional context
  final Map<String, dynamic>? context;

  const ProcessingError({
    required this.stage,
    required this.message,
    this.exception,
    this.stackTrace,
    this.context,
  });

  @override
  String toString() {
    return 'ProcessingError(stage: $stage, message: $message)';
  }
}

/// Statistics about processing operations.
class ProcessingStats {
  /// Total messages processed.
  final int totalMessages;

  /// Successfully processed messages
  final int successfulMessages;

  /// Total chunks created
  final int totalChunks;

  /// Total processing time in milliseconds
  final int processingTimeMs;

  /// Time spent in each stage
  final Map<ProcessingStage, int> stageTimings;

  const ProcessingStats({
    required this.totalMessages,
    required this.successfulMessages,
    required this.totalChunks,
    required this.processingTimeMs,
    required this.stageTimings,
  });

  /// Success rate (0.0 to 1.0)
  double get successRate {
    return totalMessages > 0 ? successfulMessages / totalMessages : 0.0;
  }

  @override
  String toString() {
    return 'ProcessingStats(messages: $totalMessages, success: $successfulMessages, '
        'chunks: $totalChunks, time: ${processingTimeMs}ms, rate: ${(successRate * 100).toStringAsFixed(1)}%)';
  }
}

/// Result of pipeline processing.
class ProcessingResult {
  /// Successfully processed messages.
  final List<Message> processedMessages;

  /// Generated chunks
  final List<MessageChunk> chunks;

  /// Embedding results if applicable
  final EmbeddingResult? embeddingResult;

  /// Processing errors
  final List<ProcessingError> errors;

  /// Processing statistics
  final ProcessingStats stats;

  const ProcessingResult({
    required this.processedMessages,
    required this.chunks,
    this.embeddingResult,
    required this.errors,
    required this.stats,
  });

  /// Whether processing was completely successful
  bool get isSuccess => errors.isEmpty;

  /// Whether processing had partial success
  bool get hasPartialSuccess =>
      processedMessages.isNotEmpty && errors.isNotEmpty;
}

/// Main pipeline orchestrator for message processing.
///
/// Coordinates validation, chunking, embedding, storage, and post-processing
/// stages based on the provided `ProcessingConfig`.
class MessageProcessor {
  final MessageChunker? _chunker;
  final EmbeddingPipeline? _embeddingPipeline;
  final VectorStore? _vectorStore;
  final SessionStore? _sessionStore;
  final _logger = ChatMemoryLogger.loggerFor('processing.message_processor');

  MessageProcessor({
    MessageChunker? chunker,
    EmbeddingPipeline? embeddingPipeline,
    VectorStore? vectorStore,
    SessionStore? sessionStore,
  }) : _chunker = chunker,
       _embeddingPipeline = embeddingPipeline,
       _vectorStore = vectorStore,
       _sessionStore = sessionStore;

  /// Process a list of messages through the configured pipeline.
  Future<ProcessingResult> processMessages(
    List<Message> messages,
    ProcessingConfig config,
  ) async {
    final opCtx = ErrorContext(
      component: 'MessageProcessor',
      operation: 'processMessages',
      params: {'messageCount': messages.length},
    );

    final stopwatch = Stopwatch()..start();
    final stageTimings = <ProcessingStage, int>{};
    final errors = <ProcessingError>[];

    try {
      _logger.fine('Starting message processing', opCtx.toMap());

      var currentMessages = messages;
      var chunks = <MessageChunk>[];
      EmbeddingResult? embeddingResult;

      // Execute configured stages in order
      for (final stage in config.stages) {
        final stageStopwatch = Stopwatch()..start();

        try {
          _logger.fine('Executing stage: $stage', opCtx.toMap());

          switch (stage) {
            case ProcessingStage.validation:
              currentMessages = await _validateMessages(
                currentMessages,
                config,
              );
              break;

            case ProcessingStage.chunking:
              chunks = await _chunkMessages(currentMessages, config);
              break;

            case ProcessingStage.embedding:
              embeddingResult = await _embedChunks(chunks, config);
              break;

            case ProcessingStage.storage:
              await _storeResults(chunks, embeddingResult, config);
              break;

            case ProcessingStage.postProcessing:
              await _postProcess(chunks, embeddingResult, config);
              break;
          }

          stageStopwatch.stop();
          stageTimings[stage] = stageStopwatch.elapsedMilliseconds;

          _logger.fine('Stage $stage completed', {
            ...opCtx.toMap(),
            'timeMs': stageStopwatch.elapsedMilliseconds,
          });
        } catch (e, st) {
          stageStopwatch.stop();
          stageTimings[stage] = stageStopwatch.elapsedMilliseconds;

          final error = ProcessingError(
            stage: stage,
            message: 'Stage $stage failed: $e',
            exception: e,
            stackTrace: st,
            context: opCtx.toMap(),
          );

          errors.add(error);

          _logger.warning('Stage $stage failed', {
            ...opCtx.toMap(),
            'error': e.toString(),
            'timeMs': stageStopwatch.elapsedMilliseconds,
          });

          if (!config.continueOnError) {
            _logger.severe('Stopping pipeline due to error in stage $stage');
            break;
          }
        }
      }

      stopwatch.stop();

      final stats = ProcessingStats(
        totalMessages: messages.length,
        successfulMessages: messages.length - errors.length,
        totalChunks: chunks.length,
        processingTimeMs: stopwatch.elapsedMilliseconds,
        stageTimings: stageTimings,
      );

      return ProcessingResult(
        processedMessages: currentMessages,
        chunks: chunks,
        embeddingResult: embeddingResult,
        errors: errors,
        stats: stats,
      );
    } catch (e, st) {
      stopwatch.stop();

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

  /// Process a single message through the pipeline.
  Future<ProcessingResult> processSingleMessage(
    Message message,
    ProcessingConfig config,
  ) async {
    return await processMessages([message], config);
  }

  /// Get a brief health status for pipeline components.
  Map<String, dynamic> getHealthStatus() {
    return {
      'chunker': _chunker != null ? 'available' : 'unavailable',
      'embeddingPipeline': _embeddingPipeline != null
          ? 'available'
          : 'unavailable',
      'vectorStore': _vectorStore != null ? 'available' : 'unavailable',
      'sessionStore': _sessionStore != null ? 'available' : 'unavailable',
      'circuitBreakerStatus': _embeddingPipeline?.getCircuitBreakerStatus(),
    };
  }

  /// Get statistics from underlying components (chunker, embedding).
  Map<String, dynamic> getComponentStatistics() {
    return {
      'chunking': _chunker?.getStatistics(),
      'embedding': _embeddingPipeline?.getStatistics(),
    };
  }

  // Private stage implementations
  Future<List<Message>> _validateMessages(
    List<Message> messages,
    ProcessingConfig config,
  ) async {
    return messages
        .where((message) => message.content.isNotEmpty && message.id.isNotEmpty)
        .toList();
  }

  Future<List<MessageChunk>> _chunkMessages(
    List<Message> messages,
    ProcessingConfig config,
  ) async {
    if (_chunker == null) return [];

    final allChunks = <MessageChunk>[];
    for (final message in messages) {
      final chunks = await _chunker!.chunkMessage(
        message,
        config.chunkingConfig,
      );
      allChunks.addAll(chunks);
    }
    return allChunks;
  }

  Future<EmbeddingResult?> _embedChunks(
    List<MessageChunk> chunks,
    ProcessingConfig config,
  ) async {
    if (_embeddingPipeline == null || chunks.isEmpty) return null;
    return await _embeddingPipeline!.processChunks(
      chunks,
      config.embeddingConfig,
    );
  }

  Future<void> _storeResults(
    List<MessageChunk> chunks,
    EmbeddingResult? embeddingResult,
    ProcessingConfig config,
  ) async {
    if (_sessionStore != null && chunks.isNotEmpty) {
      final messages = chunks
          .map(
            (chunk) => chunk.toMessage(
              role: MessageRole.user,
              timestamp: DateTime.now().toUtc(),
            ),
          )
          .toList();

      for (final message in messages) {
        await _sessionStore!.storeMessage(message);
      }
    }
  }

  Future<void> _postProcess(
    List<MessageChunk> chunks,
    EmbeddingResult? embeddingResult,
    ProcessingConfig config,
  ) async {
    // Custom post-processing logic can be added here
    _logger.fine('Post-processing completed', {
      'chunkCount': chunks.length,
      'embeddingCount': embeddingResult?.embeddings.length ?? 0,
    });
  }
}

/// Builder pattern for creating configured MessageProcessor instances
class MessageProcessorBuilder {
  MessageChunker? _chunker;
  EmbeddingPipeline? _embeddingPipeline;
  VectorStore? _vectorStore;
  SessionStore? _sessionStore;

  /// Set the message chunker
  MessageProcessorBuilder withChunker(MessageChunker chunker) {
    _chunker = chunker;
    return this;
  }

  /// Set the embedding pipeline
  MessageProcessorBuilder withEmbeddingPipeline(EmbeddingPipeline pipeline) {
    _embeddingPipeline = pipeline;
    return this;
  }

  /// Set the vector store
  MessageProcessorBuilder withVectorStore(VectorStore vectorStore) {
    _vectorStore = vectorStore;
    return this;
  }

  /// Set the session store
  MessageProcessorBuilder withSessionStore(SessionStore sessionStore) {
    _sessionStore = sessionStore;
    return this;
  }

  /// Build the configured MessageProcessor
  MessageProcessor build() {
    return MessageProcessor(
      chunker: _chunker,
      embeddingPipeline: _embeddingPipeline,
      vectorStore: _vectorStore,
      sessionStore: _sessionStore,
    );
  }
}

/// Factory for creating common MessageProcessor configurations
class MessageProcessorFactory {
  /// Create a basic processor with minimal components
  static MessageProcessor createBasic({required MessageChunker chunker}) {
    return MessageProcessorBuilder().withChunker(chunker).build();
  }

  /// Create a full-featured processor with all components
  static MessageProcessor createFull({
    required MessageChunker chunker,
    required EmbeddingPipeline embeddingPipeline,
    required VectorStore vectorStore,
    required SessionStore sessionStore,
  }) {
    return MessageProcessorBuilder()
        .withChunker(chunker)
        .withEmbeddingPipeline(embeddingPipeline)
        .withVectorStore(vectorStore)
        .withSessionStore(sessionStore)
        .build();
  }

  /// Create a processor optimized for development
  static MessageProcessor createDevelopment({
    required MessageChunker chunker,
    required EmbeddingPipeline embeddingPipeline,
  }) {
    return MessageProcessorBuilder()
        .withChunker(chunker)
        .withEmbeddingPipeline(embeddingPipeline)
        .build();
  }

  /// Create a processor optimized for production
  static MessageProcessor createProduction({
    required MessageChunker chunker,
    required EmbeddingPipeline embeddingPipeline,
    required VectorStore vectorStore,
    required SessionStore sessionStore,
  }) {
    return MessageProcessorBuilder()
        .withChunker(chunker)
        .withEmbeddingPipeline(embeddingPipeline)
        .withVectorStore(vectorStore)
        .withSessionStore(sessionStore)
        .build();
  }
}

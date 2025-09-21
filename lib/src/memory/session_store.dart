import '../errors.dart';
import '../logging/chat_memory_logger.dart';
import '../models/message.dart';
import '../vector_stores/vector_store.dart';
import '../embeddings/embedding_service.dart';
import 'memory_manager.dart';

/// Handles message persistence and vector storage operations
///
/// This class encapsulates all message storage logic including vector
/// embeddings generation, batch operations, and retry mechanisms with
/// proper error handling and logging.
class SessionStore {
  final VectorStore? _vectorStore;
  final EmbeddingService? _embeddingService;
  final MemoryConfig _config;
  final _logger = ChatMemoryLogger.loggerFor('memory.session_store');

  SessionStore({
    VectorStore? vectorStore,
    EmbeddingService? embeddingService,
    required MemoryConfig config,
  }) : _vectorStore = vectorStore,
       _embeddingService = embeddingService,
       _config = config;

  /// Store a single message with vector embedding if semantic memory is enabled
  Future<void> storeMessage(Message message) async {
    final opCtx = ErrorContext(
      component: 'SessionStore',
      operation: 'storeMessage',
      params: {'messageId': message.id, 'role': message.role.toString()},
    );

    try {
      // Skip system and summary messages for semantic storage
      if (!_shouldStoreMessage(message)) {
        _logger.fine('Skipping storage for message type', opCtx.toMap());
        return;
      }

      if (!_config.enableSemanticMemory ||
          _vectorStore == null ||
          _embeddingService == null) {
        _logger.fine(
          'Semantic memory disabled, skipping vector storage',
          opCtx.toMap(),
        );
        return;
      }

      await _storeMessageWithRetry(message, opCtx);
      _logger.fine('Message stored successfully', opCtx.toMap());
    } catch (e, st) {
      ChatMemoryLogger.logError(
        _logger,
        'storeMessage',
        e,
        stackTrace: st,
        params: opCtx.toMap(),
        shouldRethrow: false,
      );
      throw MemoryException(
        'Failed to store message',
        cause: e,
        stackTrace: st,
        context: opCtx,
      );
    }
  }

  /// Store multiple messages in batch with efficient embedding generation
  Future<void> storeMessageBatch(List<Message> messages) async {
    final opCtx = ErrorContext(
      component: 'SessionStore',
      operation: 'storeMessageBatch',
      params: {'messageCount': messages.length},
    );

    try {
      if (!_config.enableSemanticMemory ||
          _vectorStore == null ||
          _embeddingService == null) {
        _logger.fine(
          'Semantic memory disabled, skipping batch storage',
          opCtx.toMap(),
        );
        return;
      }

      // Filter messages that should be stored
      final storableMessages = messages.where(_shouldStoreMessage).toList();
      if (storableMessages.isEmpty) {
        _logger.fine('No storable messages in batch', opCtx.toMap());
        return;
      }

      await _storeMessageBatchWithRetry(storableMessages, opCtx);
      _logger.fine('Message batch stored successfully', {
        ...opCtx.toMap(),
        'storedCount': storableMessages.length,
      });
    } catch (e, st) {
      ChatMemoryLogger.logError(
        _logger,
        'storeMessageBatch',
        e,
        stackTrace: st,
        params: opCtx.toMap(),
        shouldRethrow: false,
      );
      throw MemoryException(
        'Failed to store message batch',
        cause: e,
        stackTrace: st,
        context: opCtx,
      );
    }
  }

  /// Check if a message should be stored in vector storage
  bool _shouldStoreMessage(Message message) {
    return message.role != MessageRole.system &&
        message.role != MessageRole.summary;
  }

  /// Store a single message with retry logic and exponential backoff
  Future<void> _storeMessageWithRetry(
    Message message,
    ErrorContext opCtx,
  ) async {
    const maxRetries = 3;
    var retryCount = 0;
    var delay = const Duration(milliseconds: 100);

    while (retryCount < maxRetries) {
      try {
        // Generate embedding
        final embedding = await _embeddingService!.embed(message.content);

        // Validate embedding
        if (embedding.isEmpty) {
          throw VectorStoreException(
            'Empty embedding generated',
            context: opCtx,
          );
        }

        // Store in vector store
        final vectorEntry = message.toVectorEntry(embedding);
        await _vectorStore!.store(vectorEntry);
        return;
      } catch (e) {
        retryCount++;
        _logger.warning('Storage attempt $retryCount failed', {
          ...opCtx.toMap(),
          'error': e.toString(),
          'retryCount': retryCount,
        });

        if (retryCount >= maxRetries) {
          rethrow;
        }

        // Exponential backoff
        await Future.delayed(delay);
        delay = Duration(milliseconds: delay.inMilliseconds * 2);
      }
    }
  }

  /// Store multiple messages with batch embedding generation and retry logic
  Future<void> _storeMessageBatchWithRetry(
    List<Message> messages,
    ErrorContext opCtx,
  ) async {
    const maxRetries = 3;
    var retryCount = 0;
    var delay = const Duration(milliseconds: 100);

    while (retryCount < maxRetries) {
      try {
        // Generate embeddings in batch
        final contents = messages.map((m) => m.content).toList();
        final embeddings = await _embeddingService!.embedBatch(contents);

        // Validate embeddings
        if (embeddings.length != messages.length) {
          throw VectorStoreException(
            'Embedding count mismatch: expected=${messages.length}, actual=${embeddings.length}',
            context: opCtx,
          );
        }

        // Create vector entries
        final vectorEntries = <VectorEntry>[];
        for (var i = 0; i < messages.length; i++) {
          if (embeddings[i].isEmpty) {
            throw VectorStoreException(
              'Empty embedding in batch at index $i',
              context: opCtx,
            );
          }
          vectorEntries.add(messages[i].toVectorEntry(embeddings[i]));
        }

        // Store in vector store
        await _vectorStore!.storeBatch(vectorEntries);
        return;
      } catch (e) {
        retryCount++;
        _logger.warning('Batch storage attempt $retryCount failed', {
          ...opCtx.toMap(),
          'error': e.toString(),
          'retryCount': retryCount,
        });

        if (retryCount >= maxRetries) {
          rethrow;
        }

        // Exponential backoff
        await Future.delayed(delay);
        delay = Duration(milliseconds: delay.inMilliseconds * 2);
      }
    }
  }
}

import 'dart:math';

import '../errors.dart';
import '../logging/chat_memory_logger.dart';
import '../models/message.dart';
import '../utils/token_counter.dart';

/// Chunking strategies for different content types
enum ChunkingStrategy {
  /// Fixed token count chunking
  fixedToken,

  /// Fixed character count chunking
  fixedChar,

  /// Word-boundary aware chunking
  wordBoundary,

  /// Sentence-boundary aware chunking
  sentenceBoundary,

  /// Paragraph-boundary aware chunking
  paragraphBoundary,

  /// Sliding window with overlap
  slidingWindow,

  /// Custom delimiter-based chunking
  delimiter,

  /// Semantic-aware chunking (future enhancement)
  semantic,
}

/// Configuration for message chunking behavior
class ChunkingConfig {
  /// Maximum tokens per chunk
  final int maxChunkTokens;

  /// Maximum characters per chunk
  final int maxChunkChars;

  /// Minimum chunk size to avoid tiny fragments
  final int minChunkSize;

  /// Overlap ratio for sliding window (0.0 to 1.0)
  final double overlapRatio;

  /// Chunking strategy to use
  final ChunkingStrategy strategy;

  /// Whether to preserve word boundaries
  final bool preserveWords;

  /// Whether to preserve sentence boundaries
  final bool preserveSentences;

  /// Custom delimiters for delimiter strategy
  final List<String> customDelimiters;

  /// Maximum number of chunks per message
  final int maxChunksPerMessage;

  const ChunkingConfig({
    this.maxChunkTokens = 500,
    this.maxChunkChars = 2000,
    this.minChunkSize = 50,
    this.overlapRatio = 0.1,
    this.strategy = ChunkingStrategy.fixedToken,
    this.preserveWords = true,
    this.preserveSentences = false,
    this.customDelimiters = const [],
    this.maxChunksPerMessage = 100,
  });
}

/// A chunk of content from a larger message
class MessageChunk {
  /// Unique identifier for this chunk
  final String id;

  /// Content of the chunk
  final String content;

  /// ID of the parent message
  final String parentMessageId;

  /// Index of this chunk within the parent message
  final int chunkIndex;

  /// Total number of chunks from the parent message
  final int totalChunks;

  /// Start position in the original message
  final int startPosition;

  /// End position in the original message
  final int endPosition;

  /// Estimated token count for this chunk
  final int estimatedTokens;

  /// Additional metadata for the chunk
  final Map<String, dynamic>? metadata;

  const MessageChunk({
    required this.id,
    required this.content,
    required this.parentMessageId,
    required this.chunkIndex,
    required this.totalChunks,
    required this.startPosition,
    required this.endPosition,
    required this.estimatedTokens,
    this.metadata,
  });

  /// Convert chunk back to a Message
  Message toMessage({required MessageRole role, required DateTime timestamp}) {
    final chunkMetadata = <String, dynamic>{
      'isChunk': true,
      'parentMessageId': parentMessageId,
      'chunkIndex': chunkIndex,
      'totalChunks': totalChunks,
      'startPosition': startPosition,
      'endPosition': endPosition,
      ...?metadata,
    };

    return Message(
      id: id,
      role: role,
      content: content,
      timestamp: timestamp,
      metadata: chunkMetadata,
    );
  }
}

/// Statistics about chunking operations
class ChunkingStats {
  /// Total messages processed
  final int totalMessages;

  /// Total chunks created
  final int totalChunks;

  /// Average chunks per message
  final double averageChunksPerMessage;

  /// Average chunk size in characters
  final double averageChunkSize;

  /// Processing time in milliseconds
  final int processingTimeMs;

  /// Chunk size distribution
  final Map<String, int> sizeDistribution;

  const ChunkingStats({
    required this.totalMessages,
    required this.totalChunks,
    required this.averageChunksPerMessage,
    required this.averageChunkSize,
    required this.processingTimeMs,
    required this.sizeDistribution,
  });
}

/// Intelligent message chunker with configurable strategies
class MessageChunker {
  final TokenCounter _tokenCounter;
  final _logger = ChatMemoryLogger.loggerFor('processing.message_chunker');

  // Statistics tracking
  int _totalMessagesProcessed = 0;
  int _totalChunksCreated = 0;
  int _totalProcessingTimeMs = 0;
  final List<int> _chunkSizes = [];

  MessageChunker({required TokenCounter tokenCounter})
    : _tokenCounter = tokenCounter;

  /// Chunk a single message into smaller pieces
  Future<List<MessageChunk>> chunkMessage(
    Message message,
    ChunkingConfig config,
  ) async {
    final opCtx = ErrorContext(
      component: 'MessageChunker',
      operation: 'chunkMessage',
      params: {
        'messageId': message.id,
        'contentLength': message.content.length,
        'strategy': config.strategy.toString(),
      },
    );

    try {
      Validation.validateNonEmptyString(
        'content',
        message.content,
        context: opCtx,
      );
      Validation.validateNonEmptyString(
        'messageId',
        message.id,
        context: opCtx,
      );

      _logger.fine('Starting message chunking', opCtx.toMap());

      // Check if message needs chunking
      final messageTokens = _tokenCounter.estimateTokens(message.content);
      if (messageTokens <= config.maxChunkTokens &&
          message.content.length <= config.maxChunkChars) {
        // Message is small enough, return as single chunk
        final chunk = MessageChunk(
          id: '${message.id}_chunk_0',
          content: message.content,
          parentMessageId: message.id,
          chunkIndex: 0,
          totalChunks: 1,
          startPosition: 0,
          endPosition: message.content.length,
          estimatedTokens: messageTokens,
        );

        _updateStatistics(message, [chunk]);
        return [chunk];
      }

      // Apply chunking strategy
      final chunks = await _applyChunkingStrategy(message, config, opCtx);

      // Update statistics
      _updateStatistics(message, chunks);

      _logger.fine('Message chunking completed', {
        ...opCtx.toMap(),
        'chunksCreated': chunks.length,
        'totalChars': chunks.fold<int>(
          0,
          (sum, chunk) => sum + chunk.content.length,
        ),
      });

      return chunks;
    } catch (e, st) {
      ChatMemoryLogger.logError(
        _logger,
        'chunkMessage',
        e,
        stackTrace: st,
        params: opCtx.toMap(),
        shouldRethrow: true,
      );
      rethrow;
    }
  }

  /// Chunk multiple messages efficiently
  Future<List<MessageChunk>> chunkMessages(
    List<Message> messages,
    ChunkingConfig config,
  ) async {
    final opCtx = ErrorContext(
      component: 'MessageChunker',
      operation: 'chunkMessages',
      params: {'messageCount': messages.length},
    );

    try {
      Validation.validateListNotEmpty('messages', messages, context: opCtx);

      final allChunks = <MessageChunk>[];

      for (final message in messages) {
        final chunks = await chunkMessage(message, config);
        allChunks.addAll(chunks);
      }

      _logger.fine('Batch chunking completed', {
        ...opCtx.toMap(),
        'totalChunks': allChunks.length,
      });

      return allChunks;
    } catch (e, st) {
      ChatMemoryLogger.logError(
        _logger,
        'chunkMessages',
        e,
        stackTrace: st,
        params: opCtx.toMap(),
        shouldRethrow: true,
      );
      rethrow;
    }
  }

  /// Get chunking statistics
  ChunkingStats getStatistics() {
    final avgChunksPerMessage = _totalMessagesProcessed > 0
        ? _totalChunksCreated / _totalMessagesProcessed
        : 0.0;

    final avgChunkSize = _chunkSizes.isNotEmpty
        ? _chunkSizes.reduce((a, b) => a + b) / _chunkSizes.length
        : 0.0;

    // Calculate size distribution
    final sizeDistribution = <String, int>{};
    for (final size in _chunkSizes) {
      final bucket = _getSizeBucket(size);
      sizeDistribution[bucket] = (sizeDistribution[bucket] ?? 0) + 1;
    }

    return ChunkingStats(
      totalMessages: _totalMessagesProcessed,
      totalChunks: _totalChunksCreated,
      averageChunksPerMessage: avgChunksPerMessage,
      averageChunkSize: avgChunkSize,
      processingTimeMs: _totalProcessingTimeMs,
      sizeDistribution: sizeDistribution,
    );
  }

  /// Reset statistics
  void resetStatistics() {
    _totalMessagesProcessed = 0;
    _totalChunksCreated = 0;
    _totalProcessingTimeMs = 0;
    _chunkSizes.clear();
  }

  // Private helper methods

  Future<List<MessageChunk>> _applyChunkingStrategy(
    Message message,
    ChunkingConfig config,
    ErrorContext opCtx,
  ) async {
    switch (config.strategy) {
      case ChunkingStrategy.fixedToken:
        return _chunkByTokens(message, config);
      case ChunkingStrategy.fixedChar:
        return _chunkByCharacters(message, config);
      case ChunkingStrategy.wordBoundary:
        return _chunkByWords(message, config);
      case ChunkingStrategy.sentenceBoundary:
        return _chunkBySentences(message, config);
      case ChunkingStrategy.paragraphBoundary:
        return _chunkByParagraphs(message, config);
      case ChunkingStrategy.slidingWindow:
        return _chunkSlidingWindow(message, config);
      case ChunkingStrategy.delimiter:
        return _chunkByDelimiters(message, config);
      case ChunkingStrategy.semantic:
        // Future enhancement - for now fall back to word boundary
        return _chunkByWords(message, config);
    }
  }

  List<MessageChunk> _chunkByTokens(Message message, ChunkingConfig config) {
    final chunks = <MessageChunk>[];
    final content = message.content;
    var currentPos = 0;
    var chunkIndex = 0;

    while (currentPos < content.length) {
      var endPos = content.length;
      var chunkContent = content.substring(currentPos);

      // Find the right end position based on token count
      if (_tokenCounter.estimateTokens(chunkContent) > config.maxChunkTokens) {
        // Binary search for optimal cut point
        var low = currentPos;
        var high = content.length;

        while (low < high) {
          final mid = (low + high) ~/ 2;
          final testContent = content.substring(currentPos, mid);
          if (_tokenCounter.estimateTokens(testContent) <=
              config.maxChunkTokens) {
            low = mid + 1;
          } else {
            high = mid;
          }
        }

        endPos = low - 1;
        if (endPos <= currentPos) endPos = currentPos + 1;
        chunkContent = content.substring(currentPos, endPos);
      }

      // Adjust for word boundaries if needed
      if (config.preserveWords && endPos < content.length) {
        endPos = _adjustForWordBoundary(content, endPos, currentPos);
        chunkContent = content.substring(currentPos, endPos);
      }

      final chunk = MessageChunk(
        id: '${message.id}_chunk_$chunkIndex',
        content: chunkContent,
        parentMessageId: message.id,
        chunkIndex: chunkIndex,
        totalChunks: 0, // Will be updated later
        startPosition: currentPos,
        endPosition: endPos,
        estimatedTokens: _tokenCounter.estimateTokens(chunkContent),
      );

      chunks.add(chunk);
      currentPos = endPos;
      chunkIndex++;

      if (chunkIndex >= config.maxChunksPerMessage) {
        _logger.warning('Maximum chunks per message reached', {
          'messageId': message.id,
          'maxChunks': config.maxChunksPerMessage,
        });
        break;
      }
    }

    return _finalizeCunks(chunks);
  }

  List<MessageChunk> _chunkByCharacters(
    Message message,
    ChunkingConfig config,
  ) {
    final chunks = <MessageChunk>[];
    final content = message.content;
    final chunkSize = config.maxChunkChars;
    var chunkIndex = 0;

    for (var i = 0; i < content.length; i += chunkSize) {
      var endPos = min(i + chunkSize, content.length);

      // Adjust for word boundaries if needed
      if (config.preserveWords && endPos < content.length) {
        endPos = _adjustForWordBoundary(content, endPos, i);
      }

      final chunkContent = content.substring(i, endPos);

      final chunk = MessageChunk(
        id: '${message.id}_chunk_$chunkIndex',
        content: chunkContent,
        parentMessageId: message.id,
        chunkIndex: chunkIndex,
        totalChunks: 0, // Will be updated later
        startPosition: i,
        endPosition: endPos,
        estimatedTokens: _tokenCounter.estimateTokens(chunkContent),
      );

      chunks.add(chunk);
      chunkIndex++;

      if (chunkIndex >= config.maxChunksPerMessage) break;
    }

    return _finalizeCunks(chunks);
  }

  List<MessageChunk> _chunkByWords(Message message, ChunkingConfig config) {
    final words = message.content.split(RegExp(r'\s+'));
    final chunks = <MessageChunk>[];
    var currentChunk = <String>[];
    var currentTokens = 0;
    var chunkIndex = 0;
    var currentPos = 0;

    for (final word in words) {
      final wordTokens = _tokenCounter.estimateTokens(word);

      if (currentTokens + wordTokens > config.maxChunkTokens &&
          currentChunk.isNotEmpty) {
        // Create chunk from current words
        final chunkContent = currentChunk.join(' ');
        final chunk = _createChunk(
          message,
          chunkContent,
          chunkIndex,
          currentPos,
          currentPos + chunkContent.length,
        );
        chunks.add(chunk);

        currentPos += chunkContent.length + 1; // +1 for space
        currentChunk.clear();
        currentTokens = 0;
        chunkIndex++;
      }

      currentChunk.add(word);
      currentTokens += wordTokens;
    }

    // Add remaining words as final chunk
    if (currentChunk.isNotEmpty) {
      final chunkContent = currentChunk.join(' ');
      final chunk = _createChunk(
        message,
        chunkContent,
        chunkIndex,
        currentPos,
        currentPos + chunkContent.length,
      );
      chunks.add(chunk);
    }

    return _finalizeCunks(chunks);
  }

  List<MessageChunk> _chunkBySentences(Message message, ChunkingConfig config) {
    final sentences = message.content.split(RegExp(r'[.!?]+\s+'));
    final chunks = <MessageChunk>[];
    var currentSentences = <String>[];
    var currentTokens = 0;
    var chunkIndex = 0;
    var currentPos = 0;

    for (final sentence in sentences) {
      final sentenceTokens = _tokenCounter.estimateTokens(sentence);

      if (currentTokens + sentenceTokens > config.maxChunkTokens &&
          currentSentences.isNotEmpty) {
        // Create chunk from current sentences
        final chunkContent = currentSentences.join('. ');
        final chunk = _createChunk(
          message,
          chunkContent,
          chunkIndex,
          currentPos,
          currentPos + chunkContent.length,
        );
        chunks.add(chunk);

        currentPos += chunkContent.length + 2; // +2 for '. '
        currentSentences.clear();
        currentTokens = 0;
        chunkIndex++;
      }

      currentSentences.add(sentence.trim());
      currentTokens += sentenceTokens;
    }

    // Add remaining sentences as final chunk
    if (currentSentences.isNotEmpty) {
      final chunkContent = currentSentences.join('. ');
      final chunk = _createChunk(
        message,
        chunkContent,
        chunkIndex,
        currentPos,
        currentPos + chunkContent.length,
      );
      chunks.add(chunk);
    }

    return _finalizeCunks(chunks);
  }

  List<MessageChunk> _chunkByParagraphs(
    Message message,
    ChunkingConfig config,
  ) {
    final paragraphs = message.content.split('\n\n');
    final chunks = <MessageChunk>[];
    var currentParagraphs = <String>[];
    var currentTokens = 0;
    var chunkIndex = 0;
    var currentPos = 0;

    for (final paragraph in paragraphs) {
      final paragraphTokens = _tokenCounter.estimateTokens(paragraph);

      if (currentTokens + paragraphTokens > config.maxChunkTokens &&
          currentParagraphs.isNotEmpty) {
        // Create chunk from current paragraphs
        final chunkContent = currentParagraphs.join('\n\n');
        final chunk = _createChunk(
          message,
          chunkContent,
          chunkIndex,
          currentPos,
          currentPos + chunkContent.length,
        );
        chunks.add(chunk);

        currentPos += chunkContent.length + 2; // +2 for '\n\n'
        currentParagraphs.clear();
        currentTokens = 0;
        chunkIndex++;
      }

      currentParagraphs.add(paragraph.trim());
      currentTokens += paragraphTokens;
    }

    // Add remaining paragraphs as final chunk
    if (currentParagraphs.isNotEmpty) {
      final chunkContent = currentParagraphs.join('\n\n');
      final chunk = _createChunk(
        message,
        chunkContent,
        chunkIndex,
        currentPos,
        currentPos + chunkContent.length,
      );
      chunks.add(chunk);
    }

    return _finalizeCunks(chunks);
  }

  List<MessageChunk> _chunkSlidingWindow(
    Message message,
    ChunkingConfig config,
  ) {
    final chunks = <MessageChunk>[];
    final content = message.content;
    final stepSize = (config.maxChunkChars * (1.0 - config.overlapRatio))
        .round();
    var chunkIndex = 0;

    for (var i = 0; i < content.length; i += stepSize) {
      final endPos = min(i + config.maxChunkChars, content.length);
      var chunkContent = content.substring(i, endPos);

      // Adjust for word boundaries if needed
      if (config.preserveWords && endPos < content.length) {
        final adjustedEnd = _adjustForWordBoundary(content, endPos, i);
        chunkContent = content.substring(i, adjustedEnd);
      }

      final chunk = MessageChunk(
        id: '${message.id}_chunk_$chunkIndex',
        content: chunkContent,
        parentMessageId: message.id,
        chunkIndex: chunkIndex,
        totalChunks: 0, // Will be updated later
        startPosition: i,
        endPosition: i + chunkContent.length,
        estimatedTokens: _tokenCounter.estimateTokens(chunkContent),
        metadata: {'overlapRatio': config.overlapRatio},
      );

      chunks.add(chunk);
      chunkIndex++;

      if (chunkIndex >= config.maxChunksPerMessage) break;
      if (i + chunkContent.length >= content.length) break;
    }

    return _finalizeCunks(chunks);
  }

  List<MessageChunk> _chunkByDelimiters(
    Message message,
    ChunkingConfig config,
  ) {
    if (config.customDelimiters.isEmpty) {
      throw ConfigurationException.invalid(
        'customDelimiters',
        'required for delimiter chunking strategy',
        context: ErrorContext(
          component: 'MessageChunker',
          operation: '_chunkByDelimiters',
          params: {'messageId': message.id},
        ),
      );
    }

    final chunks = <MessageChunk>[];
    var content = message.content;
    var chunkIndex = 0;
    var currentPos = 0;

    for (final delimiter in config.customDelimiters) {
      final parts = content.split(delimiter);

      for (var i = 0; i < parts.length; i++) {
        final part = parts[i].trim();
        if (part.isEmpty) continue;

        final chunk = MessageChunk(
          id: '${message.id}_chunk_$chunkIndex',
          content: part,
          parentMessageId: message.id,
          chunkIndex: chunkIndex,
          totalChunks: 0, // Will be updated later
          startPosition: currentPos,
          endPosition: currentPos + part.length,
          estimatedTokens: _tokenCounter.estimateTokens(part),
          metadata: {'delimiter': delimiter},
        );

        chunks.add(chunk);
        currentPos += part.length + delimiter.length;
        chunkIndex++;

        if (chunkIndex >= config.maxChunksPerMessage) break;
      }

      if (chunkIndex >= config.maxChunksPerMessage) break;
    }

    return _finalizeCunks(chunks);
  }

  MessageChunk _createChunk(
    Message message,
    String content,
    int index,
    int startPos,
    int endPos,
  ) {
    return MessageChunk(
      id: '${message.id}_chunk_$index',
      content: content,
      parentMessageId: message.id,
      chunkIndex: index,
      totalChunks: 0, // Will be updated later
      startPosition: startPos,
      endPosition: endPos,
      estimatedTokens: _tokenCounter.estimateTokens(content),
    );
  }

  List<MessageChunk> _finalizeCunks(List<MessageChunk> chunks) {
    final totalChunks = chunks.length;

    return chunks
        .map(
          (chunk) => MessageChunk(
            id: chunk.id,
            content: chunk.content,
            parentMessageId: chunk.parentMessageId,
            chunkIndex: chunk.chunkIndex,
            totalChunks: totalChunks,
            startPosition: chunk.startPosition,
            endPosition: chunk.endPosition,
            estimatedTokens: chunk.estimatedTokens,
            metadata: chunk.metadata,
          ),
        )
        .toList();
  }

  int _adjustForWordBoundary(String content, int endPos, int startPos) {
    if (endPos >= content.length) return content.length;

    // Look backwards for word boundary
    var pos = endPos;
    while (pos > startPos && !_isWordBoundary(content, pos)) {
      pos--;
    }

    // If we went too far back, look forward instead
    if (pos <= startPos) {
      pos = endPos;
      while (pos < content.length && !_isWordBoundary(content, pos)) {
        pos++;
      }
    }

    return pos;
  }

  bool _isWordBoundary(String content, int position) {
    if (position <= 0 || position >= content.length) return true;

    final char = content[position];
    final prevChar = content[position - 1];

    return char == ' ' ||
        char == '\n' ||
        char == '\t' ||
        prevChar == ' ' ||
        prevChar == '\n' ||
        prevChar == '\t';
  }

  void _updateStatistics(Message message, List<MessageChunk> chunks) {
    _totalMessagesProcessed++;
    _totalChunksCreated += chunks.length;

    for (final chunk in chunks) {
      _chunkSizes.add(chunk.content.length);
    }
  }

  String _getSizeBucket(int size) {
    if (size < 100) return 'small';
    if (size < 500) return 'medium';
    if (size < 1000) return 'large';
    return 'xlarge';
  }
}

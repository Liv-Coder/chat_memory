import 'dart:async';
import 'dart:math' as math;

import 'package:logging/logging.dart';

import '../core/persistence/persistence_strategy.dart';
import '../memory/vector_stores/vector_store.dart';
import '../core/models/message.dart';
import '../core/errors.dart';
import '../core/logging/chat_memory_logger.dart';

/// Configuration for memory optimization operations
class OptimizationConfig {
  /// Maximum memory usage threshold (in bytes)
  final int maxMemoryBytes;

  /// Maximum number of messages to keep in active storage
  final int maxActiveMessages;

  /// Age threshold for archiving messages (in days)
  final int archiveAfterDays;

  /// Age threshold for deleting archived messages (in days)
  final int deleteAfterDays;

  /// Minimum importance score to preserve during cleanup
  final double minImportanceScore;

  /// Batch size for processing operations
  final int batchSize;

  /// Enable automatic archiving
  final bool enableArchiving;

  /// Enable automatic deletion
  final bool enableDeletion;

  /// Enable rollback tracking
  final bool enableRollback;

  const OptimizationConfig({
    this.maxMemoryBytes = 100 * 1024 * 1024, // 100MB
    this.maxActiveMessages = 10000,
    this.archiveAfterDays = 30,
    this.deleteAfterDays = 90,
    this.minImportanceScore = 0.1,
    this.batchSize = 100,
    this.enableArchiving = true,
    this.enableDeletion = false,
    this.enableRollback = true,
  });

  OptimizationConfig copyWith({
    int? maxMemoryBytes,
    int? maxActiveMessages,
    int? archiveAfterDays,
    int? deleteAfterDays,
    double? minImportanceScore,
    int? batchSize,
    bool? enableArchiving,
    bool? enableDeletion,
    bool? enableRollback,
  }) {
    return OptimizationConfig(
      maxMemoryBytes: maxMemoryBytes ?? this.maxMemoryBytes,
      maxActiveMessages: maxActiveMessages ?? this.maxActiveMessages,
      archiveAfterDays: archiveAfterDays ?? this.archiveAfterDays,
      deleteAfterDays: deleteAfterDays ?? this.deleteAfterDays,
      minImportanceScore: minImportanceScore ?? this.minImportanceScore,
      batchSize: batchSize ?? this.batchSize,
      enableArchiving: enableArchiving ?? this.enableArchiving,
      enableDeletion: enableDeletion ?? this.enableDeletion,
      enableRollback: enableRollback ?? this.enableRollback,
    );
  }
}

/// Result of an optimization operation
class OptimizationResult {
  /// Messages that were archived
  final List<Message> archivedMessages;

  /// Messages that were deleted
  final List<Message> deletedMessages;

  /// Amount of storage reclaimed (in bytes)
  final int storageReclaimed;

  /// Time taken for the operation
  final Duration executionTime;

  /// Number of messages processed
  final int messagesProcessed;

  /// Success status
  final bool success;

  /// Error message if operation failed
  final String? errorMessage;

  /// Rollback token for undoing the operation
  final String? rollbackToken;

  const OptimizationResult({
    required this.archivedMessages,
    required this.deletedMessages,
    required this.storageReclaimed,
    required this.executionTime,
    required this.messagesProcessed,
    required this.success,
    this.errorMessage,
    this.rollbackToken,
  });

  OptimizationResult.success({
    required this.archivedMessages,
    required this.deletedMessages,
    required this.storageReclaimed,
    required this.executionTime,
    required this.messagesProcessed,
    this.rollbackToken,
  }) : success = true,
       errorMessage = null;

  OptimizationResult.failure({
    required this.errorMessage,
    required this.executionTime,
    this.messagesProcessed = 0,
  }) : archivedMessages = const [],
       deletedMessages = const [],
       storageReclaimed = 0,
       success = false,
       rollbackToken = null;
}

/// Memory usage statistics
class MemoryUsageStats {
  /// Current memory usage in bytes
  final int currentMemoryBytes;

  /// Number of active messages
  final int activeMessageCount;

  /// Number of archived messages
  final int archivedMessageCount;

  /// Memory usage percentage (0.0 to 1.0)
  final double memoryUsagePercentage;

  /// Average message size
  final double averageMessageSize;

  /// Oldest message timestamp
  final DateTime? oldestMessageTime;

  /// Newest message timestamp
  final DateTime? newestMessageTime;

  const MemoryUsageStats({
    required this.currentMemoryBytes,
    required this.activeMessageCount,
    required this.archivedMessageCount,
    required this.memoryUsagePercentage,
    required this.averageMessageSize,
    this.oldestMessageTime,
    this.newestMessageTime,
  });
}

/// Rollback information for undoing optimization operations
class RollbackInfo {
  /// Unique rollback token
  final String token;

  /// Timestamp of the operation
  final DateTime timestamp;

  /// Messages that were archived (to restore)
  final List<Message> archivedMessages;

  /// Messages that were deleted (to restore)
  final List<Message> deletedMessages;

  /// Original vector store entries
  final Map<String, dynamic> vectorStoreBackup;

  const RollbackInfo({
    required this.token,
    required this.timestamp,
    required this.archivedMessages,
    required this.deletedMessages,
    required this.vectorStoreBackup,
  });
}

/// Advanced memory optimizer with automatic cleanup and archiving
class MemoryOptimizer {
  final PersistenceStrategy _persistenceStrategy;
  final VectorStore _vectorStore;
  final Logger _logger;
  final OptimizationConfig _config;

  /// Archive storage for moved messages
  final PersistenceStrategy? _archiveStorage;

  /// Rollback information storage
  final Map<String, RollbackInfo> _rollbackHistory = {};

  /// Current optimization operation
  Completer<OptimizationResult>? _currentOperation;

  MemoryOptimizer({
    required PersistenceStrategy persistenceStrategy,
    required VectorStore vectorStore,
    Logger? logger,
    OptimizationConfig? config,
    PersistenceStrategy? archiveStorage,
  }) : _persistenceStrategy = persistenceStrategy,
       _vectorStore = vectorStore,
       _logger = logger ?? ChatMemoryLogger.loggerFor('MemoryOptimizer'),
       _config = config ?? const OptimizationConfig(),
       _archiveStorage = archiveStorage;

  /// Get current memory usage statistics
  Future<MemoryUsageStats> getMemoryUsage() async {
    try {
      final messages = await _persistenceStrategy.loadMessages();
      final currentBytes = _calculateMemoryUsage(messages);
      final percentage = currentBytes / _config.maxMemoryBytes;

      DateTime? oldest, newest;
      if (messages.isNotEmpty) {
        messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        oldest = messages.first.timestamp;
        newest = messages.last.timestamp;
      }

      final archivedCount = _archiveStorage != null
          ? (await _archiveStorage.loadMessages()).length
          : 0;

      return MemoryUsageStats(
        currentMemoryBytes: currentBytes,
        activeMessageCount: messages.length,
        archivedMessageCount: archivedCount,
        memoryUsagePercentage: math.min(percentage, 1.0),
        averageMessageSize: messages.isNotEmpty
            ? currentBytes / messages.length
            : 0.0,
        oldestMessageTime: oldest,
        newestMessageTime: newest,
      );
    } catch (e, stackTrace) {
      ChatMemoryLogger.logError(
        _logger,
        'getMemoryUsage',
        e,
        stackTrace: stackTrace,
        params: {'config': _config.toString()},
        shouldRethrow: true,
      );
      rethrow;
    }
  }

  /// Check if optimization is needed based on current memory usage
  Future<bool> isOptimizationNeeded() async {
    try {
      final stats = await getMemoryUsage();

      final memoryThresholdExceeded = stats.memoryUsagePercentage > 0.8;
      final messageCountExceeded =
          stats.activeMessageCount > _config.maxActiveMessages;
      final oldestTooOld =
          stats.oldestMessageTime != null &&
          DateTime.now().difference(stats.oldestMessageTime!).inDays >
              _config.archiveAfterDays;

      final needed =
          memoryThresholdExceeded || messageCountExceeded || oldestTooOld;

      _logger.info(
        'Optimization check completed: memoryThresholdExceeded=$memoryThresholdExceeded, '
        'messageCountExceeded=$messageCountExceeded, oldestTooOld=$oldestTooOld, '
        'needed=$needed, memoryUsage=${stats.memoryUsagePercentage}, '
        'messageCount=${stats.activeMessageCount}',
      );

      return needed;
    } catch (e, stackTrace) {
      ChatMemoryLogger.logError(
        _logger,
        'isOptimizationNeeded',
        e,
        stackTrace: stackTrace,
        shouldRethrow: true,
      );
      rethrow;
    }
  }

  /// Perform automatic optimization with intelligent cleanup and archiving
  Future<OptimizationResult> optimize() async {
    if (_currentOperation != null && !_currentOperation!.isCompleted) {
      throw const ChatMemoryException(
        'Optimization already in progress',
        context: ErrorContext(
          operation: 'optimize',
          component: 'MemoryOptimizer',
        ),
      );
    }

    _currentOperation = Completer<OptimizationResult>();
    final stopwatch = Stopwatch()..start();

    try {
      _logger.info(
        'Starting memory optimization with config: ${_config.toString()}',
      );

      final messages = await _persistenceStrategy.loadMessages();
      final rollbackToken = _config.enableRollback
          ? _generateRollbackToken()
          : null;

      // Create rollback information before any changes
      RollbackInfo? rollbackInfo;
      if (rollbackToken != null) {
        rollbackInfo = await _createRollbackInfo(rollbackToken, messages);
      }

      final archivedMessages = <Message>[];
      final deletedMessages = <Message>[];
      int storageReclaimed = 0;

      // Phase 1: Archive old messages
      if (_config.enableArchiving && _archiveStorage != null) {
        final toArchive = _selectMessagesForArchiving(messages);
        for (final batch in _batchMessages(toArchive, _config.batchSize)) {
          final archived = await _archiveMessages(batch);
          archivedMessages.addAll(archived);
          storageReclaimed += _calculateMemoryUsage(archived);
        }
      }

      // Phase 2: Delete very old or low-importance messages
      if (_config.enableDeletion) {
        final remainingMessages = messages
            .where((m) => !archivedMessages.contains(m))
            .toList();
        final toDelete = _selectMessagesForDeletion(remainingMessages);
        for (final batch in _batchMessages(toDelete, _config.batchSize)) {
          final deleted = await _deleteMessages(batch);
          deletedMessages.addAll(deleted);
          storageReclaimed += _calculateMemoryUsage(deleted);
        }
      }

      stopwatch.stop();

      final result = OptimizationResult.success(
        archivedMessages: archivedMessages,
        deletedMessages: deletedMessages,
        storageReclaimed: storageReclaimed,
        executionTime: stopwatch.elapsed,
        messagesProcessed: archivedMessages.length + deletedMessages.length,
        rollbackToken: rollbackToken,
      );

      // Store rollback information
      if (rollbackInfo != null && rollbackToken != null) {
        _rollbackHistory[rollbackToken] = rollbackInfo;
        _cleanupOldRollbacks();
      }

      _logger.info(
        'Memory optimization completed successfully: '
        'archivedCount=${archivedMessages.length}, '
        'deletedCount=${deletedMessages.length}, '
        'storageReclaimed=$storageReclaimed, '
        'executionTime=${stopwatch.elapsed.inMilliseconds}ms',
      );

      _currentOperation!.complete(result);
      return result;
    } catch (e, stackTrace) {
      stopwatch.stop();

      final result = OptimizationResult.failure(
        errorMessage: e.toString(),
        executionTime: stopwatch.elapsed,
      );

      ChatMemoryLogger.logError(
        _logger,
        'optimize',
        e,
        stackTrace: stackTrace,
        params: {'executionTime': stopwatch.elapsed.inMilliseconds},
      );

      _currentOperation!.complete(result);
      return result;
    }
  }

  /// Rollback a previous optimization operation
  Future<bool> rollback(String rollbackToken) async {
    final rollbackInfo = _rollbackHistory[rollbackToken];
    if (rollbackInfo == null) {
      throw ChatMemoryException(
        'Rollback token not found: $rollbackToken',
        context: ErrorContext(
          operation: 'rollback',
          component: 'MemoryOptimizer',
          params: {'rollbackToken': rollbackToken},
        ),
      );
    }

    try {
      _logger.info('Starting rollback operation for token: $rollbackToken');

      // Restore archived messages
      for (final message in rollbackInfo.archivedMessages) {
        await _persistenceStrategy.saveMessages([message]);
        if (_archiveStorage != null) {
          await _archiveStorage.deleteMessages([message.id]);
        }
      }

      // Restore deleted messages
      for (final message in rollbackInfo.deletedMessages) {
        await _persistenceStrategy.saveMessages([message]);
      }

      // Restore vector store entries
      // Note: This is a simplified approach - in practice, you'd need
      // more sophisticated vector store backup/restore mechanisms

      _rollbackHistory.remove(rollbackToken);

      _logger.info(
        'Rollback completed successfully for token $rollbackToken: '
        'restoredMessages=${rollbackInfo.archivedMessages.length + rollbackInfo.deletedMessages.length}',
      );

      return true;
    } catch (e, stackTrace) {
      ChatMemoryLogger.logError(
        _logger,
        'rollback',
        e,
        stackTrace: stackTrace,
        params: {'rollbackToken': rollbackToken},
      );
      return false;
    }
  }

  /// Get list of available rollback tokens
  List<String> getAvailableRollbacks() {
    return _rollbackHistory.keys.toList()..sort();
  }

  /// Calculate memory usage for a list of messages
  int _calculateMemoryUsage(List<Message> messages) {
    return messages.fold(0, (total, message) {
      // Rough estimation of message memory usage
      return total +
          message.content.length * 2 + // UTF-16 encoding
          message.role.toString().length * 2 +
          message.id.length * 2 +
          100; // Overhead for object structure
    });
  }

  /// Select messages for archiving based on age and importance
  List<Message> _selectMessagesForArchiving(List<Message> messages) {
    final cutoffDate = DateTime.now().subtract(
      Duration(days: _config.archiveAfterDays),
    );

    return messages.where((message) {
      final tooOld = message.timestamp.isBefore(cutoffDate);
      final lowImportance =
          _calculateImportanceScore(message) < _config.minImportanceScore;
      return tooOld || lowImportance;
    }).toList();
  }

  /// Select messages for deletion based on age and archive status
  List<Message> _selectMessagesForDeletion(List<Message> messages) {
    final cutoffDate = DateTime.now().subtract(
      Duration(days: _config.deleteAfterDays),
    );

    return messages.where((message) {
      return message.timestamp.isBefore(cutoffDate);
    }).toList();
  }

  /// Calculate importance score for a message
  double _calculateImportanceScore(Message message) {
    // Simple scoring based on message length and recency
    final lengthScore = math.min(message.content.length / 1000.0, 1.0);
    final ageInDays = DateTime.now().difference(message.timestamp).inDays;
    final recencyScore = math.max(0.0, 1.0 - ageInDays / 365.0);

    return (lengthScore * 0.3) + (recencyScore * 0.7);
  }

  /// Archive messages to archive storage
  Future<List<Message>> _archiveMessages(List<Message> messages) async {
    if (_archiveStorage == null) return [];

    final archived = <Message>[];
    for (final message in messages) {
      try {
        await _archiveStorage.saveMessages([message]);
        await _persistenceStrategy.deleteMessages([message.id]);

        // Remove from vector store
        try {
          await _vectorStore.delete(message.id);
        } catch (e) {
          // Vector might not exist, continue
          _logger.warning(
            'Failed to delete vector during archiving for message ${message.id}: $e',
          );
        }

        archived.add(message);
      } catch (e) {
        _logger.severe('Failed to archive message ${message.id}: $e');
      }
    }
    return archived;
  }

  /// Delete messages permanently
  Future<List<Message>> _deleteMessages(List<Message> messages) async {
    final deleted = <Message>[];
    for (final message in messages) {
      try {
        await _persistenceStrategy.deleteMessages([message.id]);

        // Remove from vector store
        try {
          await _vectorStore.delete(message.id);
        } catch (e) {
          // Vector might not exist, continue
          _logger.warning(
            'Failed to delete vector during deletion for message ${message.id}: $e',
          );
        }

        deleted.add(message);
      } catch (e) {
        _logger.severe('Failed to delete message ${message.id}: $e');
      }
    }
    return deleted;
  }

  /// Batch messages for processing
  Iterable<List<Message>> _batchMessages(
    List<Message> messages,
    int batchSize,
  ) sync* {
    for (int i = 0; i < messages.length; i += batchSize) {
      yield messages.sublist(i, math.min(i + batchSize, messages.length));
    }
  }

  /// Generate a unique rollback token
  String _generateRollbackToken() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = math.Random().nextInt(1000000);
    return 'rollback_${timestamp}_$random';
  }

  /// Create rollback information
  Future<RollbackInfo> _createRollbackInfo(
    String token,
    List<Message> currentMessages,
  ) async {
    return RollbackInfo(
      token: token,
      timestamp: DateTime.now(),
      archivedMessages: [],
      deletedMessages: [],
      vectorStoreBackup:
          {}, // Simplified - would need proper vector store backup
    );
  }

  /// Clean up old rollback information
  void _cleanupOldRollbacks() {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    _rollbackHistory.removeWhere(
      (token, info) => info.timestamp.isBefore(cutoff),
    );
  }
}

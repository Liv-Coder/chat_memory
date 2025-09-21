import 'dart:async';

import 'persistence_strategy.dart';
import '../models/message.dart';
import '../errors.dart';
import '../logging/chat_memory_logger.dart';

/// Simple in-memory persistence with validation, logging and optional size limits.
class InMemoryStore implements PersistenceStrategy {
  final List<Message> _messages = [];
  final _logger = ChatMemoryLogger.loggerFor('persistence.in_memory');
  final int? maxEntries;

  InMemoryStore({this.maxEntries});

  /// Save messages (append). Validates input and enforces optional maxEntries with FIFO eviction.
  @override
  Future<void> saveMessages(List<Message> messages) async {
    final ctx = ErrorContext(
      component: 'InMemoryStore',
      operation: 'saveMessages',
      params: {'count': messages.length, 'maxEntries': maxEntries},
    );

    try {
      Validation.validateListNotEmpty('messages', messages, context: ctx);

      for (final m in messages) {
        Validation.validateNonEmptyString('message.id', m.id, context: ctx);
      }

      _messages.addAll(messages);
      if (maxEntries != null && _messages.length > maxEntries!) {
        final overflow = _messages.length - maxEntries!;
        // Evict oldest entries
        _messages.removeRange(0, overflow);
        _logger.warning(
          'Evicted $overflow oldest messages due to maxEntries=$maxEntries',
        );
      }

      _logger.fine(
        'Saved ${messages.length} messages, total=${_messages.length}',
      );
    } catch (e, st) {
      _logger.severe('Failed to save messages', e, st);
      throw MemoryException(
        'InMemoryStore.saveMessages failed',
        cause: e,
        stackTrace: st,
        context: ctx,
      );
    }
  }

  /// Load all messages (immutable view).
  @override
  Future<List<Message>> loadMessages() async {
    const ctx = ErrorContext(
      component: 'InMemoryStore',
      operation: 'loadMessages',
    );
    try {
      _logger.fine('Loading messages, total=${_messages.length}');
      return List.unmodifiable(_messages);
    } catch (e, st) {
      _logger.severe('Failed to load messages', e, st);
      throw MemoryException(
        'InMemoryStore.loadMessages failed',
        cause: e,
        stackTrace: st,
        context: ctx,
      );
    }
  }

  /// Delete messages by id.
  @override
  Future<void> deleteMessages(List<String> messageIds) async {
    final ctx = ErrorContext(
      component: 'InMemoryStore',
      operation: 'deleteMessages',
      params: {'ids': messageIds.length},
    );
    try {
      Validation.validateListNotEmpty('messageIds', messageIds, context: ctx);
      final before = _messages.length;
      _messages.removeWhere((m) => messageIds.contains(m.id));
      final removed = before - _messages.length;
      _logger.fine('Deleted $removed messages, total=${_messages.length}');
    } catch (e, st) {
      _logger.severe('Failed to delete messages', e, st);
      throw MemoryException(
        'InMemoryStore.deleteMessages failed',
        cause: e,
        stackTrace: st,
        context: ctx,
      );
    }
  }

  /// Clear all messages.
  @override
  Future<void> clear() async {
    const ctx = ErrorContext(component: 'InMemoryStore', operation: 'clear');
    try {
      final before = _messages.length;
      _messages.clear();
      _logger.info('Cleared $before messages from in-memory store');
    } catch (e, st) {
      _logger.severe('Failed to clear messages', e, st);
      throw MemoryException(
        'InMemoryStore.clear failed',
        cause: e,
        stackTrace: st,
        context: ctx,
      );
    }
  }

  /// Optional health check for monitoring.
  bool isHealthy() => true;

  /// Current stored message count.
  int get storedCount => _messages.length;
}

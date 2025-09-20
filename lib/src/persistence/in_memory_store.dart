import 'dart:async';

import 'persistence_strategy.dart';
import '../models/message.dart';

class InMemoryStore implements PersistenceStrategy {
  final List<Message> _messages = [];

  @override
  Future<void> saveMessages(List<Message> messages) async {
    // Replace or append: simple implementation - append
    _messages.addAll(messages);
  }

  @override
  Future<List<Message>> loadMessages() async {
    return List.unmodifiable(_messages);
  }

  @override
  Future<void> deleteMessages(List<String> messageIds) async {
    _messages.removeWhere((m) => messageIds.contains(m.id));
  }

  @override
  Future<void> clear() async {
    _messages.clear();
  }
}

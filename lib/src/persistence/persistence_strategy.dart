import '../models/message.dart';

/// Persistence adapter interface used by `ConversationManager`.
///
/// The core package provides an in-memory default; adapters may persist to
/// file, SQLite, cloud storage, or secure stores. Persistence is opt-in.
abstract class PersistenceStrategy {
  /// Save or append messages to the store.
  Future<void> saveMessages(List<Message> messages);

  /// Load all messages (ordered oldest -> newest).
  Future<List<Message>> loadMessages();

  /// Delete messages by id.
  Future<void> deleteMessages(List<String> messageIds);

  /// Clear the entire store.
  Future<void> clear();
}

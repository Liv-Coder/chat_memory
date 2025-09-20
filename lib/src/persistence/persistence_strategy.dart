import '../models/message.dart';

abstract class PersistenceStrategy {
  Future<void> saveMessages(List<Message> messages);
  Future<List<Message>> loadMessages();
  Future<void> deleteMessages(List<String> messageIds);
  Future<void> clear();
}

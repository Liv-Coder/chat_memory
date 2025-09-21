import 'package:test/test.dart';
import 'package:chat_memory/chat_memory.dart';

void main() {
  group('InMemoryStore', () {
    test('save and load preserve order', () async {
      final store = InMemoryStore();
      final messages = [
        Message(
          id: '1',
          role: MessageRole.user,
          content: 'a',
          timestamp: DateTime.utc(2025),
        ),
        Message(
          id: '2',
          role: MessageRole.user,
          content: 'b',
          timestamp: DateTime.utc(2025).add(const Duration(seconds: 1)),
        ),
      ];

      await store.saveMessages(messages);
      final loaded = await store.loadMessages();
      expect(loaded.map((m) => m.id).toList(), equals(['1', '2']));
    });

    test('deleteMessages removes by id', () async {
      final store = InMemoryStore();
      await store.saveMessages([
        Message(
          id: 'a',
          role: MessageRole.user,
          content: 'x',
          timestamp: DateTime.utc(2025),
        ),
        Message(
          id: 'b',
          role: MessageRole.user,
          content: 'y',
          timestamp: DateTime.utc(2025),
        ),
      ]);
      await store.deleteMessages(['a']);
      final loaded = await store.loadMessages();
      expect(loaded.map((m) => m.id).toList(), equals(['b']));
    });

    test('clear empties store', () async {
      final store = InMemoryStore();
      await store.saveMessages([
        Message(
          id: 'x',
          role: MessageRole.user,
          content: 'x',
          timestamp: DateTime.utc(2025),
        ),
      ]);
      await store.clear();
      final loaded = await store.loadMessages();
      expect(loaded, isEmpty);
    });

    test('save/load/delete/clear full contract', () async {
      final store = InMemoryStore();
      final m1 = Message(
        id: 'a',
        role: MessageRole.user,
        content: 'one',
        timestamp: DateTime.utc(2025),
      );
      final m2 = Message(
        id: 'b',
        role: MessageRole.assistant,
        content: 'two',
        timestamp: DateTime.utc(2025),
      );

      await store.saveMessages([m1, m2]);
      var loaded = await store.loadMessages();
      expect(loaded.length, equals(2));

      await store.deleteMessages(['a']);
      loaded = await store.loadMessages();
      expect(loaded.length, equals(1));

      await store.clear();
      loaded = await store.loadMessages();
      expect(loaded, isEmpty);
    });
  });
}

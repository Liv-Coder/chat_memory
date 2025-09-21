import 'package:test/test.dart';
import 'package:chat_memory/chat_memory.dart';

// Tests for T003: Message model

void main() {
  group('Message model (T003)', () {
    test('constructor and toJson/fromJson round-trip', () {
      final timestamp = DateTime.parse('2025-09-21T12:00:00Z');
      final m = Message(
        id: 'id-1',
        role: MessageRole.user,
        content: 'Hello world',
        timestamp: timestamp,
        metadata: {'foo': 'bar'},
      );

      final json = m.toJson();
      final restored = Message.fromJson(json);

      expect(restored.id, equals(m.id));
      expect(restored.role, equals(m.role));
      expect(restored.content, equals(m.content));
      expect(restored.timestamp.toUtc(), equals(m.timestamp.toUtc()));
      expect(restored.metadata, equals(m.metadata));
    });

    test('copyWith returns new instance and preserves immutability', () {
      final timestamp = DateTime.parse('2025-09-21T12:00:00Z');
      final m = Message(
        id: 'id-2',
        role: MessageRole.assistant,
        content: 'Original',
        timestamp: timestamp,
      );

      final m2 = m.copyWith(content: 'Updated');
      expect(m2, isNot(same(m)));
      expect(m2.content, equals('Updated'));
      expect(m.content, equals('Original'));
      expect(m2.id, equals(m.id));
      expect(m2.timestamp, equals(m.timestamp));
    });
  });
}

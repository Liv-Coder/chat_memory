import 'package:test/test.dart';
import 'package:chat_memory/src/models/message.dart';
import 'package:chat_memory/src/vector_stores/vector_store.dart';
import '../test_utils.dart';

void main() {
  group('Message model', () {
    test('constructor and fields', () {
      final msg = TestMessageFactory.create(
        role: MessageRole.user,
        content: 'hello',
      );
      expect(msg.id, isNotEmpty);
      expect(msg.role, MessageRole.user);
      expect(msg.content, 'hello');
      expect(msg.timestamp, isA<DateTime>());
    });

    test('copyWith preserves identity and updates fields', () {
      final msg = TestMessageFactory.create(content: 'orig');
      final updated = msg.copyWith(content: 'new', metadata: {'k': 'v'});
      expect(updated.id, msg.id);
      expect(updated.role, msg.role);
      expect(updated.content, 'new');
      expect(updated.metadata, isNotNull);
      expect(updated.metadata!['k'], 'v');
    });

    test('toJson/fromJson roundtrip', () {
      final msg = TestMessageFactory.create(
        content: 'serialize me',
        metadata: {'a': 1},
      );
      final json = msg.toJson();
      final parsed = Message.fromJson(json);
      expect(parsed.id, msg.id);
      expect(parsed.content, msg.content);
      expect(parsed.metadata, msg.metadata);
      // timestamps normalized to UTC in toJson/fromJson
      expect(parsed.timestamp.isUtc, true);
    });

    test('toString produces JSON', () {
      final msg = TestMessageFactory.create(content: 'str');
      final s = msg.toString();
      expect(s, contains('"content":"str"'));
    });
  });

  group('VectorEntry and conversion', () {
    test('createTestVectorEntry and toJson/fromJson', () {
      final entry = createTestVectorEntry(id: 'vec_x', dim: 3, content: 'vec');
      final json = entry.toJson();
      final restored = VectorEntry.fromJson(json);
      expect(restored.id, entry.id);
      expect(restored.embedding, entry.embedding);
      expect(restored.content, entry.content);
      expect(restored.metadata['role'], 'user');
      expect(restored.timestamp.isUtc, true);
    });

    test('Message.toVectorEntry preserves content and role metadata', () {
      final msg = TestMessageFactory.create(
        role: MessageRole.assistant,
        content: 'assist',
      );
      final emb = [1.0, 0.0, 0.0];
      final ve = msg.toVectorEntry(emb);
      expect(ve.id, msg.id);
      expect(ve.content, msg.content);
      expect(ve.metadata['role'], 'assistant');
      expect(ve.embedding, emb);
    });
  });
}

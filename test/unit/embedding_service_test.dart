import 'dart:math';
import 'package:test/test.dart';
import 'package:chat_memory/src/memory/embeddings/simple_embedding_service.dart';

void main() {
  group('SimpleEmbeddingService', () {
    test('consistent embeddings for same text and dimension', () async {
      final svc = SimpleEmbeddingService(dimensions: 16);
      final a = await svc.embed('Hello World');
      final b = await svc.embed('Hello World');
      expect(a, equals(b));
      expect(a.length, 16);
    });

    test('embedBatch returns same order and size', () async {
      final svc = SimpleEmbeddingService(dimensions: 8);
      final texts = ['one', 'two', 'three'];
      final batch = await svc.embedBatch(texts);
      expect(batch, hasLength(3));
      for (final v in batch) {
        expect(v.length, 8);
      }
    });

    test('empty string returns zero vector', () async {
      final svc = SimpleEmbeddingService(dimensions: 12);
      final v = await svc.embed('');
      expect(v, everyElement(equals(0.0)));
    });

    test('normalization produces unit-length vectors when enabled', () async {
      final svc = SimpleEmbeddingService(dimensions: 12);
      final v = await svc.embed('normalize me');
      // When normalization=true (default), vector magnitude should be ~1.0 for non-zero
      final mag = sqrt(v.fold<double>(0.0, (s, x) => s + x * x));
      expect(mag, closeTo(1.0, 1e-6));
    });

    test(
      'different texts produce different embeddings (basic check)',
      () async {
        final svc = SimpleEmbeddingService(dimensions: 16);
        final a = await svc.embed('alpha');
        final b = await svc.embed('beta');
        expect(a, isNot(equals(b)));
      },
    );
  });
}

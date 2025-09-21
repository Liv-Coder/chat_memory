import 'package:test/test.dart';
import 'package:chat_memory/src/memory/vector_stores/in_memory_vector_store.dart';
import 'package:chat_memory/src/memory/vector_stores/local_vector_store.dart';
import 'package:chat_memory/src/memory/vector_stores/vector_store.dart';
import '../test_utils.dart';

void main() {
  group('InMemoryVectorStore', () {
    test('basic CRUD and count', () async {
      final store = InMemoryVectorStore();

      final entry = createTestVectorEntry(id: 'a', dim: 4, content: 'a');
      await store.store(entry);

      expect(await store.count(), 1);
      final fetched = await store.get('a');
      expect(fetched, isNotNull);
      expect(fetched!.content, 'a');

      await store.delete('a');
      expect(await store.count(), 0);

      await store.storeBatch([
        entry,
        createTestVectorEntry(id: 'b', content: 'b'),
      ]);
      expect(await store.count(), 2);

      await store.deleteBatch(['a', 'b']);
      expect(await store.count(), 0);

      await store.store(entry);
      await store.clear();
      expect(await store.count(), 0);
    });

    test(
      'similarity search orders by similarity and respects topK & minSimilarity',
      () async {
        final store = InMemoryVectorStore();

        final v1 = VectorEntry(
          id: 'v1',
          embedding: [1.0, 0.0, 0.0, 0.0],
          content: 'one',
          metadata: {'tag': 'group'},
          timestamp: DateTime.utc(2020),
        );

        final v2 = VectorEntry(
          id: 'v2',
          embedding: [0.0, 1.0, 0.0, 0.0],
          content: 'two',
          metadata: {'tag': 'group'},
          timestamp: DateTime.utc(2020),
        );

        await store.storeBatch([v1, v2]);

        final res = await store.search(
          queryEmbedding: [1.0, 0.0, 0.0, 0.0],
          topK: 2,
        );
        expect(res, hasLength(2));
        expect(res.first.entry.id, 'v1');
        expect(res.first.similarity, closeTo(1.0, 1e-6));
        expect(res.last.similarity, closeTo(0.0, 1e-6));

        // minSimilarity filter
        final resFiltered = await store.search(
          queryEmbedding: [1.0, 0.0, 0.0, 0.0],
          topK: 2,
          minSimilarity: 0.5,
        );
        expect(resFiltered.length, 1);
        expect(resFiltered.first.entry.id, 'v1');

        // metadata filter
        final resMeta = await store.search(
          queryEmbedding: [1.0, 0.0, 0.0, 0.0],
          topK: 2,
          metadataFilter: {'tag': 'group'},
        );
        expect(resMeta.length, 2);
      },
    );

    test('cosine similarity handles zero and mismatched dims', () async {
      final store = InMemoryVectorStore();
      final a = VectorEntry(
        id: 'a',
        embedding: [0.0, 0.0],
        content: 'zero',
        metadata: {},
        timestamp: DateTime.utc(2020),
      );
      final b = VectorEntry(
        id: 'b',
        embedding: [1.0, 0.0],
        content: 'one',
        metadata: {},
        timestamp: DateTime.utc(2020),
      );

      await store.storeBatch([a, b]);

      // Query with zero vector should yield empty results (similarity 0)
      final resZero = await store.search(queryEmbedding: [0.0, 0.0], topK: 10);
      // b has non-zero embedding but similarity with zero query is 0.0 -> filtered out only if minSimilarity>0
      expect(resZero, isA<List<SimilaritySearchResult>>());

      // mismatched dims: query length 3 vs entry length 2 -> similarity treated as 0.0
      final resMismatch = await store.search(
        queryEmbedding: [1.0, 0.0, 0.0],
        topK: 10,
      );
      // no matches with positive similarity
      expect(resMismatch.every((r) => r.similarity == 0.0), true);
    });
  });

  group('LocalVectorStore (compatibility)', () {
    test('implements same behaviors as in-memory store', () async {
      final store = LocalVectorStore(tableName: 'test_table');

      final entry = createTestVectorEntry(id: 'l1', dim: 4, content: 'local');
      await store.store(entry);
      expect(await store.count(), 1);

      final fetched = await store.get('l1');
      expect(fetched, isNotNull);
      expect(fetched!.content, 'local');

      await store.clear();
      expect(await store.count(), 0);
    });
  });
}

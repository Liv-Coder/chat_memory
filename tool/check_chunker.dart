import 'package:chat_memory/src/processing/message_chunker.dart';
import 'package:chat_memory/src/core/utils/token_counter.dart';
import 'package:chat_memory/src/core/models/message.dart';

Future<void> main() async {
  final tokenCounter = HeuristicTokenCounter();
  final chunker = MessageChunker(tokenCounter: tokenCounter);

  const longContent = '''
This is a very large message that contains multiple paragraphs and should be intelligently chunked.

The first paragraph discusses the importance of effective message processing in modern AI systems.
It covers topics such as chunking strategies, embedding generation, and vector storage optimization.

The second paragraph delves into specific implementation details including circuit breaker patterns,
retry logic with exponential backoff, and adaptive batch sizing for optimal performance.

The third paragraph explores monitoring and observability features including metrics collection,
detailed logging, and performance profiling capabilities that are essential for production systems.

The final paragraph summarizes the benefits of using a sophisticated processing pipeline
for handling conversational AI workloads at scale with reliability and efficiency.
''';

  final msg = Message(
    id: 'test_long',
    role: MessageRole.user,
    content: longContent,
    timestamp: DateTime.now().toUtc(),
  );

  try {
    // For debugging show how paragraphs are detected
    final raw = longContent.split(RegExp(r'\n\s*\n'));
    print('Raw paragraphs count: ${raw.length}');
    for (var i = 0; i < raw.length; i++) {
      print('--- raw[$i] ---');
      print(raw[i]);
    }

    const prodConfig = ChunkingConfig(
      maxChunkTokens: 500,
      strategy: ChunkingStrategy.sentenceBoundary,
      preserveWords: true,
      preserveSentences: true,
    );

    final chunks = await chunker.chunkMessage(msg, prodConfig);
    print('Chunks created: ${chunks.length}');
    for (var i = 0; i < chunks.length; i++) {
      final c = chunks[i];
      print(
        '\n--- Chunk #$i (len=${c.content.length}, tokens=${c.estimatedTokens}) ---',
      );
      print(c.content);
      print('--- end ---');
    }
  } catch (e) {
    print('Error: $e');
  }
}

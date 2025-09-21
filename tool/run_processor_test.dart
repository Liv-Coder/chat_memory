import 'package:chat_memory/src/processing/message_processor.dart';
import 'package:chat_memory/src/processing/message_chunker.dart';
import 'package:chat_memory/src/processing/processing_config.dart';
import 'package:chat_memory/src/processing/embedding_pipeline.dart';
import 'package:chat_memory/src/memory/embeddings/simple_embedding_service.dart';
import 'package:chat_memory/src/core/utils/token_counter.dart';
import 'package:chat_memory/src/core/models/message.dart';

Future<void> main() async {
  final tokenCounter = HeuristicTokenCounter();
  final chunker = MessageChunker(tokenCounter: tokenCounter);
  final embeddingService = SimpleEmbeddingService(dimensions: 128);
  final embeddingPipeline = EmbeddingPipeline(
    embeddingService: embeddingService,
  );

  final processor = MessageProcessor(
    chunker: chunker,
    embeddingPipeline: embeddingPipeline,
  );

  final largeMessage = Message(
    id: 'large',
    role: MessageRole.user,
    timestamp: DateTime.now().toUtc(),
    content: '''
This is a very large message that contains multiple paragraphs and should be intelligently chunked.

The first paragraph discusses the importance of effective message processing in modern AI systems.
It covers topics such as chunking strategies, embedding generation, and vector storage optimization.

The second paragraph delves into specific implementation details including circuit breaker patterns,
retry logic with exponential backoff, and adaptive batch sizing for optimal performance.

The third paragraph explores monitoring and observability features including metrics collection,
detailed logging, and performance profiling capabilities that are essential for production systems.

The final paragraph summarizes the benefits of using a sophisticated processing pipeline
for handling conversational AI workloads at scale with reliability and efficiency.
''',
  );

  final config = ProcessingPipelineConfig.fromPreset(
    ProcessingPreset.production,
  );

  final result = await processor.processMessages([
    largeMessage,
  ], config.processingConfig);
  print('Processing result chunks: ${result.chunks.length}');
  for (var i = 0; i < result.chunks.length; i++) {
    print(
      'Chunk $i len=${result.chunks[i].content.length} tokens=${result.chunks[i].estimatedTokens}',
    );
  }
}

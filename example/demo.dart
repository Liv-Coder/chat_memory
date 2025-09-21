import 'package:chat_memory/chat_memory.dart';
import 'dart:developer' as developer;

/// Comprehensive demo showcasing the hybrid memory system capabilities
///
/// This demo demonstrates:
/// - Basic conversation management with automatic summarization
/// - Semantic retrieval across conversation topics
/// - Different memory presets and configurations
/// - Performance monitoring and statistics
/// - Error handling and edge cases
void main() async {
  developer.log('🚀 Chat Memory Hybrid System Demo');
  developer.log('=' * 50);

  await demoBasicUsage();
  await demoSemanticRetrieval();
  await demoMemoryPresets();
  await demoAdvancedConfiguration();
  await demoPerformanceMonitoring();

  developer.log('\n✅ Demo completed successfully!');
}

/// Demo 1: Basic usage with automatic summarization
Future<void> demoBasicUsage() async {
  developer.log('\n📝 Demo 1: Basic Usage with Summarization');
  developer.log('-' * 40);

  // Create manager with small token budget to trigger summarization
  final manager = await EnhancedConversationManager.create(
    preset: MemoryPreset.development,
    maxTokens: 800,
  );

  // Simulate a long conversation about AI
  await manager.appendSystemMessage(
    'You are an expert AI researcher and educator.',
  );

  await manager.appendUserMessage(
    'Can you explain what artificial intelligence is?',
  );

  await manager.appendAssistantMessage(
    'Artificial Intelligence (AI) is a field of computer science focused on creating systems that can perform tasks typically requiring human intelligence. This includes learning from data, recognizing patterns, making decisions, and understanding natural language. AI encompasses various subfields like machine learning, natural language processing, computer vision, and robotics.',
  );

  await manager.appendUserMessage(
    'What are the different types of machine learning?',
  );

  await manager.appendAssistantMessage(
    'Machine learning has three main types: 1) Supervised Learning - uses labeled data to train models (classification, regression), 2) Unsupervised Learning - finds patterns in unlabeled data (clustering, dimensionality reduction), and 3) Reinforcement Learning - learns through interaction with an environment using rewards and penalties.',
  );

  await manager.appendUserMessage('How do neural networks work?');

  await manager.appendAssistantMessage(
    'Neural networks are inspired by biological neurons. They consist of interconnected nodes (artificial neurons) organized in layers. Each connection has a weight, and neurons apply activation functions to process inputs. Through training with backpropagation, the network adjusts weights to minimize errors and learn patterns in data.',
  );

  await manager.appendUserMessage(
    'What is deep learning and how is it different?',
  );

  // Build prompt - should trigger summarization due to token limit
  final prompt = await manager.buildPrompt(
    clientTokenBudget: 600,
    userQuery: 'deep learning explanation',
  );

  developer.log('Final prompt (${prompt.estimatedTokens} tokens):');
  developer.log('─' * 30);
  developer.log(prompt.promptText);

  if (prompt.summary != null) {
    developer.log('\n📄 Generated Summary:');
    developer.log(prompt.summary!);
  } else {
    developer.log('\n📄 No summarization needed (within token budget)');
  }

  developer.log('\n📊 Messages: ${prompt.includedMessages.length} included');
}

/// Demo 2: Semantic retrieval across different topics
Future<void> demoSemanticRetrieval() async {
  developer.log('\n🔍 Demo 2: Semantic Retrieval');
  developer.log('-' * 40);

  final manager = await EnhancedConversationManager.create(
    preset: MemoryPreset.production,
    maxTokens: 2000,
  );

  // Build conversation with diverse topics
  await manager.appendSystemMessage(
    'You are a helpful assistant with broad knowledge.',
  );

  // Topic 1: Cooking
  await manager.appendUserMessage('How do I make homemade pasta?');
  await manager.appendAssistantMessage(
    'To make homemade pasta, mix 2 cups flour with 3 eggs, knead until smooth, rest 30 minutes, then roll thin and cut into desired shapes. Fresh pasta cooks in just 2-3 minutes in boiling salted water.',
  );

  // Topic 2: Technology
  await manager.appendUserMessage('Explain blockchain technology');
  await manager.appendAssistantMessage(
    'Blockchain is a distributed ledger technology that maintains a continuously growing list of records (blocks) linked using cryptography. Each block contains a hash of the previous block, timestamp, and transaction data, making it resistant to modification.',
  );

  // Topic 3: Health & Fitness
  await manager.appendUserMessage('Best exercises for building muscle?');
  await manager.appendAssistantMessage(
    'Compound movements are most effective for muscle building: squats, deadlifts, bench press, pull-ups, and rows. Focus on progressive overload, proper form, adequate protein intake, and sufficient recovery time between workouts.',
  );

  // Topic 4: Travel
  await manager.appendUserMessage('Recommend places to visit in Europe?');
  await manager.appendAssistantMessage(
    'Europe offers incredible diversity: Paris for art and culture, Rome for history, Barcelona for architecture, Amsterdam for canals and museums, Prague for medieval charm, and the Swiss Alps for stunning natural beauty.',
  );

  // Topic 5: Science
  await manager.appendUserMessage('How does photosynthesis work?');
  await manager.appendAssistantMessage(
    'Photosynthesis converts light energy into chemical energy. Chloroplasts absorb sunlight, water from roots, and CO2 from air. Through light and dark reactions, plants produce glucose and release oxygen as a byproduct.',
  );

  // Now ask about cooking again - should retrieve relevant context
  await manager.appendUserMessage('What about making fresh bread?');

  final enhancedPrompt = await manager.buildEnhancedPrompt(
    clientTokenBudget: 1500,
    userQuery: 'bread baking techniques and tips',
  );

  developer.log('🔎 Query: "bread baking techniques and tips"');
  developer.log(
    '📚 Semantic messages retrieved: ${enhancedPrompt.semanticMessages.length}',
  );

  for (int i = 0; i < enhancedPrompt.semanticMessages.length; i++) {
    final msg = enhancedPrompt.semanticMessages[i];
    final similarity = msg.metadata?['similarity']?.toStringAsFixed(3) ?? 'N/A';
    developer.log(
      '  ${i + 1}. Similarity: $similarity | ${msg.content.substring(0, 60)}...',
    );
  }

  developer.log('\n🎯 Processing metadata:');
  enhancedPrompt.metadata.forEach((key, value) {
    developer.log('  $key: $value');
  });
}

/// Demo 3: Different memory presets
Future<void> demoMemoryPresets() async {
  developer.log('\n⚙️ Demo 3: Memory Presets Comparison');
  developer.log('-' * 40);

  final testMessages = [
    'You are a knowledgeable assistant.',
    'Tell me about renewable energy.',
    'Solar, wind, hydro, and geothermal are the main renewable energy sources. They provide sustainable alternatives to fossil fuels with lower environmental impact.',
    'What about energy storage solutions?',
    'Battery technology is crucial for renewable energy. Lithium-ion, flow batteries, and emerging solid-state batteries help store energy when production exceeds demand.',
    'How efficient are solar panels?',
    'Modern solar panels achieve 15-22% efficiency, with premium panels reaching up to 26%. Efficiency continues improving with new materials and manufacturing techniques.',
  ];

  final presets = [
    MemoryPreset.development,
    MemoryPreset.minimal,
    MemoryPreset.production,
    MemoryPreset.performance,
  ];

  for (final preset in presets) {
    developer.log('\n🔧 Testing ${preset.toString().split('.').last} preset:');

    final manager = await EnhancedConversationManager.create(
      preset: preset,
      maxTokens: 1000,
    );

    // Add messages alternating between system, user, and assistant
    final roles = [
      MessageRole.system,
      MessageRole.user,
      MessageRole.assistant,
      MessageRole.user,
      MessageRole.assistant,
      MessageRole.user,
      MessageRole.assistant,
    ];

    for (int i = 0; i < testMessages.length; i++) {
      final message = Message(
        id: 'msg_$i',
        role: roles[i],
        content: testMessages[i],
        timestamp: DateTime.now().toUtc(),
      );
      await manager.appendMessage(message);
    }

    final prompt = await manager.buildPrompt(clientTokenBudget: 800);
    final stats = await manager.getStats();

    developer.log(
      '  Messages: ${stats.totalMessages} total, ${prompt.includedMessages.length} included',
    );
    developer.log('  Tokens: ${prompt.estimatedTokens}');
    developer.log('  Vectors: ${stats.vectorCount ?? 'N/A'}');
    developer.log(
      '  Summary: ${prompt.summary != null ? 'Generated' : 'None'}',
    );
  }
}

/// Demo 4: Advanced configuration with builder pattern
Future<void> demoAdvancedConfiguration() async {
  developer.log('\n🏗️ Demo 4: Advanced Configuration');
  developer.log('-' * 40);

  var summaryCount = 0;
  var messageCount = 0;

  // Custom memory manager with specific settings
  final customMemoryManager = MemoryManagerBuilder()
      .withMaxTokens(2000)
      .withInMemoryVectorStore()
      .withSimpleEmbedding(dimensions: 256)
      .enableSemanticMemory(topK: 8, minSimilarity: 0.2)
      .build();

  final manager = EnhancedConversationManager(
    memoryManager: customMemoryManager,
    onSummaryCreated: (summary) {
      summaryCount++;
      developer.log(
        '📄 Summary created: ${summary.content.substring(0, 50)}...',
      );
    },
    onMessageStored: (message) {
      messageCount++;
      developer.log(
        '💾 Stored ${message.role.toString().split('.').last}: ${message.content.substring(0, 30)}...',
      );
    },
  );

  // Add a conversation about software development
  await manager.appendSystemMessage(
    'You are an expert software architect and mentor.',
  );

  await manager.appendUserMessage(
    'What are the key principles of microservices architecture?',
  );

  await manager.appendAssistantMessage(
    'Key microservices principles include: 1) Single Responsibility - each service owns one business capability, 2) Decentralized - autonomous teams and data, 3) Fault Isolation - failures don\'t cascade, 4) Technology Diversity - use best tools for each service.',
  );

  await manager.appendUserMessage(
    'How do you handle data consistency across services?',
  );

  await manager.appendAssistantMessage(
    'Data consistency in microservices uses eventual consistency patterns: Saga pattern for distributed transactions, Event Sourcing for audit trails, CQRS for read/write separation, and Outbox pattern for reliable event publishing.',
  );

  // Build prompt with custom configuration
  final prompt = await manager.buildPrompt(clientTokenBudget: 1200);

  developer.log('\n📋 Custom Configuration Results:');
  developer.log('  Messages processed: $messageCount');
  developer.log('  Summaries created: $summaryCount');
  developer.log('  Final tokens: ${prompt.estimatedTokens}');
  developer.log(
    '  Vector store enabled: ${customMemoryManager.vectorStore != null}',
  );
}

/// Demo 5: Performance monitoring and statistics
Future<void> demoPerformanceMonitoring() async {
  developer.log('\n📊 Demo 5: Performance Monitoring');
  developer.log('-' * 40);

  final manager = await EnhancedConversationManager.create(
    preset: MemoryPreset.performance,
    maxTokens: 3000,
  );

  // Simulate extended conversation
  final topics = [
    ('Climate change', 'What are the main causes of climate change?'),
    (
      'Renewable energy',
      'How can renewable energy help combat climate change?',
    ),
    (
      'Electric vehicles',
      'What role do electric vehicles play in sustainability?',
    ),
    ('Carbon capture', 'Explain carbon capture and storage technology'),
    ('Green buildings', 'What makes a building environmentally sustainable?'),
    ('Circular economy', 'How does circular economy reduce waste?'),
    ('Biodiversity', 'Why is biodiversity important for ecosystems?'),
  ];

  await manager.appendSystemMessage(
    'You are an environmental science expert and sustainability consultant.',
  );

  developer.log('🔄 Building extended conversation...');
  final startTime = DateTime.now();

  for (final (topic, question) in topics) {
    await manager.appendUserMessage(question);
    await manager.appendAssistantMessage(
      'This is a detailed response about $topic with comprehensive information covering multiple aspects of the topic including current research, practical applications, and future implications for environmental sustainability and climate action.',
    );
  }

  final processingTime = DateTime.now().difference(startTime);

  // Get comprehensive statistics
  final stats = await manager.getStats();
  final enhancedPrompt = await manager.buildEnhancedPrompt(
    clientTokenBudget: 2500,
    userQuery: 'environmental sustainability overview',
  );

  developer.log('\n📈 Performance Statistics:');
  developer.log('─' * 25);
  developer.log('Conversation Building:');
  developer.log('  Time taken: ${processingTime.inMilliseconds}ms');
  developer.log(
    '  Messages added: ${topics.length * 2 + 1}',
  ); // +1 for system message

  developer.log('\nMemory Statistics:');
  developer.log(stats.toString());

  developer.log('Context Retrieval:');
  developer.log(
    '  Processing time: ${enhancedPrompt.metadata['processingTimeMs']}ms',
  );
  developer.log('  Strategy used: ${enhancedPrompt.metadata['strategyUsed']}');
  developer.log(
    '  Original messages: ${enhancedPrompt.metadata['originalMessageCount']}',
  );
  developer.log(
    '  Final messages: ${enhancedPrompt.metadata['finalMessageCount']}',
  );
  developer.log(
    '  Summarized messages: ${enhancedPrompt.metadata['summarizedMessageCount']}',
  );
  developer.log(
    '  Semantic retrievals: ${enhancedPrompt.metadata['semanticRetrievalCount']}',
  );

  if (enhancedPrompt.semanticMessages.isNotEmpty) {
    developer.log('\nSemantic Retrieval Results:');
    for (int i = 0; i < enhancedPrompt.semanticMessages.length; i++) {
      final msg = enhancedPrompt.semanticMessages[i];
      final similarity =
          msg.metadata?['similarity']?.toStringAsFixed(3) ?? 'N/A';
      developer.log(
        '  ${i + 1}. Score: $similarity | ${msg.content.substring(0, 50)}...',
      );
    }
  }

  // Test follow-up generation (if available)
  final followUps = await manager.generateFollowUpQuestions(max: 3);
  if (followUps.isNotEmpty) {
    developer.log('\n❓ Suggested Follow-ups:');
    for (int i = 0; i < followUps.length; i++) {
      developer.log('  ${i + 1}. ${followUps[i]}');
    }
  }

  developer.log('\n🎯 Final Context Summary:');
  developer.log('  Total tokens: ${enhancedPrompt.estimatedTokens}');
  developer.log(
    '  Within budget: ${enhancedPrompt.estimatedTokens <= 2500 ? '✅' : '❌'}',
  );

  if (enhancedPrompt.summary != null) {
    developer.log('  Summary length: ${enhancedPrompt.summary!.length} chars');
  }
}

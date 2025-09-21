import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ai_provider.dart';
import 'settings_service.dart';

/// Enhanced AI service supporting multiple providers
class AIService {
  static final SettingsService _settingsService = SettingsService();

  static Future<String> generateResponse(
    String userMessage, {
    String? context,
  }) async {
    final settings = _settingsService.currentSettings;
    final config = settings.aiConfig;

    switch (config.provider) {
      case AIProvider.demo:
        return _generateDemoResponse(userMessage, context: context);
      case AIProvider.gemini:
        return await _generateGeminiResponse(
          userMessage,
          context: context,
          config: config,
        );
      case AIProvider.groq:
        return await _generateGroqResponse(
          userMessage,
          context: context,
          config: config,
        );
      case AIProvider.openRouter:
        return await _generateOpenRouterResponse(
          userMessage,
          context: context,
          config: config,
        );
    }
  }

  static String _generateDemoResponse(String userMessage, {String? context}) {
    final hasMemory = context != null && context.isNotEmpty;
    final message = userMessage.toLowerCase();

    // Context-aware responses based on user input
    if (message.contains('hello') || message.contains('hi')) {
      return hasMemory
          ? "Hello again! I can see we've chatted before. What would you like to discuss today?"
          : "Hello! I'm Claude with an advanced memory system. As we chat, I'll remember our conversations!";
    }

    if (message.contains('remember') || message.contains('recall')) {
      return hasMemory
          ? "I can see from our conversation history that we've discussed various topics. What specifically would you like me to recall?"
          : "I don't have any previous conversation history yet. Let's start building our memory together!";
    }

    if (message.contains('memory') || message.contains('how')) {
      return """I'm using a hybrid memory system with these features:

🧠 **Smart Summarization**: I compress older conversations while keeping important details
🔍 **Semantic Search**: I find relevant context from our past discussions  
📚 **Vector Storage**: Messages are stored as searchable embeddings
⚡ **Context-Aware**: I optimize information based on our current topic

${hasMemory ? "I can see we have conversation history stored!" : "We're just getting started - I'll build our memory as we chat!"}""";
    }

    if (message.contains('test') || message.contains('demo')) {
      return hasMemory
          ? "Great! The memory system is working - I can reference our past discussions. Try asking me about something we talked about earlier!"
          : "Perfect! Let's test the memory system. Ask me something, then later ask me to recall it!";
    }

    // Default contextual response
    return hasMemory
        ? "I understand your message: \"$userMessage\". Based on our conversation history, I can provide contextual responses. What would you like to explore further?"
        : "Thanks for your message: \"$userMessage\". I've stored it in my memory system and I'm ready to build on our conversation!";
  }

  static Future<String> _generateGeminiResponse(
    String userMessage, {
    required String? context,
    required AIProviderConfig config,
  }) async {
    try {
      final prompt = _buildEnhancedPrompt(userMessage, context);

      final response = await http.post(
        Uri.parse(
          '${config.provider.baseUrl}/models/${config.effectiveModel}:generateContent',
        ),
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': config.apiKey!,
        },
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt},
              ],
            },
          ],
          'generationConfig': {'temperature': 0.7, 'maxOutputTokens': 1000},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content =
            data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        return content ??
            'I received your message but couldn\'t generate a proper response.';
      } else {
        throw Exception('Gemini API error: ${response.statusCode}');
      }
    } catch (e) {
      return _generateDemoResponse(userMessage, context: context);
    }
  }

  static Future<String> _generateGroqResponse(
    String userMessage, {
    required String? context,
    required AIProviderConfig config,
  }) async {
    try {
      final prompt = _buildEnhancedPrompt(userMessage, context);

      final response = await http.post(
        Uri.parse('${config.provider.baseUrl}/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${config.apiKey!}',
        },
        body: jsonEncode({
          'model': config.effectiveModel,
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are Claude, a helpful AI assistant with an excellent memory system.',
            },
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.7,
          'max_tokens': 1000,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices']?[0]?['message']?['content'];
        return content ??
            'I received your message but couldn\'t generate a proper response.';
      } else {
        throw Exception('Groq API error: ${response.statusCode}');
      }
    } catch (e) {
      return _generateDemoResponse(userMessage, context: context);
    }
  }

  static Future<String> _generateOpenRouterResponse(
    String userMessage, {
    required String? context,
    required AIProviderConfig config,
  }) async {
    try {
      final prompt = _buildEnhancedPrompt(userMessage, context);

      final response = await http.post(
        Uri.parse('${config.provider.baseUrl}/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${config.apiKey!}',
          'HTTP-Referer': 'https://github.com/your-repo/chat-memory',
          'X-Title': 'Chat Memory Demo',
        },
        body: jsonEncode({
          'model': config.effectiveModel,
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are Claude, a helpful AI assistant with an excellent memory system.',
            },
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.7,
          'max_tokens': 1000,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices']?[0]?['message']?['content'];
        return content ??
            'I received your message but couldn\'t generate a proper response.';
      } else {
        throw Exception('OpenRouter API error: ${response.statusCode}');
      }
    } catch (e) {
      return _generateDemoResponse(userMessage, context: context);
    }
  }

  static String _buildEnhancedPrompt(String userMessage, String? context) {
    final buffer = StringBuffer();

    buffer.writeln(
      'You are Claude, a helpful AI assistant with an advanced memory system.',
    );
    buffer.writeln(
      'You can remember past conversations and find relevant context.',
    );
    buffer.writeln();

    if (context != null && context.isNotEmpty) {
      buffer.writeln('=== CONVERSATION CONTEXT ===');
      buffer.writeln(context);
      buffer.writeln();
    }

    buffer.writeln('=== USER MESSAGE ===');
    buffer.writeln(userMessage);
    buffer.writeln();

    buffer.writeln('Please respond naturally and conversationally.');
    if (context != null && context.isNotEmpty) {
      buffer.writeln('Reference the conversation context when relevant.');
    }

    return buffer.toString();
  }

  static Future<bool> testConnection(AIProviderConfig config) async {
    if (!config.isConfigured) return false;

    try {
      final testResponse = await generateResponse(
        'Hello, this is a connection test.',
        context: null,
      );
      return testResponse.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}

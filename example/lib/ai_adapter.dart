import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Enhanced adapter for communicating with AI services
///
/// Provides memory-aware response generation that understands the hybrid
/// memory context including summaries, semantic retrieval, and conversation flow.
class AIAdapter {
  // Replace with your actual Gemini API key
  static String? _apiKey;
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta';
  static GenerativeModel? _model;

  /// Get a memory-aware response from the AI using enhanced prompts
  ///
  /// This method handles the full hybrid memory context including:
  /// - Automatic summaries of past conversations
  /// - Semantically retrieved relevant context
  /// - Recent message history
  static Future<String> getResponse(String prompt, String? summary) async {
    try {
      // If no API key is configured, return a simulated response
      if (!isConfigured) {
        return _getSimulatedResponse(prompt, summary);
      }

      final fullPrompt = _buildEnhancedPrompt(prompt, summary);

      // Prefer SDK if configured
      if (_model != null) {
        return await _getGeminiSdkResponse(fullPrompt);
      }

      // Fallback to REST API call
      return await _getGeminiResponse(fullPrompt, null);
    } catch (e) {
      // Fallback to simulated response on error
      return _getSimulatedResponse(prompt, summary);
    }
  }

  /// Build an enhanced prompt that incorporates memory context
  static String _buildEnhancedPrompt(String prompt, String? summary) {
    final buffer = StringBuffer();

    // Add memory context instruction
    buffer.writeln(
      'You are Claude, a helpful AI assistant with an advanced memory system.',
    );
    buffer.writeln(
      'You can remember past conversations and find relevant context.',
    );
    buffer.writeln(
      'When responding, acknowledge when you\'re using information from past context.',
    );
    buffer.writeln();

    // Add summary context if available
    if (summary != null && summary.isNotEmpty) {
      buffer.writeln('=== MEMORY SUMMARY ===');
      buffer.writeln('Here\'s a summary of our previous conversations:');
      buffer.writeln(summary);
      buffer.writeln();
    }

    // Add current conversation
    buffer.writeln('=== CURRENT CONVERSATION ===');
    buffer.writeln(prompt);
    buffer.writeln();

    // Add response guidelines
    buffer.writeln(
      'Please respond naturally and conversationally. If you reference information',
    );
    buffer.writeln(
      'from the memory summary, mention that you\'re recalling from our past discussion.',
    );

    return buffer.toString();
  }

  /// Provide simulated responses when no real AI service is configured
  static String _getSimulatedResponse(String prompt, String? summary) {
    final hasMemory = summary != null && summary.isNotEmpty;

    // Extract the last user message for context-aware responses
    final lines = prompt.split('\n');
    final userMessages = lines
        .where((line) => line.startsWith('user:'))
        .toList();
    final lastUserMessage = userMessages.isNotEmpty
        ? userMessages.last.replaceFirst('user: ', '').toLowerCase()
        : '';

    // Generate context-aware simulated responses
    if (lastUserMessage.contains('remember') ||
        lastUserMessage.contains('recall')) {
      return hasMemory
          ? "I can see from our previous conversations that we've discussed several topics. ${_getTopicResponse(lastUserMessage)} Is there something specific you'd like me to recall?"
          : "I don't have any previous conversation history to recall from yet. Let's start building our conversation memory!";
    }

    if (lastUserMessage.contains('hello') || lastUserMessage.contains('hi')) {
      return hasMemory
          ? "Hello again! I remember our previous conversations. ${_getMemoryAcknowledgment()} What would you like to discuss today?"
          : "Hello! I'm Claude, and I have a sophisticated memory system. As we chat, I'll remember our conversations and be able to reference them later. What would you like to talk about?";
    }

    if (lastUserMessage.contains('how') && lastUserMessage.contains('memory')) {
      return """I'm using a hybrid memory system with several powerful features:

🧠 **Automatic Summarization**: I compress older conversations while keeping the important details
🔍 **Semantic Search**: I can find relevant context from our past discussions
📚 **Vector Storage**: Each message is stored as a searchable embedding
⚡ **Smart Context**: I optimize what information to include based on our current topic

${hasMemory ? "I can see we have conversation history stored, which helps me provide more contextual responses!" : "We're just getting started, but I'll begin building our conversation memory right away!"}""";
    }

    if (lastUserMessage.contains('test') ||
        lastUserMessage.contains('example')) {
      return hasMemory
          ? "Great! I can see from our conversation history that we've been exploring the memory system. ${_getTestResponse()} The memory system is working well - I can reference our past discussions!"
          : "Perfect! Let's test the memory system. Try asking me about something, then later ask me to recall it. You'll see how I can remember and reference our previous conversations!";
    }

    // Default response
    return hasMemory
        ? "I understand your message and I have context from our previous conversations to help inform my response. ${_getContextualResponse(lastUserMessage)}"
        : "I understand your message. This is the beginning of our conversation, so I'm starting to build our memory together. ${_getGeneralResponse(lastUserMessage)}";
  }

  /// Generate topic-specific responses
  static String _getTopicResponse(String message) {
    if (message.contains('travel') || message.contains('trip')) {
      return "I recall we discussed travel plans and destinations.";
    }
    if (message.contains('code') || message.contains('program')) {
      return "I remember we talked about programming concepts.";
    }
    if (message.contains('food') || message.contains('cook')) {
      return "I see we've discussed cooking and recipes before.";
    }
    return "I can see we've covered various topics in our conversations.";
  }

  /// Acknowledge memory usage
  static String _getMemoryAcknowledgment() {
    final responses = [
      "Thanks to my memory system, I can build on our previous discussions.",
      "I have our conversation history available for context.",
      "My memory system has preserved our past interactions.",
    ];
    return responses[DateTime.now().millisecond % responses.length];
  }

  /// Generate test-specific responses
  static String _getTestResponse() {
    return "Try asking me about something we discussed earlier, or ask me to explain how my memory works.";
  }

  /// Generate contextual responses
  static String _getContextualResponse(String message) {
    return "Let me know if you'd like me to reference specific parts of our conversation history.";
  }

  /// Generate general responses
  static String _getGeneralResponse(String message) {
    return "Feel free to ask me anything, and I'll start building our shared conversation memory!";
  }

  /// Get response from Google Gemini SDK
  static Future<String> _getGeminiSdkResponse(String fullPrompt) async {
    try {
      _model ??= GenerativeModel(model: 'gemini-2.0-flash', apiKey: _apiKey!);
      final content = [Content.text(fullPrompt)];
      final result = await _model!.generateContent(content);
      return result.text ?? '';
    } catch (e) {
      throw Exception('Gemini SDK error: $e');
    }
  }

  /// Get response from Google Gemini API
  static Future<String> _getGeminiResponse(
    String prompt,
    String? summary,
  ) async {
    try {
      // Prepare the full prompt with context
      final fullPrompt = summary != null && summary.isNotEmpty
          ? "$summary\n\nCurrent conversation:\n$prompt"
          : prompt;

      // Make API call to Google Gemini
      final response = await http.post(
        Uri.parse('$_baseUrl/models/gemini-2.0-flash:generateContent'),
        headers: {
          'Content-Type': 'application/json',
          'X-goog-api-key': _apiKey!,
        },
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': fullPrompt},
              ],
            },
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final candidates = data['candidates'] as List;

        if (candidates.isNotEmpty) {
          final content = candidates[0]['content'] as Map<String, dynamic>;
          final parts = content['parts'] as List;

          if (parts.isNotEmpty) {
            return parts[0]['text'] as String;
          }
        }

        throw Exception('No content generated from Gemini API');
      } else {
        throw Exception(
          'Gemini API error: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Failed to call Gemini API: $e');
    }
  }

  /// Real implementation using Gemini API
  /// Uncomment and configure this method to use actual Gemini AI services
  /*
  static Future<String> _getGeminiResponse(String prompt, String? summary) async {
    // Initialize the model if not already done
    _model ??= GenerativeModel(
      model: 'gemini-pro',
      apiKey: _apiKey,
    );

    final fullPrompt = summary != null && summary.isNotEmpty
        ? "$summary\n\nCurrent conversation:\n$prompt"
        : prompt;

    final content = [Content.text(fullPrompt)];
    final response = await _model!.generateContent(content);

    return response.text ?? 'I apologize, but I couldn\'t generate a response.';
  }
  */

  /// Configure the AI adapter with your Gemini API credentials
  static Future<void> configure({
    required String apiKey,
    String? modelName,
  }) async {
    if (apiKey.isEmpty) {
      await clearApiKey();
      return;
    }

    _apiKey = apiKey;
    await _saveApiKey(apiKey);
    // Initialize the model with the provided API key
    _model = GenerativeModel(model: modelName ?? 'gemini-pro', apiKey: apiKey);
  }

  /// Set API key and save to persistent storage
  static Future<void> setApiKey(String apiKey) async {
    _apiKey = apiKey;
    await _saveApiKey(apiKey);
    // Reset model to use new API key
    _model = null;
  }

  /// Get current API key (masked for security)
  static String? get maskedApiKey {
    if (_apiKey == null || _apiKey!.isEmpty) return null;
    if (_apiKey!.length < 8) return '*' * _apiKey!.length;
    return '${_apiKey!.substring(0, 4)}${'*' * (_apiKey!.length - 8)}${_apiKey!.substring(_apiKey!.length - 4)}';
  }

  /// Clear API key from memory and storage
  static Future<void> clearApiKey() async {
    _apiKey = null;
    _model = null;
    await _clearStoredApiKey();
  }

  /// Load API key from persistent storage
  static Future<void> _loadApiKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _apiKey = prefs.getString('gemini_api_key');
    } catch (e) {
      // If SharedPreferences fails, keep _apiKey as null
      _apiKey = null;
    }
  }

  /// Save API key to persistent storage
  static Future<void> _saveApiKey(String apiKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('gemini_api_key', apiKey);
    } catch (e) {
      // If SharedPreferences fails, just keep in memory
    }
  }

  /// Clear API key from persistent storage
  static Future<void> _clearStoredApiKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('gemini_api_key');
    } catch (e) {
      // If SharedPreferences fails, nothing to clear
    }
  }

  /// Check if the adapter is properly configured with a real API key
  static bool get isConfigured {
    return _apiKey != null &&
        _apiKey!.isNotEmpty &&
        _apiKey!.length > 20 && // Basic validation
        _apiKey!.startsWith('AIza'); // Gemini API keys start with AIza
  }

  /// Get configuration status information
  static Map<String, dynamic> getConfigInfo() {
    return {
      'configured': isConfigured,
      'api_key_set': _apiKey != null && _apiKey!.isNotEmpty,
      'api_key_masked': maskedApiKey,
      'model_initialized': _model != null,
      'simulation_mode': !isConfigured,
      'message': isConfigured
          ? 'Connected to Gemini AI'
          : 'Running in simulation mode - set your API key for real AI responses',
    };
  }
}

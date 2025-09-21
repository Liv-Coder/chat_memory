import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:chat_memory/chat_memory.dart';
import 'chat_manager.dart';
import 'ai_adapter.dart';
import 'api_key_screen.dart';

void main() {
  runApp(const ChatMemoryExampleApp());
}

class ChatMemoryExampleApp extends StatefulWidget {
  const ChatMemoryExampleApp({super.key});

  @override
  State<ChatMemoryExampleApp> createState() => _ChatMemoryExampleAppState();
}

class _ChatMemoryExampleAppState extends State<ChatMemoryExampleApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chat Memory Example',
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        textTheme: GoogleFonts.interTextTheme(),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[50],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          elevation: 4,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.interTextTheme(
          ThemeData(brightness: Brightness.dark).textTheme,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[900],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          elevation: 4,
        ),
      ),
      home: ChatScreen(
        onToggleTheme: () {
          setState(() {
            _themeMode = _themeMode == ThemeMode.dark
                ? ThemeMode.light
                : ThemeMode.dark;
          });
        },
        themeMode: _themeMode,
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final ThemeMode themeMode;

  const ChatScreen({
    super.key,
    required this.onToggleTheme,
    required this.themeMode,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatManager _chatManager = ChatManager();
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String? _lastSummary;
  Map<String, dynamic>? _lastTokenInfo;
  final List<String> _followUps = [];
  ConversationStats? _conversationStats;
  List<Message> _semanticMessages = [];
  Map<String, dynamic> _memoryInfo = {};

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    // Get memory info after initialization
    _memoryInfo = _chatManager.getMemoryInfo();

    // Check if API key is configured
    final isConfigured = AIAdapter.isConfigured;

    // Use memory info to show system type in debug
    debugPrint('Memory system initialized: ${_memoryInfo['memory_type']}');

    setState(() {
      _messages.add(
        ChatMessage(
          text: isConfigured
              ? "Hello! I'm Claude, an AI assistant with an advanced hybrid memory system. 🧠\n\nI can:\n• Remember our past conversations\n• Search through our chat history\n• Automatically summarize long discussions\n• Find relevant context from previous topics\n\nTry asking me something, or ask about a topic we discussed before!"
              : "Hello! I'm Claude, an AI assistant with hybrid memory. 🧠\n\n⚠️ **Running in simulation mode**\n\nTo get real AI responses, please:\n1. Tap the 🔑 key icon in the top bar\n2. Enter your Gemini API key\n3. Get your free API key at ai.google.dev\n\nFor now, I'll provide simulated responses to demonstrate the memory system!",
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
    });

    // Update stats
    _updateStats();
  }

  Future<void> _sendMessage() async {
    final userMessage = _messageController.text.trim();
    if (userMessage.isEmpty) return;

    setState(() {
      _messages.add(
        ChatMessage(text: userMessage, isUser: true, timestamp: DateTime.now()),
      );
      _isLoading = true;
      _lastSummary = null;
      _lastTokenInfo = null;
    });

    _messageController.clear();

    try {
      await _chatManager.appendUserMessage(userMessage);

      // Use enhanced prompt with semantic search
      final enhancedPrompt = await _chatManager.buildEnhancedPrompt(
        clientTokenBudget: 4000,
        userQuery: userMessage,
      );

      // Keep enhanced info for display
      _lastTokenInfo = _chatManager.getTokenInfo(enhancedPrompt);
      _lastSummary = enhancedPrompt.summary;
      _semanticMessages = enhancedPrompt.semanticMessages;

      // Generate follow-up suggestions and update stats
      try {
        final followUps = await _chatManager.getFollowUpSuggestions(max: 3);
        setState(() {
          _followUps.clear();
          _followUps.addAll(followUps);
        });
      } catch (_) {
        // Ignore follow-up generation errors
      }

      final aiResponse = await AIAdapter.getResponse(
        enhancedPrompt.promptText,
        enhancedPrompt.summary,
      );

      await _chatManager.appendAssistantMessage(aiResponse);

      setState(() {
        _messages.add(
          ChatMessage(
            text: aiResponse,
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      });
    } catch (e) {
      setState(() {
        _messages.add(
          ChatMessage(
            text: "Sorry, I encountered an error: $e",
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      _updateStats();
    }
  }

  Future<void> _updateStats() async {
    try {
      final stats = await _chatManager.getConversationStats();
      setState(() {
        _conversationStats = stats;
      });
    } catch (_) {
      // Ignore stats errors
    }
  }

  Widget _buildMemoryInfoCards(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          if (_lastSummary != null && _lastSummary!.isNotEmpty)
            _buildSummaryCard(context),
          if (_semanticMessages.isNotEmpty) _buildSemanticCard(context),
          if (_conversationStats != null) _buildStatsCard(context),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: const Icon(Icons.summarize, color: Colors.blue),
        title: const Text('Memory Summary'),
        subtitle: Text('${_lastSummary!.length} characters'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                MarkdownBody(
                  data: _lastSummary!,
                  styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy Summary'),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _lastSummary!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Summary copied!')),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSemanticCard(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: const Icon(Icons.search, color: Colors.green),
        title: const Text('Semantic Memories'),
        subtitle: Text('Found ${_semanticMessages.length} relevant memories'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Context from past conversations:',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                ..._semanticMessages.take(3).map((msg) {
                  final similarity =
                      msg.metadata?['similarity']?.toStringAsFixed(3) ?? 'N/A';
                  return Card(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    child: ListTile(
                      dense: true,
                      leading: Icon(
                        msg.role == MessageRole.user
                            ? Icons.person
                            : Icons.smart_toy,
                        size: 16,
                      ),
                      title: Text(
                        msg.content.length > 80
                            ? '${msg.content.substring(0, 80)}...'
                            : msg.content,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      trailing: Chip(
                        label: Text(similarity),
                        backgroundColor: Colors.green.withValues(alpha: 0.2),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: const Icon(Icons.analytics, color: Colors.orange),
        title: const Text('Memory Stats'),
        subtitle: Text(
          '${_conversationStats!.totalMessages} messages, ${_conversationStats!.totalTokens} tokens',
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildStatRow(
                  'Messages',
                  '${_conversationStats!.totalMessages}',
                ),
                _buildStatRow('Tokens', '${_conversationStats!.totalTokens}'),
                _buildStatRow(
                  'Vectors',
                  '${_conversationStats!.vectorCount ?? 0}',
                ),
                _buildStatRow(
                  'Summaries',
                  '${_conversationStats!.summaryMessages}',
                ),
                if (_conversationStats!.conversationDuration != null)
                  _buildStatRow(
                    'Duration',
                    '${_conversationStats!.conversationDuration!.inMinutes} min',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Chip(label: Text(value)),
        ],
      ),
    );
  }

  Widget _buildFollowUpChips(BuildContext context) {
    if (_followUps.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '💡 Suggested questions:',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: _followUps
                .map(
                  (s) => ActionChip(
                    avatar: const Icon(Icons.psychology, size: 16),
                    label: SizedBox(
                      width: 200,
                      child: Text(
                        s,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    onPressed: () {
                      _messageController.text = s;
                    },
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTokenInfoBar(BuildContext context) {
    if (_lastTokenInfo == null) return const SizedBox.shrink();
    final est = _lastTokenInfo!['estimated_tokens'];
    final hasSummary = _lastTokenInfo!['has_summary'] as bool? ?? false;
    final included = _lastTokenInfo!['included_messages_count'];
    final semanticCount = _lastTokenInfo!['semantic_messages_count'] ?? 0;
    final memoryType = _lastTokenInfo!['memory_type'] ?? 'Standard';
    final isApiConfigured = AIAdapter.isConfigured;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildInfoChip(
              context,
              isApiConfigured ? '🤖 AI' : '🔑 API',
              isApiConfigured ? 'Real' : 'Demo',
            ),
            const SizedBox(width: 8),
            _buildInfoChip(context, '🎯 Tokens', '$est'),
            const SizedBox(width: 8),
            _buildInfoChip(context, '📝 Summary', hasSummary ? 'Yes' : 'No'),
            const SizedBox(width: 8),
            _buildInfoChip(context, '💬 Messages', '$included'),
            const SizedBox(width: 8),
            _buildInfoChip(context, '🔍 Semantic', '$semanticCount'),
            const SizedBox(width: 8),
            _buildInfoChip(context, '🧠 Memory', memoryType),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(BuildContext context, String label, String value) {
    // Special styling for API status chip
    Color chipColor = Theme.of(context).colorScheme.primary;
    if (label.contains('API') || label.contains('AI')) {
      chipColor = AIAdapter.isConfigured ? Colors.green : Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: chipColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w500,
          color: chipColor.withValues(alpha: 0.8),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        widget.themeMode == ThemeMode.dark ||
        (widget.themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hybrid Memory Chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.key),
            onPressed: _openApiKeySettings,
            tooltip: 'API Key Settings',
          ),
          IconButton(
            icon: const Icon(Icons.memory),
            onPressed: _showMemoryDialog,
            tooltip: 'Memory Info',
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _clearConversation,
            tooltip: 'Clear Chat',
          ),
          IconButton(
            icon: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
            onPressed: widget.onToggleTheme,
            tooltip: 'Toggle theme',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildMemoryInfoCards(context),
          _buildFollowUpChips(context),
          _buildTokenInfoBar(context),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: ChatBubble(message: message),
                );
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: LinearProgressIndicator(),
            ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: Theme.of(context).colorScheme.surface,
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      label: 'Message input',
                      textField: true,
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Type your message...',
                          filled: true,
                          fillColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FloatingActionButton(
                    onPressed: _isLoading ? null : _sendMessage,
                    tooltip: 'Send message',
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openApiKeySettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ApiKeyScreen()),
    );

    // Optionally refresh some state after returning from API key settings
    setState(() {
      // This will trigger a rebuild which might show different status
    });
  }

  Future<void> _clearConversation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Conversation'),
        content: const Text(
          'This will clear all messages and reset the memory. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _chatManager.clearConversation();
      setState(() {
        _messages.clear();
        _lastSummary = null;
        _lastTokenInfo = null;
        _followUps.clear();
        _conversationStats = null;
        _semanticMessages.clear();
        _messages.add(
          ChatMessage(
            text:
                "Conversation cleared! Memory has been reset. Let's start fresh! 🧠✨",
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      });
    }
  }

  Future<void> _showMemoryDialog() async {
    final memoryInfo = _chatManager.getMemoryInfo();
    final memoryUsage = _chatManager.getMemoryUsage();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.memory),
            SizedBox(width: 8),
            Text('Hybrid Memory System'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Memory Type: ${memoryInfo['memory_type']}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Text('Features:', style: Theme.of(context).textTheme.titleSmall),
              ...((memoryInfo['features'] as List?) ?? []).map(
                (feature) => Padding(
                  padding: const EdgeInsets.only(left: 16, top: 4),
                  child: Text('• $feature'),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Configuration:',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text('Max Tokens: ${memoryInfo['max_tokens']}'),
              Text('Preset: ${memoryInfo['preset']}'),
              Text('Vector Store: ${memoryInfo['vector_store']}'),
              Text('Embeddings: ${memoryInfo['embedding_service']}'),
              if (memoryUsage['status'] == null) ...[
                const SizedBox(height: 16),
                Text(
                  'Current Usage:',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text('Total Messages: ${memoryUsage['total_messages']}'),
                Text('Vectors Stored: ${memoryUsage['vectors_stored']}'),
                Text('Total Tokens: ${memoryUsage['total_tokens']}'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(isUser ? 16 : 4),
      bottomRight: Radius.circular(isUser ? 4 : 16),
    );

    final gradient = isUser
        ? LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primaryContainer,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : LinearGradient(
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surfaceContainerHighest,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          gradient: gradient,
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
          borderRadius: radius,
        ),
        child: Column(
          crossAxisAlignment: isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            MarkdownBody(
              data: message.text,
              styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)),
            ),
            const SizedBox(height: 6),
            Text(
              _formatTimestamp(message.timestamp),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime t) {
    final dt = t.toLocal();
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/chat_message.dart';
import '../../core/services/demo_ai_service.dart';
import '../../core/services/settings_service.dart';
import '../../chat_manager.dart';
import '../widgets/chat_header.dart';
import '../widgets/message_list.dart';
import '../widgets/follow_up_suggestions.dart';
import '../widgets/message_input.dart';
import '../widgets/memory_stats_card.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late ChatManager _chatManager;
  final SettingsService _settingsService = SettingsService();
  final List<ChatMessage> _messages = [];
  List<String> _followUpSuggestions = [];
  bool _isLoading = false;
  bool _isInitializing = true;
  String _currentFollowUpMode = AppConstants.defaultFollowUpMode;
  bool _showFollowUpSuggestions = true;

  // Performance optimization: debounce follow-up generation
  Timer? _followUpDebouncer;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  @override
  void dispose() {
    _followUpDebouncer?.cancel();
    super.dispose();
  }

  Future<void> _initializeChat() async {
    try {
      // Initialize settings service first
      await _settingsService.initialize();

      // Load settings
      final settings = _settingsService.currentSettings;
      _currentFollowUpMode = settings.followUpMode;
      _showFollowUpSuggestions = settings.showFollowUpSuggestions;

      _chatManager = ChatManager();
      await _chatManager.initialize();

      if (mounted) {
        setState(() {
          _isInitializing = false;
        });

        // Generate initial follow-up suggestions after a short delay
        if (_showFollowUpSuggestions) {
          _debouncedGenerateFollowUps();
        }
      }
    } catch (e) {
      if (mounted) {
        // Capture messenger and theme before showing snackbar
        final messenger = ScaffoldMessenger.of(context);
        final theme = Theme.of(context);

        setState(() {
          _isInitializing = false;
        });

        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to initialize chat: $e'),
            backgroundColor: theme.colorScheme.error,
            action: SnackBarAction(label: 'Retry', onPressed: _initializeChat),
          ),
        );
      }
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _messages.add(
        ChatMessage(
          content: text,
          sender: MessageSender.user,
          timestamp: DateTime.now(),
        ),
      );
    });

    try {
      // Add user message using simplified API
      await _chatManager.addUserMessage(text);

      // Get conversation context using simplified API
      final context = await _chatManager.getContext(maxTokens: 8000);

      // Generate AI response using enhanced AI service
      final response = await AIService.generateResponse(text, context: context);

      // Add assistant response using simplified API
      await _chatManager.addAssistantMessage(response);

      // Generate follow-up suggestions with debouncing
      _debouncedGenerateFollowUps();

      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessage(
              content: response,
              sender: MessageSender.assistant,
              timestamp: DateTime.now(),
            ),
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        // Capture messenger and theme before showing snackbar
        final messenger = ScaffoldMessenger.of(context);
        final theme = Theme.of(context);

        setState(() {
          _messages.add(
            ChatMessage(
              content:
                  'Sorry, I encountered an error processing your message. Please try again.',
              sender: MessageSender.system,
              timestamp: DateTime.now(),
            ),
          );
          _isLoading = false;
        });

        messenger.showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: theme.colorScheme.error,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _sendMessage(text),
            ),
          ),
        );
      }
    }
  }

  void _onFollowUpSelected(String suggestion) {
    // Record interaction for learning
    _chatManager.recordFollowUpInteraction(
      suggestion: suggestion,
      action: 'selected',
      relevanceScore: 1.0,
    );

    _sendMessage(suggestion);
  }

  void _onToggleFollowUpSuggestions(bool show) async {
    try {
      await _settingsService.setShowFollowUpSuggestions(show);
      setState(() {
        _showFollowUpSuggestions = show;
      });

      if (show) {
        _debouncedGenerateFollowUps();
      } else {
        setState(() {
          _followUpSuggestions.clear();
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              show
                  ? 'Follow-up suggestions enabled'
                  : 'Follow-up suggestions disabled',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update setting: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _onFollowUpModeChanged(String mode) {
    try {
      setState(() {
        _currentFollowUpMode = mode;
      });
      _chatManager.setFollowUpMode(mode);
      _settingsService.setFollowUpMode(mode);

      // Regenerate follow-ups with new mode if enabled
      if (_showFollowUpSuggestions) {
        _debouncedGenerateFollowUps();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Follow-up mode changed to: ${mode.toUpperCase()}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to change mode: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// Debounced follow-up generation to improve performance
  void _debouncedGenerateFollowUps() {
    if (!_showFollowUpSuggestions) return;

    _followUpDebouncer?.cancel();
    _followUpDebouncer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final suggestions = await _chatManager.getFollowUpSuggestions();
        if (mounted) {
          setState(() {
            _followUpSuggestions = suggestions;
          });
        }
      } catch (e) {
        // Silently handle follow-up generation errors
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen during initialization
    if (_isInitializing) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chat Memory Demo')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Initializing chat memory system...'),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: ChatHeader(
        followUpMode: _currentFollowUpMode,
        onFollowUpModeChanged: _onFollowUpModeChanged,
        showFollowUpSuggestions: _showFollowUpSuggestions,
        onToggleFollowUpSuggestions: _onToggleFollowUpSuggestions,
        onClearChat: () async {
          // Capture messenger and theme before any async gaps to avoid using
          // the BuildContext after awaits (fixes use_build_context_synchronously).
          final messenger = ScaffoldMessenger.of(context);
          final theme = Theme.of(context);

          try {
            setState(() {
              _messages.clear();
              _followUpSuggestions.clear();
            });
            await _chatManager.clearConversation();

            messenger.showSnackBar(
              const SnackBar(
                content: Text('Conversation cleared successfully'),
                duration: Duration(seconds: 2),
              ),
            );
          } catch (e) {
            messenger.showSnackBar(
              SnackBar(
                content: Text('Failed to clear conversation: $e'),
                backgroundColor: theme.colorScheme.error,
              ),
            );
          }
        },
      ),
      body: Column(
        children: [
          // Memory Stats Card
          Padding(
            padding: const EdgeInsets.all(AppConstants.defaultPadding),
            child: MemoryStatsCard(chatManager: _chatManager),
          ),

          // Messages List
          Expanded(
            child: MessageList(messages: _messages, isLoading: _isLoading),
          ),

          // Follow-up Suggestions
          if (_followUpSuggestions.isNotEmpty && _showFollowUpSuggestions)
            FollowUpSuggestions(
              suggestions: _followUpSuggestions,
              mode: _currentFollowUpMode,
              onSuggestionSelected: _onFollowUpSelected,
            ),

          // Message Input
          MessageInput(onSendMessage: _sendMessage, isLoading: _isLoading),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../screens/settings_screen.dart';

class ChatHeader extends StatelessWidget implements PreferredSizeWidget {
  final String followUpMode;
  final ValueChanged<String> onFollowUpModeChanged;
  final VoidCallback onClearChat;
  final bool showFollowUpSuggestions;
  final ValueChanged<bool> onToggleFollowUpSuggestions;

  const ChatHeader({
    super.key,
    required this.followUpMode,
    required this.onFollowUpModeChanged,
    required this.onClearChat,
    required this.showFollowUpSuggestions,
    required this.onToggleFollowUpSuggestions,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text(
        'Chat Memory Demo',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      elevation: 0,
      actions: [
        // Settings button
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => _openSettings(context),
          tooltip: 'Settings',
        ),

        // Follow-up suggestions toggle
        IconButton(
          icon: Icon(
            showFollowUpSuggestions
                ? Icons.psychology
                : Icons.psychology_outlined,
            color: showFollowUpSuggestions
                ? AppTheme.getFollowUpModeColor(followUpMode)
                : null,
          ),
          onPressed: () =>
              onToggleFollowUpSuggestions(!showFollowUpSuggestions),
          tooltip: showFollowUpSuggestions
              ? 'Hide follow-up suggestions'
              : 'Show follow-up suggestions',
        ),

        // Follow-up Mode Selector
        PopupMenuButton<String>(
          icon: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.getFollowUpModeColor(followUpMode),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getFollowUpModeIcon(followUpMode),
                  size: 16,
                  color: Colors.white,
                ),
                const SizedBox(width: 4),
                Text(
                  followUpMode.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          onSelected: onFollowUpModeChanged,
          itemBuilder: (context) => [
            _buildModeMenuItem('enhanced', 'Enhanced', Icons.psychology),
            _buildModeMenuItem('ai', 'AI Powered', Icons.smart_toy),
            _buildModeMenuItem('domain', 'Domain Specific', Icons.category),
            _buildModeMenuItem('adaptive', 'Adaptive', Icons.trending_up),
          ],
        ),

        // Clear Chat Button
        IconButton(
          icon: const Icon(Icons.clear_all),
          onPressed: () => _showClearDialog(context),
          tooltip: 'Clear conversation',
        ),

        const SizedBox(width: 8),
      ],
    );
  }

  Future<void> _openSettings(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  PopupMenuItem<String> _buildModeMenuItem(
    String mode,
    String label,
    IconData icon,
  ) {
    return PopupMenuItem<String>(
      value: mode,
      child: Row(
        children: [
          Icon(icon, color: AppTheme.getFollowUpModeColor(mode), size: 20),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }

  IconData _getFollowUpModeIcon(String mode) {
    switch (mode) {
      case 'enhanced':
        return Icons.psychology;
      case 'ai':
        return Icons.smart_toy;
      case 'domain':
        return Icons.category;
      case 'adaptive':
        return Icons.trending_up;
      default:
        return Icons.help;
    }
  }

  void _showClearDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Conversation'),
        content: const Text(
          'Are you sure you want to clear all messages? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              onClearChat();
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../chat_manager.dart';

class MemoryStatsCard extends StatefulWidget {
  final ChatManager chatManager;

  const MemoryStatsCard({super.key, required this.chatManager});

  @override
  State<MemoryStatsCard> createState() => _MemoryStatsCardState();
}

class _MemoryStatsCardState extends State<MemoryStatsCard> {
  Map<String, dynamic> _stats = {};
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final stats = await widget.chatManager.getConversationStats();

      if (mounted) {
        setState(() {
          _stats = {
            'totalMessages': stats.totalMessages,
            'tokenCount': stats.totalTokens,
            'memoryUsage':
                '${(stats.totalTokens * 4 / 1024).toStringAsFixed(1)} KB',
            'lastUpdated': stats.newestMessage?.toIso8601String() ?? 'Never',
            'conversationDuration': stats.conversationDuration?.inMinutes ?? 0,
            'vectorCount': stats.vectorCount ?? 0,
          };
        });
      }
    } catch (e) {
      if (mounted) {
        // Capture messenger and theme early to avoid context after async gaps
        final messenger = ScaffoldMessenger.of(context);
        final theme = Theme.of(context);

        setState(() {
          _stats = {
            'totalMessages': 0,
            'memoryUsage': '0 KB',
            'lastUpdated': 'Never',
            'error': 'Failed to load stats: ${e.toString()}',
          };
        });

        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to load memory stats: $e'),
            backgroundColor: theme.colorScheme.error,
            action: SnackBarAction(label: 'Retry', onPressed: _loadStats),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        leading: Icon(
          Icons.memory,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(
          'Memory Statistics',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          _getSubtitleText(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        initiallyExpanded: _isExpanded,
        onExpansionChanged: (expanded) {
          setState(() {
            _isExpanded = expanded;
          });
        },
        children: [
          Padding(
            padding: const EdgeInsets.all(AppConstants.defaultPadding),
            child: Column(
              children: [
                if (_stats.containsKey('error'))
                  _buildErrorWidget()
                else
                  _buildStatsGrid(),

                const SizedBox(height: 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: _loadStats,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Refresh'),
                    ),
                    TextButton.icon(
                      onPressed: _clearMemory,
                      icon: const Icon(Icons.clear_all, size: 16),
                      label: const Text('Clear Memory'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.error,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Error loading memory stats: ${_stats['error']}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 2.5,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        _buildStatItem(
          'Messages',
          _stats['totalMessages']?.toString() ?? '0',
          Icons.chat_bubble_outline,
        ),
        _buildStatItem(
          'Memory',
          _stats['memoryUsage']?.toString() ?? '0 KB',
          Icons.storage,
        ),
        _buildStatItem(
          'Tokens',
          _stats['tokenCount']?.toString() ?? '0',
          Icons.token,
        ),
        _buildStatItem(
          'Updated',
          _formatLastUpdated(_stats['lastUpdated']),
          Icons.schedule,
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _getSubtitleText() {
    final messageCount = _stats['totalMessages'] ?? 0;
    final memoryUsage = _stats['memoryUsage'] ?? '0 KB';
    return '$messageCount messages • $memoryUsage';
  }

  String _formatLastUpdated(dynamic lastUpdated) {
    if (lastUpdated == null) return 'Never';
    if (lastUpdated is String) {
      try {
        final dateTime = DateTime.parse(lastUpdated);
        final now = DateTime.now();
        final difference = now.difference(dateTime);

        if (difference.inMinutes < 1) {
          return 'Just now';
        } else if (difference.inHours < 1) {
          return '${difference.inMinutes}m ago';
        } else if (difference.inDays < 1) {
          return '${difference.inHours}h ago';
        } else {
          return '${difference.inDays}d ago';
        }
      } catch (e) {
        return lastUpdated.toString();
      }
    }
    return lastUpdated.toString();
  }

  void _clearMemory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Memory'),
        content: const Text(
          'Are you sure you want to clear all memory data? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              // Capture messenger and theme before async gaps
              final messenger = ScaffoldMessenger.of(context);
              final theme = Theme.of(context);

              Navigator.of(context).pop();
              try {
                await widget.chatManager.clearConversation();
                await _loadStats();
                if (mounted) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Memory cleared successfully'),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Error clearing memory: $e'),
                      backgroundColor: theme.colorScheme.error,
                    ),
                  );
                }
              }
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

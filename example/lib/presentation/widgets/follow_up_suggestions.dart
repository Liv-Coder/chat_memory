import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';

class FollowUpSuggestions extends StatelessWidget {
  final List<String> suggestions;
  final String mode;
  final ValueChanged<String> onSuggestionSelected;

  const FollowUpSuggestions({
    super.key,
    required this.suggestions,
    required this.mode,
    required this.onSuggestionSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getModeIcon(mode),
                size: 16,
                color: AppTheme.getFollowUpModeColor(mode),
              ),
              const SizedBox(width: 8),
              Text(
                'Follow-up suggestions',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.getFollowUpModeColor(
                    mode,
                  ).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  mode.toUpperCase(),
                  style: TextStyle(
                    color: AppTheme.getFollowUpModeColor(mode),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions.take(AppConstants.maxFollowUpSuggestions).map(
              (suggestion) {
                return _buildSuggestionChip(context, suggestion);
              },
            ).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(BuildContext context, String suggestion) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onSuggestionSelected(suggestion),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.getFollowUpModeColor(mode).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.getFollowUpModeColor(mode).withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  suggestion,
                  style: TextStyle(
                    color: AppTheme.getFollowUpModeColor(mode),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.arrow_forward_ios,
                size: 12,
                color: AppTheme.getFollowUpModeColor(mode),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getModeIcon(String mode) {
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
}

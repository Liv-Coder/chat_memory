import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/ai_provider.dart';
import '../../core/models/app_settings.dart';
import '../../core/services/settings_service.dart';
import '../../core/services/demo_ai_service.dart';
import '../../core/constants/app_constants.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settingsService = SettingsService();
  final Map<AIProvider, TextEditingController> _apiKeyControllers = {};
  final Map<AIProvider, GlobalKey<FormState>> _formKeys = {};
  final Map<AIProvider, bool> _obscureText = {};
  final Map<AIProvider, bool> _isTestingConnection = {};

  AppSettings _settings = AppSettings.defaultSettings;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadSettings();
  }

  @override
  void dispose() {
    for (var controller in _apiKeyControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initializeControllers() {
    for (final provider in AIProvider.values) {
      _apiKeyControllers[provider] = TextEditingController();
      _formKeys[provider] = GlobalKey<FormState>();
      _obscureText[provider] = true;
      _isTestingConnection[provider] = false;
    }
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    try {
      _settings = _settingsService.currentSettings;

      // Load API keys for each provider
      for (final provider in AIProvider.values) {
        if (provider.requiresApiKey) {
          final apiKey = await _settingsService.getApiKey(provider);
          if (apiKey != null) {
            _apiKeyControllers[provider]!.text = apiKey;
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load settings: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveApiKey(AIProvider provider) async {
    final formKey = _formKeys[provider]!;
    if (!formKey.currentState!.validate()) return;

    final apiKey = _apiKeyControllers[provider]!.text.trim();

    try {
      await _settingsService.saveApiKey(provider, apiKey);
      _settings = _settingsService.currentSettings;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${provider.displayName} API key saved!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save API key: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _testConnection(AIProvider provider) async {
    setState(() => _isTestingConnection[provider] = true);

    try {
      final config = AIProviderConfig(
        provider: provider,
        apiKey: _apiKeyControllers[provider]!.text.trim(),
      );

      final isConnected = await AIService.testConnection(config);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isConnected
                  ? '${provider.displayName} connection successful!'
                  : '${provider.displayName} connection failed',
            ),
            backgroundColor: isConnected ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection test failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      setState(() => _isTestingConnection[provider] = false);
    }
  }

  Future<void> _deleteApiKey(AIProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${provider.displayName} API Key'),
        content: const Text('Are you sure you want to delete this API key?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _settingsService.deleteApiKey(provider);
        _apiKeyControllers[provider]!.clear();
        _settings = _settingsService.currentSettings;

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${provider.displayName} API key deleted'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete API key: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _selectProvider(AIProvider provider) async {
    try {
      final apiKey = provider.requiresApiKey
          ? await _settingsService.getApiKey(provider)
          : null;

      final config = AIProviderConfig(provider: provider, apiKey: apiKey);

      await _settingsService.updateAIProvider(config);
      _settings = _settingsService.currentSettings;

      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Switched to ${provider.displayName}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to switch provider: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSettings,
            tooltip: 'Refresh Settings',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAIProviderSection(),
            const SizedBox(height: 24),
            _buildFollowUpSection(),
            const SizedBox(height: 24),
            _buildAppearanceSection(),
            const SizedBox(height: 24),
            _buildDataSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildAIProviderSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.smart_toy,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'AI Provider',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Provider Selection
            ...AIProvider.values.map(
              (provider) => _buildProviderTile(provider),
            ),

            const SizedBox(height: 16),

            // Current provider info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Current: ${_settings.aiConfig.provider.displayName}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (_settings.aiConfig.isConfigured)
                    Icon(Icons.check_circle, size: 16, color: Colors.green)
                  else
                    Icon(Icons.warning, size: 16, color: Colors.orange),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderTile(AIProvider provider) {
    final isSelected = _settings.aiConfig.provider == provider;
    final isConfigured =
        provider == AIProvider.demo ||
        _apiKeyControllers[provider]!.text.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).dividerColor,
          width: isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        leading: InkWell(
          onTap: isConfigured ? () => _selectProvider(provider) : null,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(
              _settings.aiConfig.provider == provider
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: _settings.aiConfig.provider == provider
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).disabledColor,
            ),
          ),
        ),
        title: Text(
          provider.displayName,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        subtitle: Text(provider.description),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isConfigured)
              Icon(Icons.check_circle, color: Colors.green, size: 16)
            else if (provider.requiresApiKey)
              Icon(Icons.key, color: Colors.orange, size: 16),
            const Icon(Icons.expand_more),
          ],
        ),
        children: [if (provider.requiresApiKey) _buildApiKeyForm(provider)],
      ),
    );
  }

  Widget _buildApiKeyForm(AIProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKeys[provider],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('API Key', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),

            TextFormField(
              controller: _apiKeyControllers[provider],
              obscureText: _obscureText[provider]!,
              decoration: InputDecoration(
                hintText: _settingsService.getApiKeyExample(provider),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        _obscureText[provider]!
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureText[provider] = !_obscureText[provider]!;
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.paste),
                      onPressed: () async {
                        final data = await Clipboard.getData(
                          Clipboard.kTextPlain,
                        );
                        if (data?.text != null) {
                          _apiKeyControllers[provider]!.text = data!.text!;
                        }
                      },
                    ),
                  ],
                ),
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'API key is required';
                }
                if (!_settingsService.isApiKeyValid(value, provider)) {
                  return 'Invalid API key format';
                }
                return null;
              },
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () => _saveApiKey(provider),
                  icon: const Icon(Icons.save),
                  label: const Text('Save'),
                ),
                const SizedBox(width: 8),

                OutlinedButton.icon(
                  onPressed: _isTestingConnection[provider]!
                      ? null
                      : () => _testConnection(provider),
                  icon: _isTestingConnection[provider]!
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.wifi_protected_setup),
                  label: const Text('Test'),
                ),

                const Spacer(),

                if (_apiKeyControllers[provider]!.text.isNotEmpty)
                  IconButton(
                    onPressed: () => _deleteApiKey(provider),
                    icon: const Icon(Icons.delete),
                    color: Colors.red,
                    tooltip: 'Delete API Key',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFollowUpSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.psychology,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Follow-up Suggestions',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),

            SwitchListTile(
              title: const Text('Show Follow-up Suggestions'),
              subtitle: const Text('Display smart conversation suggestions'),
              value: _settings.showFollowUpSuggestions,
              onChanged: (value) async {
                await _settingsService.setShowFollowUpSuggestions(value);
                setState(() {
                  _settings = _settingsService.currentSettings;
                });
              },
            ),

            const SizedBox(height: 12),

            Text('Default Mode', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),

            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'enhanced',
                  label: Text('Enhanced'),
                  icon: Icon(Icons.psychology),
                ),
                ButtonSegment(
                  value: 'ai',
                  label: Text('AI'),
                  icon: Icon(Icons.smart_toy),
                ),
                ButtonSegment(
                  value: 'domain',
                  label: Text('Domain'),
                  icon: Icon(Icons.category),
                ),
                ButtonSegment(
                  value: 'adaptive',
                  label: Text('Adaptive'),
                  icon: Icon(Icons.trending_up),
                ),
              ],
              selected: {_settings.followUpMode},
              onSelectionChanged: (selection) async {
                final mode = selection.first;
                await _settingsService.setFollowUpMode(mode);
                setState(() {
                  _settings = _settingsService.currentSettings;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppearanceSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.palette,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Appearance',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),

            SwitchListTile(
              title: const Text('Dark Mode'),
              subtitle: const Text('Use dark theme'),
              value: _settings.darkMode,
              onChanged: (value) async {
                await _settingsService.setDarkMode(value);
                setState(() {
                  _settings = _settingsService.currentSettings;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.storage,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Data Management',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),

            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('Clear All Data'),
              subtitle: const Text('Delete all settings and API keys'),
              onTap: () => _showClearDataDialog(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showClearDataDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text(
          'This will delete all your settings, API keys, and preferences. '
          'This action cannot be undone. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _settingsService.clearAllData();

        // Clear controllers
        for (var controller in _apiKeyControllers.values) {
          controller.clear();
        }

        // Reload settings
        await _loadSettings();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All data cleared successfully'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to clear data: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }
}

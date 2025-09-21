import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'ai_adapter.dart';

/// Screen for managing the Gemini API key
///
/// Allows users to set, view (masked), and manage their API key
/// with persistent storage and validation.
class ApiKeyScreen extends StatefulWidget {
  const ApiKeyScreen({super.key});

  @override
  State<ApiKeyScreen> createState() => _ApiKeyScreenState();
}

class _ApiKeyScreenState extends State<ApiKeyScreen> {
  final TextEditingController _apiKeyController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscureText = true;
  bool _hasExistingKey = false;
  String? _maskedKey;
  Map<String, dynamic> _configInfo = {};

  @override
  void initState() {
    super.initState();
    _loadCurrentConfiguration();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentConfiguration() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _configInfo = AIAdapter.getConfigInfo();
      _maskedKey = _getMaskedApiKey();
      _hasExistingKey = _configInfo['api_key_set'] ?? false;

      if (_hasExistingKey && _maskedKey != null) {
        _apiKeyController.text = _maskedKey!;
      }
    } catch (e) {
      // Handle error silently
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveApiKey() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final apiKey = _apiKeyController.text.trim();
      await AIAdapter.setApiKey(apiKey);

      // Reload configuration
      await _loadCurrentConfiguration();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ API key saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to save API key: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _testApiKey() async {
    if (!AIAdapter.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Please set an API key first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Test with a simple prompt
      final response = await AIAdapter.getResponse(
        'system: You are a test assistant.\nuser: Say "API test successful"',
        null,
      );

      if (mounted) {
        if (response.toLowerCase().contains('test') ||
            response.toLowerCase().contains('successful') ||
            response.toLowerCase().contains('api')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ API key is working correctly!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '⚠️ API responded but test unclear: ${response.substring(0, 50)}...',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ API key test failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _clearApiKey() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear API Key'),
        content: const Text(
          'This will remove your saved API key and you\'ll need to enter it again. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        await AIAdapter.clearApiKey();
        _apiKeyController.clear();
        await _loadCurrentConfiguration();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🗑️ API key cleared successfully'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Failed to clear API key: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }

      setState(() {
        _isLoading = false;
      });
    }
  }

  String? _validateApiKey(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your API key';
    }

    final trimmed = value.trim();

    if (trimmed.length < 20) {
      return 'API key seems too short';
    }

    if (!trimmed.startsWith('AIza')) {
      return 'Gemini API keys should start with "AIza"';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Key Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showHelpDialog,
            tooltip: 'Help',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildStatusCard(),
                    const SizedBox(height: 24),
                    _buildApiKeySection(),
                    const SizedBox(height: 24),
                    _buildActionButtons(),
                    const SizedBox(height: 24),
                    _buildInstructionsCard(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatusCard() {
    final isConfigured = _configInfo['configured'] ?? false;
    final simulationMode = _configInfo['simulation_mode'] ?? true;
    final message = _configInfo['message'] ?? 'Status unknown';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isConfigured ? Icons.check_circle : Icons.warning_amber,
                  color: isConfigured ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  'API Status',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(message),
            if (_hasExistingKey && _maskedKey != null) ...[
              const SizedBox(height: 8),
              Text('Current key: $_maskedKey'),
            ],
            if (simulationMode) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '⚠️ Running in simulation mode. Set your API key for real AI responses.',
                  style: TextStyle(color: Colors.orange),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildApiKeySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gemini API Key',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _apiKeyController,
              validator: _validateApiKey,
              obscureText: _obscureText,
              decoration: InputDecoration(
                labelText: 'Enter your Gemini API key',
                hintText: 'AIzaSy...',
                prefixIcon: const Icon(Icons.key),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        _obscureText ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureText = !_obscureText;
                        });
                      },
                      tooltip: _obscureText ? 'Show key' : 'Hide key',
                    ),
                    IconButton(
                      icon: const Icon(Icons.content_paste),
                      onPressed: () async {
                        final data = await Clipboard.getData(
                          Clipboard.kTextPlain,
                        );
                        if (data?.text != null) {
                          _apiKeyController.text = data!.text!;
                        }
                      },
                      tooltip: 'Paste from clipboard',
                    ),
                  ],
                ),
                border: const OutlineInputBorder(),
              ),
              maxLines: 1,
              keyboardType: TextInputType.text,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _saveApiKey,
          icon: const Icon(Icons.save),
          label: const Text('Save API Key'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _isLoading ? null : _testApiKey,
          icon: const Icon(Icons.api),
          label: const Text('Test API Connection'),
        ),
        if (_hasExistingKey) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _isLoading ? null : _clearApiKey,
            icon: const Icon(Icons.clear),
            label: const Text('Clear API Key'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ],
    );
  }

  Widget _buildInstructionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline),
                const SizedBox(width: 8),
                Text(
                  'How to get your API key',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '1. Go to Google AI Studio (ai.google.dev)\n'
              '2. Sign in with your Google account\n'
              '3. Click "Get API key"\n'
              '4. Create a new API key for your project\n'
              '5. Copy the key and paste it above\n\n'
              '⚠️ Keep your API key secure and never share it publicly!',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showHelpDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('API Key Help'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'About API Keys',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'This app uses Google\'s Gemini AI to provide intelligent responses with memory. '
                'To use real AI (instead of simulated responses), you need your own API key.',
              ),
              SizedBox(height: 16),
              Text('Security', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text(
                '• Your API key is stored securely on your device\n'
                '• It\'s never shared with anyone else\n'
                '• You can clear it anytime\n'
                '• The app shows masked keys for security',
              ),
              SizedBox(height: 16),
              Text('Costs', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text(
                'Gemini API has generous free tiers. Check Google AI Studio for current pricing and usage limits.',
              ),
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

  /// Helper method to get masked API key
  String? _getMaskedApiKey() {
    final configInfo = AIAdapter.getConfigInfo();
    final maskedKey = configInfo['api_key_masked'] as String?;
    return maskedKey;
  }
}

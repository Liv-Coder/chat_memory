import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';
import '../models/ai_provider.dart';

class SettingsService {
  static const String _settingsKey = 'app_settings';
  static const String _apiKeysKey = 'api_keys';

  SharedPreferences? _prefs;
  AppSettings _currentSettings = AppSettings.defaultSettings;

  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  AppSettings get currentSettings => _currentSettings;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settingsJson = _prefs?.getString(_settingsKey);
      if (settingsJson != null) {
        final settingsMap = jsonDecode(settingsJson) as Map<String, dynamic>;
        _currentSettings = AppSettings.fromJson(settingsMap);
      }
    } catch (e) {
      // Use default settings on error
      _currentSettings = AppSettings.defaultSettings;
    }
  }

  Future<void> updateSettings(AppSettings settings) async {
    _currentSettings = settings;
    await _saveSettings();
  }

  Future<void> _saveSettings() async {
    try {
      final settingsJson = jsonEncode(_currentSettings.toJson());
      await _prefs?.setString(_settingsKey, settingsJson);
    } catch (e) {
      // Handle save error silently
    }
  }

  Future<void> updateAIProvider(AIProviderConfig config) async {
    final updatedSettings = _currentSettings.copyWith(aiConfig: config);
    await updateSettings(updatedSettings);
  }

  Future<void> setShowFollowUpSuggestions(bool show) async {
    final updatedSettings = _currentSettings.copyWith(
      showFollowUpSuggestions: show,
    );
    await updateSettings(updatedSettings);
  }

  Future<void> setFollowUpMode(String mode) async {
    final updatedSettings = _currentSettings.copyWith(followUpMode: mode);
    await updateSettings(updatedSettings);
  }

  Future<void> setDarkMode(bool darkMode) async {
    final updatedSettings = _currentSettings.copyWith(darkMode: darkMode);
    await updateSettings(updatedSettings);
  }

  // Secure API key storage
  Future<void> saveApiKey(AIProvider provider, String apiKey) async {
    try {
      final apiKeysJson = _prefs?.getString(_apiKeysKey) ?? '{}';
      final apiKeys = Map<String, String>.from(jsonDecode(apiKeysJson));
      apiKeys[provider.name] = apiKey;
      await _prefs?.setString(_apiKeysKey, jsonEncode(apiKeys));

      // Update current settings
      final updatedConfig = _currentSettings.aiConfig.copyWith(
        provider: provider,
        apiKey: apiKey,
      );
      await updateAIProvider(updatedConfig);
    } catch (e) {
      rethrow;
    }
  }

  Future<String?> getApiKey(AIProvider provider) async {
    try {
      final apiKeysJson = _prefs?.getString(_apiKeysKey) ?? '{}';
      final apiKeys = Map<String, String>.from(jsonDecode(apiKeysJson));
      return apiKeys[provider.name];
    } catch (e) {
      return null;
    }
  }

  Future<void> deleteApiKey(AIProvider provider) async {
    try {
      final apiKeysJson = _prefs?.getString(_apiKeysKey) ?? '{}';
      final apiKeys = Map<String, String>.from(jsonDecode(apiKeysJson));
      apiKeys.remove(provider.name);
      await _prefs?.setString(_apiKeysKey, jsonEncode(apiKeys));

      // Update current settings to demo mode if current provider key was deleted
      if (_currentSettings.aiConfig.provider == provider) {
        final updatedConfig = _currentSettings.aiConfig.copyWith(
          provider: AIProvider.demo,
          apiKey: null,
        );
        await updateAIProvider(updatedConfig);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> clearAllData() async {
    try {
      await _prefs?.remove(_settingsKey);
      await _prefs?.remove(_apiKeysKey);
      _currentSettings = AppSettings.defaultSettings;
    } catch (e) {
      rethrow;
    }
  }

  // Validation helpers
  bool isApiKeyValid(String apiKey, AIProvider provider) {
    if (apiKey.isEmpty) return false;

    switch (provider) {
      case AIProvider.demo:
        return true;
      case AIProvider.gemini:
        return apiKey.startsWith('AIza') && apiKey.length >= 35;
      case AIProvider.groq:
        return apiKey.startsWith('gsk_') && apiKey.length >= 50;
      case AIProvider.openRouter:
        return apiKey.startsWith('sk-or-') && apiKey.length >= 20;
    }
  }

  String getApiKeyExample(AIProvider provider) {
    switch (provider) {
      case AIProvider.demo:
        return 'No API key required';
      case AIProvider.gemini:
        return 'AIzaSyC...';
      case AIProvider.groq:
        return 'gsk_...';
      case AIProvider.openRouter:
        return 'sk-or-...';
    }
  }
}

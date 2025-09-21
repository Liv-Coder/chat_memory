import 'ai_provider.dart';

class AppSettings {
  final AIProviderConfig aiConfig;
  final bool showFollowUpSuggestions;
  final String followUpMode;
  final bool enableNotifications;
  final bool darkMode;

  const AppSettings({
    this.aiConfig = AIProviderConfig.defaultConfig,
    this.showFollowUpSuggestions = true,
    this.followUpMode = 'enhanced',
    this.enableNotifications = true,
    this.darkMode = false,
  });

  AppSettings copyWith({
    AIProviderConfig? aiConfig,
    bool? showFollowUpSuggestions,
    String? followUpMode,
    bool? enableNotifications,
    bool? darkMode,
  }) {
    return AppSettings(
      aiConfig: aiConfig ?? this.aiConfig,
      showFollowUpSuggestions:
          showFollowUpSuggestions ?? this.showFollowUpSuggestions,
      followUpMode: followUpMode ?? this.followUpMode,
      enableNotifications: enableNotifications ?? this.enableNotifications,
      darkMode: darkMode ?? this.darkMode,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'aiConfig': aiConfig.toJson(),
      'showFollowUpSuggestions': showFollowUpSuggestions,
      'followUpMode': followUpMode,
      'enableNotifications': enableNotifications,
      'darkMode': darkMode,
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      aiConfig: AIProviderConfig.fromJson(json['aiConfig'] ?? {}),
      showFollowUpSuggestions: json['showFollowUpSuggestions'] ?? true,
      followUpMode: json['followUpMode'] ?? 'enhanced',
      enableNotifications: json['enableNotifications'] ?? true,
      darkMode: json['darkMode'] ?? false,
    );
  }

  static const AppSettings defaultSettings = AppSettings();
}

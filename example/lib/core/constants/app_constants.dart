/// Application-wide constants and configuration values
class AppConstants {
  // App Information
  static const String appName = 'Chat Memory Example';
  static const String appVersion = '1.0.0';
  
  // UI Constants
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  
  static const double defaultBorderRadius = 12.0;
  static const double smallBorderRadius = 8.0;
  static const double largeBorderRadius = 16.0;
  
  static const double defaultElevation = 2.0;
  static const double mediumElevation = 4.0;
  static const double highElevation = 8.0;
  
  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);
  
  // Chat Configuration
  static const int maxFollowUpSuggestions = 3;
  static const int defaultTokenBudget = 4000;
  static const int maxMessageLength = 1000;
  
  // Memory Configuration
  static const String defaultFollowUpMode = 'enhanced';
  static const List<String> availableFollowUpModes = [
    'enhanced',
    'ai',
    'domain',
    'adaptive',
  ];
  
  // API Configuration
  static const Duration apiTimeout = Duration(seconds: 30);
  static const int maxRetries = 3;
}
enum AIProvider {
  demo,
  gemini,
  groq,
  openRouter;

  String get displayName {
    switch (this) {
      case AIProvider.demo:
        return 'Demo Mode';
      case AIProvider.gemini:
        return 'Google Gemini';
      case AIProvider.groq:
        return 'Groq';
      case AIProvider.openRouter:
        return 'OpenRouter';
    }
  }

  String get description {
    switch (this) {
      case AIProvider.demo:
        return 'Simulated responses for testing';
      case AIProvider.gemini:
        return 'Google\'s Gemini AI models';
      case AIProvider.groq:
        return 'Fast inference with Groq chips';
      case AIProvider.openRouter:
        return 'Access multiple AI models';
    }
  }

  String get baseUrl {
    switch (this) {
      case AIProvider.demo:
        return '';
      case AIProvider.gemini:
        return 'https://generativelanguage.googleapis.com/v1beta';
      case AIProvider.groq:
        return 'https://api.groq.com/openai/v1';
      case AIProvider.openRouter:
        return 'https://openrouter.ai/api/v1';
    }
  }

  String get defaultModel {
    switch (this) {
      case AIProvider.demo:
        return 'demo';
      case AIProvider.gemini:
        return 'gemini-2.0-flash';
      case AIProvider.groq:
        return 'llama-3.3-70b-versatile';
      case AIProvider.openRouter:
        return 'anthropic/claude-3.5-sonnet';
    }
  }

  bool get requiresApiKey {
    return this != AIProvider.demo;
  }
}

class AIProviderConfig {
  final AIProvider provider;
  final String? apiKey;
  final String? model;
  final Map<String, dynamic> additionalSettings;

  const AIProviderConfig({
    required this.provider,
    this.apiKey,
    this.model,
    this.additionalSettings = const {},
  });

  AIProviderConfig copyWith({
    AIProvider? provider,
    String? apiKey,
    String? model,
    Map<String, dynamic>? additionalSettings,
  }) {
    return AIProviderConfig(
      provider: provider ?? this.provider,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      additionalSettings: additionalSettings ?? this.additionalSettings,
    );
  }

  bool get isConfigured {
    if (!provider.requiresApiKey) return true;
    return apiKey != null && apiKey!.isNotEmpty;
  }

  String get effectiveModel => model ?? provider.defaultModel;

  Map<String, dynamic> toJson() {
    return {
      'provider': provider.name,
      'apiKey': apiKey,
      'model': model,
      'additionalSettings': additionalSettings,
    };
  }

  factory AIProviderConfig.fromJson(Map<String, dynamic> json) {
    return AIProviderConfig(
      provider: AIProvider.values.firstWhere(
        (p) => p.name == json['provider'],
        orElse: () => AIProvider.demo,
      ),
      apiKey: json['apiKey'] as String?,
      model: json['model'] as String?,
      additionalSettings: Map<String, dynamic>.from(
        json['additionalSettings'] ?? {},
      ),
    );
  }

  static const AIProviderConfig defaultConfig = AIProviderConfig(
    provider: AIProvider.demo,
  );
}

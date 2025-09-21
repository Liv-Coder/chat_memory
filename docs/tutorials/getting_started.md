# Getting Started

This guide helps you set up a basic conversation memory system using `chat_memory`.

## Installation

Add to `pubspec.yaml` and run `dart pub get`.

## Your First Chat Memory System

```dart
import 'package:chat_memory/chat_memory.dart';

Future<void> main() async {
  final manager = await EnhancedConversationManager.create();
  await manager.appendSystemMessage('You are a helpful assistant.');
  await manager.appendUserMessage('Tell me about Dart futures.');
  final prompt = await manager.buildPrompt(clientTokenBudget: 4000);
  print(prompt.promptText);
}
```

## Next Steps

See `docs/tutorials/advanced_usage.md` for production tips and customization.

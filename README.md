<!--
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/tools/pub/writing-package-pages).

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/to/develop-packages).
-->

TODO: Put a short description of the package here that helps potential users
know whether this package might be useful for them.

## Features

TODO: List what your package can do. Maybe include images, gifs, or videos.

## Getting started

Add the package to your app:

```bash
flutter pub add chat_memory
```

## Usage (quickstart)

Create a `ConversationManager` and append messages:

```dart
final manager = ConversationManager();
await manager.appendMessage(Message(
	id: '1',
	role: MessageRole.user,
	content: 'Hi',
	timestamp: DateTime.now().toUtc(),
));
final payload = await manager.buildPrompt(clientTokenBudget: 2000);
// send payload.promptText to your LLM of choice
```

Optional persisted store (opt-in):

```dart
final manager = ConversationManager(persistence: InMemoryStore());
// replace InMemoryStore with a file or sqlite adapter in production
```

Register a custom summarizer:

```dart
class MySummarizer implements Summarizer {
	Future<SummaryInfo> summarize(List<Message> chunk, TokenCounter tokenCounter) async {
		final s = chunk.map((m) => m.content).join(' | ').substring(0, 200);
		return SummaryInfo(chunkId: 'my-1', summary: s, tokenEstimateBefore: tokenCounter.estimateTokens(chunk.map((m) => m.content).join(' ')), tokenEstimateAfter: tokenCounter.estimateTokens(s));
	}
}

manager.registerSummarizer(MySummarizer());
```

Trace example:

```dart
final payload = await manager.buildPrompt(trace: true);
print(payload.trace.strategyUsed);
print(payload.trace.summaries);
```

## Additional information

TODO: Tell users more about the package: where to find more information, how to
contribute to the package, how to file issues, what response they can expect
from the package authors, and more.

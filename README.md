# Chat Memory - Hybrid Memory Management System

A powerful Dart package that provides sophisticated memory management for conversational AI applications. Features include **summarization-based compression**, **semantic retrieval**, and **hybrid memory layers** for optimal context management.

## ✨ Features

### 🧠 Hybrid Memory Architecture

- **Short-term Rolling Memory**: Recent messages preserved for immediate context
- **Long-term Summaries**: Automatic compression of older conversations
- **Semantic Memory**: Vector-based retrieval of relevant historical context
- **Token Budget Management**: Intelligent context fitting within LLM limits

### 🔄 Summarization Strategies

- **Chunked Summarization**: Process messages in manageable chunks
- **Layered Summaries**: Create summaries of summaries to prevent information loss
- **Configurable Retention**: Control how much recent context to preserve
- **Multiple Summarizer Backends**: Pluggable summarization services

### 🔍 Semantic Search

- **Local Vector Storage**: SQLite-based embedding storage for persistence

````markdown
# Chat Memory - Hybrid Memory Management System

A powerful Dart package that provides sophisticated memory management for conversational AI applications. Features include **summarization-based compression**, **semantic retrieval**, and **hybrid memory layers** for optimal context management.

[![pub version](https://img.shields.io/pub/v/chat_memory.svg)](https://pub.dev/packages/chat_memory)
[![build](https://img.shields.io/github/actions/workflow/status/Liv-Coder/chat_memory/ci.yml?branch=main)](https://github.com/Liv-Coder/chat_memory/actions)
[![license](https://img.shields.io/pub/license/chat_memory.svg)](https://pub.dev/packages/chat_memory)

## Table of Contents

- [Quick Start](#quick-start)
- [Features](#features)
- [Getting Started](#getting-started)
- [Tutorials](#tutorials)
- [API Reference](#api-reference)
- [Troubleshooting](#troubleshooting)
- [FAQ](#faq)
- [Contributing](#contributing)
- [License](#license)

## Quick Start

Install the package and run a simple example:

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
````

See the `docs/` folder for getting started and advanced guides, plus `example/` for runnable samples.

## Features

- Hybrid memory (short-term + summarization + semantic retrieval)
- Pluggable vector stores and embeddings
- Configurable summarization and context strategies
- Presets for development and production

## Getting Started

Follow `docs/tutorials/getting_started.md` for a step-by-step walkthrough.

## Tutorials & Examples

- `docs/tutorials/getting_started.md`
- `docs/tutorials/advanced_usage.md`
- `docs/examples/real_world_scenarios.md`

## API Reference

See `docs/api_reference.md` for a concise overview of the core classes and interfaces.

## Troubleshooting

Common issues and solutions are in `docs/troubleshooting.md`.

## FAQ

Common questions are answered in `docs/faq.md`.

## Contributing

Contributions welcome — please open issues and PRs. See `CONTRIBUTING.md` if present.

## License

See the `LICENSE` file. This project uses the license declared in `pubspec.yaml`.

---

Built for production-ready conversation memory in Dart & Flutter.

```

```

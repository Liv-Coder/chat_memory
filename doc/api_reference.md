# API Reference

This document provides a high-level API reference for the `chat_memory` package.

## Core Classes

### EnhancedConversationManager

- High-level manager combining memory, summarization and semantic retrieval.
- Key methods: `create`, `appendUserMessage`, `appendAssistantMessage`, `appendSystemMessage`, `buildPrompt`, `getStats`.

### MemoryManager

- Lower-level orchestration of memory components. Configure token budgets, strategies, and vector stores.

### MemoryConfig

- Configuration structure used by `MemoryManager` and factories.

## Memory Components

- `VectorStore` interface — store and retrieve vector entries.
- Implementations: `LocalVectorStore`, `InMemoryVectorStore`.
- `EmbeddingService` interface — convert text to vectors. `SimpleEmbeddingService` is included as a deterministic example.

## Summarizers & Strategies

- `Summarizer` interface and `DeterministicSummarizer` implementation.
- `ContextStrategy` interface with implementations such as `SummarizationStrategy` and `SlidingWindowStrategy`.

## Data Models

- `Message` — role, content, metadata, and timestamps.
- `PromptPayload` — assembled prompt text, estimated tokens, and attached metadata.

## Factories and Builders

- `HybridMemoryFactory` — convenience factory for common presets.
- `MemoryManagerBuilder` — step-by-step builder for custom configuration.

## Error Handling

- Exceptions are thrown for invalid configurations and persistence errors. Consumers should catch and log errors during initialization and runtime operations.

# Changelog

All notable changes to this project will be documented in this file.
This project adheres to the "Keep a Changelog" format and follows
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Message chunking system (`MessageChunker`) with configurable strategies:

  - Fixed token/character, word/sentence/paragraph boundaries, sliding window with overlap, delimiter-based chunking, and a placeholder for semantic-aware chunking.
  - Chunking configuration options (max tokens/chars, overlap ratio, preserve word/sentence boundaries, custom delimiters, max chunks).
  - Chunk statistics and logging (total chunks, average size, size distribution) for diagnostics and performance tuning.

- Advanced embedding pipeline (`EmbeddingPipeline`) with resilience and optimization:

  - Processing modes: `sequential`, `parallel`, and `adaptive` for dynamic batching.
  - Circuit breaker and retry strategies (immediate, linear, exponential) to handle external embedding service failures.
  - Caching of embeddings with configurable TTL and maximum size, plus cache hit-rate tracking.
  - Embedding validation, normalization, and quality thresholding to ensure vector integrity.
  - Rate limiting and dynamic batch-size adaptation based on recent performance.
  - Detailed embedding statistics and failure reporting.

- Message processing orchestrator (`MessageProcessor`) and supporting APIs:

  - Configurable processing stages (validation, chunking, embedding, storage, post-processing).
  - Processing configuration options including concurrency, continue-on-error, and stage ordering.
  - Structured result and stats models (`ProcessingResult`, `ProcessingStats`, `ProcessingError`) for observability.
  - Builder / factory helpers for common processor setups (basic, development, production).
  - Health and component statistics methods to expose chunker/embedding status and metrics.

- Processing utilities and integrations:
  - `ProcessingConfig`, `ProcessingStage`, and related enums and models to support flexible pipelines.
  - Integration with token counting, session storage, and vector stores for end-to-end processing flows.
  - Unit and integration tests covering chunking, embedding, and processing flows.

### Changed

- Documentation: expanded API docs and examples to document the new processing, chunking, and embedding features.
- Tests: improved timing/statistics assertions to ensure non-zero reported times for short runs.

### Fixed

- N/A

## 1.0.0 - 2025-09-21

### Added

- Initial stable release of `chat_memory`.
- Core components:
  - `MemoryManager` for orchestrating memory lifecycles and persistence.
  - `EnhancedConversationManager` for stateful conversation handling and follow-ups.
  - Vector store abstractions and implementations (`in_memory`, `local_vector_store`).
- Memory strategies:
  - Summarization strategy with deterministic summarizer support.
  - Sliding window and context strategies for configurable context retention.
  - Hybrid memory factory combining short-term (in-memory) and long-term (vector) storage.
- Embeddings and vector storage:
  - `EmbeddingService` interface and a simple embedding service reference implementation.
  - Support for pluggable vector stores and persistence strategies.
- Patterns & tooling:
  - Factory and builder patterns for configurable memory stacks and presets (development, production, performance, minimal).
  - Example applications and usage examples in `example/`.
  - Comprehensive documentation in `docs/` including API reference and tutorials.
- Tests:
  - Unit and integration tests covering memory flows, strategies, and vector store behavior.

### Documentation

- Detailed README with getting started, examples, and configuration guides.
- API reference and tutorials added under `docs/`.

### Security

- Licensed under MIT (see `LICENSE`).

### Contributors

- Initial implementation and documentation by Liv Coder and contributors (see repository history).

---

For full commit history and release assets, see the repository: https://github.com/Liv-Coder/chat_memory

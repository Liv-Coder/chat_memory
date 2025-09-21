# Changelog

All notable changes to this project will be documented in this file.
This project adheres to the "Keep a Changelog" format and follows
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Placeholder for upcoming improvements and maintenance releases.

### Changed

- N/A

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

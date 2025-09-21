# Advanced Usage

This guide covers advanced customizations: custom embeddings, vector store backends, and production deployment tips.

## Custom Embedding Service

Implement `EmbeddingService` to connect to external providers.

## Persistent Vector Stores

Use `LocalVectorStore` for SQLite persistence or implement `VectorStore` for remote DBs.

## Performance Tips

- Batch embedding calls
- Cache frequent queries
- Tune `semanticTopK` and `minSimilarity`

### Production Deployment

- Use SQLite FFI for desktop persistence (`sqflite_common_ffi`).
- Monitor vector store size and periodically compact indices.

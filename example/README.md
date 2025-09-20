# Example: File-backed persistence

This example demonstrates a simple file-backed `PersistenceStrategy` using `FileStore` located at `example/adapters/file_store.dart`.

How to run (from repository root):

```powershell
dart run example/lib/main.dart
```

Notes:

- The example is a minimal Dart runner (not a full Flutter app). It demonstrates how to swap the persistence adapter into `ConversationManager`.
- This example writes `example_store.json` into the repository working directory for demonstration purposes. Do not use this in production without encryption and proper file management.

# example

A new Flutter project.

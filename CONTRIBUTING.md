# CONTRIBUTING to chat_memory

Welcome — thank you for considering contributing to chat_memory. This document explains how to get started, the preferred workflow, code-style guidelines, testing expectations, and the process for reporting issues and submitting pull requests.

## Getting started

1. Fork the repository and clone your fork:
   git clone https://github.com/your-username/chat_memory.git
2. Install dependencies:
   - Dart SDK (see SDK constraint in `pubspec.yaml`)
   - Run `dart pub get`
3. Run tests:
   - Unit tests: `dart test`
   - Integration tests: `dart test integration/` (if applicable)

## Development workflow

- Branching
  - Use feature branches: `feature/<short-description>`
  - Use fix branches: `fix/<short-description>`
  - For breaking changes: `breaking/<short-description>`
- Commits
  - Follow Conventional Commits (e.g., `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`).
  - Write clear, descriptive commit messages and include a short body when necessary.
- Pull requests
  - Target the `main` (or `master`) branch.
  - Include a summary of changes, motivations, and linked issues.
  - Provide screenshots or example snippets for UI/behavior changes.
  - Ensure CI checks and tests pass before requesting review.

## Code style & formatting

- Follow Dart style (dartfmt / dart format). Run `dart format .` before committing.
- Enable static analysis via `dart analyze` and fix reported issues.
- Keep public APIs stable and documented using dartdoc (triple-slash `///`).
- Add small, focused commits and avoid mixing unrelated changes.

## Testing

- Unit tests should live under `test/` and use `.test.dart` naming.
- Add tests for new features and bug fixes.
- Keep tests deterministic; mock external dependencies when applicable.
- Aim for meaningful coverage of business logic; CI should run all tests.

## Documentation

- Update `README.md`, `docs/`, and inline dartdoc comments for new features or breaking changes.
- Keep examples in `example/` working and up-to-date.

## Issue reporting & feature requests

- Use the issue tracker: https://github.com/Liv-Coder/chat_memory/issues
- Provide a clear title and reproduction steps.
- Include environment details (Dart SDK version, OS, and package version).
- Label suggestions: `bug`, `enhancement`, `documentation`, `question`.

## Pull request process

1. Open a PR from your branch to `main`.
2. Include the issue number if applicable.
3. Describe what you changed, why, and any migration notes.
4. Add tests/examples demonstrating the change.
5. A maintainer will review; respond to feedback and update the PR.
6. Once approved and CI passes, a maintainer will merge.

## Code of conduct

Be respectful and collaborative. This project follows a standard open-source Code of Conduct. Treat maintainers and contributors professionally. Persistent unconstructive behavior may result in removal.

## Licensing & legal

- Contributions are accepted under the project's MIT license (see `LICENSE`).
- By contributing, you agree to license your contributions under the same license.

## Maintainers & contact

- Repository: https://github.com/Liv-Coder/chat_memory
- For security concerns, use the issue tracker and mark the issue as security/privileged.

Thank you for improving chat_memory. Your contributions make the project better for everyone.

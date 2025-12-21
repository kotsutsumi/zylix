# Contributing to Zylix

Thank you for your interest in contributing to Zylix! This document provides guidelines and information for contributors.

## How to Contribute

### Reporting Bugs

Before creating a bug report, please check if the issue already exists. When creating a bug report, include:

- A clear and descriptive title
- Steps to reproduce the issue
- Expected behavior vs actual behavior
- Your environment (OS, Zig version, platform)
- Any relevant code snippets or error messages

### Suggesting Features

Feature suggestions are welcome! Please include:

- A clear description of the feature
- The problem it solves or use case
- Any implementation ideas you have

### Pull Requests

1. **Fork the repository** and create your branch from `develop`
2. **Follow the coding style** of the project
3. **Write clear commit messages** using [Conventional Commits](https://www.conventionalcommits.org/)
4. **Add tests** for new functionality
5. **Update documentation** if needed
6. **Ensure all tests pass** before submitting

## Development Setup

### Prerequisites

- [Zig](https://ziglang.org/download/) 0.11.0 or later
- Platform-specific requirements:
  - **iOS/macOS**: Xcode 15+
  - **Android**: Android Studio with NDK
  - **Linux**: GTK4 development libraries
  - **Windows**: Visual Studio 2022 with WinUI 3

### Building the Core Library

```bash
cd core
zig build
```

### Running Tests

```bash
cd core
zig build test
```

### Building for Specific Platforms

```bash
# iOS
zig build -Dtarget=aarch64-ios

# Android
zig build -Dtarget=aarch64-linux-android

# macOS
zig build -Dtarget=aarch64-macos

# Linux
zig build -Dtarget=x86_64-linux-gnu

# Windows
zig build -Dtarget=x86_64-windows

# WASM
zig build -Dtarget=wasm32-freestanding
```

## Coding Guidelines

### Zig Code Style

- Follow the [Zig Style Guide](https://ziglang.org/documentation/master/#Style-Guide)
- Use meaningful variable and function names
- Add comments for complex logic
- Keep functions focused and small

### Commit Messages

Use [Conventional Commits](https://www.conventionalcommits.org/) format:

```
type(scope): description

[optional body]

[optional footer]
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

Examples:
```
feat(core): add support for custom event handlers
fix(ios): resolve memory leak in state management
docs(readme): update installation instructions
```

### Branch Naming

- `feature/description` - New features
- `fix/description` - Bug fixes
- `docs/description` - Documentation updates
- `refactor/description` - Code refactoring

## Project Structure

```
zylix/
├── core/               # Zig core library
│   ├── src/           # Source files
│   │   ├── abi.zig    # C ABI exports
│   │   ├── state.zig  # State management
│   │   ├── events.zig # Event system
│   │   ├── vdom.zig   # Virtual DOM
│   │   └── diff.zig   # Diffing algorithm
│   └── build.zig      # Build configuration
├── platforms/          # Platform implementations
│   ├── android/       # Android/Kotlin
│   ├── ios/           # iOS/Swift
│   ├── linux/         # Linux/GTK4
│   ├── macos/         # macOS/SwiftUI
│   ├── web/           # Web/WASM
│   └── windows/       # Windows/WinUI 3
├── site/              # Documentation website
├── docs/              # Internal documentation
└── examples/          # Example projects
```

## Testing

### Unit Tests

Add tests for new functionality in the same file or a dedicated test file:

```zig
test "state increment" {
    var state = State.init();
    state.increment();
    try std.testing.expectEqual(@as(i32, 1), state.counter);
}
```

### Integration Tests

For platform-specific integration tests, follow the testing conventions of each platform.

## Documentation

- Update the [README](README.md) for significant changes
- Add inline documentation for public APIs
- Update the [documentation site](site/) for user-facing changes

## Getting Help

- Open an [issue](https://github.com/kotsutsumi/zylix/issues) for questions
- Check existing issues and discussions

## License

By contributing to Zylix, you agree that your contributions will be licensed under the [Apache License 2.0](LICENSE.md).

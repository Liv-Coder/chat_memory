# Chat Memory Demo App 🧠💬

A clean, modern Flutter app demonstrating the powerful **Chat Memory** package with enhanced follow-up generation capabilities.

## ✨ Features

### 🏗️ **Clean Architecture**

- **Modern folder structure** following Flutter best practices
- **Separation of concerns** with clear presentation/business logic layers
- **Reusable components** for maintainable code
- **Material Design 3** theming with light/dark mode support

### 🧠 **Advanced Memory System**

- **Simplified ChatMemory API** with declarative methods (`addMessage()`, `getContext()`)
- **Hybrid memory management** with automatic summarization
- **Semantic search** through conversation history
- **Vector storage** for intelligent context retrieval
- **Real-time memory statistics** and usage monitoring

### 💡 **Enhanced Follow-up Generation**

- **4 Generation Modes**:
  - **Enhanced**: Context-aware heuristic suggestions
  - **AI**: Intelligent suggestions powered by AI
  - **Domain**: Specialized templates for specific domains
  - **Adaptive**: Learning from user interactions
- **Visual mode indicators** with color-coded UI
- **Smart debouncing** for optimal performance
- **User interaction tracking** for continuous improvement

### 🎨 **Modern UI Components**

- **Message bubbles** with gradient styling and avatars
- **Interactive follow-up chips** with mode-aware theming
- **Expandable memory stats card** with real-time data
- **Smooth loading states** and error handling
- **Responsive design** with proper accessibility support

## 🚀 Getting Started

### Prerequisites

- Flutter 3.0+ installed
- Dart 3.0+ installed

### Installation

1. **Clone the repository**:

   ```bash
   git clone <repository-url>
   cd chat_memory/example
   ```

2. **Install dependencies**:

   ```bash
   flutter pub get
   ```

3. **Run the app**:

   ```bash
   flutter run
   ```

## 📱 Usage

### Basic Chat

1. **Start chatting** - Type any message to begin
2. **Watch memory build** - The system automatically stores and processes your messages
3. **View statistics** - Expand the memory stats card to see real-time data
4. **Try follow-ups** - Tap suggested follow-up questions to continue the conversation

### Follow-up Modes

Switch between different follow-up generation modes using the mode selector in the app bar:

- 🧠 **Enhanced**: Best for general conversations with smart context awareness
- 🤖 **AI**: Powered by AI for more creative and intelligent suggestions
- 📚 **Domain**: Specialized for specific domains (technical, casual, etc.)
- 📈 **Adaptive**: Learns from your preferences over time

### Memory Features

- **Ask about past topics** - \"What did we discuss about X?\"
- **Test memory recall** - \"Do you remember when I mentioned Y?\"
- **Explore context** - \"How does your memory system work?\"

## 🏗️ Architecture Overview

```
lib/
├── core/                          # Core functionality
│   ├── constants/                 # App-wide constants
│   ├── models/                    # Data models
│   ├── services/                  # Business services
│   └── theme/                     # UI theming
├── presentation/                  # UI layer
│   ├── screens/                   # App screens
│   └── widgets/                   # Reusable UI components
├── chat_manager.dart             # Main business logic
└── main.dart                     # App entry point
```

### Key Components

#### **ChatManager** 📊

Simplified wrapper around ChatMemory with clean API:

```dart
// Add messages
await chatManager.addUserMessage(\"Hello!\");
await chatManager.addAssistantMessage(\"Hi there!\");

// Get context
final context = await chatManager.getContext(maxTokens: 8000);

// Generate follow-ups
final suggestions = await chatManager.getFollowUpSuggestions();
```

#### **UI Components** 🎨

- **ChatScreen**: Main interface with modern layout
- **MessageBubble**: Beautiful message styling with animations
- **FollowUpSuggestions**: Interactive suggestion chips
- **MemoryStatsCard**: Real-time memory monitoring
- **ChatHeader**: Mode switching and controls

## 🔧 Configuration

### Memory Settings

Customize memory behavior in `chat_manager.dart`:

```dart
_chatMemory = await ChatMemoryBuilder()
    .production()                    // Use production preset
    .withSystemPrompt(prompt)        // Custom system prompt
    .withMaxTokens(8000)            // Token limit
    .build();
```

### Follow-up Configuration

Adjust follow-up generation in `app_constants.dart`:

```dart
static const int maxFollowUpSuggestions = 3;
static const String defaultFollowUpMode = 'enhanced';
```

### UI Theming

Customize appearance in `app_theme.dart`:

```dart
// Follow-up mode colors
static const Map<String, Color> followUpModeColors = {
  'enhanced': Color(0xFF6C5CE7),
  'ai': Color(0xFF00B4D8),
  'domain': Color(0xFF2ECC71),
  'adaptive': Color(0xFFFF6B6B),
};
```

## 🎯 Performance Optimizations

- **Debounced follow-up generation** prevents excessive API calls
- **Lazy loading** of memory statistics
- **Efficient state management** with minimal rebuilds
- **Error boundaries** with graceful fallbacks
- **Memory leak prevention** with proper disposal

## 🔍 Troubleshooting

### Common Issues

**Follow-ups not generating:**

- Check if ChatManager is properly initialized
- Verify the selected follow-up mode is supported
- Look for error messages in debug console

**Memory stats not loading:**

- Ensure conversation has started
- Try refreshing stats manually
- Check for permission issues

**Performance issues:**

- Reduce max token limit
- Clear conversation history
- Check for memory leaks in debug mode

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes following the existing architecture
4. Test thoroughly
5. Submit a pull request

## 📜 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- Built with the powerful **Chat Memory** package
- Uses **Material Design 3** for modern UI
- Inspired by best practices in Flutter development

---

**Happy Chatting!** 🎉

For more information about the Chat Memory package, visit the [main documentation](../README.md).

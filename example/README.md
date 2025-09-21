# Chat Memory Example App

A Flutter demonstration app showcasing the **Hybrid Memory System** with AI-powered conversations that remember context across sessions.

![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![Dart](https://img.shields.io/badge/dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)
![Google AI](https://img.shields.io/badge/Google%20AI-4285F4?style=for-the-badge&logo=google&logoColor=white)

## ✨ Features

### 🧠 **Hybrid Memory System**

- **Automatic Summarization**: Compresses older conversations while preserving key information
- **Semantic Search**: Finds relevant context from past conversations using vector embeddings
- **Rolling Window**: Keeps recent messages for immediate context
- **Smart Token Management**: Optimizes content within AI model token limits

### 🏭 **Advanced Processing Pipeline**

- **Intelligent Chunking**: Multiple strategies for message segmentation (token-based, sentence-based, sliding window)
- **Resilient Embeddings**: Circuit breakers, retry logic, and adaptive batch processing
- **Configurable Stages**: Flexible pipeline orchestration with validation, chunking, embedding, and storage
- **Performance Monitoring**: Comprehensive statistics, health checks, and optimization metrics

### 🤖 **AI Integration**

- **Google Gemini AI**: Real AI responses with your own API key
- **Simulation Mode**: Demo responses when no API key is configured
- **Memory-Aware Responses**: AI references past conversations intelligently
- **Context-Rich Prompts**: Enhanced prompts with summarized history

### 🔒 **Privacy & Security**

- **Local Storage**: API keys stored securely on your device
- **No Data Sharing**: All conversation data stays on your device
- **Masked Display**: API keys shown with masking for security
- **Easy Management**: Clear or update API keys anytime

## 🚀 Getting Started

### Prerequisites

- Flutter 3.9.2 or later
- Dart SDK
- Google Gemini API key (optional, app works in demo mode without it)

### Installation

1. **Clone the repository**

   ```bash
   git clone <repository-url>
   cd chat_memory/example
   ```

2. **Install dependencies**

   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

## 🔑 API Key Setup

### Getting Your Gemini API Key

1. **Visit Google AI Studio**: Go to [ai.google.dev](https://ai.google.dev)
2. **Sign In**: Use your Google account
3. **Create API Key**: Click "Get API key" and create a new key
4. **Copy the Key**: Save it securely (starts with `AIza...`)

### Setting Up in the App

1. **Open the app** and tap the 🔑 key icon in the top bar
2. **Paste your API key** in the text field
3. **Save** - the key is encrypted and stored locally
4. **Test** the connection using the "Test API" button
5. **Start chatting** with real AI responses!

### Demo Mode

- **No API Key Required**: App works in simulation mode
- **Feature Demonstration**: Shows all memory system capabilities
- **Educational**: Perfect for understanding the system without costs
- **Easy Upgrade**: Add your API key anytime to get real AI

## 💬 How to Use

### Basic Chat

1. Type your message in the text field
2. Tap send or press Enter
3. Watch the AI respond with memory context
4. See memory information in the expandable cards

### Memory Features

- **View Summaries**: Tap the summary card to see compressed history
- **Semantic Context**: Check which past messages were found relevant
- **Memory Stats**: Monitor token usage and conversation statistics
- **Follow-up Suggestions**: Use AI-generated conversation starters

### Settings & Management

- **🔑 API Settings**: Manage your Gemini API key
- **🧠 Memory Info**: View detailed memory system information
- **🗑️ Clear Chat**: Reset conversation and memory
- **🌓 Theme Toggle**: Switch between light and dark modes

## 🏗️ Architecture

### Memory Layers

```
┌─────────────────────────────┐
│     User Input Query        │
└──────────┬──────────────────┘
           │
┌──────────▼──────────────────┐
│    Pre-Check (Token)        │
│  ✓ Within budget → Return   │
│  ✗ Over budget → Continue   │
└──────────┬──────────────────┘
           │
┌──────────▼──────────────────┐
│   Summarization Layer       │
│  • Compress old messages    │
│  • Preserve key context     │
│  • Generate summaries       │
└──────────┬──────────────────┘
           │
┌──────────▼──────────────────┐
│    Semantic Layer          │
│  • Vector search           │
│  • Find relevant context   │
│  • Retrieve past facts     │
└──────────┬──────────────────┘
           │
┌──────────▼──────────────────┐
│   Final Prompt Assembly     │
│  System + Summaries +       │
│  Semantic + Recent Messages │
└─────────────────────────────┘
```

### Components

- **EnhancedConversationManager**: Core memory orchestration
- **LocalVectorStore**: Persistent semantic storage
- **SimpleEmbeddingService**: Text-to-vector conversion
- **SummarizationStrategy**: Smart context compression
- **AIAdapter**: Gemini API integration with fallback

## 📊 Memory Monitoring

The app provides real-time insight into the memory system:

### Token Information Bar

- **🤖/🔑 API**: Shows if using real AI or demo mode
- **🎯 Tokens**: Current prompt token count
- **📝 Summary**: Whether summarization occurred
- **💬 Messages**: Number of included messages
- **🔍 Semantic**: Relevant memories found
- **🧠 Memory**: Memory system type

### Expandable Cards

- **📄 Memory Summary**: View compressed conversation history
- **🔍 Semantic Memories**: See relevant past context with similarity scores
- **📊 Memory Stats**: Detailed conversation and storage statistics

## 🎛️ Configuration Options

### Memory Presets

The underlying system supports multiple presets:

- **Development**: Fast in-memory storage
- **Production**: Persistent SQLite storage (used in app)
- **Performance**: Optimized for large conversations
- **Minimal**: Summarization only, no semantic search

### Customization

The app demonstrates these configurable aspects:

- Token budgets and limits
- Semantic similarity thresholds
- Summarization chunk sizes
- Vector storage backends
- Embedding dimensions

## 🔒 Privacy & Data

### What's Stored Locally

- **Conversation History**: All your messages
- **Vector Embeddings**: Semantic search data
- **API Key**: Encrypted and stored securely
- **Memory Summaries**: Compressed conversation history

### What's NOT Stored

- **No Cloud Backup**: Everything stays on your device
- **No Analytics**: No usage tracking
- **No Data Sharing**: Your conversations are private

### API Usage

- **Your API Key**: Direct connection to Google Gemini
- **Your Costs**: You control API usage and costs
- **Your Data**: Messages sent to Gemini for responses only

## 🛠️ Development

### Project Structure

```
lib/
├── main.dart                 # Main app and chat UI
├── chat_manager.dart         # Enhanced conversation management
├── ai_adapter.dart          # Gemini API integration
└── api_key_screen.dart      # API key management UI

examples/
├── hybrid_memory_example.dart    # Comprehensive hybrid memory examples
└── advanced_processing_example.dart  # Processing pipeline demonstrations
```

### Key Dependencies

```yaml
dependencies:
  flutter: sdk: flutter
  chat_memory: ^1.0.0         # Hybrid memory system
  google_generative_ai: ^0.2.0 # Gemini AI SDK
  shared_preferences: ^2.2.2   # Secure local storage
  flutter_markdown: ^0.7.0     # Rich text display
  google_fonts: ^4.0.4         # Beautiful typography
```

### Building

```bash
# Debug build
flutter run

# Release build
flutter build apk --release
flutter build ios --release
```

## 🆘 Troubleshooting

### Common Issues

**"API key test failed"**

- Verify your API key is correct
- Check internet connection
- Ensure sufficient API quota at Google AI Studio

**"Running in simulation mode"**

- This is normal without an API key
- Add your Gemini API key for real AI responses

**Memory not working**

- Check that vector storage is enabled
- Try clearing and restarting the conversation
- Memory builds up over multiple exchanges

**App crashes or errors**

- Check Flutter and Dart versions
- Run `flutter clean && flutter pub get`
- Restart the app

### Getting Help

- Check the main chat_memory package documentation
- Review Google AI Studio documentation
- File issues on the project repository

## 📋 Requirements

### System Requirements

- **Flutter**: 3.9.2+
- **Dart**: 3.9.2+
- **iOS**: 12.0+ (for iOS deployment)
- **Android**: API 21+ (for Android deployment)
- **Platforms**: iOS, Android, Web, Desktop

### Optional Requirements

- **Google Gemini API Key**: For real AI responses
- **Internet Connection**: For API calls (demo mode works offline)

## 🎯 Use Cases

### Personal Assistant

- **Daily Planning**: AI remembers your schedule and preferences
- **Follow-up Questions**: Contextual conversations across sessions
- **Knowledge Building**: Accumulates understanding over time

### Learning & Education

- **Study Sessions**: AI recalls previous topics and progress
- **Concept Building**: Connects new information to past discussions
- **Personalized Help**: Adapts to your learning style and pace

### Creative Projects

- **Story Development**: Remembers characters and plot points
- **Brainstorming**: Builds on previous creative sessions
- **Project Management**: Tracks ideas and decisions over time

### Professional Use

- **Meeting Preparation**: Recalls past discussion points
- **Research Assistant**: Connects new findings to previous research
- **Decision Support**: References historical context and decisions

## 🚀 Future Enhancements

### Planned Features

- **Export/Import**: Save and share conversation memory
- **Multiple Models**: Support for other AI providers
- **Voice Input**: Speech-to-text conversation
- **Rich Media**: Image and file memory integration
- **Collaboration**: Shared memory sessions

### Advanced Features

- **Custom Embeddings**: Use specialized embedding models
- **Cloud Sync**: Optional cloud storage for memory
- **Memory Analytics**: Detailed usage and pattern analysis
- **Plugin System**: Extensible memory processors

## 📄 License

This example app is part of the chat_memory package and follows the same licensing terms.

## 🤝 Contributing

Contributions are welcome! This example helps demonstrate the capabilities of the hybrid memory system and serves as a reference for integration.

---

**Built with ❤️ using the Chat Memory Hybrid System**

_Demonstrating the future of conversational AI with persistent, intelligent memory._

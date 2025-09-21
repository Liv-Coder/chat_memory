import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'presentation/screens/chat_screen.dart';

void main() {
  runApp(const ChatMemoryExampleApp());
}

class ChatMemoryExampleApp extends StatelessWidget {
  const ChatMemoryExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chat Memory Demo',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const ChatScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

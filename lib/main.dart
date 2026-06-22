import 'package:flutter/material.dart';

import 'services/agent.dart';
import 'services/chat_compose.dart';
import 'widgets/chat_page.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  late final AgentService _agentService;
  late final ChatComposeService _chatComposeService;

  @override
  void initState() {
    super.initState();
    _agentService = AgentService();
    _chatComposeService = ChatComposeService();
  }

  @override
  void dispose() {
    _chatComposeService.dispose();
    _agentService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3B6C62)),
        useMaterial3: true,
      ),
      home: ChatPage(
        agentService: _agentService,
        chatComposeService: _chatComposeService,
      ),
    );
  }
}

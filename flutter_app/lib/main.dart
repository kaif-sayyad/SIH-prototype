import 'package:flutter/material.dart';
import 'backend/database_service.dart';
import 'models/user_session.dart';
import 'screens/auth_screen.dart';
import 'screens/portal_screen.dart';
import 'services/auth_service.dart';
import 'services/knowledge_service.dart';

/// SkillPath Family Counselling Portal — Flutter client.
///
/// The entire backend (auth, sessions, RAG knowledge base, agentic
/// counsellor loop, analytics) runs locally inside the app via
/// `lib/backend/`, converted from the Next.js/TypeScript backend.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SkillPathApp());
}

class SkillPathApp extends StatefulWidget {
  const SkillPathApp({Key? key}) : super(key: key);

  @override
  State<SkillPathApp> createState() => _SkillPathAppState();
}

class _SkillPathAppState extends State<SkillPathApp> {
  bool _backendReady = false;
  UserSession? _session;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Boot the local backend: JSON database + auth service + knowledge seed
    await DatabaseService().init();
    await AuthService().init();
    await KnowledgeService.ensureSeeded();

    final session = AuthService().currentSession;
    setState(() {
      _backendReady = true;
      _session = session;
    });
  }

  void _onLoginSuccess(UserSession session) {
    setState(() => _session = session);
  }

  void _onLogout() {
    AuthService().logout();
    setState(() => _session = null);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SkillPath Family Counselling Portal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1B365D),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: !_backendReady
          ? const Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF1B365D)),
                    SizedBox(height: 16),
                    Text('Initializing SkillPath backend…'),
                  ],
                ),
              ),
            )
          : (_session == null
              ? AuthScreen(lang: 'en', onLoginSuccess: _onLoginSuccess)
              : PortalScreen(session: _session!, onLogout: _onLogout)),
    );
  }
}

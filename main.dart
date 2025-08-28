import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';

import 'login_screen.dart';
import 'home_screen.dart';
import 'reset_password_screen.dart';
import 'supabase_service.dart';
import 'signup_screen.dart'; // ←追加

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: LoginScreen(), // ← 起動時は必ずログイン画面
    routes: {
      '/home': (context) => HomeScreen(),
      '/login': (context) => LoginScreen(),
      '/signup': (context) => SignupScreen(), // ←追加
    },
  ));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AppLinks _appLinks; // ← app_links を使う
  StreamSubscription<Uri>? _sub;

  @override
  void initState() {
    super.initState();
    _setupDeepLinks();
  }

  void _setupDeepLinks() async {
    _appLinks = AppLinks();

    // リンクをリッスン
    _sub = _appLinks.uriLinkStream.listen((uri) {
      _handleUri(uri);
    }, onError: (_) {});
  }

  void _handleUri(Uri uri) {
    // 例: http://localhost/reset-password#access_token=...
    if (uri.host == 'localhost' && uri.path == '/reset-password') {
      final params = uri.fragment.isEmpty
          ? <String, String>{}
          : Uri.splitQueryString(uri.fragment);
      final token = params['access_token'];
      if (token != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ResetPasswordScreen(accessToken: token),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: '在庫管理',
      theme: ThemeData(primarySwatch: Colors.green),
      home: SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  void _checkAuth() async {
    final session = Supabase.instance.client.auth.currentSession;

    await Future.delayed(const Duration(seconds: 2)); // ロゴとか表示用
    if (session == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

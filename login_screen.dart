import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Supabase パッケージをインポート
import 'inventory_list_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final supabase = Supabase.instance.client; // Supabaseインスタンスを取得
    final session = supabase.auth.currentSession;
    if (session != null) {
      // すでにログイン済みなら一覧へ自動遷移
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const InventoryListScreen()),
        );
      });
    }
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final supabase = Supabase.instance.client; // Supabaseインスタンスを取得
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final AuthResponse res = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (res.session != null) {
        // ログイン成功 → 在庫一覧画面へ
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const InventoryListScreen()),
        );
      } else {
        setState(() {
          _errorMessage = "ログイン失敗（セッションが取得できませんでした）";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'ログインに失敗しました: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _signUp() async {
    try {
      final supabase = Supabase.instance.client; // Supabaseインスタンスを取得
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
      );
      if (response.user != null) {
        setState(() {
          _errorMessage = "登録しました。ログインしてください。";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '登録に失敗しました: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("ログイン")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: "メールアドレス"),
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: "パスワード"),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            if (_errorMessage != null)
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 20),
            _loading
                ? const CircularProgressIndicator()
                : Column(
                    children: [
                      ElevatedButton(
                        onPressed: _login,
                        child: const Text("ログイン"),
                      ),
                      TextButton(
                        onPressed: _signUp,
                        child: const Text("新規登録"),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}

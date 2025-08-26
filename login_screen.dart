import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Supabase パッケージをインポート
import 'home_screen.dart';

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
    // ★ セッションチェック処理は削除
  }

  Future<void> _login() async {
    print('ログイン開始'); // デバッグログ追加
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final supabase = Supabase.instance.client; // Supabaseインスタンスを取得
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      print('Email: $email, Password length: ${password.length}'); // デバッグログ追加

      if (email.isEmpty || password.isEmpty) {
        setState(() {
          _errorMessage = 'メールアドレスとパスワードを入力してください';
        });
        return;
      }

      final AuthResponse res = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      print('ログインレスポンス: ${res.session != null}'); // デバッグログ追加

      if (res.session != null) {
        // ログイン成功 → ホーム画面へ
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        setState(() {
          _errorMessage = "ログイン失敗（セッションが取得できませんでした）";
        });
      }
    } catch (e) {
      print('ログインエラー: $e'); // デバッグログ追加
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
    print('新規登録開始'); // デバッグログ追加
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final supabase = Supabase.instance.client; // Supabaseインスタンスを取得
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      print(
          'SignUp Email: $email, Password length: ${password.length}'); // デバッグログ追加

      if (email.isEmpty || password.isEmpty) {
        setState(() {
          _errorMessage = 'メールアドレスとパスワードを入力してください';
        });
        return;
      }

      final response = await supabase.auth.signUp(
        email: email,
        password: password,
      );

      print('新規登録レスポンス: ${response.user != null}'); // デバッグログ追加

      if (response.user != null) {
        setState(() {
          _errorMessage = "登録しました。ログインしてください。";
        });
      }
    } catch (e) {
      print('新規登録エラー: $e'); // デバッグログ追加
      setState(() {
        _errorMessage = '登録に失敗しました: $e';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'パスワードリセットにはメールアドレスが必要です';
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final supabase = Supabase.instance.client;
      await supabase.auth.resetPasswordForEmail(email);
      setState(() {
        _errorMessage = 'パスワードリセットメールを送信しました。メールを確認してください。';
      });
    } catch (e) {
      print('パスワードリセットエラー: $e');
      setState(() {
        _errorMessage = 'パスワードリセットに失敗しました: $e';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
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
                      TextButton(
                        onPressed: _resetPassword,
                        child: const Text("パスワードを忘れた場合"),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;

  Future<void> _signUp() async {
    setState(() => _loading = true);
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      // 1. Supabase Auth にユーザー作成
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
      );
      final user = response.user;
      if (user == null) throw Exception("サインアップに失敗しました");
      final uid = user.id;

      // 2. users テーブルに行を追加
      await Supabase.instance.client.from('users').insert({
        'id': uid,
        'role': 'member',
        'created_at': DateTime.now().toIso8601String(),
      });

      // 3. companies に会社を作成
      final company = await Supabase.instance.client
          .from('companies')
          .insert({
            'name': '${email}の会社',
            'invite_code': 'AUTO-${DateTime.now().millisecondsSinceEpoch}',
            'created_by': uid,
          })
          .select('id')
          .single();
      final companyId = company['id'];

      // 4. users.company_id を更新
      await Supabase.instance.client.from('users').update({
        'company_id': companyId,
      }).eq('id', uid);

      print("DEBUG: ユーザー $uid を会社 $companyId に所属させました");

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      print("サインアップエラー: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("サインアップ失敗: $e")));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("新規登録")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
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
            const SizedBox(height: 16),
            _loading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _signUp,
                    child: const Text("新規登録"),
                  ),
          ],
        ),
      ),
    );
  }
}

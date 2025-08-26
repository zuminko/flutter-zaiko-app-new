// lib/manage_locations_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 場所管理（追加・削除／RPCで一括削除）
class ManageLocationsScreen extends StatefulWidget {
  const ManageLocationsScreen({super.key});

  @override
  State<ManageLocationsScreen> createState() => _ManageLocationsScreenState();
}

class _ManageLocationsScreenState extends State<ManageLocationsScreen> {
  final _nameCtrl = TextEditingController();
  bool _loading = false;
  List<Map<String, dynamic>> _rows = [];

  SupabaseClient get _c => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final rows = await _c
          .from('locations')
          .select('id,name,type')
          .neq('name', '未設定') // 「未設定」を除外
          .order('id');
      setState(() => _rows = List<Map<String, dynamic>>.from(rows as List));
    } catch (e) {
      _showSnack('場所一覧の取得に失敗: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _showSnack('場所名を入力してください');
      return;
    }
    setState(() => _loading = true);
    try {
      // 重複チェック
      final exists = await _c
          .from('locations')
          .select('id')
          .eq('name', name)
          .maybeSingle();
      if (exists != null) {
        _showSnack('同じ名前の場所が既にあります');
        return;
      }
      // type は NOT NULL の可能性があるため既定で other を入れる
      await _c.from('locations').insert({'name': name, 'type': 'other'});
      _nameCtrl.clear();
      await _refresh();
      _showSnack('追加しました');
    } catch (e) {
      _showSnack('追加に失敗: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final id = (row['id'] as num).toInt();
    final name = (row['name'] ?? '').toString();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('削除しますか？'),
        content:
            Text('場所「$name」を削除します。\nこれに紐づく入出庫履歴・在庫ゼロのロットも削除されます。\n※ 元に戻せません'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('キャンセル')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('削除')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _loading = true);
    try {
      // ★ ここが "2)" の変更点：通常の delete ではなく RPC を呼びます
      await _c.rpc('delete_location_cascade', params: {'loc_id': id});
      await _refresh();
      _showSnack('削除しました');
    } catch (e) {
      _showSnack('削除に失敗: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('場所管理（追加・削除）'),
        actions: [
          IconButton(
            tooltip: '再読み込み',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _refresh,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: '新しい場所名',
                      hintText: '例）第1農園A棟',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _loading ? null : _add,
                  child: const Text('追加'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView.separated(
                        itemCount: _rows.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final r = _rows[i];
                          final name = r['name']?.toString() ?? '';
                          return ListTile(
                            title: Text(name),
                            trailing: IconButton(
                              tooltip: '削除',
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.red),
                              onPressed: _loading ? null : () => _delete(r),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

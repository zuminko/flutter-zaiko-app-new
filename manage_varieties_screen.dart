// lib/manage_varieties_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase_service.dart';

/// 品種管理（追加・削除／強制削除）
class ManageVarietiesScreen extends StatefulWidget {
  const ManageVarietiesScreen({super.key});

  @override
  State<ManageVarietiesScreen> createState() => _ManageVarietiesScreenState();
}

class _ManageVarietiesScreenState extends State<ManageVarietiesScreen> {
  final _nameCtrl = TextEditingController();
  bool _loading = false;
  List<Map<String, dynamic>> _rows = [];

  SupabaseClient get _c => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    print('>>> initState: _loading=$_loading');
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final companyId = await SupaService.i.myCompanyId();
      final rows = await _c
          .from('varieties')
          .select('id,name')
          .eq('company_id', companyId) // ← フィルタ追加
          .order('id');

      setState(() => _rows = List<Map<String, dynamic>>.from(rows as List));
    } catch (e) {
      _showSnack('品種一覧の取得に失敗: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    print('>>> _add メソッドが呼び出されました');
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _showSnack('品種名を入力してください');
      return;
    }
    setState(() => _loading = true);
    try {
      final uid = _c.auth.currentUser?.id; // ログ用
      print("DEBUG: currentUser.id = $uid"); // ← 追加

      final companyId = await SupaService.i.myCompanyId();
      print("DEBUG: myCompanyId = $companyId"); // ← 追加

      print(
          '>>> inserting variety: name=$name, companyId=$companyId, created_by=$uid');

      await _c.from('varieties').insert({
        'name': name,
        'company_id': companyId,
      });

      _nameCtrl.clear();
      await _refresh();
      _showSnack('追加しました');
    } catch (e) {
      print('>>> エラー発生: $e');
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
        content: Text('品種「$name」を削除します。取り消しはできません。'),
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
      // 削除リクエスト時に id (bigint) を使用
      final res = await _c.from('varieties').delete().eq('id', id).select('id');
      final deleted = (res as List).isNotEmpty;

      if (!deleted) {
        // まだ行が存在しているか再確認。存在するなら強制削除フローへ。
        final still =
            await _c.from('varieties').select('id').eq('id', id).maybeSingle();
        if (still != null) {
          await _confirmForceDelete(id: id, name: name);
          return;
        }
      }

      await _refresh();
      _showSnack('削除しました');
    } catch (e) {
      // FK制約などでエラー → 関連データごと削除するか確認
      await _confirmForceDelete(id: id, name: name);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmForceDelete(
      {required int id, required String name}) async {
    try {
      // 関連ロットを取得
      final lots =
          await _c.from('harvest_lots').select('id').eq('variety_id', id);
      final lotIds = [for (final r in (lots as List)) (r['id'] as num).toInt()];

      int movesCount = 0;
      if (lotIds.isNotEmpty) {
        final moves = await _c
            .from('stock_moves')
            .select('id')
            .inFilter('lot_id', lotIds);
        movesCount = (moves as List).length;
      }

      final ok = mounted
          ? await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('関連データも含めて削除しますか？'),
                content: Text('''
この品種には
・収穫ロット: ${lotIds.length} 件
・入出庫履歴: $movesCount 件
が紐づいています。

これらをすべて削除してから、品種「$name」も削除します。
※ 元に戻せません'''),
                actions: [
                  TextButton(
                      onPressed: () {
                        if (!mounted) return;
                        Navigator.pop(ctx, false);
                      },
                      child: const Text('キャンセル')),
                  ElevatedButton(
                    onPressed: () {
                      if (!mounted) return;
                      Navigator.pop(ctx, true);
                    },
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('強制削除'),
                  ),
                ],
              ),
            )
          : null;
      if (ok != true) return;

      await _forceDeleteVariety(id: id, lotIds: lotIds);

      // 本当に消えたか最終確認（RLS等でブロックされる環境のため）
      final still =
          await _c.from('varieties').select('id').eq('id', id).maybeSingle();
      if (still != null) {
        throw Exception('DBポリシーにより削除できませんでした（管理者へご連絡ください）');
      }

      await _refresh();
      _showSnack('関連データごと削除しました');
    } catch (e) {
      _showSnack('強制削除に失敗: $e');
    }
  }

  Future<void> _forceDeleteVariety(
      {required int id, required List<int> lotIds}) async {
    await Supabase.instance.client
        .rpc('delete_variety_cascade', params: {'v_id': id});
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
        title: const Text('品種管理（追加・削除／強制削除）'),
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
                      labelText: '新しい品種名',
                      hintText: '例）紅ほっぺ',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _loading
                      ? null
                      : () {
                          print('>>> ボタンが押されました, _loading=$_loading');
                          _add();
                        },
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

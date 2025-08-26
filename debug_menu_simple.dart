// lib/debug_menu_simple.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'inventory_list_screen.dart';
import 'history_screen.dart';

/// どの画面からでも呼べる簡易デバッグメニュー（本物データのまま）
/// リリースビルドでは自動で出ない（kDebugMode）
Future<void> showSimpleDebugMenu(BuildContext context) async {
  if (!kDebugMode) return; // リリースでは表示しない。常時使いたいならこの行を消してください。

  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const ListTile(
            leading: Icon(Icons.developer_mode),
            title: Text('デバッグメニュー'),
            subtitle: Text('好きな画面へ即移動（本番データを使用）'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.inventory),
            title: const Text('在庫一覧へ'),
            onTap: () {
              Navigator.pop(ctx);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const InventoryListScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('履歴画面へ'),
            onTap: () {
              Navigator.pop(ctx);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HistoryScreen()),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

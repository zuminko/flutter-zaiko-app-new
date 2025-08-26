// lib/harvest_input_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'supabase_service.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// 収穫入力（圃場名は入力に出さない）
class HarvestInputScreen extends StatefulWidget {
  const HarvestInputScreen({super.key});

  @override
  State<HarvestInputScreen> createState() => _HarvestInputScreenState();
}

class _HarvestInputScreenState extends State<HarvestInputScreen> {
  List<Map<String, dynamic>> _varieties = [];
  List<Map<String, dynamic>> _locations = [];

  int? _varietyIndex; // ドロップダウンの選択は index で保持
  int? _locationId;
  final _casesCtrl = TextEditingController();
  final _memoCtrl = TextEditingController();
  final _memoFocus = FocusNode();
  DateTime _date = DateTime.now();

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadMasters();
  }

  Future<void> _loadMasters() async {
    try {
      final vs = await SupaService.i.varieties();

      // Supabaseの品種だけをセット
      final merged = <Map<String, dynamic>>[];
      final seen = <String>{};
      for (final m in vs) {
        final name = (m['name'] ?? '').toString();
        if (name.isEmpty || seen.contains(name)) continue;
        merged.add({'id': (m['id'] as num?)?.toInt() ?? -1, 'name': name});
        seen.add(name);
      }

      final ls = await SupaService.i.locations();
      setState(() {
        _varieties = merged;
        _locations = ls;
        _varietyIndex = merged.isNotEmpty ? 0 : null;
        _locationId = ls.isNotEmpty ? (ls.first['id'] as num).toInt() : null;
      });
    } catch (e) {
      _showSnack('マスタ取得に失敗: $e');
    }
  }

  @override
  void dispose() {
    _casesCtrl.dispose();
    _memoCtrl.dispose();
    _memoFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;

    final idx = _varietyIndex;
    final lId = _locationId;
    final cases = int.tryParse(_casesCtrl.text.trim());

    // ✅ 入力チェック
    if (idx == null) {
      _showSnack('品種を選択してください');
      return;
    }
    if (lId == null) {
      _showSnack('場所を選択してください');
      return;
    }
    if (cases == null || cases <= 0) {
      _showSnack('数量は1以上の数字で入力してください');
      return;
    }

    // ✅ 品種ID確定
    final item = _varieties[idx];
    final selectedName = (item['name'] ?? '').toString();
    final dbId = (item['id'] as num?)?.toInt();
    final varietyId = (dbId != null && dbId > 0)
        ? dbId
        : await SupaService.i.ensureVariety(selectedName);

    setState(() => _loading = true);
    try {
      // ✅ 収穫レコード作成 → 直後に入庫
      final result = await SupaService.i.insertHarvestAndIn(
        varietyId: varietyId,
        locationId: lId,
        cases: cases,
        date: _date,
        memo: _memoCtrl.text,
      );

      // QRを表示＆保存・共有
      if (!mounted) return;
      await showQrDialog(context, result['lot_code']);

      if (!mounted) return;
      _casesCtrl.clear();
      _memoCtrl.clear();
      _showSnack('入庫を保存しました');
    } catch (e) {
      if (mounted) _showSnack('保存に失敗: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('収穫入力'),
      ),
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent, // ← 空白部分だけ拾う
              onTap: () => FocusScope.of(context).unfocus(), // キーボード閉じる
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<int>(
                      value: _varietyIndex,
                      decoration: const InputDecoration(labelText: '品種'),
                      items: [
                        for (int i = 0; i < _varieties.length; i++)
                          DropdownMenuItem<int>(
                            value: i,
                            child: Text(_varieties[i]['name'].toString()),
                          ),
                      ],
                      onChanged: (v) => setState(() => _varietyIndex = v),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: _locationId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: '場所'),
                      items: _locations.map((loc) {
                        final id = (loc['id'] as num?)?.toInt();
                        final name = (loc['name'] ?? '').toString();
                        return DropdownMenuItem<int>(
                          value: id,
                          child: Text(name),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _locationId = v),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _casesCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: false,
                        decimal: false,
                      ),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: '数量（ケース）',
                        hintText: '例: 10',
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) =>
                          FocusScope.of(context).requestFocus(_memoFocus),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _memoCtrl,
                      focusNode: _memoFocus,
                      decoration: const InputDecoration(
                        labelText: 'メモ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('日付：'),
                        TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _date,
                              firstDate: DateTime(2020, 1, 1),
                              lastDate: DateTime(2100, 12, 31),
                            );
                            if (picked != null) setState(() => _date = picked);
                          },
                          child: Text(
                              '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('保存して入庫'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showQrDialog(BuildContext context, String lotCode) async {
  final qrKey = GlobalKey();

  showDialog(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text("ロットQRコード"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Lot Code: $lotCode"),
            const SizedBox(height: 12),
            RepaintBoundary(
              key: qrKey,
              child: SizedBox(
                width: 200,
                height: 200,
                child: QrImageView(
                  data: lotCode,
                  version: QrVersions.auto,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("閉じる"),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.save_alt),
            label: const Text("保存・共有"),
            onPressed: () async {
              await _saveAndShareQr(qrKey, lotCode);
            },
          ),
        ],
      );
    },
  );
}

Future<void> _saveAndShareQr(GlobalKey key, String lotCode) async {
  try {
    // フレーム描画完了を待つ
    await WidgetsBinding.instance.endOfFrame;

    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) throw Exception("QR not ready");

    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List();

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$lotCode.png');
    await file.writeAsBytes(pngBytes);

    await Share.shareXFiles([XFile(file.path)], text: "ロット $lotCode のQRコード");
  } catch (e) {
    debugPrint("QR保存/共有失敗: $e");
  }
}

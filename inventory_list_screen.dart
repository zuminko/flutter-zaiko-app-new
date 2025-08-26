import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'supabase_service.dart';
import 'package:kana_kit/kana_kit.dart';
import 'package:intl/intl.dart'; // ← 追加
import 'scan_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;

final kanaKit = KanaKit();

class InventoryListScreen extends StatefulWidget {
  const InventoryListScreen({super.key});

  @override
  State<InventoryListScreen> createState() => _InventoryListScreenState();
}

class _InventoryListScreenState extends State<InventoryListScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _loading = false;
  final List<Map<String, dynamic>> _rows = [];
  List<Map<String, dynamic>> _allRows = []; // 全データ（検索用に保持）
  String _orderBy = 'on_hand';
  bool _descending = true;
  int _offset = 0; // ページング用
  final int _limit = 50;
  bool _hasMore = true; // まだデータがあるか？
  String _searchQuery = ''; // ← 追加
  bool _isSearching = false;
  final TextEditingController _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _filteredRows = []; // フィルタ結果を保持

  // Added state variables for filtering
  String? _filterVariety; // 品種名で絞り込み
  String? _filterLocation; // 場所名で絞り込み
  bool _includeZero = false; // ゼロ在庫を含めるか

  // Changed from final to mutable
  bool _excludeZero = true;

  @override
  void initState() {
    super.initState();
    // initStateから直接SnackBar等を触らないため、フレーム後に呼ぶ
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
    });
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _loadMore();
      }
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _rows.clear();
      _offset = 0;
      _hasMore = true;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      // Supabase からデータ取得
      final rows = await SupaService.i.fetchInventory(
        limit: _limit,
        offset: _offset,
        excludeZero: _excludeZero,
        orderBy: _orderBy,
        descending: _descending,
      );
      if (!mounted) return;
      setState(() {
        _rows.addAll(rows);
        _allRows = List.from(_rows);
        _filteredRows = _applyFiltersAndSearch(_allRows);
        _offset += _limit;
        if (rows.length < _limit) _hasMore = false;
      });
    } catch (e) {
      // エラーハンドリング
      debugPrint('在庫取得に失敗: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('在庫取得に失敗しました: $e')),
      );
    } finally {
      // 必要なら後始末
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchCtrl,
                decoration: const InputDecoration(
                  hintText: '品種 / ロット番号 / 場所で検索',
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                    _filteredRows = _applyFiltersAndSearch(_allRows);
                  });
                },
              )
            : const Text('在庫一覧'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _searchQuery = '';
                  _searchCtrl.clear();
                  _filteredRows = _allRows;
                }
                _isSearching = !_isSearching;
              });
            },
          ),
          // PDFエクスポートメニュー
          PopupMenuButton<String>(
            icon: const Icon(Icons.picture_as_pdf),
            onSelected: (value) async {
              if (value == 'labels') {
                await exportQrPdfLabels(_filteredRows);
              } else if (value == 'table') {
                await exportQrPdfTable(_filteredRows);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'labels', child: Text('QRラベル出力')),
              const PopupMenuItem(value: 'table', child: Text('帳票出力')),
            ],
          ),
          IconButton(
            tooltip: 'QRスキャン',
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _startScan,
          ),
          Row(
            children: [
              // 並べ替え基準の選択
              PopupMenuButton<String>(
                icon: const Icon(Icons.sort),
                onSelected: (value) {
                  setState(() {
                    _orderBy = value;
                  });
                  _refresh();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'on_hand', child: Text('数量')),
                  const PopupMenuItem(value: 'updated_at', child: Text('更新日')),
                  const PopupMenuItem(
                      value: 'variety_name', child: Text('品種名')),
                  const PopupMenuItem(
                      value: 'location_name', child: Text('場所名')),
                  const PopupMenuItem(value: 'lot_code', child: Text('ロット番号')),
                ],
              ),

              // 昇順／降順トグル
              IconButton(
                icon: Icon(
                    _descending ? Icons.arrow_downward : Icons.arrow_upward),
                onPressed: () {
                  setState(() {
                    _descending = !_descending; // 反転
                  });
                  _refresh();
                },
              ),
            ],
          ),
          IconButton(
            tooltip: '絞り込み',
            icon: const Icon(Icons.filter_list_alt), // ← 別のフィルターアイコン
            onPressed: _openFilterDialog,
          ),
        ],
      ), // 修正: AppBarの閉じ忘れを修正
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _loading && _filteredRows.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _filteredRows.isEmpty
                ? const Center(child: Text('在庫データがありません'))
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: _filteredRows.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == _filteredRows.length) {
                        // ローディングインジケーター
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      final row = _filteredRows[i];
                      final location = row['location_name'] ?? 'Unknown';
                      final variety = row['variety_name'] ?? 'Unknown';
                      final qty = row['on_hand'] ?? 0;
                      final updatedTxt = (() {
                        final raw = row['updated_at'];
                        if (raw == null) return '';
                        final dt = (raw is DateTime)
                            ? raw.toLocal()
                            : DateTime.tryParse(raw.toString())?.toLocal();
                        return dt != null ? formatReiwa(dt) : raw.toString();
                      })();

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 場所
                              _highlightText(location.toString(), _searchQuery),
                              const SizedBox(height: 2),
                              // 品種
                              _highlightText(variety.toString(), _searchQuery),
                              const SizedBox(height: 6),
                              // ロット
                              _highlightText('ロット: ${row['lot_code'] ?? ''}',
                                  _searchQuery),
                              const SizedBox(height: 6),
                              // 在庫・更新日時（2行）
                              Text('在庫: $qty',
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold)),
                              Text(updatedTxt,
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    tooltip: '入庫',
                                    icon: const Icon(Icons.north),
                                    onPressed: () {
                                      _showQuantityDialog(row, isIn: true);
                                    },
                                  ),
                                  IconButton(
                                    tooltip: '出庫',
                                    icon: const Icon(Icons.south),
                                    onPressed: () {
                                      _showQuantityDialog(row, isIn: false);
                                    },
                                  ),
                                  IconButton(
                                    tooltip: 'QR表示',
                                    icon: const Icon(Icons.qr_code),
                                    onPressed: () {
                                      _showQrDialog(
                                          context, row['lot_code'].toString());
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  Future<void> openTransferSheet(Map<String, dynamic> row) async {
    final lotId = (row['lot_id'] as num).toInt();
    final fromLocationId = (row['location_id'] as num).toInt();
    int? toLocationId;
    final qtyCtrl = TextEditingController();

    final locations = await SupaService.i.locations();
    if (!mounted) return;

    await showModalBottomSheet(
        context: context,
        builder: (ctx) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('ロットID: $lotId / から: ${row['location_name']}'),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(labelText: '移動先'),
                items: locations
                    .map((m) => DropdownMenuItem(
                          value: (m['id'] as num).toInt(),
                          child: Text(m['name'].toString()),
                        ))
                    .toList(),
                onChanged: (v) => toLocationId = v,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '数量（ケース）'),
              ),
              const SizedBox(height: 12),
              SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('移動する'),
                    onPressed: () async {
                      setState(() => _loading = true);
                      try {
                        final q = int.tryParse(qtyCtrl.text);
                        if (q == null || q <= 0) return;
                        if (toLocationId == null) return;

                        await SupaService.i.transfer(
                          lotId: lotId,
                          fromLocationId: fromLocationId,
                          toLocationId: toLocationId!,
                          qty: q,
                        );

                        if (!mounted) return;
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('移動しました')));
                        await _refresh();
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text('移動失敗: $e')));
                      } finally {
                        setState(() => _loading = false);
                      }
                    },
                  )),
            ]),
          );
        });
  }

  Future<void> debugInventoryView() async {
    // デバッグ用のコードは削除されました。
  }

  List<Map<String, dynamic>> _applyFilter(
      List<Map<String, dynamic>> rows, String query) {
    if (query.isEmpty) return rows;

    // 入力を小文字 & ひらがな化
    final terms = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .map((t) => kanaKit.toHiragana(t)) // ← ひらがなに揃える
        .toList();

    return rows.where((row) {
      // 対象テキストを1本にまとめて正規化
      final text = [
        row['variety_name'] ?? '',
        row['lot_code'] ?? '',
        row['location_name'] ?? '',
      ].join(' ').toLowerCase();

      final normalized = kanaKit.toHiragana(text);

      // 全ワードを含むかチェック
      return terms.every((t) => normalized.contains(t));
    }).toList();
  }

  List<Map<String, dynamic>> _applyFiltersAndSearch(
      List<Map<String, dynamic>> rows) {
    var list = rows;

    if (_filterVariety != null && _filterVariety!.isNotEmpty) {
      list = list
          .where((r) => (r['variety_name'] ?? '').toString() == _filterVariety)
          .toList();
    }
    if (_filterLocation != null && _filterLocation!.isNotEmpty) {
      list = list
          .where(
              (r) => (r['location_name'] ?? '').toString() == _filterLocation)
          .toList();
    }
    if (_searchQuery.isNotEmpty) {
      list = _applyFilter(list, _searchQuery); // 既存の“かな検索”関数を再利用
    }
    if (!_includeZero) {
      list = list.where((r) => (r['on_hand'] ?? 0) > 0).toList();
    }
    return list;
  }

  Widget _highlightText(String text, String query) {
    if (query.isEmpty || text.isEmpty) return Text(text);

    // 検索語の候補（入力そのまま / ひらがな / カタカナ）
    final qHira = kanaKit.toHiragana(query.toLowerCase());
    final qKata = kanaKit.toKatakana(qHira);
    final candidates = <String>{
      query,
      qHira,
      qKata,
    }.where((s) => s.isNotEmpty).toList();

    // 元テキスト内で見つかった最初の候補でハイライト
    final lowerText = text.toLowerCase();
    String? hit;
    int idx = -1;
    for (final c in candidates) {
      final i = lowerText.indexOf(c.toLowerCase());
      if (i >= 0) {
        hit = c;
        idx = i;
        break;
      }
    }
    if (hit == null) return Text(text);

    final spans = <TextSpan>[];
    // 通常部分
    if (idx > 0) spans.add(TextSpan(text: text.substring(0, idx)));
    // ヒット部分
    spans.add(TextSpan(
      text: text.substring(idx, idx + hit.length),
      style: const TextStyle(
        backgroundColor: Colors.yellow,
        fontWeight: FontWeight.bold,
      ),
    ));
    // 残り
    if (idx + hit.length < text.length) {
      spans.add(TextSpan(text: text.substring(idx + hit.length)));
    }

    return Text.rich(TextSpan(children: spans));
  }

  Future<void> _startScan() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ScanScreen()),
    );
    if (!mounted) return;

    if (code == null || code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QRが読み取れませんでした')),
      );
      return;
    }

    try {
      // ロットコードから在庫1件取得（inventory_view）
      final row = await SupaService.i.fetchInventoryByLotCode(code);
      if (!mounted) return;

      if (row == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('在庫が見つかりません: $code')),
        );
        return;
      }

      _showMoveDialog(row);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラー: $e')),
      );
    }
  }

  void _showMoveDialog(Map<String, dynamic> row) {
    final qtyCtrl = TextEditingController();
    final lotId = (row['lot_id'] as num?)?.toInt();
    final locationId = (row['location_id'] as num?)?.toInt();
    final variety = (row['variety_name'] ?? '').toString();
    final location = (row['location_name'] ?? '').toString();
    final lotCode = (row['lot_code'] ?? '').toString();

    if (lotId == null || locationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('このロットのID/場所が取得できませんでした')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('在庫操作'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ロット: $lotCode'),
              Text('場所: $location'),
              Text('品種: $variety'),
              const SizedBox(height: 12),
              TextField(
                controller: qtyCtrl,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: false,
                  decimal: false,
                ),
                decoration: const InputDecoration(
                  labelText: '数量',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('キャンセル'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.north),
              label: const Text('入庫'),
              onPressed: () async {
                final q = int.tryParse(qtyCtrl.text);
                if (q == null || q <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('正しい数量を入力してください')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                try {
                  await SupaService.i.insertMove(
                    lotId: lotId,
                    delta: q, // 入庫はプラス
                    locationId: locationId, // ← 必須
                  );
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$q 入庫しました')),
                  );
                  await _refresh(); // 一覧更新
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('入庫失敗: $e')),
                  );
                }
              },
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.south),
              label: const Text('出庫'),
              onPressed: () async {
                final q = int.tryParse(qtyCtrl.text);
                if (q == null || q <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('正しい数量を入力してください')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                try {
                  await SupaService.i.insertMove(
                    lotId: lotId,
                    delta: -q, // 出庫はマイナス
                    locationId: locationId, // ← 必須
                  );
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$q 出庫しました')),
                  );
                  await _refresh(); // 一覧更新
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('出庫失敗: $e')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showQrDialog(BuildContext context, String lotCode) {
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
    return Future.value();
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

  Future<void> exportQrPdf(List<Map<String, dynamic>> rows) async {
    // TODO: Implement QR code PDF export logic
    debugPrint("Exporting QR codes to PDF...");
  }

  Future<void> exportQrPdfLabels(List<Map<String, dynamic>> lots) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.notoSansJPRegular();

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Wrap(
            spacing: 20,
            runSpacing: 20,
            children: lots.map((lot) {
              final lotCode = lot['lot_code'] ?? '';
              final variety = lot['variety_name'] ?? '';
              final location = lot['location_name'] ?? '';

              return pw.Column(
                children: [
                  pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: lotCode.toString(),
                    width: 100,
                    height: 100,
                  ),
                  pw.Text(lotCode.toString(),
                      style: pw.TextStyle(font: font, fontSize: 10)),
                  pw.Text(variety.toString(),
                      style: pw.TextStyle(font: font, fontSize: 9)),
                  pw.Text(location.toString(),
                      style: pw.TextStyle(font: font, fontSize: 9)),
                ],
              );
            }).toList(),
          )
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: "lot_labels.pdf",
    );
  }

  Future<void> exportQrPdfTable(List<Map<String, dynamic>> lots) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.notoSansJPRegular();

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.TableHelper.fromTextArray(
            headers: ["Lot Code", "Variety", "Location", "Qty", "Updated"],
            headerStyle:
                pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold),
            cellStyle: pw.TextStyle(font: font, fontSize: 10),
            columnWidths: {
              0: pw.FlexColumnWidth(2), // Lot Code
              1: pw.FlexColumnWidth(2), // Variety
              2: pw.FlexColumnWidth(2), // Location
              3: pw.FlexColumnWidth(1), // Qty
              4: pw.FlexColumnWidth(2), // Date
            },
            data: lots.map((lot) {
              final lotCode = lot['lot_code'] ?? '';
              final variety = lot['variety_name'] ?? '';
              final location = lot['location_name'] ?? '';
              final qty = lot['on_hand']?.toString() ?? '0';
              final updatedRaw = lot['updated_at'];
              DateTime? updated = updatedRaw is String
                  ? DateTime.tryParse(updatedRaw)
                  : updatedRaw as DateTime?;
              final updatedTxt =
                  updated != null ? formatReiwa(updated.toLocal()) : '';

              return [
                lotCode.toString(),
                variety.toString(),
                location.toString(),
                qty,
                updatedTxt,
              ];
            }).toList(),
          )
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: "lot_report.pdf",
    );
  }

  Future<void> _openFilterDialog() async {
    final varieties = await SupaService.i.varieties(); // [{id,name}]
    final locations = await SupaService.i.locations(); // [{id,name}]

    String? selVar = _filterVariety;
    String? selLoc = _filterLocation;
    bool includeZeroTmp = _includeZero;

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('絞り込み'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 品種選択
            DropdownButtonFormField<String>(
              value: selVar,
              decoration: const InputDecoration(labelText: '品種'),
              items: [
                const DropdownMenuItem(value: null, child: Text('（すべて）')),
                ...varieties.map((v) => DropdownMenuItem(
                      value: v['name'].toString(),
                      child: Text(v['name'].toString()),
                    )),
              ],
              onChanged: (v) => selVar = v,
            ),
            const SizedBox(height: 8),

            // 場所選択
            DropdownButtonFormField<String>(
              value: selLoc,
              decoration: const InputDecoration(labelText: '場所'),
              items: [
                const DropdownMenuItem(value: null, child: Text('（すべて）')),
                ...locations.map((l) => DropdownMenuItem(
                      value: l['name'].toString(),
                      child: Text(l['name'].toString()),
                    )),
              ],
              onChanged: (v) => selLoc = v,
            ),
            const SizedBox(height: 8),

            // 在庫ゼロを含めるチェック
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: includeZeroTmp,
              onChanged: (v) => includeZeroTmp = v ?? false,
              title: const Text('在庫0を含める'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              final prevExcludeZero = _excludeZero;
              setState(() {
                _filterVariety = selVar;
                _filterLocation = selLoc;
                _includeZero = includeZeroTmp;
                _excludeZero = !includeZeroTmp;
              });
              if (prevExcludeZero != _excludeZero) {
                _refresh(); // DBから再取得
              } else {
                setState(
                    () => _filteredRows = _applyFiltersAndSearch(_allRows));
              }
            },
            child: const Text('適用'),
          ),
        ],
      ),
    );
  }

  void _showQuantityDialog(Map<String, dynamic> row, {required bool isIn}) {
    final qtyCtrl = TextEditingController();
    final lotId = (row['lot_id'] as num?)?.toInt();
    final locationId = (row['location_id'] as num?)?.toInt();
    final lotCode = (row['lot_code'] ?? '').toString();

    if (lotId == null || locationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('このロットのID/場所が取得できませんでした')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: isIn ? const Text('入庫') : const Text('出庫'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('ロット: $lotCode'),
              const SizedBox(height: 12),
              TextField(
                controller: qtyCtrl,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: false,
                  decimal: false,
                ),
                decoration: const InputDecoration(
                  labelText: '数量',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('キャンセル'),
            ),
            ElevatedButton.icon(
              icon: isIn ? const Icon(Icons.north) : const Icon(Icons.south),
              label: isIn ? const Text('入庫') : const Text('出庫'),
              onPressed: () async {
                final q = int.tryParse(qtyCtrl.text);
                if (q == null || q <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('正しい数量を入力してください')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                try {
                  await SupaService.i.insertMove(
                    lotId: lotId,
                    delta: isIn ? q : -q, // 入庫はプラス、出庫はマイナス
                    locationId: locationId, // ← 必須
                  );
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$q ${isIn ? '入庫' : '出庫'}しました')),
                  );
                  await _refresh(); // 一覧更新
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${isIn ? '入庫' : '出庫'}失敗: $e')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }
}

// 和暦フォーマッタ
String formatReiwa(DateTime dt) {
  final y = dt.year;
  if (y >= 2019) {
    final r = y - 2018; // 2019 = 令和1
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return 'r$r/${dt.month}/${dt.day} $h:$m';
  }
  // 令和以前は西暦
  return DateFormat('yyyy/MM/dd HH:mm').format(dt);
}

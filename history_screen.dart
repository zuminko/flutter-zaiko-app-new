import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'supabase_service.dart';
import 'package:csv/csv.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _rows = [];
  bool _descending = true;
  String? _filterVariety; // 状態変数: 品種フィルター
  String? _filterLocation; // 状態変数: 場所フィルター
  String? _filterDirection; // 状態変数: 方向フィルター
  String _searchQuery = '';
  int _offset = 0;
  final int _limit = 50;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // initStateでcontext依存の処理を避けるため、フレーム後に実行
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh();
    });
    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Reverted filtering logic to focus on memo and lot_code search
  List<Map<String, dynamic>> get _searchedRows {
    if (_searchQuery.isEmpty) return _rows;
    return _rows.where((r) {
      final memo = (r['memo'] ?? '').toString().toLowerCase();
      final lot = (r['lot_code'] ?? '').toString().toLowerCase();
      return memo.contains(_searchQuery.toLowerCase()) ||
          lot.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await SupaService.i.fetchHistory(
        limit: 50,
        descending: true,
        varieties: _filterVariety?.split(","),
        locations: _filterLocation?.split(","),
        directions: _filterDirection?.split(","),
      );

      if (!mounted) return;
      setState(() => _rows = data);
    } on PostgrestException catch (e) {
      if (e.message.contains("function") && e.message.contains("not found")) {
        debugPrint("⚠️ Function not found: ${e.message}");
        _showError("サーバー関数が見つかりません。アプリの更新が必要です。");
      } else {
        _showError("Supabaseエラー: ${e.message}");
      }
    } on SocketException {
      _showError("ネットワークに接続できません。オフラインです。");
    } catch (e, st) {
      debugPrint("Unexpected error: $e\n$st");
      _showError("不明なエラーが発生しました");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    setState(() => _error = msg);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  Future<void> _loadMore() async {
    if (_loading) return;

    setState(() => _loading = true);

    try {
      final data = await SupaService.i.fetchHistory(
        limit: _limit,
        offset: _offset + _rows.length,
        descending: _descending,
        varieties: _filterVariety?.split(","),
        locations: _filterLocation?.split(","),
        directions: _filterDirection?.split(","),
      );
      if (!mounted) return;
      setState(() => _rows.addAll(data));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('追加読み込みに失敗: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('履歴'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: '再読込',
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: '絞り込み',
            onPressed: () async {
              final varieties = await SupaService.i.varieties();
              final locations = await SupaService.i.locations();

              final selectedFilters =
                  await showDialog<Map<String, List<String>>>(
                context: context,
                builder: (context) {
                  final selectedVarieties = Set<String>();
                  final selectedLocations = Set<String>();
                  final selectedDirections = Set<String>();

                  return StatefulBuilder(
                    builder: (context, setState) {
                      return AlertDialog(
                        title: const Text('絞り込み'),
                        content: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('品種'),
                              ...varieties.map((v) => CheckboxListTile(
                                    title: Text(v['name']),
                                    value:
                                        selectedVarieties.contains(v['name']),
                                    onChanged: (checked) {
                                      setState(() {
                                        if (checked == true) {
                                          selectedVarieties.add(v['name']);
                                        } else {
                                          selectedVarieties.remove(v['name']);
                                        }
                                      });
                                    },
                                  )),
                              const Divider(),
                              const Text('場所'),
                              ...locations.map((loc) => CheckboxListTile(
                                    title: Text(loc['name']),
                                    value:
                                        selectedLocations.contains(loc['name']),
                                    onChanged: (checked) {
                                      setState(() {
                                        if (checked == true) {
                                          selectedLocations.add(loc['name']);
                                        } else {
                                          selectedLocations.remove(loc['name']);
                                        }
                                      });
                                    },
                                  )),
                              const Divider(),
                              const Text('方向'),
                              CheckboxListTile(
                                title: const Text('入庫のみ'),
                                value: selectedDirections.contains('IN'),
                                onChanged: (checked) {
                                  setState(() {
                                    if (checked == true) {
                                      selectedDirections.add('IN');
                                    } else {
                                      selectedDirections.remove('IN');
                                    }
                                  });
                                },
                              ),
                              CheckboxListTile(
                                title: const Text('出庫のみ'),
                                value: selectedDirections.contains('OUT'),
                                onChanged: (checked) {
                                  setState(() {
                                    if (checked == true) {
                                      selectedDirections.add('OUT');
                                    } else {
                                      selectedDirections.remove('OUT');
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('キャンセル'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop({
                              'varieties': selectedVarieties.toList(),
                              'locations': selectedLocations.toList(),
                              'directions': selectedDirections.toList(),
                            }),
                            child: const Text('適用'),
                          ),
                        ],
                      );
                    },
                  );
                },
              );

              if (selectedFilters == null) return;

              setState(() {
                _filterVariety = selectedFilters['varieties']?.join(',');
                _filterLocation = selectedFilters['locations']?.join(',');
                _filterDirection = selectedFilters['directions']?.join(',');
              });

              _refresh();
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'pdf') {
                await exportHistoryToPdf(_rows); // PDF出力
              } else if (value == 'csv') {
                await exportHistoryToCsv(_rows); // CSV出力
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'pdf',
                child: Text('PDF出力'),
              ),
              const PopupMenuItem(
                value: 'csv',
                child: Text('帳票出力'),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50.0),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'メモやロットコードで検索',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _rows.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('読み込みエラー\n\n$_error'),
        ),
      );
    }
    if (_searchedRows.isEmpty) {
      return const Center(child: Text('履歴はまだありません'));
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: _searchedRows.length + 1,
      itemBuilder: (context, i) {
        if (i == _searchedRows.length) {
          return _loading
              ? const Center(child: CircularProgressIndicator())
              : const SizedBox.shrink();
        }

        final r = _searchedRows[i];
        final createdAtStr = (r['created_at'] ?? '').toString();
        final createdAt = DateTime.tryParse(createdAtStr);
        final ts = createdAt != null ? formatReiwa(createdAt) : createdAtStr;

        return ListTile(
          leading: Icon(
            r['direction'] == 'IN' ? Icons.arrow_upward : Icons.arrow_downward,
            color: r['direction'] == 'IN' ? Colors.green : Colors.red,
            size: 28,
          ),
          title: Text(
            '${r['variety_name'] ?? '不明'}（${r['location_name'] ?? '未設定'}）',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (r['memo'] != null && r['memo'].toString().isNotEmpty)
                Text(
                  'メモ: ${r['memo']}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
          trailing: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${r['qty']} ${r['unit']}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.black,
                ),
              ),
              Text(
                ts,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        );
      },
    );
  }
}

Future<void> exportHistoryToPdf(List<Map<String, dynamic>> rows) async {
  final font = await PdfGoogleFonts.notoSansJPRegular();

  final pdf = pw.Document();
  pdf.addPage(
    pw.Page(
      build: (context) => pw.Column(
        children: rows.map((r) {
          final dt = DateTime.tryParse(r['created_at'] ?? '')?.toLocal();
          final updated = dt != null ? formatReiwa(dt) : '';
          return pw.Text(
            '${updated} ${r['direction']} ${r['qty']} ${r['variety_name']} ${r['location_name']} ${r['memo'] ?? ''}',
            style: pw.TextStyle(font: font, fontSize: 10),
          );
        }).toList(),
      ),
    ),
  );

  await Printing.sharePdf(
    bytes: await pdf.save(),
    filename: "history_report.pdf",
  );
}

Future<void> exportHistoryToCsv(List<Map<String, dynamic>> rows) async {
  if (rows.isEmpty) {
    print("履歴データなし");
    return;
  }

  final csv = const ListToCsvConverter().convert([
    ['日時', '方向', '数量', '品種', '場所', 'メモ'],
    ...rows.map((r) {
      final dt = DateTime.tryParse(r['created_at'] ?? '')?.toLocal();
      return [
        dt != null ? formatReiwa(dt) : '',
        r['direction'] ?? '',
        r['qty'].toString(),
        r['variety_name'] ?? '',
        r['location_name'] ?? '',
        r['memo'] ?? '',
      ];
    }),
  ]);

  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/history_report.csv');
  await file.writeAsString(csv, encoding: utf8);

  print("CSV saved at: \\${file.path}");

  await Share.shareXFiles(
    [XFile(file.path, mimeType: 'text/csv')],
    text: '入出庫履歴CSVを出力しました',
  );
}

String formatReiwa(DateTime dateTime) {
  final year = dateTime.year;
  final reiwaYear = year - 2018; // 2019年=令和元年
  final month = dateTime.month.toString().padLeft(2, '0');
  final day = dateTime.day.toString().padLeft(2, '0');
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return 'r$reiwaYear/$month/$day $hour:$minute';
}

// 履歴の1件表示（ListTile 例）
ListTile buildHistoryTile(Map<String, dynamic> move) {
  return ListTile(
    leading: Icon(
      move['direction'] == 'IN' ? Icons.arrow_upward : Icons.arrow_downward,
      color: move['direction'] == 'IN' ? Colors.green : Colors.red,
    ),
    title: Text(
      '${move['qty']} ${move['unit']} - ${move['variety_name']}',
      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
    ),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('場所: ${move['location_name']} / ロット: ${move['lot_code']}'),
        if (move['memo'] != null && move['memo'].isNotEmpty)
          Text('メモ: ${move['memo']}'),
        Text(formatReiwa(DateTime.parse(move['created_at']))),
      ],
    ),
  );
}

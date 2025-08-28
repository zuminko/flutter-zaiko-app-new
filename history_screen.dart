import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'supabase_service.dart';
import 'utils/date_format.dart';
import 'package:csv/csv.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';

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
  List<Map<String, dynamic>> get _filteredRows =>
      _descending ? _rows : List.from(_rows.reversed);

  @override
  void initState() {
    super.initState();
    // initStateでcontext依存の処理を避けるため、フレーム後に実行
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh();
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data =
          await SupaService.i.fetchHistory(limit: 50, descending: true);
      if (!mounted) return;
      setState(() => _rows = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('履歴の取得に失敗: $e')),
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.picture_as_pdf),
            onSelected: (value) async {
              final rows = _rows; // 今画面にある履歴データ
              if (rows.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('出力できる履歴がありません')),
                );
                return;
              }
              if (value == 'pdf') {
                await exportHistoryToPdf(rows);
              } else if (value == 'csv') {
                await exportHistoryToCsv(rows);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'pdf', child: Text('履歴PDF出力')),
              const PopupMenuItem(value: 'csv', child: Text('履歴CSV出力')),
            ],
          ),
          IconButton(
            tooltip: '並べ替え',
            icon: Icon(_descending ? Icons.arrow_downward : Icons.arrow_upward),
            onPressed: () {
              setState(() => _descending = !_descending);
              _refresh();
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('読み込みエラー\n\n\$_error'),
        ),
      );
    }
    if (_rows.isEmpty) {
      return const Center(child: Text('履歴はまだありません'));
    }

    return ListView.separated(
      itemCount: _filteredRows.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final r = _filteredRows[i];

        final createdAtStr = (r['created_at'] ?? '').toString();
        final createdAt = DateTime.tryParse(createdAtStr);
        final ts = createdAt != null
            ? DateFormat('yyyy/MM/dd HH:mm').format(createdAt)
            : createdAtStr;

        final direction = (r['direction'] ?? '').toString();
        final sign = direction == 'OUT' ? '-' : '+';
        final qty = r['qty'] ?? r['quantity'] ?? 0;
        final unit = (r['unit'] ?? '').toString();

        final variety = (r['variety_name'] ?? r['variety'] ?? '').toString();
        final field = (r['field_name'] ?? r['location_name'] ?? '').toString();
        final memo = (r['memo'] ?? r['note'] ?? r['remarks'] ?? '').toString();

        final title = [
          if (variety.isNotEmpty) variety,
          if (field.isNotEmpty) ' / $field',
        ].join();

        final subtitlePieces = <String>[ts];
        if (memo.isNotEmpty) subtitlePieces.add('メモ: $memo');
        final subtitle = subtitlePieces.join('    ');

        return ListTile(
          leading: Text(
            sign,
            style: TextStyle(
              fontSize: 20,
              color: direction == 'OUT' ? Colors.red : Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
          title: Text(title.isEmpty ? 'ロットID: ${r['lot_id']}' : title),
          subtitle: Text(subtitle),
          trailing: Text(
            '${qty.toString()} ${unit.toString()}',
            style: const TextStyle(fontWeight: FontWeight.bold),
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

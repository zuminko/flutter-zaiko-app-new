import 'dart:io';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

/// 共通：和暦フォーマット
String formatReiwa(DateTime dt) {
  final y = dt.year;
  if (y >= 2019) {
    final r = y - 2018; // 2019=令和1
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return 'r$r/${dt.month}/${dt.day} $h:$m';
  }
  return DateFormat('yyyy/MM/dd HH:mm').format(dt);
}

/// 複数ロットをQR付きでPDF出力
Future<void> exportQrPdf(List<Map<String, dynamic>> lots) async {
  final pdf = pw.Document();

  pdf.addPage(
    pw.MultiPage(
      build: (context) => [
        pw.Wrap(
          spacing: 20,
          runSpacing: 20,
          children: lots.map((lot) {
            final lotCode = lot['lot_code'].toString();
            final variety = lot['variety_name'] ?? '';
            final location = lot['location_name'] ?? '';
            final date = lot['updated_at']?.toString() ?? '';

            return pw.Column(
              children: [
                pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: lotCode,
                  width: 80,
                  height: 80,
                ),
                pw.Text(lotCode, style: const pw.TextStyle(fontSize: 10)),
                pw.Text(variety, style: const pw.TextStyle(fontSize: 8)),
                pw.Text(location, style: const pw.TextStyle(fontSize: 8)),
                pw.Text(date, style: const pw.TextStyle(fontSize: 8)),
              ],
            );
          }).toList(),
        )
      ],
    ),
  );

  await Printing.sharePdf(
    bytes: await pdf.save(),
    filename: "lot_qr_codes.pdf",
  );
}

/// 複数ロットをCSV出力
Future<void> exportLotsCsv(List<Map<String, dynamic>> lots) async {
  if (lots.isEmpty) {
    return;
  }

  final rows = [
    ['lot_code', 'variety_name', 'location_name', 'updated_at', 'on_hand'],
    ...lots.map((lot) => [
          lot['lot_code'] ?? '',
          lot['variety_name'] ?? '',
          lot['location_name'] ?? '',
          lot['updated_at'] ?? '',
          lot['on_hand'] ?? '',
        ]),
  ];

  final csv = const ListToCsvConverter().convert(rows);

  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/lots.csv');
  await file.writeAsString(csv, encoding: utf8);

  await Share.shareXFiles([XFile(file.path)], text: '在庫一覧CSVを出力しました');
}

/// 帳票（テーブル形式）
Future<void> exportQrPdfTable(List<Map<String, dynamic>> lots) async {
  final pdf = pw.Document();

  pdf.addPage(
    pw.MultiPage(
      build: (context) => [
        pw.Table.fromTextArray(
          headers: ["Lot Code", "Variety", "Location", "Qty", "Updated"],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          cellStyle: const pw.TextStyle(fontSize: 10),
          columnWidths: {
            0: const pw.FixedColumnWidth(80), // Lot
            1: const pw.FixedColumnWidth(120), // Variety
            2: const pw.FixedColumnWidth(120), // Location
            3: const pw.FixedColumnWidth(40), // Qty
            4: const pw.FixedColumnWidth(100), // Date
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

/// ラベル（QR＋品種・場所付き）
Future<void> exportQrPdfLabels(List<Map<String, dynamic>> lots) async {
  final pdf = pw.Document();

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
                    style: const pw.TextStyle(fontSize: 10)),
                pw.Text(variety.toString(),
                    style: const pw.TextStyle(fontSize: 9)),
                pw.Text(location.toString(),
                    style: const pw.TextStyle(fontSize: 9)),
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

Future<void> exportHistoryToPdf(List<Map<String, dynamic>> rows) async {
  final font = await PdfGoogleFonts.notoSansJPRegular();

  final pdf = pw.Document();
  pdf.addPage(
    pw.Page(
      build: (context) => pw.Text(
        "こんにちは世界",
        style: pw.TextStyle(font: font),
      ),
    ),
  );

  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/history_report.pdf');
  await file.writeAsBytes(await pdf.save());

  await Share.shareXFiles([XFile(file.path)], text: '入出庫履歴レポート');
}

Future<void> exportHistoryToCsv(List<Map<String, dynamic>> rows) async {
  final csv = const ListToCsvConverter().convert([
    ['日時', '方向', '数量', '品種', '場所', 'メモ'],
    ...rows.map((r) {
      final dt = DateTime.parse(r['created_at']).toLocal();
      return [
        formatReiwa(dt),
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
  await file.writeAsString(csv);

  await Share.shareXFiles([XFile(file.path)], text: '入出庫履歴CSV');
}

Future<void> generatePdf() async {
  final font = await PdfGoogleFonts.notoSansJPRegular();

  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      build: (context) => pw.Column(
        children: [
          pw.Text(
            'とちあいか（日光農園）',
            style: pw.TextStyle(font: font, fontSize: 18),
          ),
          pw.Text(
            '在庫一覧テスト',
            style: pw.TextStyle(font: font, fontSize: 14),
          ),
        ],
      ),
    ),
  );

  // Save or share the PDF as needed
}

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QrDisplayScreen extends StatelessWidget {
  final String lotCode;
  final String varietyName;
  final String locationName;

  const QrDisplayScreen({
    super.key,
    required this.lotCode,
    required this.varietyName,
    required this.locationName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("QRコード表示")),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 🔼 ロットコードを上に表示
            Text(
              "ロットコード: $lotCode",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // QRコード本体
            QrImageView(
              data: lotCode,
              version: QrVersions.auto,
              size: 200,
            ),
            const SizedBox(height: 16),

            // 🔽 品種名と場所名を下に表示
            Text(
              "品種: $varietyName",
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              "場所: $locationName",
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

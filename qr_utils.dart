import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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
  await WidgetsBinding.instance.endOfFrame;
  final boundary =
      key.currentContext!.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return;

  final image = await boundary.toImage(pixelRatio: 3.0);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  final pngBytes = byteData!.buffer.asUint8List();

  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$lotCode.png');
  await file.writeAsBytes(pngBytes);

  await Share.shareXFiles([XFile(file.path)], text: "ロット $lotCode のQRコード");
}

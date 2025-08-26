// lib/scan_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// QR/バーコード読み取り → 呼び出し元へ String を返す
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    // QR中心なら絞った方が誤検出が減る
    formats: const [BarcodeFormat.qrCode],
    // v3系: 検出の重複をSDK側で減らす
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _handled = false; // ポップ重複防止

  // --- Lifecycle: カメラの開始/停止を適切に
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose(); // ← stopだけでなくdisposeまで
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // バックグラウンドで停止、復帰で再開（端末節電＆クラッシュ回避）
    if (state == AppLifecycleState.paused) {
      _controller.stop();
    } else if (state == AppLifecycleState.resumed) {
      _controller.start();
    }
  }

  // Hot-reload時の再起動（Androidでカメラが止まる事がある対策）
  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      _controller.stop();
    }
    _controller.start();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled) return;
    final code =
        capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue : null;
    if (code == null || code.isEmpty) return;

    _handled = true;
    HapticFeedback.lightImpact(); // 触覚で分かりやすく
    try {
      await _controller.stop();
    } catch (_) {/* ignore */}
    if (!mounted) return;
    Navigator.of(context).pop(code); // 結果を返して閉じる
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QRスキャン'),
        actions: [
          IconButton(
            tooltip: 'ライト',
            icon: const Icon(Icons.flash_on),
            onPressed: () async {
              try {
                await _controller.toggleTorch();
              } catch (_) {}
            },
          ),
          IconButton(
            tooltip: 'カメラ切替',
            icon: const Icon(Icons.cameraswitch),
            onPressed: () async {
              try {
                await _controller.switchCamera();
              } catch (_) {}
            },
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            fit: BoxFit.cover,
            errorBuilder: (context, error) {
              return Center(
                child: Text(
                  'カメラにアクセスできません。\n${error.toString()}',
                  textAlign: TextAlign.center,
                ),
              );
            },
          ),
          // 画面中央のスキャンガイド（枠）
          IgnorePointer(
            child: Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.7,
                height: MediaQuery.of(context).size.width * 0.7,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white70, width: 3),
                  boxShadow: const [
                    BoxShadow(color: Colors.black45, blurRadius: 8),
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

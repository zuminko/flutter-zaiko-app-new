// lib/widgets/lot_code_qr_widget.dart
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class LotCodeQrWidget extends StatelessWidget {
  final String lotCode;
  const LotCodeQrWidget({super.key, required this.lotCode});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: QrImageView(
        data: lotCode,
        version: QrVersions.auto,
        size: 200.0,
      ),
    );
  }
}

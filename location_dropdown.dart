// lib/widgets/location_dropdown.dart
import 'package:flutter/material.dart';
import '../supabase_service.dart';

/// ロケーション（倉庫など）を選ぶドロップダウン
/// onChanged に選択された location_id を返す
class LocationDropdown extends StatefulWidget {
  final int? initialLocationId;
  final ValueChanged<int> onChanged;
  const LocationDropdown(
      {super.key, this.initialLocationId, required this.onChanged});

  @override
  State<LocationDropdown> createState() => _LocationDropdownState();
}

class _LocationDropdownState extends State<LocationDropdown> {
  int? _selectedId;
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = SupaService.i.locations(); // ← SupaService に定義済み
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox(
              height: 56, child: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError || !(snap.hasData)) {
          return const Text('場所の読み込みに失敗しました');
        }
        final rows = snap.data!;
        _selectedId ??= widget.initialLocationId ??
            (rows.isNotEmpty ? (rows.first['id'] as num).toInt() : null);
        return DropdownButtonFormField<int>(
          value: _selectedId,
          items: rows
              .map((e) => DropdownMenuItem<int>(
                    value: (e['id'] as num).toInt(),
                    child: Text((e['name'] ?? '不明').toString()),
                  ))
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            setState(() => _selectedId = v);
            widget.onChanged(v);
          },
          decoration: const InputDecoration(labelText: '場所'),
        );
      },
    );
  }
}

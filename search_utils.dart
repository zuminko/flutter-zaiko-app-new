// lib/utils/search_utils.dart
import 'package:kana_kit/kana_kit.dart';

final _kana = const KanaKit();

String normalize(String s) => _kana.toHiragana(s.trim().toLowerCase());

bool matchesLoose(List<String> fields, String query) {
  if (query.trim().isEmpty) return true;
  final tokens =
      normalize(query).split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
  final normFields = fields.map(normalize).toList();
  return tokens.every((t) => normFields.any((f) => f.contains(t)));
}

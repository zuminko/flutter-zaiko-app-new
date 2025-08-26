// lib/utils/date_format.dart
import 'package:intl/intl.dart';

String formatReiwa(DateTime dt) {
  final local = dt.toLocal();
  if (local.isBefore(DateTime(2019, 5, 1))) {
    return DateFormat('yyyy/M/d HH:mm').format(local);
  }
  final r = local.year - 2018;
  final mm = local.month;
  final dd = local.day;
  final hh = local.hour.toString().padLeft(2, '0');
  final mi = local.minute.toString().padLeft(2, '0');
  return 'r$r/$mm/$dd $hh:$mi';
}

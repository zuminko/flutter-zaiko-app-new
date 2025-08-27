// lib/supabase_service.dart
import 'dart:core';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

/// Supabase ラッパー（シングルトン）
class SupaService {
  SupaService._();
  static final SupaService i = SupaService._();
  final SupabaseClient _c = Supabase.instance.client;

  /// デバッグ・ユースケース用: 生クライアント
  SupabaseClient get client => _c;

  // =========================
  // マスタ
  // =========================

  /// マスタ：場所
  Future<List<Map<String, dynamic>>> locations() async {
    try {
      final rows = await _c
          .from('locations')
          .select('id,name')
          .neq('name', '未設定') // 除外
          .order('id');
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (e) {
      throw Exception('場所一覧の取得に失敗しました: $e');
    }
  }

  /// マスタ：品種（is_active = true のみ）
  Future<List<Map<String, dynamic>>> varieties() async {
    try {
      final rows = await _c.from('varieties').select('id,name').order('id');
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (_) {
      // 未整備でもアプリを落とさない
      return <Map<String, dynamic>>[];
    }
  }

  /// 品種（全件：管理画面用）
  Future<List<Map<String, dynamic>>> varietiesAll() async {
    try {
      final rows = await _c.from('varieties').select('id,name').order('id');
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  /// 場所を新規作成
  Future<Map<String, dynamic>> createLocation({
    required String name,
    String type = 'other',
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw Exception('場所名が空です');
    try {
      final inserted = await _c
          .from('locations')
          .insert({'name': trimmed, 'type': type})
          .select('id,name,type')
          .single();
      return Map<String, dynamic>.from(inserted as Map);
    } catch (e) {
      throw Exception('場所の追加に失敗しました: $e');
    }
  }

  /// 場所名/種別を更新
  Future<void> updateLocation({
    required int id,
    required String name,
    String? type,
  }) async {
    final body = <String, dynamic>{'name': name.trim()};
    if (type != null && type.isNotEmpty) body['type'] = type;
    try {
      await _c.from('locations').update(body).eq('id', id);
    } catch (e) {
      throw Exception('場所の更新に失敗しました: $e');
    }
  }

  /// 参照がある場合は削除不可（moves に履歴があればエラー）
  Future<void> deleteLocation(int id) async {
    try {
      final used = await _c
          .from('moves') // ← stock_moves ではなく moves
          .select('id')
          .eq('location_id', id)
          .limit(1)
          .maybeSingle();
      if (used != null) {
        throw Exception('この場所は入出庫履歴があるため削除できません');
      }
      await _c.from('locations').delete().eq('id', id);
    } catch (e) {
      throw Exception('場所の削除に失敗しました: $e');
    }
  }

  // =========================
  // 在庫
  // =========================

  /// 在庫一覧（inventory_view）
  Future<List<Map<String, dynamic>>> fetchInventory({
    int limit = 50,
    int offset = 0,
    bool descending = false,
    bool excludeZero = true,
    String orderBy = 'updated_at',
  }) async {
    var q = _c.from('inventory_view').select(
        'lot_id,lot_code,variety_id,variety_name,location_id,location_name,on_hand,updated_at');

    if (excludeZero) q = q.neq('on_hand', 0);

    final rows = await q
        .order(orderBy, ascending: !descending)
        .range(offset, offset + limit - 1);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  /// 集計ビュー（品種×場所）
  Future<List<Map<String, dynamic>>> fetchInventoryTotals({
    int limit = 200,
    int offset = 0,
    int? varietyId,
    int? locationId,
    bool excludeZero = true,
    String orderBy = 'on_hand',
    bool descending = true,
  }) async {
    var q = _c.from('inventory_totals').select(
        'variety_id,variety_name,location_id,location_name,on_hand,updated_at');
    if (varietyId != null) q = q.eq('variety_id', varietyId);
    if (locationId != null) q = q.eq('location_id', locationId);
    if (excludeZero) q = q.neq('on_hand', 0);

    final rows = await q
        .order(orderBy, ascending: !descending, nullsFirst: false)
        .range(offset, offset + limit - 1);

    return List<Map<String, dynamic>>.from(rows as List);
  }

  /// 入庫（moves へ IN）
  Future<void> moveIn({
    required int lotId,
    required int locationId,
    required num qty,
    required String unit,
    String? memo,
  }) async {
    await addMove(
      lotId: lotId,
      locationId: locationId,
      direction: 'IN',
      qty: qty,
      unit: unit,
      memo: _sanitizeMemo(memo),
    );
  }

  /// 出庫（moves へ OUT）
  Future<void> moveOut({
    required int lotId,
    required int locationId,
    required num qty,
    required String unit,
    String? memo,
  }) async {
    await addMove(
      lotId: lotId,
      locationId: locationId,
      direction: 'OUT',
      qty: qty,
      unit: unit,
      memo: _sanitizeMemo(memo),
    );
  }

  /// 在庫履歴（ビュー）
  Future<List<Map<String, dynamic>>> fetchHistory({
    int limit = 50,
    bool descending = true,
  }) async {
    final rows = await _c
        .from('move_history_view')
        .select(
            'created_at,direction,qty,unit,memo,lot_id,variety_name,location_name')
        .order('created_at', ascending: !descending)
        .limit(limit);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  /// 在庫行（ロット）を削除（在庫が0の時だけ）
  Future<void> deleteLotIfEmpty(int lotId) async {
    try {
      // 合計 on_hand をチェック
      final rows =
          await _c.from('inventory_view').select('on_hand').eq('lot_id', lotId);
      final list = rows as List;
      int sum = 0;
      for (final r in list) {
        final v = r['on_hand'];
        if (v is num) sum += v.toInt();
      }
      if (sum > 0) {
        throw Exception('在庫が残っているため削除できません（先に出庫または調整で0にしてください）');
      }

      // 先に子（moves）を削除 → 親（harvest_lots）を削除
      await _c.from('moves').delete().eq('lot_id', lotId); // ← 修正
      await _c.from('harvest_lots').delete().eq('id', lotId);
    } catch (e) {
      throw Exception('ロット削除に失敗しました: $e');
    }
  }

  /// varietyId & locationId から在庫が多いロットを1件解決
  Future<int?> resolveLotIdByVarietyLocation({
    required int varietyId,
    required int locationId,
  }) async {
    try {
      final row = await _c
          .from('inventory_view')
          .select('lot_id,on_hand')
          .eq('variety_id', varietyId)
          .eq('location_id', locationId)
          .order('on_hand', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null) return null;
      return (row['lot_id'] as num).toInt();
    } catch (e) {
      throw Exception('ロット解決に失敗しました: $e');
    }
  }

  /// lot_code から lot_id を解決
  Future<int?> resolveLotIdByLotCode(String lotCode) async {
    try {
      final res = await _c
          .from('harvest_lots')
          .select('id')
          .eq('lot_code', lotCode.trim().toUpperCase())
          .maybeSingle();
      if (res == null) return null;
      return (res['id'] as num).toInt();
    } catch (e) {
      throw Exception('lotコード解決に失敗: $e');
    }
  }

  /// ロットID → ロットコード
  Future<String?> fetchLotCodeByLotId(int lotId) async {
    final row = await _c
        .from('harvest_lots')
        .select('lot_code')
        .eq('id', lotId)
        .maybeSingle();
    if (row == null) return null;
    final code = row['lot_code'];
    return code is String ? code : code?.toString();
  }

  /// ロットIDで在庫1件
  Future<Map<String, dynamic>?> fetchInventoryByLotId(int lotId) async {
    final row = await _c
        .from('inventory_view')
        .select(
            'lot_id,lot_code,variety_name,location_id,location_name,on_hand,updated_at')
        .eq('lot_id', lotId)
        .maybeSingle();
    if (row == null) return null;
    return Map<String, dynamic>.from(row as Map);
  }

  /// ロットコードで在庫1件
  Future<Map<String, dynamic>?> fetchInventoryByLotCode(String lotCode) async {
    try {
      final rows = await _c
          .from('inventory_view')
          .select()
          .eq('lot_code', lotCode)
          .limit(1);
      if ((rows as List).isNotEmpty) {
        return Map<String, dynamic>.from(rows.first);
      }
      return null;
    } catch (e) {
      throw Exception('ロットコードによる在庫取得に失敗しました: $e');
    }
  }

  // =========================
  // 収穫 → 入庫
  // =========================

  /// 収穫→入庫（harvest_lots に1行追加→直後に IN 追加）
  Future<Map<String, dynamic>> insertHarvestAndIn({
    required int varietyId,
    required int locationId,
    required int cases,
    DateTime? date,
    String? memo,
  }) async {
    try {
      final lot = await _createHarvestLot(
        varietyId: varietyId,
        locationId: locationId,
        cases: 0,
        date: date,
        memo: memo,
      );
      final lotId = (lot['id'] as num).toInt();
      final lotCode = lot['lot_code'] as String;
      await moveIn(
        lotId: lotId,
        locationId: locationId,
        qty: cases,
        unit: 'ケース',
        memo: _sanitizeMemo(memo),
      );
      return {'lot_id': lotId, 'lot_code': lotCode};
    } catch (e) {
      throw Exception('収穫の保存/入庫に失敗しました: $e');
    }
  }

  /// 品種名から id を保証（無ければ varieties に作成）
  Future<int> ensureVariety(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw Exception('品種名が空です');
    }
    try {
      final exist = await _c
          .from('varieties')
          .select('id')
          .eq('name', trimmed)
          .maybeSingle();
      if (exist != null) return (exist['id'] as num).toInt();

      final inserted = await _c
          .from('varieties')
          .insert({'name': trimmed})
          .select('id')
          .single();
      return (inserted['id'] as num).toInt();
    } catch (e) {
      throw Exception('品種IDの確定に失敗しました: $e');
    }
  }

  /// 未使用の品種を削除（harvest_lots に出てこない id を削除）
  Future<void> removeUnusedVarieties() async {
    try {
      final harvestVarieties =
          await _c.from('harvest_lots').select('variety_id');
      final harvestIds = (harvestVarieties as List)
          .map((e) => (e['variety_id'] as num).toInt())
          .toSet();

      final allVarieties = await _c.from('varieties').select('id');
      final varietyIds =
          (allVarieties as List).map((e) => (e['id'] as num).toInt()).toSet();

      final unusedVarieties = varietyIds.difference(harvestIds);
      for (final id in unusedVarieties) {
        await _c.from('varieties').delete().eq('id', id);
      }
    } catch (e) {
      throw Exception('未使用の品種を削除できませんでした: $e');
    }
  }

  // =========================
  // 内部ヘルパー
  // =========================

  /// harvest_lots に1行 INSERT して lot_id/lot_code を返す
  Future<Map<String, dynamic>> _createHarvestLot({
    required int varietyId,
    required int locationId,
    required int cases,
    DateTime? date,
    String? memo,
  }) async {
    final locName = await _getLocationName(locationId) ?? '未設定';
    final d = date ?? DateTime.now();
    final dateStr = _yyyyMmDd(d);
    final lotCode = _generateLotCode();
    try {
      final inserted = await _c
          .from('harvest_lots')
          .insert({
            'date': dateStr,
            'variety_id': varietyId,
            'field': _sanitize(locName),
            'cases': cases,
            'lot_code': lotCode,
            if (memo != null && memo.isNotEmpty) 'memo': _sanitize(memo),
          })
          .select('id, lot_code')
          .single();
      return Map<String, dynamic>.from(inserted as Map);
    } catch (e) {
      throw Exception('収穫データの保存に失敗しました: $e');
    }
  }

  Future<String?> _getLocationName(int locationId) async {
    try {
      final row = await _c
          .from('locations')
          .select('name')
          .eq('id', locationId)
          .limit(1)
          .maybeSingle();
      if (row == null) return null;
      final name = row['name'];
      return name is String ? name : name?.toString();
    } catch (_) {
      return null;
    }
  }

  String _yyyyMmDd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$y-$m-$dd';
  }

  /// 入出庫の登録（メモはNULL文字除去）
  Future<void> addMove({
    required int lotId,
    required int locationId,
    required String direction, // 'IN' or 'OUT'
    required num qty,
    required String unit,
    String? memo,
  }) async {
    final map = <String, dynamic>{
      'lot_id': lotId,
      'location_id': locationId,
      'direction': direction,
      'qty': qty,
      'unit': unit,
      if (memo != null && memo.trim().isNotEmpty) 'memo': _sanitizeMemo(memo),
    };
    await _c.from('moves').insert(map);
  }

  /// A→B へ数量を移動（ OUT@A → IN@B ）
  Future<void> transfer({
    required int lotId,
    required int fromLocationId,
    required int toLocationId,
    required int qty, // ケース数
    String unit = 'ケース',
    String? memo,
  }) async {
    if (qty <= 0) throw Exception('数量は1以上にしてください');
    if (fromLocationId == toLocationId) {
      throw Exception('同じ場所への移動はできません');
    }
    await addMove(
      lotId: lotId,
      direction: 'OUT',
      qty: qty,
      unit: unit,
      memo: _sanitizeMemo(memo),
      locationId: fromLocationId,
    );
    await addMove(
      lotId: lotId,
      direction: 'IN',
      qty: qty,
      unit: unit,
      memo: _sanitizeMemo(memo),
      locationId: toLocationId,
    );
  }

  String? _sanitize(String? s) => s?.replaceAll('\u0000', '');
  String? _sanitizeMemo(String? memo) => memo?.replaceAll('\u0000', '');
  String? sanitize(String? text) => text?.replaceAll('\u0000', '');

  String _generateLotCode({int length = 12}) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random.secure();
    return List.generate(length, (_) => chars[rand.nextInt(chars.length)])
        .join();
  }

  // =========================
  // 便利系・分析
  // =========================

  /// 品種ごとの収穫量推移（variety_id, date, cases）
  Future<List<Map<String, dynamic>>> fetchHarvestTrends() async {
    try {
      final rows = await _c
          .from('harvest_lots')
          .select('variety_id, date, cases')
          .order('date', ascending: true);
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (e) {
      throw Exception('収穫量推移の取得に失敗しました: $e');
    }
  }

  /// 日別収穫サマリ（指定日の合計 cases）
  Future<int> fetchDailyHarvestSummary({required DateTime date}) async {
    try {
      final ymd = _yyyyMmDd(date);
      final result =
          await _c.from('harvest_lots').select('cases').eq('date', ymd);
      final totalCases = (result as List).fold<int>(
        0,
        (sum, row) => sum + ((row['cases'] as num?)?.toInt() ?? 0),
      );
      return totalCases;
    } catch (e) {
      throw Exception('日別収穫サマリの取得に失敗しました: $e');
    }
  }

  /// 収穫データ一覧（編集用）
  Future<List<Map<String, dynamic>>> fetchHarvestRecords() async {
    try {
      final rows = await _c
          .from('harvest_lots')
          .select('id, variety_id, date, cases')
          .order('date', ascending: false);
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (e) {
      throw Exception('収穫データの取得に失敗しました: $e');
    }
  }

  /// 収穫データを更新
  Future<void> updateHarvestRecord({
    required int id,
    required int cases,
  }) async {
    try {
      await _c.from('harvest_lots').update({'cases': cases}).eq('id', id);
    } catch (e) {
      throw Exception('収穫データの更新に失敗しました: $e');
    }
  }

  /// 収穫データを削除
  Future<void> deleteHarvestRecord({required int id}) async {
    try {
      await _c.from('harvest_lots').delete().eq('id', id);
    } catch (e) {
      throw Exception('収穫データの削除に失敗しました: $e');
    }
  }

  /// 現在のユーザーID
  String? get currentUserId => _c.auth.currentUser?.id;

  /// 在庫移動（+入庫 / -出庫）。locationId 必須。
  Future<void> insertMove({
    required int lotId,
    required int delta,
    required int locationId,
  }) async {
    // 出庫時は在庫チェック
    if (delta < 0) {
      final inv = await fetchInventoryByLotId(lotId);
      final currentStock =
          (inv?['on_hand'] is num) ? (inv!['on_hand'] as num).toInt() : 0;
      final requested = -delta;
      if (requested > currentStock) {
        throw Exception('在庫不足: 出庫数量が現在庫($currentStock)を超えています');
      }
    }

    if (delta > 0) {
      await moveIn(
        lotId: lotId,
        locationId: locationId,
        qty: delta,
        unit: 'ケース',
        memo: 'QRスキャン入庫',
      );
    } else if (delta < 0) {
      await moveOut(
        lotId: lotId,
        locationId: locationId,
        qty: -delta,
        unit: 'ケース',
        memo: 'QRスキャン出庫',
      );
    }
  }

  /// 日別の入庫・出庫サマリを取得
  Future<List<Map<String, dynamic>>> fetchDailyInOutSummary() async {
    try {
      final rows = await _c
          .from('moves')
          .select('direction, qty, created_at')
          .order('created_at', ascending: true);

      // Dart側で日付ごとに集計
      final Map<String, Map<String, int>> summary = {};

      for (final row in rows) {
        final dir = row['direction'] as String;
        final qty = (row['qty'] as num).toInt();
        final date = DateTime.parse(row['created_at']).toLocal();
        final dateStr = DateFormat('yyyy-MM-dd').format(date);

        summary.putIfAbsent(dateStr, () => {'IN': 0, 'OUT': 0});
        summary[dateStr]![dir] = (summary[dateStr]![dir] ?? 0) + qty;
      }

      // List<Map> に変換
      return summary.entries.map((e) {
        return {
          'date': DateTime.parse(e.key),
          'inQty': e.value['IN'] ?? 0,
          'outQty': e.value['OUT'] ?? 0,
        };
      }).toList()
        ..sort(
            (a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
    } catch (e) {
      throw Exception('日別入出庫サマリの取得に失敗しました: $e');
    }
  }

  /// 時間帯別の入庫・出庫サマリを取得（モバイル最適化版）
  Future<List<Map<String, dynamic>>> fetchHourlyInOutSummary({
    required DateTime date,
    String? varietyName, // nullなら全品種
    String? locationName, // nullなら全場所
    int startHour = 6,
    int endHour = 24, // 表示上の右端ラベル用（バーの最大は23時）
  }) async {
    try {
      final startUtc = DateTime.utc(date.year, date.month, date.day);
      final endUtc = startUtc.add(const Duration(days: 1));

      var q = _c
          .from('move_history_view')
          .select('created_at,direction,qty,variety_name,location_name')
          .gte('created_at', startUtc.toIso8601String())
          .lt('created_at', endUtc.toIso8601String());

      if (varietyName != null && varietyName.isNotEmpty)
        q = q.eq('variety_name', varietyName);
      if (locationName != null && locationName.isNotEmpty)
        q = q.eq('location_name', locationName);

      final rows = await q.order('created_at', ascending: true);

      final buckets = <int, Map<String, int>>{
        for (var h = startHour; h < 24; h++) h: {'IN': 0, 'OUT': 0}
      };

      for (final r in rows as List) {
        final dt = DateTime.parse(r['created_at'].toString()); // ← サーバはUTC想定
        final h = dt.toLocal().hour;
        if (h >= startHour && h < 24) {
          final dir = (r['direction'] ?? '').toString();
          final qty = (r['qty'] as num?)?.toInt() ?? 0;
          if (dir == 'IN' || dir == 'OUT') {
            buckets[h]![dir] = (buckets[h]![dir] ?? 0) + qty;
          }
        }
      }

      return [
        for (var h = startHour; h < 24; h++)
          {
            'hour': h,
            'in': buckets[h]!['IN'] ?? 0,
            'out': buckets[h]!['OUT'] ?? 0
          }
      ];
    } catch (e) {
      throw Exception('時間帯別サマリ取得に失敗しました: $e');
    }
  }

  /// 月間（日別）サマリ：指定年月
  Future<List<Map<String, dynamic>>> fetchDailyInOutSummaryForMonth({
    required int year,
    required int month,
    String? varietyName,
    String? locationName,
  }) async {
    try {
      final fromUtc = DateTime.utc(year, month, 1);
      final toUtc = DateTime.utc(
          month == 12 ? year + 1 : year, month == 12 ? 1 : month + 1, 1);

      var q = _c
          .from('move_history_view')
          .select('created_at,direction,qty,variety_name,location_name')
          .gte('created_at', fromUtc.toIso8601String())
          .lt('created_at', toUtc.toIso8601String());

      if (varietyName != null && varietyName.isNotEmpty)
        q = q.eq('variety_name', varietyName);
      if (locationName != null && locationName.isNotEmpty)
        q = q.eq('location_name', locationName);

      final rows = await q.order('created_at', ascending: true);

      final daysInMonth = DateTime(year, month + 1, 0).day;
      final list =
          List.generate(daysInMonth, (i) => {'day': i + 1, 'in': 0, 'out': 0});

      for (final r in rows as List) {
        final d = DateTime.parse(r['created_at'].toString()).toLocal().day;
        final dir = (r['direction'] ?? '').toString();
        final qty = (r['qty'] as num?)?.toInt() ?? 0;
        if (dir == 'IN') list[d - 1]['in'] = (list[d - 1]['in'] as int) + qty;
        if (dir == 'OUT')
          list[d - 1]['out'] = (list[d - 1]['out'] as int) + qty;
      }
      return list;
    } catch (e) {
      throw Exception('月間（日別）サマリ取得に失敗しました: $e');
    }
  }

  /// 年間（月別）サマリ：指定年
  Future<List<Map<String, dynamic>>> fetchMonthlyInOutSummaryForYear({
    required int year,
    String? varietyName,
    String? locationName,
  }) async {
    try {
      final fromUtc = DateTime.utc(year, 1, 1);
      final toUtc = DateTime.utc(year + 1, 1, 1);

      var q = _c
          .from('move_history_view')
          .select('created_at,direction,qty,variety_name,location_name')
          .gte('created_at', fromUtc.toIso8601String())
          .lt('created_at', toUtc.toIso8601String());

      if (varietyName != null && varietyName.isNotEmpty)
        q = q.eq('variety_name', varietyName);
      if (locationName != null && locationName.isNotEmpty)
        q = q.eq('location_name', locationName);

      final rows = await q.order('created_at', ascending: true);

      final list =
          List.generate(12, (i) => {'month': i + 1, 'in': 0, 'out': 0});

      for (final r in rows as List) {
        final m = DateTime.parse(r['created_at'].toString()).toLocal().month;
        final dir = (r['direction'] ?? '').toString();
        final qty = (r['qty'] as num?)?.toInt() ?? 0;
        if (dir == 'IN') list[m - 1]['in'] = (list[m - 1]['in'] as int) + qty;
        if (dir == 'OUT')
          list[m - 1]['out'] = (list[m - 1]['out'] as int) + qty;
      }
      return list;
    } catch (e) {
      throw Exception('年間（月別）サマリ取得に失敗しました: $e');
    }
  }

  /// 移動履歴を取得（範囲指定・フィルタリング・ページネーション対応）
  Future<List<Map<String, dynamic>>> fetchMoveHistoryRange({
    DateTime? fromUtc,
    DateTime? toUtc,
    String? varietyName,
    String? locationName,
    String? direction, // 'IN' | 'OUT' | null
    String orderBy = 'created_at',
    bool descending = true,
    int limit = 500,
    int offset = 0,
  }) async {
    var q = _c.from('move_history_view').select(
        'created_at,direction,qty,unit,memo,variety_name,location_name');

    // 先に filter
    if (fromUtc != null) q = q.gte('created_at', fromUtc.toIso8601String());
    if (toUtc != null) q = q.lt('created_at', toUtc.toIso8601String());
    if (varietyName != null && varietyName.isNotEmpty) {
      q = q.eq('variety_name', varietyName);
    }
    if (locationName != null && locationName.isNotEmpty) {
      q = q.eq('location_name', locationName);
    }
    if (direction != null && (direction == 'IN' || direction == 'OUT')) {
      q = q.eq('direction', direction);
    }

    // 最後に order / range → await
    final rows = await q
        .order(orderBy, ascending: !descending)
        .range(offset, offset + limit - 1);

    return List<Map<String, dynamic>>.from(rows as List);
  }
}

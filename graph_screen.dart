import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'supabase_service.dart';

enum GraphRange { day, month, year }

class GraphScreen extends StatefulWidget {
  const GraphScreen({super.key});
  @override
  State<GraphScreen> createState() => _GraphScreenState();
}

class _GraphScreenState extends State<GraphScreen> {
  GraphRange _range = GraphRange.day; // デフォルト：日（時間帯）
  bool _isBarChart = true; // デフォルト：棒
  DateTime _anchor = DateTime.now(); // 基準日/年月/年
  late Future<List<Map<String, dynamic>>> _future;

  // フィルタ
  List<Map<String, dynamic>> _varieties = [];
  List<Map<String, dynamic>> _locations = [];
  String? _selectedVarietyName; // null=すべて
  String? _selectedLocationName; // null=すべて

  @override
  void initState() {
    super.initState();
    _loadMasters();
    _future = _loadData();
  }

  Future<void> _loadMasters() async {
    try {
      final vs = await SupaService.i.varieties();
      final ls = await SupaService.i.locations();
      if (!mounted) return;
      setState(() {
        _varieties = vs;
        _locations = ls;
      });
    } catch (_) {}
  }

  // 修正: fetchHourlyInOutSummary, fetchDailyInOutSummaryForMonth, fetchMonthlyInOutSummaryForYear の呼び出し部分を正しいパラメータ名で更新
  Future<List<Map<String, dynamic>>> _loadData() {
    switch (_range) {
      case GraphRange.day:
        return SupaService.i.fetchHourlyInOutSummary(
          date: _anchor,
          varietyName: _selectedVarietyName,
          locationName: _selectedLocationName,
          startHour: 6,
          endHour: 24,
        );
      case GraphRange.month:
        return SupaService.i.fetchDailyInOutSummaryForMonth(
          year: _anchor.year,
          month: _anchor.month,
          varietyName: _selectedVarietyName,
          locationName: _selectedLocationName,
        );
      case GraphRange.year:
        return SupaService.i.fetchMonthlyInOutSummaryForYear(
          year: _anchor.year,
          varietyName: _selectedVarietyName,
          locationName: _selectedLocationName,
        );
    }
  }

  void _reload() {
    setState(() {
      _future = _loadData();
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _anchor,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked != null) {
      setState(() {
        _anchor = picked;
        _future = _loadData();
      });
    }
  }

  void _prev() {
    setState(() {
      if (_range == GraphRange.day) {
        _anchor = _anchor.subtract(const Duration(days: 1));
      } else if (_range == GraphRange.month) {
        _anchor = DateTime(_anchor.year, _anchor.month - 1, 1);
      } else {
        _anchor = DateTime(_anchor.year - 1, 1, 1);
      }
      _future = _loadData();
    });
  }

  void _next() {
    setState(() {
      if (_range == GraphRange.day) {
        _anchor = _anchor.add(const Duration(days: 1));
      } else if (_range == GraphRange.month) {
        _anchor = DateTime(_anchor.year, _anchor.month + 1, 1);
      } else {
        _anchor = DateTime(_anchor.year + 1, 1, 1);
      }
      _future = _loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_range) {
      GraphRange.day =>
        "${_anchor.year}/${_anchor.month}/${_anchor.day}（6-24時）",
      GraphRange.month => "${_anchor.year}/${_anchor.month}（日別）",
      GraphRange.year => "${_anchor.year} 年（月別）",
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text("データ・グラフ"),
        actions: [
          IconButton(
            tooltip: _isBarChart ? '折れ線に切替' : '棒グラフに切替',
            icon: Icon(_isBarChart ? Icons.show_chart : Icons.bar_chart),
            onPressed: () => setState(() => _isBarChart = !_isBarChart),
          ),
          IconButton(
            tooltip: '日付を選ぶ',
            icon: const Icon(Icons.date_range),
            onPressed: _pickDate,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ChoiceChip(
                    label: const Text('日'),
                    selected: _range == GraphRange.day,
                    onSelected: (_) {
                      _range = GraphRange.day;
                      _reload();
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('月'),
                    selected: _range == GraphRange.month,
                    onSelected: (_) {
                      _range = GraphRange.month;
                      _reload();
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('年'),
                    selected: _range == GraphRange.year,
                    onSelected: (_) {
                      _range = GraphRange.year;
                      _reload();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                      onPressed: _prev, icon: const Icon(Icons.chevron_left)),
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  IconButton(
                      onPressed: _next, icon: const Icon(Icons.chevron_right)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedVarietyName,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: '品種（すべて）'),
                      items: [
                        const DropdownMenuItem<String>(
                            value: null, child: Text('すべて')),
                        ..._varieties.map((v) => DropdownMenuItem<String>(
                              value: v['name'].toString(),
                              child: Text(v['name'].toString()),
                            )),
                      ],
                      onChanged: (v) {
                        _selectedVarietyName = v;
                        _reload();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedLocationName,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: '場所（すべて）'),
                      items: [
                        const DropdownMenuItem<String>(
                            value: null, child: Text('すべて')),
                        ..._locations.map((l) => DropdownMenuItem<String>(
                              value: l['name'].toString(),
                              child: Text(l['name'].toString()),
                            )),
                      ],
                      onChanged: (v) {
                        _selectedLocationName = v;
                        _reload();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.square, color: Colors.blue, size: 14),
                  SizedBox(width: 4),
                  Text('入荷'),
                  SizedBox(width: 16),
                  Icon(Icons.square, color: Colors.red, size: 14),
                  SizedBox(width: 4),
                  Text('出荷'),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _future,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return Center(child: Text('エラー: ${snap.error}'));
                    }
                    final data = snap.data ?? [];
                    if (data.isEmpty) {
                      return const Center(child: Text('データがありません'));
                    }

                    // maxY 自動
                    num maxIn = 0, maxOut = 0;
                    for (final d in data) {
                      final a = (d['in'] as num?) ?? 0;
                      final b = (d['out'] as num?) ?? 0;
                      if (a > maxIn) maxIn = a;
                      if (b > maxOut) maxOut = b;
                    }
                    final maxY = ((maxIn > maxOut ? maxIn : maxOut) * 1.2)
                        .clamp(10, 1e9)
                        .toDouble();

                    // 合計（デバッグ用）
                    final totalIn = data.fold<num>(
                        0, (s, d) => s + ((d['in'] as num?) ?? 0));
                    final totalOut = data.fold<num>(
                        0, (s, d) => s + ((d['out'] as num?) ?? 0));

                    // ✅ ここを Column + Expanded(グラフ) で返す
                    return Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('入荷: $totalIn',
                                style: const TextStyle(color: Colors.blue)),
                            const SizedBox(width: 16),
                            Text('出荷: $totalOut',
                                style: const TextStyle(color: Colors.red)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: _isBarChart
                              ? _buildBarChart(data, maxY)
                              : _buildLineChart(data, maxY),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // === 棒グラフ ===
  Widget _buildBarChart(List<Map<String, dynamic>> data, double maxY) {
    // ====== 月以外（そのまま） ======
    if (_range != GraphRange.month) {
      final isDay = _range == GraphRange.day;

      final groups = <BarChartGroupData>[];
      for (final d in data) {
        final x = isDay
            ? (d['hour'] as int)
            : _range == GraphRange.year
                ? (d['month'] as int)
                : (d['day'] as int);

        final inVal = ((d['in'] ?? 0) as num).toDouble();
        final outVal = ((d['out'] ?? 0) as num).toDouble();

        groups.add(
          BarChartGroupData(
            x: x,
            barRods: [
              BarChartRodData(toY: inVal, color: Colors.blue, width: 7),
              BarChartRodData(toY: outVal, color: Colors.red, width: 7),
            ],
            barsSpace: 3,
          ),
        );
      }

      // 日グラフは 24 を見切れないようダミー棒を追加
      if (_range == GraphRange.day && !groups.any((g) => g.x == 24)) {
        groups.add(
          BarChartGroupData(
            x: 24,
            barRods: [
              BarChartRodData(toY: 0, color: Colors.transparent, width: 0.0001),
              BarChartRodData(toY: 0, color: Colors.transparent, width: 0.0001),
            ],
            barsSpace: 3,
          ),
        );
      }

      return BarChart(
        BarChartData(
          minY: 0,
          maxY: maxY,
          barGroups: groups,
          gridData: FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: _chooseYInterval(maxY),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: _range == GraphRange.day ? 3 : 1,
                getTitlesWidget: (value, meta) {
                  if (_range == GraphRange.day) {
                    final v = value.round();
                    if (v == 24) return const Text('24');
                    if (v >= 6 && v <= 23 && v % 3 == 0) return Text('$v');
                    return const SizedBox.shrink();
                  } else {
                    // year
                    final v = value.toInt();
                    if (v < 1 || v > 12) return const SizedBox.shrink();
                    return Text('$v');
                  }
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final x = group.x;
                final label = _range == GraphRange.day ? '${x}時' : '${x}月';
                final kind = rodIndex == 0 ? '入荷' : '出荷';
                return BarTooltipItem('$label\n$kind: ${rod.toY.toInt()}',
                    const TextStyle(color: Colors.white));
              },
            ),
          ),
        ),
      );
    }

    // ====== 月グラフ（横スクロール対応） ======
    return LayoutBuilder(builder: (context, constraints) {
      final days = data.length; // 1..末日
      const barWidth = 10.0; // 1本の棒幅
      const barsSpace = 3.0; // 入/出の間
      const groupGap = 8.0; // 日ごとの隙間
      final groupWidth = (barWidth * 2) + barsSpace + groupGap;
      final chartWidth =
          math.max(constraints.maxWidth, groupWidth * days + 24); // 24は余白

      final groups = <BarChartGroupData>[];
      for (final d in data) {
        final x = (d['day'] as int);
        final inVal = ((d['in'] ?? 0) as num).toDouble();
        final outVal = ((d['out'] ?? 0) as num).toDouble();

        groups.add(
          BarChartGroupData(
            x: x,
            barsSpace: barsSpace,
            barRods: [
              BarChartRodData(toY: inVal, color: Colors.blue, width: barWidth),
              BarChartRodData(toY: outVal, color: Colors.red, width: barWidth),
            ],
          ),
        );
      }

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: chartWidth,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceBetween,
              minY: 0,
              maxY: maxY,
              barGroups: groups,
              gridData: FlGridData(show: true, drawVerticalLine: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    interval: _chooseYInterval(maxY),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    // ラベル間引き：1,5,10,15,20,25,末日（15日以下なら毎日）
                    getTitlesWidget: (value, meta) {
                      final v = value.toInt();
                      if (v < 1 || v > days) return const SizedBox.shrink();
                      if (days <= 15 ||
                          v == 1 ||
                          v == 5 ||
                          v == 10 ||
                          v == 15 ||
                          v == 20 ||
                          v == 25 ||
                          v == days) {
                        return Text('$v', style: const TextStyle(fontSize: 11));
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                enabled: true,
                handleBuiltInTouches: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final day = group.x;
                    final kind = (rodIndex == 0) ? '入荷' : '出荷';
                    return BarTooltipItem(
                      '${day}日\n$kind: ${rod.toY.toInt()}',
                      const TextStyle(color: Colors.white),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  // === 折れ線グラフ ===
  Widget _buildLineChart(List<Map<String, dynamic>> data, double maxY) {
    final isDay = _range == GraphRange.day;

    final inSpots = <FlSpot>[];
    final outSpots = <FlSpot>[];
    for (final d in data) {
      final x = isDay
          ? ((d['hour'] ?? 0) as int).toDouble()
          : _range == GraphRange.month
              ? ((d['day'] ?? 0) as int).toDouble()
              : ((d['month'] ?? 0) as int).toDouble();
      inSpots.add(FlSpot(x, ((d['in'] ?? 0) as num).toDouble()));
      outSpots.add(FlSpot(x, ((d['out'] ?? 0) as num).toDouble()));
    }

    final minX = _range == GraphRange.day ? 6.0 : 1.0;
    final maxX = _range == GraphRange.day
        ? 24.0 // ← 23 → 24 に
        : _range == GraphRange.month
            ? data.length.toDouble()
            : 12.0;

    return LineChart(
      LineChartData(
        minX: minX,
        maxX: maxX,
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(show: true),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: _chooseYInterval(maxY),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: _range == GraphRange.day ? 3 : 1,
              getTitlesWidget: (value, meta) {
                if (_range == GraphRange.day) {
                  final v = value.round();
                  if (v == 24) return const Text('24');
                  if (v >= 6 && v <= 23 && v % 3 == 0) return Text('$v');
                  return const SizedBox.shrink();
                } else if (_range == GraphRange.month) {
                  final v = value.toInt();
                  if (v <= 0 || v > data.length) return const SizedBox.shrink();
                  return Text('$v');
                } else {
                  final v = value.toInt();
                  if (v < 1 || v > 12) return const SizedBox.shrink();
                  return Text('$v');
                }
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: inSpots,
            isCurved: true,
            color: Colors.blue,
            barWidth: 3,
            dotData: FlDotData(show: false),
          ),
          LineChartBarData(
            spots: outSpots,
            isCurved: true,
            color: Colors.red,
            barWidth: 3,
            dotData: FlDotData(show: false),
          ),
        ],
      ),
    );
  }

  // === 補助: Y軸/日付の間引き ===
  double _chooseYInterval(double maxY) {
    if (maxY <= 20) return 5;
    if (maxY <= 50) return 10;
    if (maxY <= 100) return 20;
    if (maxY <= 500) return 100;
    if (maxY <= 1000) return 200;
    return (maxY / 5).ceilToDouble();
  }
}

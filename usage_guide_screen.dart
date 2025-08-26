import 'package:flutter/material.dart';

/// ------------------------------------------------------------
/// 使い方ガイド（ホーム + 各機能ごとのスライド, すべて1ファイル）
/// ------------------------------------------------------------
/// 使い方：
/// 1) このファイルを lib/usage_guide_screen.dart として追加。
/// 2) ホーム画面（main.dartなど）のメニューに以下を追加：
///    Navigator.push(context,
///      MaterialPageRoute(builder: (_) => const UsageGuideHome()));
/// 3) すべて日本語・初心者向けのやさしい説明。グラフ画面は対象外。
/// ------------------------------------------------------------

// ======================== 共通ウィジェット ========================

class GuidePage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const GuidePage({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 96, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class GuideSlider extends StatefulWidget {
  final String title;
  final List<Widget> pages; // 各機能 5ページ程度

  const GuideSlider({super.key, required this.title, required this.pages});

  @override
  State<GuideSlider> createState() => _GuideSliderState();
}

class _GuideSliderState extends State<GuideSlider> {
  final PageController _controller = PageController();
  int _index = 0;

  void _next() {
    if (_index < widget.pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      Navigator.pop(context); // 最終ページは閉じる
    }
  }

  void _prev() {
    if (_index > 0) {
      _controller.previousPage(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _controller,
              onPageChanged: (i) => setState(() => _index = i),
              children: widget.pages,
            ),
          ),
          const SizedBox(height: 6),
          // ドットインジケータ
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.pages.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                width: _index == i ? 16 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _index == i
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          // ナビゲーションボタン
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _index == 0 ? null : _prev,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('前へ'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _next,
                    icon: Icon(_index < widget.pages.length - 1
                        ? Icons.arrow_forward
                        : Icons.check),
                    label: Text(
                      _index < widget.pages.length - 1 ? '次へ' : '完了',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ======================== 使い方ホーム ========================

class UsageGuideHome extends StatelessWidget {
  const UsageGuideHome({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      _GuideItem(
        title: '収穫入力',
        subtitle: '収穫を記録して在庫に追加',
        icon: Icons.agriculture,
        builder: (_) => const HarvestGuide(),
      ),
      _GuideItem(
        title: '在庫一覧',
        subtitle: '検索・絞り込み・並び替え・出力',
        icon: Icons.inventory,
        builder: (_) => const InventoryGuide(),
      ),
      _GuideItem(
        title: 'QRスキャン',
        subtitle: 'QRで素早く入庫・出庫',
        icon: Icons.qr_code_scanner,
        builder: (_) => const QrGuide(),
      ),
      _GuideItem(
        title: '履歴',
        subtitle: '過去の記録を確認・出力',
        icon: Icons.history,
        builder: (_) => const HistoryGuide(),
      ),
      _GuideItem(
        title: '品種管理',
        subtitle: '品種マスタの追加・編集',
        icon: Icons.category,
        builder: (_) => const VarietyGuide(),
      ),
      _GuideItem(
        title: '場所管理',
        subtitle: '倉庫や圃場などの場所マスタ',
        icon: Icons.place,
        builder: (_) => const LocationGuide(),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('使い方ガイド')),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final it = items[i];
          return ListTile(
            leading: Icon(it.icon, size: 28),
            title: Text(it.title),
            subtitle: Text(it.subtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: it.builder),
            ),
          );
        },
      ),
    );
  }
}

class _GuideItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final WidgetBuilder builder;
  _GuideItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.builder,
  });
}

// ======================== 各機能ガイド（各5ページ） ========================

class HarvestGuide extends StatelessWidget {
  const HarvestGuide({super.key});
  @override
  Widget build(BuildContext context) {
    return GuideSlider(
      title: '収穫入力',
      pages: const [
        GuidePage(
          icon: Icons.agriculture,
          title: '何ができる？',
          description: '収穫した「品種・数量・場所（倉庫/圃場）」を登録します。\n登録すると在庫に自動で反映されます。',
        ),
        GuidePage(
          icon: Icons.list_alt,
          title: '入力項目',
          description:
              '・品種：事前に品種管理で登録\n・場所：場所管理で登録\n・数量：数値のみ（単位は運用に合わせる）\n・メモ：任意で補足を残せます',
        ),
        GuidePage(
          icon: Icons.checklist_rtl,
          title: '登録のコツ',
          description: 'よく使う品種や場所は名称を統一。\n数量は実物の単位（ケース/個/箱）に合わせて入力するとミスが減ります。',
        ),
        GuidePage(
          icon: Icons.qr_code,
          title: '登録後の動き',
          description: '登録が成功すると在庫一覧に反映。\n必要ならQRラベルの印刷や共有もできます（運用に応じて）。',
        ),
        GuidePage(
          icon: Icons.tips_and_updates,
          title: '困ったとき',
          description: '品種/場所が選べない→マスタに追加。\n入力ミス→履歴から調整（入庫/出庫で差し引き）。',
        ),
      ],
    );
  }
}

class InventoryGuide extends StatelessWidget {
  const InventoryGuide({super.key});
  @override
  Widget build(BuildContext context) {
    return GuideSlider(
      title: '在庫一覧',
      pages: const [
        GuidePage(
          icon: Icons.inventory,
          title: '何が見える？',
          description: '現在の在庫を一覧で確認。\n在庫ゼロの扱いは設定で切替可能（絞り込み参照）。',
        ),
        GuidePage(
          icon: Icons.search,
          title: '検索とハイライト',
          description: '上部の検索で「品種・ロット・場所」を横断検索。\n一致部分は黄色で強調表示されます。',
        ),
        GuidePage(
          icon: Icons.filter_list,
          title: '絞り込みと並び替え',
          description: '・品種/場所で絞り込み\n・在庫0を含める/除外\n・数量/更新日/名前などで並び替え',
        ),
        GuidePage(
          icon: Icons.compare_arrows,
          title: '入庫・出庫',
          description: '各カードのボタンから数量を入力して在庫を増減。\nQRスキャンからも同じ操作が可能です。',
        ),
        GuidePage(
          icon: Icons.picture_as_pdf,
          title: 'PDF/CSV 出力',
          description: 'PDF（帳票/QRラベル）やCSVで共有。\nPDF＝見せる用、CSV＝Excel集計用として使い分け。',
        ),
      ],
    );
  }
}

class QrGuide extends StatelessWidget {
  const QrGuide({super.key});
  @override
  Widget build(BuildContext context) {
    return GuideSlider(
      title: 'QRスキャン',
      pages: const [
        GuidePage(
          icon: Icons.qr_code_scanner,
          title: '何ができる？',
          description: 'QRを読み取ってロットを一発指定。\n入庫/出庫ダイアログに進んで素早く登録できます。',
        ),
        GuidePage(
          icon: Icons.lightbulb_outline,
          title: '読み取りのコツ',
          description: 'ピントが合う距離で静止。暗いときはライトをON。\nコードが汚れている場合は印刷し直しを。',
        ),
        GuidePage(
          icon: Icons.qr_code_2,
          title: 'ラベル運用',
          description: '収穫後にQRラベルを印刷して箱に貼付。\n移動や出荷時にスキャンするだけで記録が残ります。',
        ),
        GuidePage(
          icon: Icons.smartphone,
          title: '手動との使い分け',
          description: '現場で素早く→QRスキャン。\nまとめて調整→在庫一覧から手動入力が便利です。',
        ),
        GuidePage(
          icon: Icons.help_outline,
          title: 'うまく読めない？',
          description: '反射や影を避ける/角度を変える。\n最終手段として在庫一覧から検索→手動で操作。',
        ),
      ],
    );
  }
}

class HistoryGuide extends StatelessWidget {
  const HistoryGuide({super.key});
  @override
  Widget build(BuildContext context) {
    return GuideSlider(
      title: '履歴',
      pages: const [
        GuidePage(
          icon: Icons.history,
          title: '何が見える？',
          description: '収穫・入庫・出庫の記録を時系列で確認。\n作業の振り返りや棚卸しチェックに役立ちます。',
        ),
        GuidePage(
          icon: Icons.list_alt,
          title: '項目の意味',
          description: '日時／方向（IN/OUT）／数量／品種／場所／メモ。\n必要な情報だけ簡潔にまとまっています。',
        ),
        GuidePage(
          icon: Icons.tune,
          title: '確認のコツ',
          description: '数量が合わない時は直近の履歴を確認。\n操作ミスに気づいたら在庫側で調整しましょう。',
        ),
        GuidePage(
          icon: Icons.picture_as_pdf,
          title: 'PDF/CSV 出力',
          description: '履歴もPDFやCSVへ出力・共有が可能。\n報告書やExcel分析に活用できます。',
        ),
        GuidePage(
          icon: Icons.tips_and_updates,
          title: 'よくある活用',
          description: '・棚卸し後の差異チェック\n・日次/週次の作業実績の共有\n・問い合わせ対応の根拠資料に',
        ),
      ],
    );
  }
}

class VarietyGuide extends StatelessWidget {
  const VarietyGuide({super.key});
  @override
  Widget build(BuildContext context) {
    return GuideSlider(
      title: '品種管理',
      pages: const [
        GuidePage(
          icon: Icons.category,
          title: '何をする画面？',
          description: '扱う作物の「品種名」を登録・編集します。\n収穫入力で正しい品種を選べるように整備します。',
        ),
        GuidePage(
          icon: Icons.add_box,
          title: '追加・編集・削除',
          description: '新しい品種の追加／名称変更／不要な品種の削除。\n表記ゆれを直すと検索も楽になります。',
        ),
        GuidePage(
          icon: Icons.rule_folder,
          title: '名前の付け方',
          description: '現場で迷わない短い名前に。\nかな/カナ表記を揃えると検索精度が上がります。',
        ),
        GuidePage(
          icon: Icons.link,
          title: '在庫・履歴との関係',
          description: '品種名の変更は一覧/履歴の表記にも反映。\n過去データとの整合性を意識して運用しましょう。',
        ),
        GuidePage(
          icon: Icons.tips_and_updates,
          title: '困ったとき',
          description: '対象が見つからない→品種管理で追加。\n使わなくなったものは削除でスッキリ。',
        ),
      ],
    );
  }
}

class LocationGuide extends StatelessWidget {
  const LocationGuide({super.key});
  @override
  Widget build(BuildContext context) {
    return GuideSlider(
      title: '場所管理',
      pages: const [
        GuidePage(
          icon: Icons.place,
          title: '何をする画面？',
          description: '圃場・倉庫・店舗などの「場所」を登録・編集。\n在庫や収穫の記録と紐づけます。',
        ),
        GuidePage(
          icon: Icons.add_business,
          title: '追加・編集・削除',
          description: '新しい場所の追加／名称変更／不要な場所の削除。\n実態に合わせて整理しておきましょう。',
        ),
        GuidePage(
          icon: Icons.drive_file_rename_outline,
          title: '名前の付け方',
          description: '現場で伝わる呼び名を。例：温室A/倉庫1F/店舗北。\n略称ルールを決めると混乱が減ります。',
        ),
        GuidePage(
          icon: Icons.link,
          title: '在庫・履歴との関係',
          description: '場所名の変更は一覧/履歴にも表示。\nどこで収穫・保管・出荷したか追跡に役立ちます。',
        ),
        GuidePage(
          icon: Icons.tips_and_updates,
          title: '困ったとき',
          description: '選択肢に無い→場所管理で追加。\n似た名前が多い→命名ルールで統一。',
        ),
      ],
    );
  }
}

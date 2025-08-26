import 'package:flutter/material.dart';
import 'inventory_list_screen.dart';
import 'harvest_input_screen.dart';
import 'history_screen.dart';
import 'scan_screen.dart';
import 'manage_varieties_screen.dart';
import 'manage_locations_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ホーム'),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            const Text(
              'いちご在庫管理システム',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            _buildMenuButton(
              context,
              '在庫一覧',
              Icons.inventory,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const InventoryListScreen()),
              ),
            ),
            const SizedBox(height: 15),
            _buildMenuButton(
              context,
              '収穫入力',
              Icons.add_box,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HarvestInputScreen()),
              ),
            ),
            const SizedBox(height: 15),
            _buildMenuButton(
              context,
              'QRスキャン',
              Icons.qr_code_scanner,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ScanScreen()),
              ),
            ),
            const SizedBox(height: 15),
            _buildMenuButton(
              context,
              '履歴',
              Icons.history,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HistoryScreen()),
              ),
            ),
            const SizedBox(height: 15),
            _buildMenuButton(
              context,
              '品種管理',
              Icons.settings,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ManageVarietiesScreen()),
              ),
            ),
            const SizedBox(height: 15),
            _buildMenuButton(
              context,
              '場所管理',
              Icons.location_on,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ManageLocationsScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButton(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 30),
          const SizedBox(width: 20),
          Text(
            title,
            style: const TextStyle(fontSize: 18),
          ),
        ],
      ),
    );
  }
}

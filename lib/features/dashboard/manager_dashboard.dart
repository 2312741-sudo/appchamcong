import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/router.dart';
import '../../core/widgets/store_drawer.dart';

class ManagerDashboard extends ConsumerWidget {
  const ManagerDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4EE),
      appBar: AppBar(
        title: const Text('Dashboard Quản Lý', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1C4E6B),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: const StoreDrawer(),
      body: Column(
        children: [
          const Spacer(),
          Center(
            child: InkWell(
              onTap: () => context.push(AppRoutes.checkIn),
              child: Container(
                width: 160,
                height: 160,
                decoration: const BoxDecoration(
                  color: Color(0xFF1C4E6B),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('CHẤM CÔNG', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                ),
              ),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Truy cập nhanh', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildActionButton(context, Icons.account_balance_wallet, 'Lương của tôi', AppRoutes.salary),
                    _buildActionButton(context, Icons.calendar_today, 'Đăng ký Lịch', AppRoutes.scheduleRegister),
                    _buildActionButton(context, Icons.admin_panel_settings, 'Duyệt Lịch', AppRoutes.scheduleManager),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, IconData icon, String label, String route) {
    return InkWell(
      onTap: () => context.push(route),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1C4E6B).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF1C4E6B), size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A))),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/router.dart';
import '../../core/widgets/store_drawer.dart';
import '../store/providers/store_provider.dart';
import '../attendance/providers/attendance_provider.dart';

class OwnerDashboard extends ConsumerWidget {
  const OwnerDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(storeMembersProvider);
    final pendingAsync = ref.watch(pendingMembersProvider);
    final attendancesAsync = ref.watch(allTodayAttendancesProvider);

    final totalMembers = membersAsync.valueOrNull?.where((m) => m.isActive).length.toString() ?? '0';
    final totalPending = pendingAsync.valueOrNull?.length.toString() ?? '0';
    final workingToday = attendancesAsync.valueOrNull?.where((a) => a.checkOut == null).length.toString() ?? '0';

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: const Text('Dashboard Chủ', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1A1A1A),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: const StoreDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tổng quan', style: TextStyle(color: Colors.white, fontSize: 24)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildStatCard('Tổng nhân viên', totalMembers, Colors.white),
                _buildStatCard('Đang làm hôm nay', workingToday, const Color(0xFF1A6B5A)),
                _buildStatCard('Chờ duyệt', totalPending, const Color(0xFFF5C842)),
              ],
            ),
            const SizedBox(height: 32),
            const Text('Công cụ', style: TextStyle(color: Colors.white, fontSize: 24)),
            const SizedBox(height: 16),
            InkWell(
              onTap: () => context.push(AppRoutes.scheduleManager),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.calendar_month, color: Color(0xFFC8102E), size: 32),
                    SizedBox(width: 16),
                    Text('Duyệt Lịch Làm', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    Spacer(),
                    Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF1A1A1A),
        unselectedItemColor: Colors.grey,
        selectedItemColor: const Color(0xFFC8102E),
        currentIndex: 0,
        onTap: (index) {
          if (index == 1) context.push(AppRoutes.members);
          if (index == 2) context.push(AppRoutes.attendanceTable);
          if (index == 3) context.push(AppRoutes.storeSettings);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Nhân viên'),
          BottomNavigationBarItem(icon: Icon(Icons.table_chart), label: 'Bảng công'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Cài đặt'),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Card(
      color: const Color(0xFF2A2A2A),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: color, fontSize: 32, fontWeight: FontWeight.bold)),
            Text(title, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

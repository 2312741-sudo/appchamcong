import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/router.dart';
import '../../core/widgets/store_drawer.dart';

class EmployeeDashboard extends ConsumerWidget {
  const EmployeeDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Nhân viên', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFC8102E),
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
                  color: Color(0xFFC8102E),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('CHẤM CÔNG', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                ),
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        unselectedItemColor: Colors.grey,
        selectedItemColor: const Color(0xFFC8102E),
        currentIndex: 0,
        onTap: (index) {
          if (index == 1) context.push(AppRoutes.scheduleRegister);
          if (index == 2) context.push(AppRoutes.salary);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'Lịch làm'),
          BottomNavigationBarItem(icon: Icon(Icons.attach_money), label: 'Lương'),
        ],
      ),
    );
  }
}

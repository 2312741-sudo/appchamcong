import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import 'schedule_manager_screen.dart';
import 'schedule_register_screen.dart';

class EmployeeScheduleTab extends ConsumerStatefulWidget {
  const EmployeeScheduleTab({super.key});

  @override
  ConsumerState<EmployeeScheduleTab> createState() =>
      _EmployeeScheduleTabState();
}

class _EmployeeScheduleTabState extends ConsumerState<EmployeeScheduleTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text(
          'Lịch làm việc',
          style: GoogleFonts.beVietnamPro(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: AppColors.primary,
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              labelStyle: GoogleFonts.beVietnamPro(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
              unselectedLabelStyle: GoogleFonts.beVietnamPro(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              tabs: const [
                Tab(
                  icon: Icon(Icons.edit_calendar_rounded, size: 18),
                  text: 'Đăng ký lịch làm',
                ),
                Tab(
                  icon: Icon(Icons.storefront_rounded, size: 18),
                  text: 'Lịch cửa hàng',
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          ScheduleRegisterScreen(showAppBar: false),
          ScheduleManagerScreen(showAppBar: false, isReadOnly: true),
        ],
      ),
    );
  }
}

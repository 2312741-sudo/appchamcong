import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../app/router.dart';
import '../../core/constants/app_colors.dart';
import '../../features/store/providers/store_provider.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/attendance/providers/attendance_provider.dart';

class ManagerDashboard extends ConsumerStatefulWidget {
  const ManagerDashboard({super.key});

  @override
  ConsumerState<ManagerDashboard> createState() => _ManagerDashboardState();
}

class _ManagerDashboardState extends ConsumerState<ManagerDashboard> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUserProvider).value?.id;

    // Kick out if removed
    ref.listen(storeMembersProvider, (prev, next) {
      next.whenData((members) {
        final member = members.where((m) => m.userId == uid).firstOrNull;
        if (member == null) {
          ref.invalidate(userStoresProvider);
          ref.invalidate(currentUserProvider);
          context.go(AppRoutes.splash);
        }
      });
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _ManagerHomeTab(uid: uid ?? ''),
          _ManagerScheduleTab(),
          _ManagerProfileTab(uid: uid ?? ''),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, -4))],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              _MgrNavItem(icon: Icons.home_rounded, label: 'Tổng quan', index: 0, selected: _selectedIndex, onTap: (i) => setState(() => _selectedIndex = i)),
              _MgrNavItem(icon: Icons.calendar_month_rounded, label: 'Lịch làm', index: 1, selected: _selectedIndex, onTap: (i) => setState(() => _selectedIndex = i)),
              _MgrNavItem(icon: Icons.person_rounded, label: 'Hồ sơ', index: 2, selected: _selectedIndex, onTap: (i) => setState(() => _selectedIndex = i)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── HOME TAB ────────────────────────────────────────────────────────────────

class _ManagerHomeTab extends ConsumerWidget {
  final String uid;
  const _ManagerHomeTab({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    final store = ref.watch(currentStoreProvider).value;

    if (store == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final membersAsync = ref.watch(storeMembersProvider);
    final attendancesAsync = ref.watch(allTodayAttendancesProvider);
    final now = DateTime.now();

    final activeCount = membersAsync.valueOrNull?.where((m) => m.isActive).length ?? 0;
    final workingNow = attendancesAsync.valueOrNull?.where((a) => a.checkOut == null).length ?? 0;
    final doneToday = attendancesAsync.valueOrNull?.where((a) => a.checkOut != null).length ?? 0;
    final firstName = (user?.name ?? 'Quản lý').split(' ').last;

    return CustomScrollView(
      slivers: [
        // Header — xanh navy
        SliverToBoxAdapter(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1C4E6B), Color(0xFF0A3247)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${_getGreeting(now.hour)}, $firstName', style: const TextStyle(color: Colors.white70, fontSize: 14, fontFamily: 'BeVietnamPro')),
                              const SizedBox(height: 4),
                              const Text('Quản lý', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, fontFamily: 'BeVietnamPro')),
                            ],
                          ),
                        ),
                        if (store != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.store_rounded, color: Colors.white, size: 14),
                                const SizedBox(width: 6),
                                Text(store.name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'BeVietnamPro')),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(DateFormat('EEEE, dd/MM/yyyy', 'vi').format(now), style: const TextStyle(color: Colors.white60, fontSize: 13, fontFamily: 'BeVietnamPro')),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Chấm công nhanh cho manager
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: GestureDetector(
              onTap: () => context.push(AppRoutes.checkIn),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFC8102E), Color(0xFF8B0000)]),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: const Color(0xFFC8102E).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))],
                ),
                child: const Row(
                  children: [
                    Icon(Icons.fingerprint_rounded, color: Colors.white, size: 36),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Chấm công của tôi', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800, fontFamily: 'BeVietnamPro')),
                          Text('Nhấn để vào/ra ca', style: TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'BeVietnamPro')),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 18),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Stats
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Expanded(child: _MgrStatCard(value: workingNow.toString(), label: 'Đang làm', icon: Icons.work_rounded, color: const Color(0xFF1A6B5A))),
                const SizedBox(width: 12),
                Expanded(child: _MgrStatCard(value: doneToday.toString(), label: 'Đã ra ca', icon: Icons.check_circle_rounded, color: const Color(0xFF1C4E6B))),
                const SizedBox(width: 12),
                Expanded(child: _MgrStatCard(value: activeCount.toString(), label: 'Tổng NV', icon: Icons.people_rounded, color: const Color(0xFF7B1FA2))),
              ],
            ),
          ),
        ),

        // NV đang làm
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Nhân viên đang làm', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, fontFamily: 'BeVietnamPro', color: Color(0xFF1A1A1A))),
                const SizedBox(height: 12),
                attendancesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1C4E6B))),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (atts) {
                    final working = atts.where((a) => a.checkOut == null).take(5).toList();
                    if (working.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                        child: const Center(child: Text('Chưa có ai vào ca', style: TextStyle(color: Colors.grey, fontFamily: 'BeVietnamPro'))),
                      );
                    }
                    return Container(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
                      child: Column(
                        children: working.map((att) {
                          final members = ref.watch(storeMembersProvider).valueOrNull ?? [];
                          final member = members.where((m) => m.userId == att.userId).firstOrNull;
                          final name = member?.name ?? att.userId;
                          final checkInTime = '${att.checkIn.hour.toString().padLeft(2,'0')}:${att.checkIn.minute.toString().padLeft(2,'0')}';
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF1C4E6B).withOpacity(0.15),
                              child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: Color(0xFF1C4E6B), fontWeight: FontWeight.w700, fontFamily: 'BeVietnamPro')),
                            ),
                            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'BeVietnamPro', fontSize: 14)),
                            subtitle: Text('Vào: $checkInTime', style: const TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'BeVietnamPro')),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: const Color(0xFF1A6B5A).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                              child: const Text('Đang làm', style: TextStyle(color: Color(0xFF1A6B5A), fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'BeVietnamPro')),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),

        // Tools
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Công cụ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, fontFamily: 'BeVietnamPro', color: Color(0xFF1A1A1A))),
                const SizedBox(height: 12),
                _MgrToolCard(icon: Icons.admin_panel_settings_rounded, label: 'Duyệt lịch làm', sub: 'Quản lý lịch toàn bộ NV', color: const Color(0xFF1C4E6B), onTap: () => context.push(AppRoutes.scheduleManager)),
                const SizedBox(height: 10),
                _MgrToolCard(icon: Icons.table_chart_rounded, label: 'Bảng chấm công', sub: 'Xem bảng công hôm nay', color: const Color(0xFF1A6B5A), onTap: () => context.push(AppRoutes.attendanceTable)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _getGreeting(int hour) {
    if (hour < 12) return 'Chào buổi sáng';
    if (hour < 18) return 'Chào buổi chiều';
    return 'Chào buổi tối';
  }
}

// ─── SCHEDULE TAB ─────────────────────────────────────────────────────────────

class _ManagerScheduleTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Lịch làm', style: TextStyle(fontWeight: FontWeight.w700, fontFamily: 'BeVietnamPro')),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today_rounded, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => context.push(AppRoutes.scheduleManager),
              icon: const Icon(Icons.edit_calendar_rounded),
              label: const Text('Duyệt & Chỉnh lịch làm', style: TextStyle(fontFamily: 'BeVietnamPro')),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1C4E6B), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.push(AppRoutes.scheduleRegister),
              icon: const Icon(Icons.event_available_rounded),
              label: const Text('Đăng ký lịch của tôi', style: TextStyle(fontFamily: 'BeVietnamPro')),
              style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF1C4E6B), side: const BorderSide(color: Color(0xFF1C4E6B)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── PROFILE TAB ─────────────────────────────────────────────────────────────

class _ManagerProfileTab extends ConsumerWidget {
  final String uid;
  const _ManagerProfileTab({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Hồ sơ', style: TextStyle(fontWeight: FontWeight.w700, fontFamily: 'BeVietnamPro')),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 4))]),
            child: Row(
              children: [
                CircleAvatar(radius: 36, backgroundColor: const Color(0xFF1C4E6B), child: Text((user?.name ?? 'Q')[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800))),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.name ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'BeVietnamPro')),
                      Text(user?.email ?? '', style: const TextStyle(color: Colors.grey, fontSize: 13, fontFamily: 'BeVietnamPro')),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFF1C4E6B).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                        child: const Text('Quản lý', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1C4E6B), fontFamily: 'BeVietnamPro')),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildMenuItem(context, Icons.attach_money_rounded, 'Lương của tôi', const Color(0xFF1A6B5A), () => context.push(AppRoutes.salary)),
          _buildMenuItem(context, Icons.history_rounded, 'Lịch sử chấm công', const Color(0xFF1C4E6B), () => context.push(Uri(path: AppRoutes.attendanceHistory, queryParameters: {'userId': uid}).toString())),
          _buildMenuItem(context, Icons.settings_rounded, 'Cài đặt tài khoản', Colors.grey, () => context.push(AppRoutes.profileSettings)),
          _buildMenuItem(context, Icons.logout_rounded, 'Đăng xuất', Colors.red, () async {
            final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
              title: const Text('Đăng xuất?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Hủy')),
                TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Đăng xuất', style: TextStyle(color: Colors.red))),
              ],
            ));
            if (confirm == true && context.mounted) {
              await ref.read(authRepositoryProvider).signOut();
              context.go(AppRoutes.splash);
            }
          }),
        ],
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))]),
      child: ListTile(
        onTap: onTap,
        leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 22)),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'BeVietnamPro', fontSize: 14)),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
      ),
    );
  }
}

// ─── SHARED WIDGETS ───────────────────────────────────────────────────────────

class _MgrStatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _MgrStatCard({required this.value, required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color, fontFamily: 'BeVietnamPro')),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontFamily: 'BeVietnamPro'), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _MgrToolCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sub;
  final Color color;
  final VoidCallback onTap;

  const _MgrToolCard({required this.icon, required this.label, this.sub, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))]),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 22)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontFamily: 'BeVietnamPro', fontSize: 14)),
              if (sub != null) Text(sub!, style: const TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'BeVietnamPro')),
            ])),
            Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}

class _MgrNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int selected;
  final Function(int) onTap;

  const _MgrNavItem({required this.icon, required this.label, required this.index, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isSelected = index == selected;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(color: isSelected ? const Color(0xFF1C4E6B).withOpacity(0.08) : Colors.transparent, borderRadius: BorderRadius.circular(14)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: isSelected ? const Color(0xFF1C4E6B) : Colors.grey, size: 22),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isSelected ? const Color(0xFF1C4E6B) : Colors.grey, fontFamily: 'BeVietnamPro')),
            ],
          ),
        ),
      ),
    );
  }
}

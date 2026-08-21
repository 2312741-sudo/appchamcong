import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../app/router.dart';
import '../../models/member_model.dart';
import '../../models/attendance_model.dart';
import '../../features/store/providers/store_provider.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/providers/auth_notifier.dart';
import '../../features/attendance/providers/attendance_provider.dart';
import '../../core/widgets/store_drawer.dart';
import '../../core/widgets/notification_bell_icon.dart';
import '../../core/widgets/avatar_widget.dart';
import '../../features/members/screens/members_list_screen.dart';
import '../../features/attendance/screens/attendance_table_screen.dart';

class OwnerDashboard extends ConsumerStatefulWidget {
  const OwnerDashboard({super.key});

  @override
  ConsumerState<OwnerDashboard> createState() => _OwnerDashboardState();
}

class _OwnerDashboardState extends ConsumerState<OwnerDashboard> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Reactive role check: If user role changed to Manager or Employee, auto-navigate
    ref.listen<MemberModel?>(currentMemberProvider, (prev, next) {
      if (next == null) return;
      if (next.status == MemberStatus.pending) {
        context.go(AppRoutes.pendingApproval);
        return;
      }
      if (next.status == MemberStatus.kicked) {
        context.go(AppRoutes.welcome);
        return;
      }
      if (next.isManager) {
        context.go(AppRoutes.managerDashboard);
      } else if (next.isEmployee) {
        context.go(AppRoutes.employeeDashboard);
      }
    });

    return Scaffold(
      drawer: const StoreDrawer(),
      backgroundColor: const Color(0xFFF5F6FA),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _OwnerHomeTab(),
          const MembersListScreen(),
          const AttendanceTableScreen(),
          _OwnerSettingsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.checkIn),
        backgroundColor: const Color(0xFFC8102E),
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.fingerprint_rounded, size: 22),
        label: const Text(
          'Chấm công',
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
          ),
        ),
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
              _OwnerNavItem(icon: Icons.home_rounded, label: 'Tổng quan', index: 0, selected: _selectedIndex, onTap: (i) => setState(() => _selectedIndex = i)),
              _OwnerNavItem(icon: Icons.people_alt_rounded, label: 'Nhân viên', index: 1, selected: _selectedIndex, onTap: (i) => setState(() => _selectedIndex = i)),
              _OwnerNavItem(icon: Icons.table_chart_rounded, label: 'Bảng công', index: 2, selected: _selectedIndex, onTap: (i) => setState(() => _selectedIndex = i)),
              _OwnerNavItem(icon: Icons.settings_rounded, label: 'Cài đặt', index: 3, selected: _selectedIndex, onTap: (i) => setState(() => _selectedIndex = i)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── HOME TAB ────────────────────────────────────────────────────────────────

class _OwnerHomeTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final user = ref.watch(currentUserProvider).value;
    final store = ref.watch(currentStoreProvider).value;

    if (store == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final membersAsync = ref.watch(storeMembersProvider);
    final pendingAsync = ref.watch(pendingMembersProvider);
    final attendancesAsync = ref.watch(allTodayAttendancesProvider);
    final ownerAttendanceAsync = ref.watch(todayAttendanceProvider);

    final activeCount = membersAsync.valueOrNull?.where((m) => m.isActive).length ?? 0;
    final pendingCount = pendingAsync.valueOrNull?.where((m) => m.isActive && m.status == MemberStatus.pending).length ?? (pendingAsync.valueOrNull?.length ?? 0);
    final unclassifiedManagers = membersAsync.valueOrNull?.where((m) => m.isActive && m.isLegacyManager).toList() ?? [];
    final workingNow = attendancesAsync.valueOrNull?.where((a) => a.checkOut == null).length ?? 0;
    final doneToday = attendancesAsync.valueOrNull?.where((a) => a.checkOut != null).length ?? 0;
    final now = DateTime.now();
    final firstName = (user?.name ?? 'Chủ').split(' ').last;

    return CustomScrollView(
      slivers: [
        // Header
        SliverToBoxAdapter(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1A1A1A), Color(0xFF2C2C2C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_getGreeting(now.hour)}, $firstName 👋',
                            style: const TextStyle(color: Colors.white70, fontSize: 14, fontFamily: 'BeVietnamPro'),
                          ),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () => Scaffold.of(context).openDrawer(),
                            child: Row(
                              children: [
                                Text(
                                  store.name,
                                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, fontFamily: 'BeVietnamPro'),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_drop_down, color: Colors.white, size: 24),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            DateFormat('EEEE, dd/MM/yyyy', 'vi').format(now),
                            style: const TextStyle(color: Colors.white38, fontSize: 13, fontFamily: 'BeVietnamPro'),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const NotificationBellIcon(
                          iconColor: Colors.white,
                          backgroundColor: Color(0x26FFFFFF),
                        ),
                        const SizedBox(width: 8),
                        // Store code badge - store is guaranteed non-null here
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFC8102E),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              const Text('Mã cửa hàng', style: TextStyle(color: Colors.white60, fontSize: 10, fontFamily: 'BeVietnamPro')),
                              Text(store.code, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, fontFamily: 'BeVietnamPro', letterSpacing: 2)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Owner's Personal Check-in Status Card
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: ownerAttendanceAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (att) => _OwnerPersonalAttendanceCard(
                attendance: att,
                userId: userId,
              ),
            ),
          ),
        ),

        // Banner: Phân loại Quản lý cũ (Migration Banner)
        if (unclassifiedManagers.isNotEmpty)
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFD54F), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF57F17).withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Color(0xFFE65100), size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Cần phân loại Quản lý (${unclassifiedManagers.length})',
                          style: GoogleFonts.beVietnamPro(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: const Color(0xFFE65100),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Có ${unclassifiedManagers.length} tài khoản Quản lý cũ cần được phân loại lại thành Quản lý 1 hoặc Quản lý 2. Hiện tại họ đang tạm giữ toàn quyền.',
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 12.5,
                      color: const Color(0xFF5D4037),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        context.push(AppRoutes.members);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE65100),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        'Phân loại ngay',
                        style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Stats grid
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Hôm nay', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, fontFamily: 'BeVietnamPro', color: Color(0xFF1A1A1A))),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _StatCard(value: workingNow.toString(), label: 'Đang làm', icon: Icons.work_rounded, color: const Color(0xFF1A6B5A))),
                    const SizedBox(width: 12),
                    Expanded(child: _StatCard(value: doneToday.toString(), label: 'Đã ra ca', icon: Icons.check_circle_rounded, color: const Color(0xFF1C4E6B))),
                    const SizedBox(width: 12),
                    Expanded(child: _StatCard(value: activeCount.toString(), label: 'Tổng NV', icon: Icons.people_rounded, color: const Color(0xFF7B1FA2))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: pendingCount > 0 ? () => GoRouter.of(context).push(AppRoutes.pendingMembers) : null,
                        child: _StatCard(value: pendingCount.toString(), label: 'Chờ duyệt', icon: Icons.pending_rounded, color: const Color(0xFFC8102E), highlight: pendingCount > 0),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Live list — NV đang làm
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(child: Text('Đang làm việc', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, fontFamily: 'BeVietnamPro', color: Color(0xFF1A1A1A)))),
                    TextButton(
                      onPressed: () => GoRouter.of(context).push(AppRoutes.attendanceTable),
                      child: const Text('Xem tất cả', style: TextStyle(color: Color(0xFFC8102E), fontFamily: 'BeVietnamPro')),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                attendancesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFC8102E))),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (atts) {
                    final working = atts.where((a) => a.checkOut == null).take(5).toList();
                    if (working.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                        child: const Center(child: Text('Chưa có ai chấm vào ca', style: TextStyle(color: Colors.grey, fontFamily: 'BeVietnamPro'))),
                      );
                    }
                    return Container(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
                      child: Column(
                        children: working.asMap().entries.map((entry) {
                          final att = entry.value;
                          final members = ref.watch(storeMembersProvider).valueOrNull ?? [];
                          final member = members.where((m) => m.userId == att.userId).firstOrNull;
                          final name = member?.name ?? att.userId;
                          final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
                          final checkInTime = '${att.checkIn.hour.toString().padLeft(2,'0')}:${att.checkIn.minute.toString().padLeft(2,'0')}';
                          return Material(
                            color: Colors.transparent,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFF1A6B5A).withOpacity(0.15),
                                child: Text(initial, style: const TextStyle(color: Color(0xFF1A6B5A), fontWeight: FontWeight.w700, fontFamily: 'BeVietnamPro')),
                              ),
                              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'BeVietnamPro', fontSize: 14)),
                              subtitle: Text('Vào ca: $checkInTime', style: const TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'BeVietnamPro')),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: const Color(0xFF1A6B5A).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                child: const Text('Đang làm', style: TextStyle(color: Color(0xFF1A6B5A), fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'BeVietnamPro')),
                              ),
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

        // Quick tools
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Công cụ quản lý', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, fontFamily: 'BeVietnamPro', color: Color(0xFF1A1A1A))),
                const SizedBox(height: 12),
                _ToolCard(icon: Icons.fingerprint_rounded, label: 'Chấm công của tôi', sub: 'Chấm vào/ra ca nhanh', color: const Color(0xFFC8102E), onTap: () => GoRouter.of(context).push(AppRoutes.checkIn)),
                const SizedBox(height: 10),
                _ToolCard(icon: Icons.calendar_month_rounded, label: 'Quản lý lịch làm', sub: 'Xem & chỉnh lịch toàn bộ NV', color: const Color(0xFF1C4E6B), onTap: () => GoRouter.of(context).push(AppRoutes.scheduleManager)),
                const SizedBox(height: 10),
                _ToolCard(icon: Icons.payments_rounded, label: 'Báo cáo lương', sub: 'Tổng hợp lương tháng', color: const Color(0xFF1A6B5A), onTap: () => GoRouter.of(context).push(AppRoutes.salaryOverview)),
                const SizedBox(height: 10),
                _ToolCard(icon: Icons.account_balance_wallet_rounded, label: 'Duyệt tạm ứng', sub: 'Xem yêu cầu ứng lương', color: const Color(0xFFB8860B), onTap: () => GoRouter.of(context).push(AppRoutes.manageAdvances)),
                const SizedBox(height: 10),
                _ToolCard(icon: Icons.qr_code_rounded, label: 'QR chấm công', sub: 'Chia sẻ mã QR cho NV', color: const Color(0xFF7B1FA2), onTap: () => GoRouter.of(context).push(AppRoutes.qrDisplay)),
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


// ─── SETTINGS TAB ─────────────────────────────────────────────────────────────

class _OwnerSettingsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    final store = ref.watch(currentStoreProvider).value;

    if (store == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Cài đặt', style: TextStyle(fontWeight: FontWeight.w700, fontFamily: 'BeVietnamPro')),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Owner Profile Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)]),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: const Color(0xFFC8102E).withOpacity(0.12),
                  backgroundImage: getAvatarImageProvider(user?.avatarUrl),
                  child: (getAvatarImageProvider(user?.avatarUrl) == null)
                      ? Text((user?.name.isNotEmpty == true) ? user!.name[0].toUpperCase() : '?', style: const TextStyle(color: Color(0xFFC8102E), fontSize: 24, fontWeight: FontWeight.w800, fontFamily: 'BeVietnamPro'))
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.name ?? 'Chủ quán', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, fontFamily: 'BeVietnamPro', color: Color(0xFF1A1A1A))),
                      const SizedBox(height: 4),
                      Text(user?.email ?? '', style: const TextStyle(fontSize: 13, color: Colors.grey, fontFamily: 'BeVietnamPro')),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFFC8102E).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                        child: const Text('Chủ cửa hàng', style: TextStyle(color: Color(0xFFC8102E), fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'BeVietnamPro')),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _SettingsSection(title: 'Chấm công & Cá nhân', items: [
            _SettingsItem(
              icon: Icons.fingerprint_rounded,
              label: 'Chấm công',
              sub: 'Chấm vào ca / ra ca (WiFi, GPS, QR)',
              color: const Color(0xFFC8102E),
              onTap: () => GoRouter.of(context).push(AppRoutes.checkIn),
            ),
            _SettingsItem(
              icon: Icons.history_rounded,
              label: 'Lịch sử chấm công của tôi',
              sub: 'Xem chi tiết ngày công và giờ vào/ra',
              color: const Color(0xFF1C4E6B),
              onTap: () => GoRouter.of(context).push(
                Uri(path: AppRoutes.attendanceHistory, queryParameters: {'userId': user?.id}).toString(),
              ),
            ),
            _SettingsItem(
              icon: Icons.calendar_month_rounded,
              label: 'Lịch làm việc & Đăng ký ca',
              sub: 'Xem và đăng ký ca làm cá nhân',
              color: const Color(0xFF1A6B5A),
              onTap: () => GoRouter.of(context).push(AppRoutes.scheduleRegister),
            ),
            _SettingsItem(
              icon: Icons.payments_rounded,
              label: 'Bảng lương của tôi',
              sub: 'Xem lương và tạm ứng cá nhân',
              color: const Color(0xFFB8860B),
              onTap: () => GoRouter.of(context).push(AppRoutes.salary),
            ),
          ]),
          const SizedBox(height: 12),

          _SettingsSection(title: 'Cửa hàng', items: [
            _SettingsItem(icon: Icons.store_rounded, label: 'Cài đặt cửa hàng', sub: store.name, onTap: () => GoRouter.of(context).push(AppRoutes.storeSettings)),
            _SettingsItem(icon: Icons.schedule_rounded, label: 'Quản lý ca làm', onTap: () => GoRouter.of(context).push(AppRoutes.shiftSettings)),
            _SettingsItem(icon: Icons.qr_code_rounded, label: 'Mã QR cửa hàng', onTap: () => GoRouter.of(context).push(AppRoutes.qrDisplay)),
          ]),
          const SizedBox(height: 12),
          _SettingsSection(title: 'Tài khoản', items: [
            _SettingsItem(icon: Icons.person_rounded, label: 'Hồ sơ cá nhân', onTap: () => GoRouter.of(context).push(AppRoutes.profileSettings)),
            _SettingsItem(icon: Icons.logout_rounded, label: 'Đăng xuất', color: Colors.red, onTap: () async {
              final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
                title: const Text('Đăng xuất?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Hủy')),
                  TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Đăng xuất', style: TextStyle(color: Colors.red))),
                ],
              ));
              if (confirm == true && context.mounted) {
                context.go(AppRoutes.login);
                await ref.read(authNotifierProvider.notifier).signOut();
              }
            }),
          ]),
        ],
      ),
    );
  }
}

// ─── SHARED WIDGETS ───────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final bool highlight;

  const _StatCard({required this.value, required this.label, required this.icon, required this.color, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlight ? color.withOpacity(0.08) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: highlight ? Border.all(color: color.withOpacity(0.4)) : null,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color, fontFamily: 'BeVietnamPro')),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontFamily: 'BeVietnamPro'), textAlign: TextAlign.center, maxLines: 2),
        ],
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sub;
  final Color color;
  final VoidCallback onTap;

  const _ToolCard({required this.icon, required this.label, this.sub, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontFamily: 'BeVietnamPro', fontSize: 14)),
                  if (sub != null) Text(sub!, style: const TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'BeVietnamPro')),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<_SettingsItem> items;

  const _SettingsSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey, fontFamily: 'BeVietnamPro')),
        ),
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
          child: Column(
            children: items.asMap().entries.map((e) {
              final item = e.value;
              final isLast = e.key == items.length - 1;
              return Column(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: ListTile(
                      onTap: item.onTap,
                      leading: Icon(item.icon, color: item.color ?? const Color(0xFF1A1A1A), size: 22),
                      title: Text(item.label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'BeVietnamPro', color: item.color ?? const Color(0xFF1A1A1A))),
                      subtitle: item.sub != null ? Text(item.sub!, style: const TextStyle(fontSize: 12, color: Colors.grey, fontFamily: 'BeVietnamPro')) : null,
                      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                    ),
                  ),
                  if (!isLast) const Divider(height: 1, indent: 56),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _SettingsItem {
  final IconData icon;
  final String label;
  final String? sub;
  final Color? color;
  final VoidCallback onTap;

  const _SettingsItem({required this.icon, required this.label, this.sub, this.color, required this.onTap});
}

class _OwnerNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int selected;
  final Function(int) onTap;

  const _OwnerNavItem({required this.icon, required this.label, required this.index, required this.selected, required this.onTap});

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
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFC8102E).withOpacity(0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: isSelected ? const Color(0xFFC8102E) : Colors.grey, size: 22),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 10, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isSelected ? const Color(0xFFC8102E) : Colors.grey, fontFamily: 'BeVietnamPro')),
            ],
          ),
        ),
      ),
    );
  }
}

class _OwnerPersonalAttendanceCard extends StatelessWidget {
  final AttendanceModel? attendance;
  final String userId;

  const _OwnerPersonalAttendanceCard({
    required this.attendance,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = attendance != null && attendance!.isActive;
    final isDone = attendance != null && !attendance!.isActive;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFF1A6B5A).withOpacity(0.12)
                      : isDone
                          ? const Color(0xFF1C4E6B).withOpacity(0.12)
                          : const Color(0xFFC8102E).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isActive
                      ? Icons.timer_rounded
                      : isDone
                          ? Icons.check_circle_rounded
                          : Icons.fingerprint_rounded,
                  color: isActive
                      ? const Color(0xFF1A6B5A)
                      : isDone
                          ? const Color(0xFF1C4E6B)
                          : const Color(0xFFC8102E),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isActive
                          ? 'Đang trong ca làm việc'
                          : isDone
                              ? 'Đã hoàn thành ca hôm nay'
                              : 'Chưa chấm công hôm nay',
                      style: GoogleFonts.beVietnamPro(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isActive
                          ? 'Vào ca lúc ${DateFormat('HH:mm').format(attendance!.checkIn)}'
                          : isDone && attendance?.checkOut != null
                              ? 'Tổng giờ: ${(attendance!.totalHours ?? 0).toStringAsFixed(1)}h (${DateFormat('HH:mm').format(attendance!.checkIn)} - ${DateFormat('HH:mm').format(attendance!.checkOut!)})'
                              : 'Chạm để chấm vào ca làm việc của bạn',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => context.push(AppRoutes.checkIn),
                icon: Icon(
                  isActive ? Icons.logout_rounded : Icons.fingerprint_rounded,
                  size: 16,
                ),
                label: Text(
                  isActive ? 'Ra ca' : 'Chấm công',
                  style: GoogleFonts.beVietnamPro(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isActive
                      ? const Color(0xFF1A6B5A)
                      : const Color(0xFFC8102E),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _PersonalQuickLink(
                icon: Icons.history_rounded,
                label: 'Lịch sử công',
                onTap: () => context.push(
                  Uri(
                    path: AppRoutes.attendanceHistory,
                    queryParameters: {'userId': userId},
                  ).toString(),
                ),
              ),
              _PersonalQuickLink(
                icon: Icons.calendar_month_rounded,
                label: 'Lịch cá nhân',
                onTap: () => context.push(AppRoutes.scheduleRegister),
              ),
              _PersonalQuickLink(
                icon: Icons.payments_rounded,
                label: 'Lương cá nhân',
                onTap: () => context.push(AppRoutes.salary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PersonalQuickLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PersonalQuickLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: const Color(0xFF1C4E6B)),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.beVietnamPro(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1C4E6B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

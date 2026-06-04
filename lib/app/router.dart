import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/auth/screens/welcome_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/screens/profile_setup_screen.dart';
import '../features/store/screens/create_store_screen.dart';
import '../features/store/screens/join_store_screen.dart';
import '../features/store/screens/join_qr_screen.dart';
import '../features/store/screens/pending_approval_screen.dart';
import '../features/store/screens/store_settings_screen.dart';
import '../features/store/screens/shift_settings_screen.dart';
import '../features/attendance/screens/check_in_screen.dart';
import '../features/attendance/screens/attendance_history_screen.dart';
import '../features/attendance/screens/attendance_table_screen.dart';
import '../features/attendance/screens/monthly_attendance_screen.dart';
import '../features/schedule/screens/schedule_register_screen.dart';
import '../features/schedule/screens/schedule_manager_screen.dart';
import '../features/salary/screens/salary_detail_screen.dart';
import '../features/salary/screens/salary_overview_screen.dart';
import '../features/salary/screens/manage_advances_screen.dart';
import '../features/members/screens/members_list_screen.dart';
import '../features/members/screens/member_detail_screen.dart';
import '../features/members/screens/pending_members_screen.dart';
import '../features/auth/screens/profile_settings_screen.dart';
import '../features/dashboard/owner_dashboard.dart';
import '../features/dashboard/manager_dashboard.dart';
import '../features/dashboard/employee_dashboard.dart';
import '../models/member_model.dart';

// Route path constants
class AppRoutes {
  AppRoutes._();

  static const String splash = '/splash';
  static const String welcome = '/welcome';
  static const String login = '/login';
  static const String register = '/register';
  static const String profileSetup = '/profile-setup';

  static const String createStore = '/create-store';
  static const String joinStore = '/join-store';
  static const String joinStoreQr = '/join-qr';
  static const String pendingApproval = '/pending-approval';

  static const String ownerDashboard = '/owner-dashboard';
  static const String managerDashboard = '/manager-dashboard';
  static const String employeeDashboard = '/employee-dashboard';

  static const String checkIn = '/check-in';
  static const String attendanceHistory = '/attendance-history';
  static const String attendanceTable = '/attendance-table';
  static const String monthlyAttendance = '/monthly-attendance';

  static const String scheduleRegister = '/schedule';
  static const String scheduleManager = '/schedule-manager';
  static const String salary = '/salary';
  static const String salaryOverview = '/salary-overview';
  static const String manageAdvances = '/manage-advances';
  static const String members = '/members';
  static const String memberDetail = '/member-detail';
  static const String pendingMembers = '/pending-members';
  static const String storeSettings = '/store-settings';
  static const String shiftSettings = '/shift-settings';
  static const String profileSettings = '/profile-settings';
}

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateChangesProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    redirect: (BuildContext context, GoRouterState state) {
      final isAuthenticated =
          authState.whenOrNull(data: (user) => user != null) ?? false;
      final isLoading = authState.isLoading;
      final currentPath = state.matchedLocation;

      // Don't redirect while loading
      if (isLoading) return null;

      // Allow splash to handle its own redirect
      if (currentPath == AppRoutes.splash) return null;

      // Auth screens - allow access only when not authenticated
      final authScreens = [
        AppRoutes.login,
        AppRoutes.register,
      ];
      final isOnAuthScreen = authScreens.contains(currentPath);

      if (!isAuthenticated && !isOnAuthScreen) {
        return AppRoutes.login;
      }

      if (isAuthenticated && isOnAuthScreen) {
        return AppRoutes.splash;
      }

      return null;
    },
    routes: [
      // ── Splash ────────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),

      // ── Auth Flow ─────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.welcome,
        name: 'welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.profileSetup,
        name: 'profile-setup',
        builder: (context, state) => const ProfileSetupScreen(),
      ),

      // ── Store Setup ───────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.createStore,
        name: 'create-store',
        builder: (context, state) => const CreateStoreScreen(),
      ),
      GoRoute(
        path: AppRoutes.joinStore,
        name: 'join-store',
        builder: (context, state) => const JoinStoreScreen(),
      ),
      GoRoute(
        path: AppRoutes.joinStoreQr,
        name: 'join-qr',
        builder: (context, state) => const JoinQrScreen(),
      ),
      GoRoute(
        path: AppRoutes.pendingApproval,
        name: 'pending-approval',
        builder: (context, state) => const PendingApprovalScreen(),
      ),

      // ── Dashboards ────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.ownerDashboard,
        name: 'owner-dashboard',
        builder: (context, state) => const OwnerDashboard(),
      ),
      GoRoute(
        path: AppRoutes.managerDashboard,
        name: 'manager-dashboard',
        builder: (context, state) => const ManagerDashboard(),
      ),
      GoRoute(
        path: AppRoutes.employeeDashboard,
        name: 'employee-dashboard',
        builder: (context, state) => const EmployeeDashboard(),
      ),

      // ── Attendance ────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.checkIn,
        name: 'check-in',
        builder: (context, state) => const CheckInScreen(),
      ),
      GoRoute(
        path: AppRoutes.attendanceHistory,
        name: 'attendance-history',
        builder: (context, state) {
          final userId = state.uri.queryParameters['userId'];
          return AttendanceHistoryScreen(userId: userId);
        },
      ),
      GoRoute(
        path: AppRoutes.attendanceTable,
        name: 'attendance-table',
        builder: (context, state) => const AttendanceTableScreen(),
      ),
      GoRoute(
        path: AppRoutes.monthlyAttendance,
        name: 'monthly-attendance',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final memberId = extra?['memberId'] as String? ?? '';
          final memberName = extra?['memberName'] as String? ?? '';
          return MonthlyAttendanceScreen(
              memberId: memberId, memberName: memberName);
        },
      ),

      // ── Schedule ──────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.scheduleRegister,
        name: 'schedule',
        builder: (context, state) => const ScheduleRegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.scheduleManager,
        name: 'schedule-manager',
        builder: (context, state) => const ScheduleManagerScreen(),
      ),

      // ── Salary ────────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.salary,
        name: 'salary',
        builder: (context, state) => const SalaryDetailScreen(),
      ),
      GoRoute(
        path: AppRoutes.salaryOverview,
        name: 'salary-overview',
        builder: (context, state) => const SalaryOverviewScreen(),
      ),
      GoRoute(
        path: AppRoutes.manageAdvances,
        name: 'manage-advances',
        builder: (context, state) => const ManageAdvancesScreen(),
      ),

      // ── Members ───────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.members,
        name: 'members',
        builder: (context, state) => const MembersListScreen(),
      ),
      GoRoute(
        path: AppRoutes.memberDetail,
        name: 'member-detail',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final userId = extra?['userId'] as String? ?? '';
          return MemberDetailScreen(userId: userId);
        },
      ),
      GoRoute(
        path: AppRoutes.pendingMembers,
        name: 'pending-members',
        builder: (context, state) => const PendingMembersScreen(),
      ),

      // ── Store Settings ────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.storeSettings,
        name: 'store-settings',
        builder: (context, state) => const StoreSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.shiftSettings,
        name: 'shift-settings',
        builder: (context, state) => const ShiftSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.profileSettings,
        name: 'profile-settings',
        builder: (context, state) => const ProfileSettingsScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      backgroundColor: const Color(0xFFF8F4EE),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Color(0xFFC8102E)),
            const SizedBox(height: 16),
            Text(
              'Không tìm thấy trang',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              state.error?.message ?? 'Đường dẫn không hợp lệ',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.splash),
              child: const Text('Về trang chủ'),
            ),
          ],
        ),
      ),
    ),
  );
});

// Helper extension for role-based navigation
extension RoleNavigation on BuildContext {
  void navigateToDashboard(UserRole role) {
    switch (role) {
      case UserRole.owner:
        go(AppRoutes.ownerDashboard);
      case UserRole.manager:
        go(AppRoutes.managerDashboard);
      case UserRole.employee:
        go(AppRoutes.employeeDashboard);
    }
  }
}

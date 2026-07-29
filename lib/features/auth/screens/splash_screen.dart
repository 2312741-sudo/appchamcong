import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../../../app/router.dart';
import '../../store/providers/user_repository.dart';
import '../../store/providers/store_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/notification_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    // Single entry point: wait for auth then navigate
    _waitAndNavigate();
  }

  Future<void> _waitAndNavigate() async {
    // Give splash screen time to render
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    // Wait for auth state to resolve (max 10 seconds)
    for (int i = 0; i < 20; i++) {
      final authState = ref.read(authStateChangesProvider);
      if (!authState.isLoading) break;
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
    }

    _navigate();
  }

  Future<void> _navigate() async {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;

    final authState = ref.read(authStateChangesProvider);
    final user = authState.valueOrNull;

    // Not logged in
    if (user == null) {
      if (mounted) context.go(AppRoutes.welcome);
      return;
    }

    // Initialize notifications after confirming user is logged in
    try {
      await NotificationService().initialize();
      await NotificationService().saveTokenForUser(user.uid);
    } catch (_) {}

    // Wait for user model to load (max 5 seconds)
    for (int i = 0; i < 10; i++) {
      final userAsync = ref.read(currentUserProvider);
      if (!userAsync.isLoading) break;
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
    }

    final userModel = ref.read(currentUserProvider).valueOrNull;

    if (!mounted) return;

    // No user document in Firestore
    if (userModel == null) {
      context.go(AppRoutes.profileSetup);
      return;
    }

    // User has no store assigned
    if (!userModel.hasStore) {
      try {
        final stores = await ref.read(userStoresProvider.future);
        if (stores.isNotEmpty && mounted) {
          final userRepo = ref.read(userRepositoryProvider);
          await userRepo.updateCurrentStoreId(userModel.id, stores.first.id);
          // Refresh and navigate
          ref.invalidate(currentUserProvider);
          context.go(AppRoutes.splash);
          return;
        }
      } catch (_) {}
      if (mounted) context.go(AppRoutes.welcome);
      return;
    }

    // User has a store - determine role and navigate
    try {
      final memberDoc = await FirebaseFirestore.instance
          .collection('stores')
          .doc(userModel.currentStoreId)
          .collection('members')
          .doc(userModel.id)
          .get();

      if (!mounted) return;

      if (memberDoc.exists) {
        final role = memberDoc.data()?['role'] as String?;
        final status = memberDoc.data()?['status'] as String?;

        if (status == 'pending') {
          context.go(AppRoutes.pendingApproval);
          return;
        }
        if (status == 'kicked') {
          context.go(AppRoutes.welcome);
          return;
        }

        if (role == 'owner') {
          context.go(AppRoutes.ownerDashboard);
        } else if (role == 'manager') {
          context.go(AppRoutes.managerDashboard);
        } else {
          context.go(AppRoutes.employeeDashboard);
        }
        return;
      }
    } catch (_) {}

    // Fallback
    if (mounted) context.go(AppRoutes.employeeDashboard);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  image: const DecorationImage(
                    image: AssetImage('assets/images/logo.jpg'),
                    fit: BoxFit.contain,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.neutral.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // App Name
              const Text(
                AppStrings.appName,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AppColors.white,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              // Tagline
              const Text(
                AppStrings.appTagline,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: AppColors.white,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 64),

              // Loading Indicator
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  color: Colors.white70,
                  strokeWidth: 2.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

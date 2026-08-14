import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/auth_provider.dart';
import '../../../app/router.dart';
import '../../store/providers/user_repository.dart';
import '../../store/providers/store_provider.dart';
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
    // Start navigation flow immediately without artificial delays
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthAndNavigate();
    });
  }

  Future<void> _checkAuthAndNavigate() async {
    if (_hasNavigated || !mounted) return;

    try {
      // 1. Await auth state (cached locally by Firebase Auth)
      final authState = await ref.read(authStateChangesProvider.future);
      if (!mounted || _hasNavigated) return;

      // Not logged in -> Go to Welcome screen immediately
      if (authState == null) {
        _navigateTo(AppRoutes.welcome);
        return;
      }

      // 2. Initialize push notifications in background (non-blocking)
      unawaited(() async {
        try {
          await NotificationService().initialize();
          await NotificationService().saveTokenForUser(authState.uid);
        } catch (_) {}
      }());

      // 3. Await current user model with a fast timeout
      final userModel = await ref
          .read(currentUserProvider.future)
          .timeout(const Duration(seconds: 4), onTimeout: () => null);

      if (!mounted || _hasNavigated) return;

      // No user profile in Firestore
      if (userModel == null) {
        _navigateTo(AppRoutes.profileSetup);
        return;
      }

      // User has no store assigned
      if (!userModel.hasStore) {
        try {
          final stores = await ref
              .read(userStoresProvider.future)
              .timeout(const Duration(seconds: 3), onTimeout: () => []);
          if (stores.isNotEmpty && mounted && !_hasNavigated) {
            final userRepo = ref.read(userRepositoryProvider);
            await userRepo.updateCurrentStoreId(userModel.id, stores.first.id);
            ref.invalidate(currentUserProvider);
            _navigateTo(AppRoutes.splash);
            return;
          }
        } catch (_) {}
        _navigateTo(AppRoutes.welcome);
        return;
      }

      // 4. Resolve member role and status
      try {
        final memberDoc = await FirebaseFirestore.instance
            .collection('stores')
            .doc(userModel.currentStoreId)
            .collection('members')
            .doc(userModel.id)
            .get()
            .timeout(const Duration(seconds: 3));

        if (!mounted || _hasNavigated) return;

        if (memberDoc.exists) {
          final role = memberDoc.data()?['role'] as String?;
          final status = memberDoc.data()?['status'] as String?;

          if (status == 'pending') {
            _navigateTo(AppRoutes.pendingApproval);
            return;
          }
          if (status == 'kicked') {
            _navigateTo(AppRoutes.welcome);
            return;
          }

          if (role == 'owner') {
            _navigateTo(AppRoutes.ownerDashboard);
          } else if (role == 'manager') {
            _navigateTo(AppRoutes.managerDashboard);
          } else {
            _navigateTo(AppRoutes.employeeDashboard);
          }
          return;
        }
      } catch (_) {}

      // Fallback
      _navigateTo(AppRoutes.employeeDashboard);
    } catch (_) {
      if (mounted && !_hasNavigated) {
        _navigateTo(AppRoutes.welcome);
      }
    }
  }

  void _navigateTo(String route) {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    context.go(route);
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

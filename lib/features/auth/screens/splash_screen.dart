import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../../../app/router.dart';
import '../../store/providers/user_repository.dart';
import '../../store/providers/store_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _scheduleNavigation();
  }

  void _scheduleNavigation() {
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted && !_hasNavigated) {
        _navigate();
      }
    });
  }

  void _navigate() {
    if (_hasNavigated) return;
    _hasNavigated = true;

    final authState = ref.read(authStateChangesProvider);
    authState.whenOrNull(
      data: (user) {
        if (!mounted) return;
        if (user == null) {
          context.go(AppRoutes.welcome);
        } else {
          // Check user's role and store status
          final userAsync = ref.read(currentUserProvider);
          userAsync.whenOrNull(
            data: (userModel) async {
              if (!mounted) return;
              if (userModel == null) {
                context.go(AppRoutes.login);
              } else if (!userModel.hasStore) {
                // Check if they actually belong to stores but currentStoreId is null
                try {
                  final stores = await ref.read(userStoresProvider.future);
                  if (stores.isNotEmpty && mounted) {
                    final userRepo = ref.read(userRepositoryProvider);
                    await userRepo.updateCurrentStoreId(
                        userModel.id, stores.first.id);
                    context.go(AppRoutes.employeeDashboard);
                    return;
                  }
                } catch (_) {}
                if (mounted) context.go(AppRoutes.welcome);
              } else {
                // Navigate to appropriate dashboard based on member role
                try {
                  final memberDoc = await FirebaseFirestore.instance
                      .collection('stores')
                      .doc(userModel.currentStoreId)
                      .collection('members')
                      .doc(userModel.id)
                      .get();

                  if (memberDoc.exists) {
                    final role = memberDoc.data()?['role'] as String?;
                    final status = memberDoc.data()?['status'] as String?;

                    if (status == 'pending') {
                      if (mounted) context.go(AppRoutes.pendingApproval);
                      return;
                    } else if (status == 'kicked') {
                      // Optional: handle kicked state, for now go to welcome
                      if (mounted) context.go(AppRoutes.welcome);
                      return;
                    }

                    if (mounted) {
                      if (role == 'owner') {
                        context.go(AppRoutes.ownerDashboard);
                      } else if (role == 'manager') {
                        context.go(AppRoutes.managerDashboard);
                      } else {
                        context.go(AppRoutes.employeeDashboard);
                      }
                    }
                    return;
                  }
                } catch (_) {}

                // Default fallback
                if (mounted) context.go(AppRoutes.employeeDashboard);
              }
            },
            error: (_, __) {
              if (mounted) context.go(AppRoutes.login);
            },
          );
          // If user model not yet loaded, go welcome as safe fallback
          if (!mounted) return;
          if (userAsync.isLoading) {
            // Wait for user provider to load instead of going to welcome immediately
            // We'll rely on the provider listener
          }
        }
      },
      loading: () {
        // Wait a bit more if still loading
        if (!_hasNavigated) {
          _hasNavigated = false;
          _scheduleNavigation();
        }
      },
      error: (_, __) {
        if (mounted) context.go(AppRoutes.login);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch auth changes so we can react as soon as auth state resolves
    ref.listen(authStateChangesProvider, (prev, next) {
      next.whenOrNull(
        data: (_) {
          if (!_hasNavigated) {
            Future.delayed(const Duration(milliseconds: 500), _navigate);
          }
        },
      );
    });

    ref.listen(currentUserProvider, (prev, next) {
      next.whenOrNull(
        data: (_) {
          if (!_hasNavigated) {
            Future.delayed(const Duration(milliseconds: 500), _navigate);
          }
        },
        error: (_, __) {
          if (mounted && !_hasNavigated) {
            context.go(AppRoutes.login);
          }
        },
      );
    });

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
              )
                  .animate()
                  .fadeIn(duration: 600.ms)
                  .scale(begin: const Offset(0.6, 0.6), duration: 600.ms),

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
              )
                  .animate()
                  .fadeIn(delay: 300.ms, duration: 600.ms)
                  .slideY(begin: 0.3, delay: 300.ms, duration: 600.ms),

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
              )
                  .animate()
                  .fadeIn(delay: 500.ms, duration: 600.ms)
                  .slideY(begin: 0.3, delay: 500.ms, duration: 600.ms),

              const SizedBox(height: 64),

              // Loading Indicator
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  color: AppColors.white.withOpacity(0.8),
                  strokeWidth: 2.5,
                ),
              ).animate().fadeIn(delay: 800.ms, duration: 400.ms),
            ],
          ),
        ),
      ),
    );
  }
}

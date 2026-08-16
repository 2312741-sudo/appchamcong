import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
      // 1. Check current auth state
      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser == null) {
        _navigateTo(AppRoutes.welcome);
        return;
      }

      // 2. Initialize push notifications in background (non-blocking)
      unawaited(() async {
        try {
          await NotificationService().initialize();
          await NotificationService().saveTokenForUser(authUser.uid);
        } catch (_) {}
      }());

      // 3. Get user document from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(authUser.uid)
          .get();

      if (!mounted || _hasNavigated) return;

      if (!userDoc.exists || userDoc.data() == null) {
        _navigateTo(AppRoutes.profileSetup);
        return;
      }

      final userData = userDoc.data()!;
      var currentStoreId = userData['currentStoreId'] as String?;

      // 4. If currentStoreId is missing or empty, discover user's stores
      if (currentStoreId == null || currentStoreId.isEmpty) {
        final storeRepo = ref.read(storeRepositoryProvider);
        final stores = await storeRepo.getUserStores(authUser.uid);
        if (stores.isNotEmpty) {
          currentStoreId = stores.first.id;
          await FirebaseFirestore.instance
              .collection('users')
              .doc(authUser.uid)
              .set({
            'currentStoreId': currentStoreId,
            'storeIds': stores.map((s) => s.id).toList(),
          }, SetOptions(merge: true));
        } else {
          _navigateTo(AppRoutes.welcome);
          return;
        }
      }

      if (!mounted || _hasNavigated) return;

      // 5. Resolve member role and status in current store
      final memberDoc = await FirebaseFirestore.instance
          .collection('stores')
          .doc(currentStoreId)
          .collection('members')
          .doc(authUser.uid)
          .get();

      if (!mounted || _hasNavigated) return;

      if (memberDoc.exists && memberDoc.data() != null) {
        final data = memberDoc.data()!;
        final role = data['role'] as String?;
        final status = data['status'] as String?;

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
        } else if (role == 'manager_1' ||
            role == 'manager1' ||
            role == 'manager_2' ||
            role == 'manager2' ||
            role == 'manager') {
          _navigateTo(AppRoutes.managerDashboard);
        } else {
          _navigateTo(AppRoutes.employeeDashboard);
        }
        return;
      }

      // Check if user is owner of the store
      final storeDoc = await FirebaseFirestore.instance
          .collection('stores')
          .doc(currentStoreId)
          .get();

      if (storeDoc.exists && storeDoc.data()?['ownerId'] == authUser.uid) {
        _navigateTo(AppRoutes.ownerDashboard);
        return;
      }

      // If not a member of currentStoreId, try other stores
      final storeRepo = ref.read(storeRepositoryProvider);
      final stores = await storeRepo.getUserStores(authUser.uid);
      if (stores.isNotEmpty) {
        final newStoreId = stores.first.id;
        await FirebaseFirestore.instance
            .collection('users')
            .doc(authUser.uid)
            .update({'currentStoreId': newStoreId});
        _navigateTo(AppRoutes.splash);
        return;
      }

      _navigateTo(AppRoutes.welcome);
    } catch (e) {
      debugPrint('SplashScreen auth error: $e');
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

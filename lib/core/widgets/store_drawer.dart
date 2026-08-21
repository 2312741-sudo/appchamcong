import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../app/router.dart';
import '../../features/store/providers/store_provider.dart';
import '../../features/store/providers/user_repository.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/providers/auth_notifier.dart';
import '../../models/member_model.dart';
import '../constants/app_colors.dart';

import 'avatar_widget.dart';

class StoreDrawer extends ConsumerWidget {
  const StoreDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storesAsync = ref.watch(userStoresProvider);
    final currentStoreId = ref.watch(currentStoreIdProvider);
    final user = ref.watch(currentUserProvider).value;

    return Drawer(
      backgroundColor: AppColors.background,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: AppColors.primary),
            accountName: Text(
              user?.name ?? 'Người dùng',
              style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'BeVietnamPro'),
            ),
            accountEmail: Text(user?.email ?? '', style: const TextStyle(fontFamily: 'BeVietnamPro')),
            currentAccountPicture: CircleAvatar(
              backgroundColor: AppColors.surface,
              backgroundImage: getAvatarImageProvider(user?.avatarUrl),
              child: getAvatarImageProvider(user?.avatarUrl) == null
                  ? const Icon(Icons.person, color: AppColors.primary, size: 36)
                  : null,
            ),
          ),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            alignment: Alignment.centerLeft,
            child: const Text(
              'CÁC CỬA HÀNG CỦA BẠN',
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          
          Expanded(
            child: storesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (err, _) => Center(child: Text('Lỗi: $err')),
              data: (stores) {
                if (stores.isEmpty) {
                  return const Center(child: Text('Bạn chưa tham gia cửa hàng nào.'));
                }
                
                return ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: stores.length,
                  itemBuilder: (context, index) {
                    final store = stores[index];
                    final isSelected = store.id == currentStoreId;
                    
                    return ListTile(
                      leading: Icon(
                        isSelected ? Icons.store_rounded : Icons.store_outlined,
                        color: isSelected ? AppColors.primary : AppColors.textSecondary,
                      ),
                      title: Text(
                        store.name,
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? AppColors.primary : AppColors.neutral,
                        ),
                      ),
                      subtitle: Text(
                        'Mã: ${store.code}',
                        style: const TextStyle(fontFamily: 'BeVietnamPro', fontSize: 12),
                      ),
                      trailing: isSelected 
                          ? const Icon(Icons.check_circle, color: AppColors.primary, size: 20)
                          : null,
                      onTap: () async {
                        if (!isSelected && user != null) {
                          try {
                            final userRepo = ref.read(userRepositoryProvider);
                            await userRepo.updateCurrentStoreId(user.id, store.id);
                            
                            if (!context.mounted) return;
                            
                            // Fetch role in new store
                            final memberDoc = await FirebaseFirestore.instance
                                .collection('stores')
                                .doc(store.id)
                                .collection('members')
                                .doc(user.id)
                                .get();
                            
                            if (context.mounted) {
                              Navigator.pop(context); // close drawer
                              
                              final isOwner = store.ownerId == user.id;
                              if (memberDoc.exists || isOwner) {
                                final role = isOwner
                                    ? UserRole.owner
                                    : UserRoleExtension.fromString(memberDoc.data()?['role'] as String?);
                                final currentPath = GoRouterState.of(context).uri.toString();
                                String targetPath = AppRoutes.employeeDashboard;
                                if (role.isOwner) {
                                  targetPath = AppRoutes.ownerDashboard;
                                } else if (role.isManager) {
                                  targetPath = AppRoutes.managerDashboard;
                                }
                                
                                if (currentPath == targetPath) {
                                  // Force UI refresh if staying on same route
                                  // Just let Riverpod handle it, but we can show a snackbar
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Đã chuyển sang: ${store.name}'), backgroundColor: AppColors.success),
                                  );
                                } else {
                                  context.go(targetPath);
                                }
                              } else {
                                context.go(AppRoutes.welcome);
                              }
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Lỗi chuyển cửa hàng: $e'), backgroundColor: AppColors.primary),
                              );
                            }
                          }
                        } else {
                          Navigator.pop(context);
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
          
          const Divider(),
          
          ListTile(
            leading: const Icon(Icons.add_business_rounded, color: AppColors.neutral),
            title: const Text('Tạo cửa hàng mới', style: TextStyle(fontFamily: 'BeVietnamPro')),
            onTap: () {
              Navigator.pop(context);
              context.push(AppRoutes.createStore);
            },
          ),
          ListTile(
            leading: const Icon(Icons.group_add_rounded, color: AppColors.neutral),
            title: const Text('Tham gia cửa hàng', style: TextStyle(fontFamily: 'BeVietnamPro')),
            onTap: () {
              Navigator.pop(context);
              context.push(AppRoutes.joinStore);
            },
          ),
          
          const Divider(),
          
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.danger),
            title: const Text('Đăng xuất', style: TextStyle(color: AppColors.danger, fontFamily: 'BeVietnamPro')),
            onTap: () async {
              Navigator.of(context).pop(); // Close drawer
              context.go(AppRoutes.login);
              await ref.read(authNotifierProvider.notifier).signOut();
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

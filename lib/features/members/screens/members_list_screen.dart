import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/avatar_widget.dart';
import '../../../models/member_model.dart';
import '../../store/providers/store_provider.dart';

class MembersListScreen extends ConsumerWidget {
  const MembersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeMembers = ref.watch(activeMembersProvider);
    final store = ref.watch(currentStoreProvider).valueOrNull;
    final currentMember = ref.watch(currentMemberStreamProvider).valueOrNull;
    final isOwner = currentMember?.isOwner ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Danh sách nhân viên',
            style: TextStyle(
                fontFamily: 'BeVietnamPro', fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_rounded),
            tooltip: 'Yêu cầu chờ duyệt',
            onPressed: () {
              context.push(AppRoutes.pendingMembers);
            },
          ),
        ],
      ),
      body: activeMembers.isEmpty
          ? const Center(
              child: Text(
                'Chưa có nhân viên nào trong cửa hàng.',
                style: TextStyle(
                    fontFamily: 'BeVietnamPro', color: AppColors.textSecondary),
              ),
            )
          : isOwner
              ? ReorderableListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: activeMembers.length,
                  onReorder: (oldIndex, newIndex) {
                    if (oldIndex < newIndex) newIndex -= 1;
                    final items = List<MemberModel>.from(activeMembers);
                    final item = items.removeAt(oldIndex);
                    items.insert(newIndex, item);
                    final newOrder = items.map((m) => m.userId).toList();
                    if (store != null) {
                      ref
                          .read(storeRepositoryProvider)
                          .updateMemberOrder(store.id, newOrder);
                    }
                  },
                  itemBuilder: (context, index) {
                    final member = activeMembers[index];
                    final isHidden = store?.hiddenScheduleUserIds
                            .contains(member.userId) ??
                        false;
                    return Padding(
                      key: ValueKey(member.userId),
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildMemberCard(
                        context,
                        member,
                        key: ValueKey('card_${member.userId}'),
                        isOwner: isOwner,
                        isHidden: isHidden,
                        index: index,
                      ),
                    );
                  },
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: activeMembers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final member = activeMembers[index];
                    final isHidden = store?.hiddenScheduleUserIds
                            .contains(member.userId) ??
                        false;
                    return _buildMemberCard(
                      context,
                      member,
                      key: ValueKey(member.userId),
                      isOwner: isOwner,
                      isHidden: isHidden,
                      index: index,
                    );
                  },
                ),
    );
  }

  Widget _buildMemberCard(
    BuildContext context,
    MemberModel member, {
    required Key key,
    required bool isOwner,
    required bool isHidden,
    required int index,
  }) {
    return InkWell(
      key: key,
      onTap: () {
        context.push(AppRoutes.memberDetail, extra: {'userId': member.userId});
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            if (isOwner) ...[
              ReorderableDragStartListener(
                index: index,
                child: const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Icon(Icons.drag_handle_rounded,
                      color: AppColors.textDisabled, size: 20),
                ),
              ),
            ],
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primary.withOpacity(0.1),
              backgroundImage: getAvatarImageProvider(member.avatarUrl),
              child: getAvatarImageProvider(member.avatarUrl) == null
                  ? Text(
                      member.initials,
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          member.name,
                          style: const TextStyle(
                            fontFamily: 'BeVietnamPro',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.neutral,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isHidden) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3CD),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFFFEEBA)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.visibility_off_rounded,
                                  size: 11, color: Color(0xFFD9480F)),
                              SizedBox(width: 3),
                              Text(
                                'Ẩn lịch',
                                style: TextStyle(
                                  fontFamily: 'BeVietnamPro',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFD9480F),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getRoleColor(member.role).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          member.role.shortLabel,
                          style: TextStyle(
                            fontFamily: 'BeVietnamPro',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _getRoleColor(member.role),
                          ),
                        ),
                      ),
                      if (member.isLegacyManager) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3CD),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFFFEEBA)),
                          ),
                          child: const Text(
                            'Cần phân loại',
                            style: TextStyle(
                              fontFamily: 'BeVietnamPro',
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF856404),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      Text(
                        member.employeeType.shortLabel,
                        style: const TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textDisabled),
          ],
        ),
      ),
    );
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.owner:
        return AppColors.danger;
      case UserRole.manager1:
        return const Color(0xFF1C4E6B);
      case UserRole.manager2:
        return const Color(0xFF00796B);
      case UserRole.legacyManager:
        return const Color(0xFFE65100);
      case UserRole.employee:
        return AppColors.success;
    }
  }
}

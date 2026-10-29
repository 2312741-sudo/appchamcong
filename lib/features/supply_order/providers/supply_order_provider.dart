import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/department_utils.dart';
import '../../auth/providers/auth_provider.dart';
import '../../schedule/providers/schedule_provider.dart';
import '../../../models/supply_order_model.dart';
import '../../store/providers/store_provider.dart';
import '../repositories/supply_order_repository.dart';

final supplyOrderRepositoryProvider = Provider<SupplyOrderRepository>((ref) => SupplyOrderRepository());

/// Danh mục hàng đang dùng
final supplyItemsProvider = StreamProvider<List<SupplyItem>>((ref) {
  final storeId = ref.watch(currentStoreIdProvider);
  if (storeId == null || storeId.isEmpty) return Stream.value(const []);
  return ref.watch(supplyOrderRepositoryProvider).watchItems(storeId);
});

/// Toàn bộ danh mục (kể cả đã ẩn) — màn quản lý danh mục
final allSupplyItemsProvider = StreamProvider<List<SupplyItem>>((ref) {
  final storeId = ref.watch(currentStoreIdProvider);
  if (storeId == null || storeId.isEmpty) return Stream.value(const []);
  return ref.watch(supplyOrderRepositoryProvider).watchItems(storeId, includeInactive: true);
});

/// Phiếu của một ngày (yyyy-MM-dd)
final supplyOrderProvider = StreamProvider.family<SupplyOrder, String>((ref, date) {
  final storeId = ref.watch(currentStoreIdProvider);
  if (storeId == null || storeId.isEmpty) return Stream.value(SupplyOrder(date: date));
  return ref.watch(supplyOrderRepositoryProvider).watchOrder(storeId, date);
});

/// Lịch sử phiếu gần đây
final recentSupplyOrdersProvider = StreamProvider<List<SupplyOrder>>((ref) {
  final storeId = ref.watch(currentStoreIdProvider);
  if (storeId == null || storeId.isEmpty) return Stream.value(const []);
  return ref.watch(supplyOrderRepositoryProvider).watchRecentOrders(storeId);
});

/// Cài đặt đặt & soạn hàng (giờ chốt, bộ phận soạn hàng)
final supplySettingsProvider = StreamProvider<SupplySettings>((ref) {
  final storeId = ref.watch(currentStoreIdProvider);
  if (storeId == null || storeId.isEmpty) return Stream.value(const SupplySettings());
  return ref.watch(supplyOrderRepositoryProvider).watchSettings(storeId);
});

/// Người dùng hiện tại có phải NGƯỜI SOẠN HÀNG của ngày [date] không:
/// được xếp lịch ở bộ phận soạn hàng (Cài đặt → vd. "Phục vụ lobby") trong ngày đó.
/// Chưa chọn bộ phận nào → mọi người đều soạn được.
final isSupplyPreparerProvider = Provider.family<bool, String>((ref, date) {
  final settings = ref.watch(supplySettingsProvider).valueOrNull ?? const SupplySettings();
  if (settings.preparerDepartmentIds.isEmpty) return true;
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return false;
  final member = ref.watch(currentMemberProvider);
  final store = ref.watch(currentStoreProvider).valueOrNull;
  final schedule = ref.watch(weekScheduleProvider(DepartmentUtils.getMondayOfWeek(date))).valueOrNull;
  return DepartmentUtils.isUserInDepartmentOnDate(
    userId: uid,
    dateStr: date,
    targetDeptIds: settings.preparerDepartmentIds,
    schedule: schedule,
    memberDepartment: member?.department,
    storeDepartments: store?.departments,
  );
});

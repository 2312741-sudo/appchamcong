import 'package:flutter_riverpod/flutter_riverpod.dart';
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

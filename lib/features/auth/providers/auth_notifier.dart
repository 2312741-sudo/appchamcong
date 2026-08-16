import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/auth_repository.dart';
import '../../../models/user_model.dart';
import '../../../core/services/notification_service.dart';
import 'auth_provider.dart';
import '../../store/providers/store_provider.dart';

// ── Auth Action State ─────────────────────────────────────────────────────────

class AuthState {
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  const AuthState({
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  AuthState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage:
          clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }

  bool get hasError => errorMessage != null;
  bool get hasSuccess => successMessage != null;
}

// ── Auth Notifier ─────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  final Ref _ref;

  AuthNotifier(this._repository, this._ref) : super(const AuthState());

  void _invalidateAllUserData() {
    _ref.invalidate(currentUserProvider);
    _ref.invalidate(currentFirebaseUserProvider);
    _ref.invalidate(currentUserIdProvider);
    _ref.invalidate(userStoresProvider);
    _ref.invalidate(currentStoreProvider);
    _ref.invalidate(storeMembersProvider);
    _ref.invalidate(currentMemberStreamProvider);
  }

  // ── Sign In ─────────────────────────────────────────────────────────────

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      await _repository.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      _invalidateAllUserData();
      
      // Update FCM token in background without blocking login
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        unawaited(NotificationService().saveTokenForUser(user.uid).catchError((_) {}));
      }

      state = state.copyWith(
        isLoading: false,
        successMessage: 'Đăng nhập thành công',
      );
      return true;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: AuthRepository.parseFirebaseAuthError(e),
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Có lỗi xảy ra, vui lòng thử lại',
      );
      return false;
    }
  }

  // ── Register ────────────────────────────────────────────────────────────

  Future<bool> register({
    required String email,
    required String password,
    required String name,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      final credential = await _repository.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Không thể tạo tài khoản, vui lòng thử lại',
        );
        return false;
      }

      // Update Firebase display name
      await _repository.updateFirebaseProfile(displayName: name);

      // Create Firestore user document
      final userModel = UserModel(
        id: credential.user!.uid,
        name: name,
        email: email,
        createdAt: DateTime.now().toUtc(),
      );
      await _repository.createUserDocument(userModel);

      _invalidateAllUserData();

      // Update FCM token in background
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        unawaited(NotificationService().saveTokenForUser(currentUser.uid).catchError((_) {}));
      }

      state = state.copyWith(
        isLoading: false,
        successMessage: 'Đăng ký thành công',
      );
      return true;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: AuthRepository.parseFirebaseAuthError(e),
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Có lỗi xảy ra, vui lòng thử lại',
      );
      return false;
    }
  }

  // ── Sign Out ────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repository.signOut();
      _invalidateAllUserData();
      state = const AuthState();
    } catch (e) {
      _invalidateAllUserData();
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Có lỗi khi đăng xuất',
      );
    }
  }

  // ── Update Profile ──────────────────────────────────────────────────────

  Future<bool> updateProfile({
    required String uid,
    required String name,
    String? phone,
    String? avatarUrl,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      final updateData = <String, dynamic>{'name': name};
      if (phone != null) updateData['phone'] = phone;
      if (avatarUrl != null) updateData['avatarUrl'] = avatarUrl;

      await _repository.updateUserDocument(uid: uid, data: updateData);
      await _repository.updateFirebaseProfile(
        displayName: name,
        photoURL: avatarUrl,
      );

      state = state.copyWith(
        isLoading: false,
        successMessage: 'Cập nhật hồ sơ thành công',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Có lỗi khi cập nhật hồ sơ',
      );
      return false;
    }
  }

  // ── Send Password Reset ─────────────────────────────────────────────────

  Future<bool> sendPasswordResetEmail(String email) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      await _repository.sendPasswordResetEmail(email);
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Email đặt lại mật khẩu đã được gửi',
      );
      return true;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: AuthRepository.parseFirebaseAuthError(e),
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Có lỗi xảy ra, vui lòng thử lại',
      );
      return false;
    }
  }

  // ── Delete Account ──────────────────────────────────────────────────────

  Future<bool> deleteAccount({required String password}) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      await _repository.deleteAccount(password: password);
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Tài khoản đã được xóa thành công',
      );
      return true;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: AuthRepository.parseFirebaseAuthError(e),
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Có lỗi khi xóa tài khoản: $e',
      );
      return false;
    }
  }

  // ── Clear Error/Success ─────────────────────────────────────────────────

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  void clearSuccess() {
    state = state.copyWith(clearSuccess: true);
  }
}

// ── Auth Notifier Provider ────────────────────────────────────────────────────

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return AuthNotifier(repo, ref);
});

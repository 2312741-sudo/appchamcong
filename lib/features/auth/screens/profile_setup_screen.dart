import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../providers/auth_notifier.dart';
import '../providers/auth_provider.dart';
import '../../../app/router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/loading_overlay.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  File? _avatarFile;
  bool _isUploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill name from Firebase Auth
    final user = ref.read(currentFirebaseUserProvider);
    if (user?.displayName != null) {
      _nameController.text = user!.displayName!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() => _avatarFile = File(picked.path));
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined,
                  color: AppColors.primary),
              title: const Text(AppStrings.takePhoto),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: AppColors.primary),
              title: const Text(AppStrings.chooseFromGallery),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<String?> _uploadAvatar(String uid) async {
    if (_avatarFile == null) return null;
    setState(() => _isUploadingAvatar = true);
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('avatars')
          .child('$uid.jpg');
      await ref.putFile(_avatarFile!);
      final url = await ref.getDownloadURL();
      return url;
    } catch (e) {
      debugPrint('Avatar upload error: $e');
      return null;
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _handleContinue() async {
    if (!_formKey.currentState!.validate()) return;

    final uid = ref.read(currentUserIdProvider);
    if (uid == null) {
      if (mounted) context.go(AppRoutes.welcome);
      return;
    }

    String? avatarUrl;
    if (_avatarFile != null) {
      avatarUrl = await _uploadAvatar(uid);
    }

    final success = await ref.read(authNotifierProvider.notifier).updateProfile(
          uid: uid,
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
          avatarUrl: avatarUrl,
        );

    if (!mounted) return;

    if (success) {
      context.go(AppRoutes.welcome);
    } else {
      final error = ref.read(authNotifierProvider).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? AppStrings.errorGeneral),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading || _isUploadingAvatar;

    return LoadingOverlay(
      isLoading: isLoading,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text(AppStrings.profileSetup),
          automaticallyImplyLeading: false,
          actions: [
            TextButton(
              onPressed: isLoading
                  ? null
                  : () => context.go(AppRoutes.welcome),
              child: const Text(
                AppStrings.skip,
                style: TextStyle(color: AppColors.white),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ── Header ─────────────────────────────────────────────
                  Text(
                    AppStrings.profileSetup,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppStrings.profileSetupSubtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 32),

                  // ── Avatar Picker ──────────────────────────────────────
                  GestureDetector(
                    onTap: _showImageSourceDialog,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 56,
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          backgroundImage: _avatarFile != null
                              ? FileImage(_avatarFile!)
                              : null,
                          child: _avatarFile == null
                              ? const Icon(
                                  Icons.person_rounded,
                                  size: 52,
                                  color: AppColors.primary,
                                )
                              : null,
                        ),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            size: 20,
                            color: AppColors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  TextButton(
                    onPressed: _showImageSourceDialog,
                    child: const Text(AppStrings.chooseAvatar),
                  ),

                  const SizedBox(height: 24),

                  // ── Full Name ──────────────────────────────────────────
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: AppStrings.fullName,
                      hintText: AppStrings.fullNameHint,
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return AppStrings.errorNameRequired;
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // ── Phone ──────────────────────────────────────────────
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _handleContinue(),
                    decoration: const InputDecoration(
                      labelText: AppStrings.phoneNumber,
                      hintText: AppStrings.phoneHint,
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        if (!RegExp(r'^[0-9]{9,11}$')
                            .hasMatch(value.replaceAll(RegExp(r'[\s\-]'), ''))) {
                          return 'Số điện thoại không hợp lệ';
                        }
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 32),

                  // ── Continue Button ────────────────────────────────────
                  ElevatedButton(
                    onPressed: isLoading ? null : _handleContinue,
                    child: const Text(AppStrings.continueButton),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

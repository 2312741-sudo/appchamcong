import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_colors.dart';
import '../utils/version_utils.dart';

class AppVersionControlModel {
  final String latestVersion;
  final String minimumRequiredVersion;
  final String updateMessage;
  final String? updateUrlIos;
  final String? updateUrlAndroid;
  final String? updateUrl;

  const AppVersionControlModel({
    required this.latestVersion,
    required this.minimumRequiredVersion,
    required this.updateMessage,
    this.updateUrlIos,
    this.updateUrlAndroid,
    this.updateUrl,
  });

  factory AppVersionControlModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AppVersionControlModel(
      latestVersion: data['latestVersion'] as String? ?? '1.0.0',
      minimumRequiredVersion: data['minimumRequiredVersion'] as String? ?? '1.0.0',
      updateMessage: data['updateMessage'] as String? ??
          'Đã có phiên bản mới với nhiều cải tiến và sửa lỗi quan trọng. Vui lòng cập nhật ứng dụng.',
      updateUrlIos: data['updateUrlIos'] as String? ??
          'https://apps.apple.com/app/id6742385802',
      updateUrlAndroid: data['updateUrlAndroid'] as String? ??
          'https://play.google.com/store/apps/details?id=com.chamcong.chamCongTram',
      updateUrl: data['updateUrl'] as String?,
    );
  }

  String get targetStoreUrl {
    if (kIsWeb) {
      return updateUrl ?? 'https://webquanlychamcong.vercel.app';
    }
    if (Platform.isIOS) {
      return updateUrlIos ?? updateUrl ?? 'https://apps.apple.com/app/id6742385802';
    }
    if (Platform.isAndroid) {
      return updateUrlAndroid ?? updateUrl ?? 'https://play.google.com/store/apps/details?id=com.chamcong.chamCongTram';
    }
    return updateUrl ?? 'https://webquanlychamcong.vercel.app';
  }
}

class AppUpdateService {
  static final AppUpdateService _instance = AppUpdateService._internal();
  factory AppUpdateService() => _instance;
  AppUpdateService._internal();

  bool _isDialogShowing = false;

  /// Fetches version control configuration from Firestore collection `app_config`, doc `version_control`
  Future<AppVersionControlModel?> fetchVersionConfig() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('version_control')
          .get();

      if (!doc.exists) return null;
      return AppVersionControlModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('Failed to fetch version_control from Firestore: $e');
      return null;
    }
  }

  /// Checks the current app version against Firestore config.
  /// If force update is required, displays a blocking dialog.
  /// If optional update is available, displays a dismissible dialog.
  Future<void> checkAppVersion(
    BuildContext context, {
    bool isManualCheck = false,
  }) async {
    if (_isDialogShowing) return;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final config = await fetchVersionConfig();
      if (config == null) {
        if (isManualCheck && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không thể kết nối máy chủ để kiểm tra phiên bản')),
          );
        }
        return;
      }

      if (!context.mounted) return;

      // 1. Force update check: currentVersion < minimumRequiredVersion
      if (VersionUtils.isBelow(currentVersion, config.minimumRequiredVersion)) {
        _showUpdateDialog(
          context: context,
          isForce: true,
          config: config,
          currentVersion: currentVersion,
        );
        return;
      }

      // 2. Optional update check: currentVersion < latestVersion
      if (VersionUtils.isBelow(currentVersion, config.latestVersion)) {
        _showUpdateDialog(
          context: context,
          isForce: false,
          config: config,
          currentVersion: currentVersion,
        );
        return;
      }

      // 3. App is up to date
      if (isManualCheck && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bạn đang sử dụng phiên bản mới nhất ($currentVersion)'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error in checkAppVersion: $e');
    }
  }

  void _showUpdateDialog({
    required BuildContext context,
    required bool isForce,
    required AppVersionControlModel config,
    required String currentVersion,
  }) {
    _isDialogShowing = true;

    showDialog(
      context: context,
      barrierDismissible: !isForce,
      builder: (dialogCtx) => PopScope(
        canPop: !isForce,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          titlePadding: EdgeInsets.zero,
          title: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isForce
                  ? const Color(0xFFC8102E).withValues(alpha: 0.08)
                  : const Color(0xFF0284C7).withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isForce ? const Color(0xFFC8102E) : const Color(0xFF0284C7),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isForce ? Icons.system_update_rounded : Icons.new_releases_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  isForce ? 'Bắt buộc cập nhật ứng dụng' : 'Đã có phiên bản mới',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Phiên bản mới: v${config.latestVersion} (Hiện tại: v$currentVersion)',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                config.updateMessage.isNotEmpty
                    ? config.updateMessage
                    : 'Ứng dụng đã có bản cập nhật mới với nhiều cải tiến và tính năng hữu ích. Vui lòng cập nhật để có trải nghiệm tốt nhất.',
                style: GoogleFonts.beVietnamPro(
                  fontSize: 13.5,
                  color: const Color(0xFF334155),
                  height: 1.5,
                ),
              ),
              if (isForce) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Phiên bản hiện tại không còn được hỗ trợ. Bạn cần cập nhật để tiếp tục sử dụng.',
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 11.5,
                            color: const Color(0xFFB91C1C),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            if (!isForce)
              TextButton(
                onPressed: () {
                  _isDialogShowing = false;
                  Navigator.of(dialogCtx).pop();
                },
                child: Text(
                  'Để sau',
                  style: GoogleFonts.beVietnamPro(
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC8102E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () async {
                final url = config.targetStoreUrl;
                try {
                  final uri = Uri.parse(url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                } catch (e) {
                  debugPrint('Failed to launch store URL: $e');
                }
              },
              child: Text(
                'Cập nhật ngay',
                style: GoogleFonts.beVietnamPro(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    ).then((_) {
      _isDialogShowing = false;
    });
  }
}

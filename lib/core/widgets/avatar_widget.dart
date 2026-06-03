import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../constants/app_colors.dart';

class AvatarWidget extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final double radius;
  final Color? backgroundColor;

  const AvatarWidget({
    super.key,
    this.avatarUrl,
    required this.name,
    this.radius = 24,
    this.backgroundColor,
  });

  String get _initials {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.isNotEmpty ? parts.first[0].toUpperCase() : '?';
    }
    final first = parts.first.isNotEmpty ? parts.first[0] : '';
    final last = parts.last.isNotEmpty ? parts.last[0] : '';
    return '$first$last'.toUpperCase();
  }

  Color _getColorFromName() {
    if (name.isEmpty) return AppColors.primary;
    final colors = [
      AppColors.primary,
      AppColors.info,
      AppColors.success,
      const Color(0xFF7B2FBE),
      const Color(0xFFE07B39),
      const Color(0xFF2196F3),
      const Color(0xFF009688),
    ];
    final index = name.codeUnitAt(0) % colors.length;
    return colors[index];
  }

  @override
  Widget build(BuildContext context) {
    final hasAvatar = avatarUrl != null && avatarUrl!.isNotEmpty;
    final bgColor = backgroundColor ?? _getColorFromName();
    final diameter = radius * 2;

    if (!hasAvatar) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: bgColor,
        child: Text(
          _initials,
          style: TextStyle(
            color: AppColors.white,
            fontSize: radius * 0.6,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: avatarUrl!,
        width: diameter,
        height: diameter,
        fit: BoxFit.cover,
        placeholder: (context, url) => Shimmer.fromColors(
          baseColor: const Color(0xFFECE8E2),
          highlightColor: const Color(0xFFF8F4EE),
          child: Container(
            width: diameter,
            height: diameter,
            color: AppColors.white,
          ),
        ),
        errorWidget: (context, url, error) => CircleAvatar(
          radius: radius,
          backgroundColor: bgColor,
          child: Text(
            _initials,
            style: TextStyle(
              color: AppColors.white,
              fontSize: radius * 0.6,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand Colors
  static const Color primary = Color(0xFFCB2D2E); // Red from logo
  static const Color success = Color(0xFF1A6B5A); // Teal green
  static const Color accent = Color(0xFFEB9B28); // Orange/Yellow from logo
  static const Color info = Color(0xFF1C4E6B);
  static const Color neutral = Color(0xFF1A1A1A);
  static const Color surface = Color(0xFFF8F4EE);
  static const Color background = Color(0xFFF8F4EE);
  static const Color white = Colors.white;

  // Semantic Colors
  static const Color checkIn = success;
  static const Color checkOut = Color(0xFF888780);
  static const Color pending = accent;
  static const Color danger = primary;

  // Text Colors
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B6B6B);
  static const Color textDisabled = Color(0xFFAAAAAA);
  static const Color textOnPrimary = Colors.white;

  // Border & Divider
  static const Color border = Color(0xFFE0DAD4);
  static const Color divider = Color(0xFFECE8E2);

  // Card & Shadow
  static const Color cardSurface = Color(0xFFFFFFFF);
  static const Color shadow = Color(0x1A000000);

  // Status Colors
  static const Color statusActive = success;
  static const Color statusInactive = Color(0xFF888780);
  static const Color statusPending = accent;
  static const Color statusDanger = primary;

  // Role Badge Colors
  static const Color ownerBadge = primary;
  static const Color managerBadge = info;
  static const Color employeeBadge = Color(0xFF888780);

  // Shift Colors
  static const Color shiftMorning = Color(0xFFF5C842);
  static const Color shiftAfternoon = Color(0xFFFF8C42);
  static const Color shiftEvening = Color(0xFF1C4E6B);
  static const Color shiftOff = Color(0xFFCCCCCC);

  // Gradient Definitions
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE8192F), Color(0xFFC8102E)],
  );

  static const LinearGradient darkGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1A1A1A), Color(0xFF2D2D2D)],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF22876D), Color(0xFF1A6B5A)],
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFC8102E), Color(0xFFF8F4EE)],
    stops: [0.0, 0.45],
  );

  static const RadialGradient checkInButtonGradient = RadialGradient(
    colors: [Color(0xFF22876D), Color(0xFF1A6B5A)],
    radius: 0.85,
  );

  static const RadialGradient checkOutButtonGradient = RadialGradient(
    colors: [Color(0xFFE8192F), Color(0xFFC8102E)],
    radius: 0.85,
  );
}

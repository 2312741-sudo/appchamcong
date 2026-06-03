import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AttendanceHistoryScreen extends ConsumerWidget {
  final String? userId;
  const AttendanceHistoryScreen({super.key, this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử chấm công'),
      ),
      body: const Center(
        child: Text('Lịch sử chấm công cá nhân'),
      ),
    );
  }
}

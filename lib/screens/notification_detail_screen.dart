import 'package:flutter/material.dart';

import '../models/notification_detail.dart';

// Design Ref: §5 — 알림 상세 전체 화면 (보텀시트 대체, 긴 본문 전체 스크롤)
// Plan SC: SC-01/SC-03 — 상세 페이지 신설, 긴 본문 끝까지 스크롤
class NotificationDetailScreen extends StatelessWidget {
  final NotificationDetail detail;

  const NotificationDetailScreen({super.key, required this.detail});

  @override
  Widget build(BuildContext context) {
    final body = detail.body.trim();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '알림',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1B2E5C),
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1B2E5C)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                detail.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1B2E5C),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _formatTime(detail.createDT),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
              ),
              const SizedBox(height: 16),
              Divider(color: Colors.grey.shade200, height: 1),
              const SizedBox(height: 16),
              SelectableText(
                body.isEmpty ? '내용이 없습니다' : body,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.6,
                  color: body.isEmpty ? Colors.grey.shade400 : const Color(0xFF3A3A3A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '방금 전';
    try {
      final dt = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return '방금 전';
      if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
      if (diff.inHours < 24) return '${diff.inHours}시간 전';
      return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }
}

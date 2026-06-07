import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../models/notification_detail.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

// Design Ref: §5 — 알림 상세 전체 화면 (보텀시트 대체, 긴 본문 전체 스크롤)
// Plan SC: SC-01/SC-03 — 상세 페이지 신설, 긴 본문 끝까지 스크롤
// alertRef가 있으면 /api/IV/monitor/alerts/{id}에서 ai_commentary 전체를 조회해 표시
class NotificationDetailScreen extends StatefulWidget {
  final NotificationDetail detail;

  const NotificationDetailScreen({super.key, required this.detail});

  @override
  State<NotificationDetailScreen> createState() =>
      _NotificationDetailScreenState();
}

class _NotificationDetailScreenState extends State<NotificationDetailScreen> {
  bool _loading = false;
  String? _fullBody; // ai_commentary (전체)
  String? _stockName;
  String? _sentAt;

  @override
  void initState() {
    super.initState();
    if (widget.detail.alertRef != null) {
      _loadAlertDetail(widget.detail.alertRef!);
    }
  }

  Future<void> _loadAlertDetail(int id) async {
    final user = AuthService().currentUser;
    if (user == null) return;

    setState(() => _loading = true);
    try {
      final data = await ApiService.get(
        '${ApiConfig.monitorAlerts}/$id',
        params: {'companyKey': user.companyKey, 'userId': user.userId},
      );
      if (data['resultCode'] == '200' && data['res'] != null) {
        final res = Map<String, dynamic>.from(data['res'] as Map);
        final commentary = (res['ai_commentary'] as String?)?.trim();
        final summary = (res['summary'] as String?)?.trim();
        if (mounted) {
          setState(() {
            _fullBody = (commentary != null && commentary.isNotEmpty)
                ? commentary
                : (summary?.isNotEmpty == true ? summary : null);
            _stockName = res['stock_name'] as String?;
            _sentAt = res['sent_at'] as String?;
          });
        }
      }
    } catch (_) {
      // 실패 시 기존 body로 폴백 (build에서 처리)
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = widget.detail;
    final body = (_fullBody ?? detail.body).trim();
    final timeStr = _formatTime(_sentAt ?? detail.createDT);

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
              if (_stockName != null && _stockName!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  _stockName!,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                timeStr,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
              ),
              const SizedBox(height: 16),
              Divider(color: Colors.grey.shade200, height: 1),
              const SizedBox(height: 16),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                SelectableText(
                  body.isEmpty ? '내용이 없습니다' : body,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    color: body.isEmpty
                        ? Colors.grey.shade400
                        : const Color(0xFF3A3A3A),
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
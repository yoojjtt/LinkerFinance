import 'package:flutter/material.dart';

import '../notification_list_screen.dart';

// Design Ref: §5.3 — 더보기 메뉴 화면 (껍데기)
// Plan SC: SC-04 — 더보기 탭에서 알림센터 진입 가능

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _buildMenuItem(
          context,
          icon: Icons.radar,
          title: 'AI 스캐너',
          subtitle: '종합 AI 종목 분석',
          isReady: false,
        ),
        _buildMenuItem(
          context,
          icon: Icons.notifications_outlined,
          title: '알림센터',
          subtitle: '푸시 알림 내역',
          isReady: true,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationListScreen()),
          ),
        ),
        _buildMenuItem(
          context,
          icon: Icons.hub_outlined,
          title: '인사이트맵',
          subtitle: '시장 연관관계 시각화',
          isReady: false,
        ),
        _buildMenuItem(
          context,
          icon: Icons.alarm,
          title: '가격알림',
          subtitle: '목표가 도달 알림 설정',
          isReady: false,
        ),
        _buildMenuItem(
          context,
          icon: Icons.analytics_outlined,
          title: '퀀트 스크리너',
          subtitle: '조건 기반 종목 필터링',
          isReady: false,
        ),
      ],
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isReady,
    VoidCallback? onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF1B2E5C).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF1B2E5C), size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF333333),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        trailing: isReady
            ? const Icon(Icons.chevron_right, color: Colors.grey)
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '준비 중',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
        onTap: isReady
            ? onTap
            : () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$title 기능은 준비 중입니다'),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              },
      ),
    );
  }
}

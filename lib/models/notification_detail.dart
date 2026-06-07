import 'package:firebase_messaging/firebase_messaging.dart';

// Design Ref: §3.1 — 목록(log Map)/푸시(RemoteMessage) 두 출처를 한 곳에서 정규화하는 값 객체
class NotificationDetail {
  final int? seq; // fcm_send_log 식별자 (읽음 처리용)
  final int? alertRef; // alert_history.id — null 아니면 ai_commentary 전체 조회 가능
  final String title;
  final String body; // 푸시/목록의 (잘린) 본문 — alertRef 없을 때 표시
  final String? createDT; // ISO 문자열 (목록은 보유, 푸시는 null → '방금 전')

  const NotificationDetail({
    this.seq,
    this.alertRef,
    required this.title,
    required this.body,
    this.createDT,
  });

  // 목록 항목(log Map) → 상세
  factory NotificationDetail.fromLog(Map<String, dynamic> log) {
    return NotificationDetail(
      seq: _toInt(log['seq']),
      alertRef: _toInt(log['alert_ref']),
      title: log['title'] as String? ?? '알림',
      body: log['body'] as String? ?? '',
      createDT: log['create_DT'] as String?,
    );
  }

  // 푸시(RemoteMessage) → 상세
  // Plan SC: SC-04/05/06 — 푸시 탭 진입 시 내용 표시
  factory NotificationDetail.fromMessage(RemoteMessage m) {
    final data = m.data;
    return NotificationDetail(
      seq: _toInt(data['seq']),
      alertRef: _toInt(data['alert_ref']),
      title: m.notification?.title ?? data['title'] as String? ?? '알림',
      body: m.notification?.body ?? data['body'] as String? ?? '',
      createDT: null,
    );
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse('$v');
  }
}
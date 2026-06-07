import 'package:firebase_messaging/firebase_messaging.dart';

// Design Ref: §3.1 — 목록(log Map)/푸시(RemoteMessage) 두 출처를 한 곳에서 정규화하는 값 객체
class NotificationDetail {
  final int? seq; // 서버 로그 식별자 (푸시 data에 없으면 null)
  final String title;
  final String body; // 전체 본문 (잘리지 않음)
  final String? createDT; // ISO 문자열 (목록은 보유, 푸시는 null → '방금 전')

  const NotificationDetail({
    this.seq,
    required this.title,
    required this.body,
    this.createDT,
  });

  // 목록 항목(log Map) → 상세
  factory NotificationDetail.fromLog(Map<String, dynamic> log) {
    return NotificationDetail(
      seq: log['seq'] as int?,
      title: log['title'] as String? ?? '알림',
      body: log['body'] as String? ?? '',
      createDT: log['create_DT'] as String?,
    );
  }

  // 푸시(RemoteMessage) → 상세
  // Plan SC: SC-04/05/06 — 푸시 탭 진입 시 내용 표시. notification.body는 잘리지 않음
  factory NotificationDetail.fromMessage(RemoteMessage m) {
    final data = m.data;
    final seqRaw = data['seq'];
    return NotificationDetail(
      seq: seqRaw is int ? seqRaw : int.tryParse('${seqRaw ?? ''}'),
      title: m.notification?.title ?? data['title'] as String? ?? '알림',
      body: m.notification?.body ?? data['body'] as String? ?? '',
      createDT: null,
    );
  }
}

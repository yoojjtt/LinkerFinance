import 'dart:developer' as dev;
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/api_config.dart';
import '../models/notification_detail.dart';
import '../models/notification_model.dart';
import '../screens/notification_detail_screen.dart';
import 'api_service.dart';
import 'auth_service.dart';

class FcmService {
  static final FcmService _instance = FcmService._();
  factory FcmService() => _instance;
  FcmService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final List<NotificationModel> notifications = [];
  final ValueNotifier<int> unreadCount = ValueNotifier(0);
  final _storage = const FlutterSecureStorage();

  int? _tokenSeq;
  bool _pushEnabled = true;

  GlobalKey<NavigatorState>? navigatorKey;

  // Design Ref: §4.2 — 콜드스타트(앱 종료 상태) 푸시 탭 시 navigatorKey 준비 전 보존
  NotificationDetail? _pendingDetail;

  Future<void> initialize() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    dev.log('FCM 권한 상태: ${settings.authorizationStatus}');

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    try {
      final token = await _messaging.getToken();
      dev.log('FCM Token: $token');
    } catch (e) {
      dev.log('FCM 토큰 가져오기 실패 (시뮬레이터?): $e');
    }

    _pushEnabled = await getPushEnabled();
    final savedSeq = await _storage.read(key: 'fcm_token_seq');
    if (savedSeq != null) _tokenSeq = int.tryParse(savedSeq);

    final user = AuthService().currentUser;
    if (user != null && _pushEnabled) {
      try {
        await registerToken(user.userId, int.parse(user.companyKey));
      } catch (_) {}
    }

    await fetchUnreadCount();

    _messaging.onTokenRefresh.listen((newToken) {
      dev.log('FCM Token 갱신: $newToken');
      final user = AuthService().currentUser;
      if (user != null && _pushEnabled) {
        registerToken(user.userId, int.parse(user.companyKey));
      }
    });

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Plan SC: SC-06 — 종료 상태에서 푸시 탭 시 앱 시작 후 상세 진입 (홈 마운트 후 flush)
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _addNotification(initialMessage, isRead: true);
      _pendingDetail = NotificationDetail.fromMessage(initialMessage);
    }
  }

  // Design Ref: §4.2 — 상세 진입 + 읽음 처리. navigatorKey 미준비 시 보류
  void _openDetail(NotificationDetail detail) {
    final nav = navigatorKey?.currentState;
    if (nav == null) {
      _pendingDetail = detail;
      return;
    }
    nav.push(
      MaterialPageRoute(
        builder: (_) => NotificationDetailScreen(detail: detail),
      ),
    );
    // Plan SC: SC-04 — 읽음 PUT 완료(await) 후 카운트 조회 (경합 제거)
    // Design Ref: §5.2
    if (detail.seq != null) {
      markLogAsRead(detail.seq!).then((_) => fetchUnreadCount());
    }
  }

  // 앱이 로그인/홈까지 준비된 뒤 호출 (HomeScreen initState)
  void flushPendingDetail() {
    final d = _pendingDetail;
    if (d != null) {
      _pendingDetail = null;
      _openDetail(d);
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    dev.log('──── FCM 메시지 수신 ────');
    dev.log('title: ${message.notification?.title}');
    dev.log('body: ${message.notification?.body}');
    dev.log('data: ${message.data}');
    dev.log('apple badge: ${message.notification?.apple?.badge}');
    dev.log('apple sound: ${message.notification?.apple?.sound?.name}');
    _addNotification(message);
    _showInAppNotification(message);
    fetchUnreadCount();
  }

  // Plan SC: SC-05 — 백그라운드 상태 푸시 탭 시 상세 페이지로 자동 진입
  void _handleMessageOpenedApp(RemoteMessage message) {
    dev.log('알림 탭으로 앱 열림: ${message.notification?.title}');
    dev.log('알림 탭 data: ${message.data}'); // V-01: seq 포함 여부 검증용
    _addNotification(message, isRead: true);
    fetchUnreadCount();
    _openDetail(NotificationDetail.fromMessage(message));
  }

  void _addNotification(RemoteMessage message, {bool isRead = false}) {
    final notification = NotificationModel(
      id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: message.notification?.title ?? '알림',
      body: message.notification?.body ?? '',
      receivedAt: DateTime.now(),
      data: message.data,
      isRead: isRead,
    );
    notifications.insert(0, notification);
    // Design Ref: §5.4 — 안읽음 수 단일 진실은 서버(fetchUnreadCount). 인메모리 리스트는 표시용.
    // (호출부에서 fetchUnreadCount()로 동기화 → 깜빡임 방지, Plan SC: SC-07)
  }

  void _showInAppNotification(RemoteMessage message) {
    final context = navigatorKey?.currentContext;
    if (context == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.notification?.title ?? '알림',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (message.notification?.body != null)
              Text(
                message.notification!.body!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          // Plan SC: SC-04 — 포그라운드 스낵바 '보기' 탭 시 상세 페이지로 이동
          label: '보기',
          textColor: Colors.white,
          onPressed: () {
            _openDetail(NotificationDetail.fromMessage(message));
          },
        ),
      ),
    );
  }

  // Design Ref: §5.4 — 안읽음 수 단일 진실은 서버(fetchUnreadCount).
  // 인메모리 리스트 기반 카운트 메서드는 제거(미사용 + 서버값과 충돌 방지).

  Future<void> fetchUnreadCount() async {
    final user = AuthService().currentUser;
    if (user == null) {
      dev.log('fetchUnreadCount: user is null, skip');
      return;
    }
    try {
      dev.log('fetchUnreadCount: user_id=${user.userId}, company_key=${user.companyKey}, app_type=FINANCE');
      final data = await ApiService.get(
        ApiConfig.fcmLogUnreadCount,
        params: {
          'company_key': user.companyKey,
          'user_id': user.userId,
          'app_type': 'FINANCE',
        },
      );
      dev.log('fetchUnreadCount 응답: $data');
      if (data['resultCode'] == '200') {
        final count = (data['res'] as int?) ?? 0;
        unreadCount.value = count;
        dev.log('fetchUnreadCount: unreadCount=$count');
        _updateAppBadge(count);
      }
    } catch (e) {
      dev.log('fetchUnreadCount 에러: $e');
    }
  }

  void _updateAppBadge(int count) {
    try {
      if (count > 0) {
        FlutterAppBadger.updateBadgeCount(count);
        dev.log('앱 뱃지 업데이트: $count');
      } else {
        FlutterAppBadger.removeBadge();
        dev.log('앱 뱃지 제거');
      }
    } catch (e) {
      dev.log('앱 뱃지 업데이트 실패: $e');
    }
  }

  Future<void> markLogAsRead(int seq) async {
    try {
      await ApiService.put(
        ApiConfig.fcmLogRead,
        params: {'seq': '$seq'},
      );
    } catch (_) {}
  }

  Future<void> markAllLogsAsRead() async {
    final user = AuthService().currentUser;
    if (user == null) return;
    try {
      await ApiService.put(
        ApiConfig.fcmLogReadAll,
        params: {
          'company_key': user.companyKey,
          'user_id': user.userId,
          'app_type': 'FINANCE',
        },
      );
      // Design Ref: §5.1 — Plan SC: SC-03, 모두읽음 즉시 OS 아이콘 뱃지 제거
      unreadCount.value = 0;
      _updateAppBadge(0);
    } catch (_) {}
  }

  Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (_) {
      return null;
    }
  }

  Future<void> registerToken(String userId, int companyKey) async {
    try {
      final token = await _messaging.getToken();
      if (token == null) {
        dev.log('FCM 토큰 없음 (시뮬레이터?)');
        return;
      }

      final deviceOs = Platform.isIOS ? 'iOS' : 'ANDROID';
      dev.log('──── FCM 토큰 등록 요청 ────');
      dev.log('user_id: $userId');
      dev.log('company_key: $companyKey');
      dev.log('app_type: FINANCE');
      dev.log('device_os: $deviceOs');
      dev.log('token: ${token.substring(0, 20)}...');
      dev.log('endpoint: ${ApiConfig.fcmTokenAccess}');

      final data = await ApiService.post(ApiConfig.fcmTokenAccess, {
        'company_key': companyKey,
        'user_id': userId,
        'app_type': 'FINANCE',
        'token': token,
        'device_os': deviceOs,
      });

      dev.log('응답 resultCode: ${data['resultCode']}');
      dev.log('응답 res: ${data['res']}');

      if (data['resultCode'] == '200') {
        _tokenSeq = data['res'] as int;
        await _storage.write(key: 'fcm_token_seq', value: '$_tokenSeq');
        dev.log('✅ FCM 토큰 서버 등록 완료 (seq: $_tokenSeq)');
      } else {
        dev.log('⚠️ FCM 토큰 등록 실패 - resultCode: ${data['resultCode']}');
      }
    } catch (e) {
      dev.log('FCM 토큰 서버 등록 실패: $e');
    }
  }

  Future<void> deactivateToken() async {
    if (_tokenSeq == null) return;
    try {
      await ApiService.put(
        ApiConfig.fcmTokenDeactivate,
        params: {'seq': '$_tokenSeq'},
      );
      dev.log('FCM 토큰 비활성화 완료 (seq: $_tokenSeq)');
    } catch (e) {
      dev.log('FCM 토큰 비활성화 실패: $e');
      rethrow;
    }
  }

  Future<void> setPushEnabled(bool enabled) async {
    if (enabled) {
      final user = AuthService().currentUser;
      if (user != null) {
        await registerToken(user.userId, int.parse(user.companyKey));
      }
    } else {
      await deactivateToken();
    }
    _pushEnabled = enabled;
    await _storage.write(key: 'push_enabled', value: '$enabled');
  }

  Future<bool> getPushEnabled() async {
    final value = await _storage.read(key: 'push_enabled');
    return value != 'false';
  }
}

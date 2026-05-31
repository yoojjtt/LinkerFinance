import 'dart:developer' as dev;
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/api_config.dart';
import '../models/notification_model.dart';
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

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _addNotification(initialMessage, isRead: true);
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    dev.log('포그라운드 메시지 수신: ${message.notification?.title}');
    _addNotification(message);
    _showInAppNotification(message);
    fetchUnreadCount();
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    dev.log('알림 탭으로 앱 열림: ${message.notification?.title}');
    _addNotification(message, isRead: true);
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
    _updateUnreadCount();
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
          label: '보기',
          textColor: Colors.white,
          onPressed: () {
            navigatorKey?.currentState?.pushNamed('/notifications');
          },
        ),
      ),
    );
  }

  void markAsRead(String id) {
    final notification = notifications.where((n) => n.id == id).firstOrNull;
    if (notification != null) {
      notification.isRead = true;
      _updateUnreadCount();
    }
  }

  void markAllAsRead() {
    for (final n in notifications) {
      n.isRead = true;
    }
    _updateUnreadCount();
  }

  void deleteNotification(String id) {
    notifications.removeWhere((n) => n.id == id);
    _updateUnreadCount();
  }

  void _updateUnreadCount() {
    unreadCount.value = notifications.where((n) => !n.isRead).length;
  }

  Future<void> fetchUnreadCount() async {
    final user = AuthService().currentUser;
    if (user == null) return;
    try {
      final data = await ApiService.get(
        ApiConfig.fcmLogUnreadCount,
        params: {
          'user_id': user.userId,
          'app_type': 'FINANCE',
        },
      );
      if (data['resultCode'] == '200') {
        unreadCount.value = (data['res'] as int?) ?? 0;
      }
    } catch (_) {}
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
          'user_id': user.userId,
          'app_type': 'FINANCE',
        },
      );
      unreadCount.value = 0;
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

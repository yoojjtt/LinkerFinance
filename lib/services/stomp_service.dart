import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../config/api_config.dart';
import '../models/realtime_price_model.dart';
import 'api_service.dart';

// Design Ref: §4 — STOMP WebSocket 싱글톤 서비스
// Plan SC: SC-02, SC-03, SC-04

/// 연결 실패 시 외부에 알리기 위한 콜백
typedef StompErrorCallback = void Function();

class StompService {
  static final StompService _instance = StompService._();
  factory StompService() => _instance;
  StompService._();

  StompClient? _client;
  // Gap Fix #1: StompUnsubscribe 타입으로 실제 STOMP 구독 해제 가능
  final Map<String, StompUnsubscribe> _subscriptions = {};
  final Map<String, Function(RealtimePrice)> _callbacks = {};
  bool _isConnected = false;

  // Gap Fix #2: retry 카운트 — 3회 실패 시 disconnect
  int _retryCount = 0;
  static const _maxRetries = 3;
  StompErrorCallback? onMaxRetriesReached;

  bool get isConnected => _isConnected;

  /// STOMP 연결 시작
  Future<bool> connect() async {
    if (_isConnected && _client != null) return true;

    // 서버 스트림 연결 확인 (실패해도 STOMP 시도)
    try {
      await ApiService.post(ApiConfig.streamConnect, {});
      debugPrint('[StompService] streamConnect 성공');
    } catch (e) {
      debugPrint('[StompService] streamConnect 실패 (무시): $e');
    }

    final completer = Completer<bool>();

    _client = StompClient(
      config: StompConfig.sockJS(
        url: '${ApiConfig.baseUrl}/ws',
        onConnect: (StompFrame frame) {
          debugPrint('[StompService] STOMP 연결 성공');
          _isConnected = true;
          _retryCount = 0; // 연결 성공 시 리셋
          _resubscribeAll();
          if (!completer.isCompleted) completer.complete(true);
        },
        onDisconnect: (StompFrame frame) {
          debugPrint('[StompService] STOMP 연결 해제');
          _isConnected = false;
          _subscriptions.clear();
        },
        onStompError: (StompFrame frame) {
          debugPrint('[StompService] STOMP 에러: ${frame.headers['message']}');
          _isConnected = false;
          _handleRetry();
          if (!completer.isCompleted) completer.complete(false);
        },
        onWebSocketError: (error) {
          debugPrint('[StompService] WebSocket 에러: $error');
          _isConnected = false;
          _handleRetry();
          if (!completer.isCompleted) completer.complete(false);
        },
        reconnectDelay: const Duration(seconds: 3),
      ),
    );

    _client!.activate();

    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        debugPrint('[StompService] 연결 타임아웃');
        return _isConnected;
      },
    );
  }

  /// Gap Fix #2: retry 카운트 관리
  void _handleRetry() {
    _retryCount++;
    debugPrint('[StompService] 재시도 $_retryCount/$_maxRetries');
    if (_retryCount >= _maxRetries) {
      debugPrint('[StompService] 최대 재시도 초과 — 연결 종료');
      disconnect();
      onMaxRetriesReached?.call();
    }
  }

  /// 특정 종목 체결가 구독
  void subscribe(String stockCode, Function(RealtimePrice) onPrice) {
    if (_subscriptions.containsKey(stockCode)) return;

    _callbacks[stockCode] = onPrice;

    if (!_isConnected || _client == null) {
      connect(); // 연결 후 _resubscribeAll에서 자동 구독
      return;
    }

    _doSubscribe(stockCode);
  }

  void _doSubscribe(String stockCode) {
    final callback = _callbacks[stockCode];
    if (callback == null || _client == null) return;

    final unsubscribeFn = _client!.subscribe(
      destination: '/topic/kiwoom/price/$stockCode',
      callback: (StompFrame frame) {
        if (frame.body == null) return;
        try {
          final json = jsonDecode(frame.body!) as Map<String, dynamic>;
          final price = RealtimePrice.fromJson(json);
          callback(price);
        } catch (e) {
          debugPrint('[StompService] 메시지 파싱 에러: $e');
        }
      },
    );

    _subscriptions[stockCode] = unsubscribeFn;
    debugPrint('[StompService] 구독: $stockCode');
  }

  void _resubscribeAll() {
    _subscriptions.clear();
    for (final code in _callbacks.keys.toList()) {
      _doSubscribe(code);
    }
  }

  /// Gap Fix #1: 실제 STOMP 프로토콜 레벨 구독 해제
  void unsubscribe(String stockCode) {
    final unsubscribeFn = _subscriptions.remove(stockCode);
    if (unsubscribeFn != null) {
      try {
        unsubscribeFn(); // STOMP 프로토콜 레벨 구독 해제
      } catch (e) {
        debugPrint('[StompService] 구독 해제 에러: $e');
      }
    }
    _callbacks.remove(stockCode);
    debugPrint('[StompService] 구독 해제: $stockCode');

    if (_subscriptions.isEmpty && _callbacks.isEmpty) {
      disconnect();
    }
  }

  /// 모든 구독 해제
  void unsubscribeAll() {
    for (final fn in _subscriptions.values) {
      try { fn(); } catch (_) {}
    }
    _subscriptions.clear();
    _callbacks.clear();
    disconnect();
  }

  /// STOMP 연결 종료
  void disconnect() {
    _isConnected = false;
    _retryCount = 0;
    try {
      _client?.deactivate();
    } catch (_) {}
    _client = null;
    _subscriptions.clear();
    _callbacks.clear();
    debugPrint('[StompService] 연결 종료');
  }
}

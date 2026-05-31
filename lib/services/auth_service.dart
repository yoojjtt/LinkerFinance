import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/api_config.dart';
import '../models/user_model.dart';
import 'api_service.dart';
import 'fcm_service.dart';

// Design Ref: §5.3 — 싱글톤 AuthService, 자격증명 메모리 보관 (로그아웃 API 필요)
class AuthService {
  static final AuthService _instance = AuthService._();
  factory AuthService() => _instance;
  AuthService._();

  final _storage = const FlutterSecureStorage();

  UserModel? currentUser;
  String? _username;
  String? _password;

  // Plan SC: SC-01, SC-02 — 로그인 성공/실패 처리
  Future<({bool success, String message})> login(
    String username,
    String password,
  ) async {
    final data = await ApiService.post(ApiConfig.login, {
      'username': username,
      'password': password,
    });
    if (data['resultCode'] == '200') {
      final list = data['res'] as List;
      currentUser = UserModel.fromJson(list[0] as Map<String, dynamic>);
      _username = username;
      _password = password;

      // 로그인 성공 후 FCM 토큰 서버 등록
      try {
        final pushEnabled = await FcmService().getPushEnabled();
        if (pushEnabled) {
          await FcmService().registerToken(
            currentUser!.userId,
            int.parse(currentUser!.companyKey),
          );
        }
      } catch (e) {
        debugPrint('FCM 토큰 등록 실패: $e');
      }

      return (success: true, message: '');
    }
    return (success: false, message: _loginErrorMessage(data['resultCode']));
  }

  // Plan SC: SC-09 — 로그아웃 시 세션/자동로그인 정보 삭제
  Future<void> logout() async {
    if (_username != null && _password != null) {
      try {
        await ApiService.post(ApiConfig.logout, {
          'username': _username!,
          'password': _password!,
        });
      } catch (_) {}
    }
    currentUser = null;
    _username = null;
    _password = null;
    try {
      await clearAutoLogin();
    } catch (_) {}
  }

  // Plan SC: SC-03 — 자동로그인 저장/읽기/삭제
  Future<void> saveAutoLogin(String username, String password) async {
    try {
      await _storage.write(key: 'username', value: username);
      await _storage.write(key: 'password', value: password);
    } catch (_) {}
  }

  Future<({String? username, String? password})> getAutoLogin() async {
    try {
      final username = await _storage.read(key: 'username');
      final password = await _storage.read(key: 'password');
      return (username: username, password: password);
    } catch (_) {
      return (username: null, password: null);
    }
  }

  Future<void> clearAutoLogin() async {
    await _storage.deleteAll();
  }

  Future<UserModel?> refreshMyInfo() async {
    if (currentUser == null) return null;
    final data = await ApiService.post(ApiConfig.myInfo, {
      'user_id': currentUser!.userId,
    });
    if (data['resultCode'] == '200') {
      currentUser = UserModel.fromJson(data['res'] as Map<String, dynamic>);
      return currentUser;
    }
    return null;
  }

  String _loginErrorMessage(dynamic code) {
    switch (code.toString()) {
      case '300':
        return '비밀번호가 일치하지 않습니다.';
      case '400':
        return '등록되지 않은 계정입니다.';
      default:
        return '로그인에 실패했습니다.';
    }
  }
}

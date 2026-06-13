import '../config/api_config.dart';
import '../models/psych_model.dart';
import 'api_service.dart';
import 'auth_service.dart';

class PsychService {
  static String get _ck => AuthService().currentUser?.companyKey ?? '';
  static String get _uid => AuthService().currentUser?.userId ?? '';

  static bool _ok(Map<String, dynamic> d) => d['res'] == 'success' || d['resultCode'] == '200';
  static dynamic _data(Map<String, dynamic> d) => d['data'] ?? d['res'];

  // 투자 원칙
  static Future<List<TradingRule>> getRules() async {
    try {
      final d = await ApiService.get('${ApiConfig.psych}/rules', params: {'company_key': _ck, 'user_id': _uid});
      if (_ok(d) && _data(d) is List) {
        return (_data(d) as List).map((e) => TradingRule.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<bool> createRule(TradingRule rule) async {
    try {
      final body = rule.toJson()..['company_key'] = _ck..['user_id'] = _uid;
      final d = await ApiService.post('${ApiConfig.psych}/rules', body);
      return _ok(d);
    } catch (_) {}
    return false;
  }

  static Future<bool> updateRule(String id, TradingRule rule) async {
    try {
      final body = rule.toJson()..['company_key'] = _ck..['user_id'] = _uid;
      final d = await ApiService.putBody('${ApiConfig.psych}/rules/$id', body);
      return _ok(d);
    } catch (_) {}
    return false;
  }

  static Future<bool> deleteRule(String id) async {
    try {
      final d = await ApiService.delete('${ApiConfig.psych}/rules/$id');
      return _ok(d);
    } catch (_) {}
    return false;
  }

  // 체크리스트 이력
  static Future<List<PsychChecklist>> getChecklists() async {
    try {
      final d = await ApiService.get('${ApiConfig.psych}/checklists', params: {'company_key': _ck, 'user_id': _uid});
      if (_ok(d) && _data(d) is List) {
        return (_data(d) as List).map((e) => PsychChecklist.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  // 준수율 통계
  static Future<ComplianceStats?> getComplianceStats() async {
    try {
      final d = await ApiService.get('${ApiConfig.psych}/stats/compliance', params: {'company_key': _ck, 'user_id': _uid});
      if (_ok(d) && _data(d) is Map) return ComplianceStats.fromJson(_data(d) as Map<String, dynamic>);
    } catch (_) {}
    return null;
  }
}

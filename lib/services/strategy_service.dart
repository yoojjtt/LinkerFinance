import '../config/api_config.dart';
import '../models/strategy_model.dart';
import 'api_service.dart';
import 'auth_service.dart';

class StrategyService {
  static String get _ck => AuthService().currentUser?.companyKey ?? '';
  static String get _uid => AuthService().currentUser?.userId ?? '';

  static bool _ok(Map<String, dynamic> d) => d['res'] == 'success' || d['resultCode'] == '200';
  static dynamic _data(Map<String, dynamic> d) => d['data'] ?? d['res'];

  static Future<List<TradingStrategy>> getList() async {
    try {
      final d = await ApiService.get(ApiConfig.strategy, params: {'company_key': _ck, 'user_id': _uid});
      if (_ok(d) && _data(d) is List) {
        return (_data(d) as List).map((e) => TradingStrategy.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<TradingStrategy?> getDetail(String id) async {
    try {
      final d = await ApiService.get('${ApiConfig.strategy}/$id');
      if (_ok(d) && _data(d) is Map) return TradingStrategy.fromJson(_data(d) as Map<String, dynamic>);
    } catch (_) {}
    return null;
  }

  static Future<bool> create(TradingStrategy s) async {
    try {
      final body = s.toJson()..['company_key'] = _ck..['user_id'] = _uid;
      final d = await ApiService.post(ApiConfig.strategy, body);
      return _ok(d);
    } catch (_) {}
    return false;
  }

  static Future<bool> update(String id, TradingStrategy s) async {
    try {
      final body = s.toJson()..['company_key'] = _ck..['user_id'] = _uid;
      final d = await ApiService.putBody('${ApiConfig.strategy}/$id', body);
      return _ok(d);
    } catch (_) {}
    return false;
  }

  static Future<bool> delete(String id) async {
    try {
      final d = await ApiService.delete('${ApiConfig.strategy}/$id');
      return _ok(d);
    } catch (_) {}
    return false;
  }

  static Future<bool> updateSteps(String id, List<StrategyStep> steps) async {
    try {
      final d = await ApiService.putBody('${ApiConfig.strategy}/$id/steps', {
        'steps': steps.map((s) => s.toJson()).toList(),
      });
      return _ok(d);
    } catch (_) {}
    return false;
  }
}

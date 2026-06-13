import '../config/api_config.dart';
import '../models/event_model.dart';
import 'api_service.dart';
import 'auth_service.dart';

class EventService {
  static String get _ck => AuthService().currentUser?.companyKey ?? '';
  static String get _uid => AuthService().currentUser?.userId ?? '';

  static bool _ok(Map<String, dynamic> d) => d['res'] == 'success' || d['resultCode'] == '200';
  static dynamic _data(Map<String, dynamic> d) => d['data'] ?? d['res'];

  static Future<List<StockEvent>> getList({required String startDate, required String endDate, String? eventType}) async {
    try {
      final params = {
        'company_key': _ck, 'user_id': _uid,
        'start_date': startDate, 'end_date': endDate,
      };
      if (eventType != null) params['event_type'] = eventType;
      final d = await ApiService.get(ApiConfig.events, params: params);
      if (_ok(d) && _data(d) is List) {
        return (_data(d) as List).map((e) => StockEvent.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<bool> create(StockEvent e) async {
    try {
      final body = e.toJson()..['company_key'] = _ck..['user_id'] = _uid;
      final d = await ApiService.post(ApiConfig.events, body);
      return _ok(d);
    } catch (_) {}
    return false;
  }

  static Future<bool> update(String id, StockEvent e) async {
    try {
      final body = e.toJson()..['company_key'] = _ck..['user_id'] = _uid;
      final d = await ApiService.putBody('${ApiConfig.events}/$id', body);
      return _ok(d);
    } catch (_) {}
    return false;
  }

  static Future<bool> delete(String id) async {
    try {
      final d = await ApiService.delete('${ApiConfig.events}/$id?company_key=$_ck&user_id=$_uid');
      return _ok(d);
    } catch (_) {}
    return false;
  }

  static Future<bool> recordResult(String id, Map<String, dynamic> result, String? note) async {
    try {
      final body = {'result': result, if (note != null) 'result_note': note};
      final d = await ApiService.putBody('${ApiConfig.events}/$id/result', body);
      return _ok(d);
    } catch (_) {}
    return false;
  }

  static Future<bool> crawlEarnings({String? stockCode}) async {
    try {
      final body = {'company_key': _ck, 'user_id': _uid};
      if (stockCode != null) body['stock_code'] = stockCode;
      final d = await ApiService.post('${ApiConfig.events}/crawl/earnings', body);
      return _ok(d);
    } catch (_) {}
    return false;
  }
}

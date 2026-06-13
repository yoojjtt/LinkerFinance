import '../config/api_config.dart';
import '../models/journal_model.dart';
import 'api_service.dart';
import 'auth_service.dart';

class JournalService {
  static String get _ck => AuthService().currentUser?.companyKey ?? '';
  static String get _uid => AuthService().currentUser?.userId ?? '';

  static bool _ok(Map<String, dynamic> d) => d['res'] == 'success' || d['resultCode'] == '200';
  static dynamic _data(Map<String, dynamic> d) => d['data'] ?? d['res'];

  static Future<List<MarketJournal>> getList({int page = 1, int size = 20, String? journalType}) async {
    try {
      final params = {'company_key': _ck, 'user_id': _uid, 'page': '$page', 'size': '$size'};
      if (journalType != null) params['journal_type'] = journalType;
      final d = await ApiService.get(ApiConfig.journal, params: params);
      if (_ok(d) && _data(d) is List) {
        return (_data(d) as List).map((e) => MarketJournal.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<bool> create(MarketJournal j) async {
    try {
      final body = j.toJson()..['company_key'] = _ck..['user_id'] = _uid;
      final d = await ApiService.post(ApiConfig.journal, body);
      return _ok(d);
    } catch (_) {}
    return false;
  }

  static Future<bool> update(String id, MarketJournal j) async {
    try {
      final body = j.toJson()..['company_key'] = _ck..['user_id'] = _uid;
      final d = await ApiService.putBody('${ApiConfig.journal}/$id', body);
      return _ok(d);
    } catch (_) {}
    return false;
  }

  static Future<bool> delete(String id) async {
    try {
      final d = await ApiService.delete('${ApiConfig.journal}/$id');
      return _ok(d);
    } catch (_) {}
    return false;
  }

  static Future<bool> togglePin(String id) async {
    try {
      final d = await ApiService.putBody('${ApiConfig.journal}/$id/pin', {});
      return _ok(d);
    } catch (_) {}
    return false;
  }

  static Future<List<MarketJournal>> search({String? tag, String? stockCode, String? keyword}) async {
    try {
      final params = {'company_key': _ck, 'user_id': _uid};
      if (tag != null) params['tag'] = tag;
      if (stockCode != null) params['stock_code'] = stockCode;
      if (keyword != null) params['keyword'] = keyword;
      final d = await ApiService.get('${ApiConfig.journal}/search', params: params);
      if (_ok(d) && _data(d) is List) {
        return (_data(d) as List).map((e) => MarketJournal.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<JournalStreak?> getStreak() async {
    try {
      final d = await ApiService.get('${ApiConfig.journal}/stats/streak', params: {'company_key': _ck, 'user_id': _uid});
      if (_ok(d) && _data(d) != null) return JournalStreak.fromJson(_data(d) as Map<String, dynamic>);
    } catch (_) {}
    return null;
  }

  static Future<List<Map<String, dynamic>>> getMoodStats({int days = 30}) async {
    try {
      final d = await ApiService.get('${ApiConfig.journal}/stats/mood', params: {'company_key': _ck, 'user_id': _uid, 'days': '$days'});
      if (_ok(d) && _data(d) is List) return (_data(d) as List).cast<Map<String, dynamic>>();
    } catch (_) {}
    return [];
  }

  static Future<List<Map<String, dynamic>>> getTagStats() async {
    try {
      final d = await ApiService.get('${ApiConfig.journal}/stats/tags', params: {'company_key': _ck, 'user_id': _uid});
      if (_ok(d) && _data(d) is List) return (_data(d) as List).cast<Map<String, dynamic>>();
    } catch (_) {}
    return [];
  }

  // AI 기능
  static Future<String?> getAiDraft({String? date}) async {
    try {
      final params = <String, String>{};
      if (date != null) params['date'] = date;
      final d = await ApiService.get('${ApiConfig.journal}/ai-draft', params: params.isNotEmpty ? params : null);
      if (_ok(d)) return _data(d)?.toString();
    } catch (_) {}
    return null;
  }

  static Future<List<String>> getAiTags(String content) async {
    try {
      final d = await ApiService.post('${ApiConfig.journal}/ai-tags', {'content': content});
      if (_ok(d) && _data(d) is List) return (_data(d) as List).map((e) => e.toString()).toList();
    } catch (_) {}
    return [];
  }

  static Future<String?> aiAnalyze(String id) async {
    try {
      final d = await ApiService.post('${ApiConfig.journal}/$id/ai-analyze', {});
      if (_ok(d)) return _data(d)?.toString();
    } catch (_) {}
    return null;
  }

  static Future<Map<String, dynamic>?> getAiReport({String? month, bool regenerate = false}) async {
    try {
      final params = {'company_key': _ck, 'user_id': _uid};
      if (month != null) params['month'] = month;
      if (regenerate) params['regenerate'] = 'true';
      final d = await ApiService.get('${ApiConfig.journal}/ai-report', params: params);
      if (_ok(d) && _data(d) is Map) return _data(d) as Map<String, dynamic>;
    } catch (_) {}
    return null;
  }
}

import '../config/api_config.dart';
import '../models/watchlist_model.dart';
import '../services/auth_service.dart';
import 'api_service.dart';

class WatchlistService {
  static String get _companyKey => AuthService().currentUser?.companyKey ?? '';
  static String get _userId => AuthService().currentUser?.userId ?? '';

  static bool _isSuccess(Map<String, dynamic> data) {
    return data['res'] == 'success' || data['resultCode'] == '200';
  }

  static dynamic _getData(Map<String, dynamic> data) {
    return data['data'] ?? data['res'];
  }

  /// 그룹 목록 조회
  static Future<List<WatchlistGroup>> getGroups() async {
    try {
      final data = await ApiService.get(
        ApiConfig.watchlistGroups,
        params: {'company_key': _companyKey, 'user_id': _userId},
      );
      if (_isSuccess(data) && _getData(data) != null) {
        final list = _getData(data) as List;
        return list.map((e) => WatchlistGroup.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// 종목 목록 조회 (가격 포함)
  static Future<List<WatchlistStock>> getStocks({int? groupId}) async {
    try {
      final params = {
        'company_key': _companyKey,
        'user_id': _userId,
        'with_price': 'true',
      };
      if (groupId != null) params['group_id'] = '$groupId';

      final data = await ApiService.get(ApiConfig.watchlistStocks, params: params);
      if (_isSuccess(data) && _getData(data) != null) {
        final list = _getData(data) as List;
        return list.map((e) => WatchlistStock.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// 기간수익률 조회
  static Future<Map<String, Map<String, double>>> getReturns(
    List<String> stockCodes, {
    String period = '1m',
  }) async {
    if (stockCodes.isEmpty) return {};
    try {
      final data = await ApiService.post(ApiConfig.watchlistReturns, {
        'stock_codes': stockCodes,
        'period': period,
      });
      if (_isSuccess(data) && _getData(data) != null) {
        final map = _getData(data) as Map<String, dynamic>;
        return map.map((code, val) {
          if (val is Map) {
            return MapEntry(
              code,
              val.map((k, v) => MapEntry(k as String, (v as num).toDouble())),
            );
          }
          return MapEntry(code, <String, double>{});
        });
      }
    } catch (_) {}
    return {};
  }
}

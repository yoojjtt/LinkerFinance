import '../config/api_config.dart';
import '../models/stock_model.dart';
import 'api_service.dart';

class StockService {
  static bool _ok(Map<String, dynamic> d) => d['res'] == 'success' || d['resultCode'] == '200';

  /// 일봉
  static Future<List<StockCandle>> getChart(String stockCode, {int days = 60}) async {
    try {
      final data = await ApiService.get('${ApiConfig.stockChart}/$stockCode', params: {'days': '$days'});
      if (_ok(data) && data['data'] != null) {
        final candles = (data['data'] as List).map((e) => StockCandle.fromJson(e as Map<String, dynamic>)).toList();
        candles.sort((a, b) => a.date.compareTo(b.date));
        return candles;
      }
    } catch (_) {}
    return [];
  }

  /// 주봉
  static Future<List<StockCandle>> getWeeklyChart(String stockCode, {int weeks = 52}) async {
    try {
      final data = await ApiService.get('${ApiConfig.stockChart}/$stockCode/weekly', params: {'weeks': '$weeks'});
      if (_ok(data) && data['data'] != null) {
        final candles = (data['data'] as List).map((e) => StockCandle.fromJson(e as Map<String, dynamic>)).toList();
        candles.sort((a, b) => a.date.compareTo(b.date));
        return candles;
      }
    } catch (_) {}
    return [];
  }

  /// 월봉
  static Future<List<StockCandle>> getMonthlyChart(String stockCode, {int months = 24}) async {
    try {
      final data = await ApiService.get('${ApiConfig.stockChart}/$stockCode/monthly', params: {'months': '$months'});
      if (_ok(data) && data['data'] != null) {
        final candles = (data['data'] as List).map((e) => StockCandle.fromJson(e as Map<String, dynamic>)).toList();
        candles.sort((a, b) => a.date.compareTo(b.date));
        return candles;
      }
    } catch (_) {}
    return [];
  }

  /// 종목 검색
  static Future<List<StockSearchResult>> search(String keyword) async {
    if (keyword.trim().isEmpty) return [];
    try {
      final data = await ApiService.get(ApiConfig.stockSearch, params: {'keyword': keyword.trim()});
      if (data['resultCode'] == '200' && data['res'] != null) {
        return (data['res'] as List).map((e) => StockSearchResult.fromJson(e as Map<String, dynamic>)).take(30).toList();
      }
    } catch (_) {}
    return [];
  }
}

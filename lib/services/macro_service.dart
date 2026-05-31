import '../config/api_config.dart';
import '../models/macro_asset_model.dart';
import 'api_service.dart';

// 매크로 API는 res:"success" + data:[...] 구조 (계정 API와 다름)
class MacroService {
  static bool _isSuccess(Map<String, dynamic> data) {
    return data['res'] == 'success' || data['resultCode'] == '200';
  }

  static dynamic _getData(Map<String, dynamic> data) {
    return data['data'] ?? data['res'];
  }

  static Future<List<MacroAsset>> getLatest() async {
    try {
      final data = await ApiService.get(ApiConfig.macroLatest);
      if (_isSuccess(data) && _getData(data) != null) {
        final list = _getData(data) as List;
        return list.map((e) => MacroAsset.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<List<MacroAsset>> getCurrent({String? category}) async {
    try {
      final params = <String, String>{};
      if (category != null && category.isNotEmpty) {
        params['category'] = category;
      }
      final data = await ApiService.get(ApiConfig.macroCurrent, params: params.isNotEmpty ? params : null);
      if (_isSuccess(data) && _getData(data) != null) {
        final list = _getData(data) as List;
        return list.map((e) => MacroAsset.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<List<MacroHistory>> getHistory(String symbol, {String period = '1m'}) async {
    try {
      final data = await ApiService.get(
        ApiConfig.macroHistory,
        params: {'symbol': symbol, 'period': period},
      );
      if (_isSuccess(data) && _getData(data) != null) {
        final list = _getData(data) as List;
        return list.map((e) => MacroHistory.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<YieldSpreadData?> getYieldSpread() async {
    try {
      final data = await ApiService.get(ApiConfig.macroYieldSpread);
      if (_isSuccess(data) && _getData(data) != null) {
        return YieldSpreadData.fromJson(_getData(data) as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }

  static Future<FearGreedData?> getFearGreed() async {
    try {
      final data = await ApiService.get(ApiConfig.macroFearGreed);
      if (_isSuccess(data) && _getData(data) != null) {
        return FearGreedData.fromJson(_getData(data) as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }
}

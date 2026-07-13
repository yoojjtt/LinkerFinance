import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import '../models/investor_model.dart';
import 'api_service.dart';
import 'auth_service.dart';

// Design Ref: §4.2 — 투자자 수급 API 서비스
class InvestorService {
  static Map<String, String> _authParams() {
    final user = AuthService().currentUser;
    return {
      if (user != null) ...{
        'companyKey': user.companyKey,
        'userId': user.userId,
      },
    };
  }

  /// 시장 수급 요약 조회
  static Future<MarketSummary?> getMarketSummary({int? days}) async {
    try {
      final auth = _authParams();
      final params = <String, String>{...auth};
      if (days != null) params['days'] = days.toString();

      final data = await ApiService.get(
        ApiConfig.investorMarketSummary,
        params: params.isNotEmpty ? params : null,
      );
      debugPrint('[InvestorService] market-summary keys: ${data.keys}');
      final summary = MarketSummary.fromJson(data);
      debugPrint('[InvestorService] kospi=${summary.kospi != null}, kosdaq=${summary.kosdaq != null}, etc=${summary.etc != null}');
      return summary;
    } catch (e) {
      debugPrint('[InvestorService] market-summary 에러: $e');
    }
    return null;
  }
}

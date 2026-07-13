import '../config/api_config.dart';
import '../models/scanner_model.dart';
import 'api_service.dart';
import 'auth_service.dart';

// Design Ref: §4.2 — 스캐너 결과 + 섹터 플로우 API 통합 서비스
class ScannerService {
  static bool _isSuccess(Map<String, dynamic> data) {
    return data['res'] == 'success' || data['resultCode'] == '200';
  }

  static Map<String, String> _authParams() {
    final user = AuthService().currentUser;
    return {
      if (user != null) ...{
        'companyKey': user.companyKey,
        'userId': user.userId,
      },
    };
  }

  /// AI 스캔 종목 — 가장 최근 거래일 데이터 자동 탐색
  /// 1) summary로 최근 날짜 확인 → 2) 해당 날짜 results 조회
  static Future<List<ScanResult>> getResults({
    String minGrade = 'B',
    int limit = 5,
  }) async {
    try {
      // 먼저 summary로 가장 최근 스캔 날짜 확인
      final summaryData = await ApiService.get(
        ApiConfig.scannerResults.replaceAll('/results', '/summary'),
        params: {'days': '3', ..._authParams()},
      );
      final summaryList = summaryData['res'];
      if (summaryList is! List || summaryList.isEmpty) return [];

      // 가장 최근 날짜 추출
      final latestDate = summaryList[0]['scan_date'] as String? ?? '';
      if (latestDate.isEmpty) return [];

      // 해당 날짜의 결과 조회
      final data = await ApiService.get(
        ApiConfig.scannerResults,
        params: {
          'scanDate': latestDate,
          'minGrade': minGrade,
          ..._authParams(),
        },
      );
      final list = data['res'];
      if (list is List) {
        final results = list
            .map((e) => ScanResult.fromJson(e as Map<String, dynamic>))
            .toList();
        // totalScore 높은 순 정렬, 상위 limit개
        results.sort((a, b) => b.totalScore.compareTo(a.totalScore));
        return results.take(limit).toList();
      }
    } catch (_) {}
    return [];
  }

  /// 섹터별 수급 플로우 조회
  static Future<List<SectorFlow>> getSectorFlow({int days = 20}) async {
    try {
      final data = await ApiService.get(
        ApiConfig.investorSectorFlow,
        params: {
          'days': days.toString(),
          ..._authParams(),
        },
      );
      if (_isSuccess(data) && data['data'] != null) {
        final list = data['data'] as List;
        final flows = list
            .map((e) => SectorFlow.fromJson(e as Map<String, dynamic>))
            .toList();
        // 외국인+기관 순매수 절대값 기준 정렬 (수급 변동 큰 섹터 먼저)
        flows.sort((a, b) =>
            b.smartMoneyNet.abs().compareTo(a.smartMoneyNet.abs()));
        return flows;
      }
    } catch (_) {}
    return [];
  }
}

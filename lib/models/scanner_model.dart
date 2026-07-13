// Design Ref: §3.1, §3.2 — ScanResult + SectorFlow 데이터 모델
// 실제 API 응답 기반으로 필드 매핑

import 'dart:convert';

class ScanResult {
  final String stockCode;
  final String stockName;
  final String grade; // 'S', 'A', 'B'
  final double totalScore;
  final double chartScore;
  final double financialScore;
  final String? sectorName;
  final String marketType; // 'KOSPI', 'KOSDAQ'
  final double? closePrice;
  final double? changeRate; // chart_detail에서 추출
  final String? aiComment; // chart_detail 요약
  final DateTime scanDate;

  ScanResult({
    required this.stockCode,
    required this.stockName,
    required this.grade,
    required this.totalScore,
    this.chartScore = 0,
    this.financialScore = 0,
    this.sectorName,
    this.marketType = '',
    this.closePrice,
    this.changeRate,
    this.aiComment,
    required this.scanDate,
  });

  factory ScanResult.fromJson(Map<String, dynamic> json) {
    // chart_detail은 JSON 문자열로 들어옴
    Map<String, dynamic>? chartDetail;
    final chartDetailRaw = json['chart_detail'] ?? json['chartDetail'];
    if (chartDetailRaw is String) {
      try {
        chartDetail = jsonDecode(chartDetailRaw) as Map<String, dynamic>;
      } catch (_) {}
    } else if (chartDetailRaw is Map) {
      chartDetail = chartDetailRaw as Map<String, dynamic>;
    }

    // chart_detail에서 유용한 정보 추출
    String? comment;
    if (chartDetail != null) {
      final parts = <String>[];
      if (chartDetail['goldenCross'] == true) parts.add('골든크로스');
      if (chartDetail['smartMoneyBuy'] == true) parts.add('스마트머니 매수');
      if (chartDetail['cloudBreakout'] == true) parts.add('구름 돌파');
      if (chartDetail['dispRecovery'] == true) parts.add('이격도 회복');
      final drawdown = chartDetail['drawdownLevel'] as String?;
      if (drawdown != null) parts.add(drawdown);
      if (parts.isNotEmpty) comment = parts.join(', ');
    }

    return ScanResult(
      stockCode: json['stock_code'] as String? ?? json['stockCode'] as String? ?? '',
      stockName: json['stock_name'] as String? ?? json['stockName'] as String? ?? '',
      grade: json['grade'] as String? ?? 'B',
      totalScore: (json['total_score'] ?? json['totalScore'] as num?)?.toDouble() ?? 0,
      chartScore: (json['chart_score'] ?? json['chartScore'] as num?)?.toDouble() ?? 0,
      financialScore: (json['financial_score'] ?? json['financialScore'] as num?)?.toDouble() ?? 0,
      sectorName: chartDetail?['sectorName'] as String?,
      marketType: json['market_type'] as String? ?? json['marketType'] as String? ?? '',
      closePrice: (chartDetail?['closePrice'] as num?)?.toDouble(),
      changeRate: (chartDetail?['rangePct'] as num?)?.toDouble(),
      aiComment: comment,
      scanDate: DateTime.tryParse(json['scan_date'] as String? ?? json['scanDate'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class SectorFlow {
  final String sectorName;
  final String sectorCode;
  final double foreignTotal;
  final double institutionTotal;
  final double individualTotal;
  final double? pensionTotal;
  final int stockCount;

  SectorFlow({
    required this.sectorName,
    required this.sectorCode,
    required this.foreignTotal,
    required this.institutionTotal,
    required this.individualTotal,
    this.pensionTotal,
    required this.stockCount,
  });

  /// 외국인+기관 순매수 합계
  double get smartMoneyNet => foreignTotal + institutionTotal;

  /// 수급 방향 (외국인+기관 기준)
  bool get isNetBuying => smartMoneyNet > 0;

  factory SectorFlow.fromJson(Map<String, dynamic> json) {
    return SectorFlow(
      sectorName: json['sector_name'] as String? ?? json['sectorName'] as String? ?? '',
      sectorCode: json['sector_code'] as String? ?? json['sectorCode'] as String? ?? '',
      foreignTotal: (json['foreign_total'] ?? json['foreignTotal'] as num?)?.toDouble() ?? 0,
      institutionTotal: (json['institution_total'] ?? json['institutionTotal'] as num?)?.toDouble() ?? 0,
      individualTotal: (json['individual_total'] ?? json['individualTotal'] as num?)?.toDouble() ?? 0,
      pensionTotal: (json['pension_total'] ?? json['pensionTotal'] as num?)?.toDouble(),
      stockCount: (json['stock_count'] ?? json['stockCount'] as num?)?.toInt() ?? 0,
    );
  }
}

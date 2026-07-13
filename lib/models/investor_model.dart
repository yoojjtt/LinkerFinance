// Design Ref: §3.3 — MarketSummary 데이터 모델
// API 응답: 직접 JSON 객체 반환 (표준 래퍼 없음)

class MarketSummary {
  final MarketFlowData? kospi;
  final MarketFlowData? kosdaq;
  final MarketFlowData? etc;

  MarketSummary({this.kospi, this.kosdaq, this.etc});

  factory MarketSummary.fromJson(Map<String, dynamic> json) {
    return MarketSummary(
      kospi: json['kospi'] != null
          ? MarketFlowData.fromJson(json['kospi'] as Map<String, dynamic>)
          : null,
      kosdaq: json['kosdaq'] != null
          ? MarketFlowData.fromJson(json['kosdaq'] as Map<String, dynamic>)
          : null,
      etc: json['etc'] != null
          ? MarketFlowData.fromJson(json['etc'] as Map<String, dynamic>)
          : null,
    );
  }
}

class MarketFlowData {
  final double foreignTotal;
  final double institutionTotal;
  final double individualTotal;
  final double? pensionTotal;
  final int stockCount;
  final int tradingDays;
  final String? latestDate;

  MarketFlowData({
    required this.foreignTotal,
    required this.institutionTotal,
    required this.individualTotal,
    this.pensionTotal,
    required this.stockCount,
    required this.tradingDays,
    this.latestDate,
  });

  factory MarketFlowData.fromJson(Map<String, dynamic> json) {
    return MarketFlowData(
      foreignTotal: (json['foreign_total'] ?? json['foreignTotal'] as num?)?.toDouble() ?? 0,
      institutionTotal: (json['institution_total'] ?? json['institutionTotal'] as num?)?.toDouble() ?? 0,
      individualTotal: (json['individual_total'] ?? json['individualTotal'] as num?)?.toDouble() ?? 0,
      pensionTotal: (json['pension_total'] ?? json['pensionTotal'] as num?)?.toDouble(),
      stockCount: (json['stock_count'] ?? json['stockCount'] as num?)?.toInt() ?? 0,
      tradingDays: (json['trading_days'] ?? json['tradingDays'] as num?)?.toInt() ?? 0,
      latestDate: json['latest_date'] as String? ?? json['latestDate'] as String?,
    );
  }
}

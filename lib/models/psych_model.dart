class TradingRule {
  final String? id;
  final String category; // PSYCH, ENTRY, EXIT, RISK
  final String title;

  TradingRule({this.id, required this.category, required this.title});

  factory TradingRule.fromJson(Map<String, dynamic> json) => TradingRule(
    id: json['id']?.toString(),
    category: json['category'] as String? ?? 'PSYCH',
    title: json['title'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {'category': category, 'title': title};
}

class PsychChecklist {
  final String? id;
  final String stockCode;
  final String stockName;
  final bool passed;
  final double complianceRate;
  final double cashRatio;
  final double betRatio;
  final String? memo;
  final DateTime? createdAt;

  PsychChecklist({
    this.id,
    this.stockCode = '',
    this.stockName = '',
    this.passed = false,
    this.complianceRate = 0,
    this.cashRatio = 0,
    this.betRatio = 0,
    this.memo,
    this.createdAt,
  });

  factory PsychChecklist.fromJson(Map<String, dynamic> json) => PsychChecklist(
    id: json['id']?.toString(),
    stockCode: json['stock_code'] as String? ?? '',
    stockName: json['stock_name'] as String? ?? '',
    passed: json['passed'] == true || json['passed'] == 1,
    complianceRate: (json['compliance_rate'] as num?)?.toDouble() ?? 0,
    cashRatio: (json['cash_ratio'] as num?)?.toDouble() ?? 0,
    betRatio: (json['bet_ratio'] as num?)?.toDouble() ?? 0,
    memo: json['memo'] as String?,
    createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
  );
}

class ComplianceStats {
  final int compliantTrades;
  final double compliantWinRate;
  final double compliantAvgReturn;
  final int nonCompliantTrades;
  final double nonCompliantWinRate;
  final double nonCompliantAvgReturn;

  ComplianceStats({
    this.compliantTrades = 0,
    this.compliantWinRate = 0,
    this.compliantAvgReturn = 0,
    this.nonCompliantTrades = 0,
    this.nonCompliantWinRate = 0,
    this.nonCompliantAvgReturn = 0,
  });

  factory ComplianceStats.fromJson(Map<String, dynamic> json) => ComplianceStats(
    compliantTrades: (json['compliant_trades'] as num?)?.toInt() ?? 0,
    compliantWinRate: (json['compliant_win_rate'] as num?)?.toDouble() ?? 0,
    compliantAvgReturn: (json['compliant_avg_return'] as num?)?.toDouble() ?? 0,
    nonCompliantTrades: (json['non_compliant_trades'] as num?)?.toInt() ?? 0,
    nonCompliantWinRate: (json['non_compliant_win_rate'] as num?)?.toDouble() ?? 0,
    nonCompliantAvgReturn: (json['non_compliant_avg_return'] as num?)?.toDouble() ?? 0,
  );
}

// 카테고리 상수
const Map<String, (String label, int color)> ruleCategories = {
  'PSYCH': ('심리', 0xFFA855F7),
  'ENTRY': ('진입', 0xFF22C55E),
  'EXIT': ('청산', 0xFFEF4444),
  'RISK': ('리스크', 0xFFF59E0B),
};

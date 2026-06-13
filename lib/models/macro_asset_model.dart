import '../utils/macro_utils.dart' show symbolCategoryMap;

class MacroAsset {
  final String symbol;
  final String name;
  final String category;
  final double price;
  final double change;
  final double changePercent;
  final String? interpretation;
  final DateTime? updatedAt;

  MacroAsset({
    required this.symbol,
    required this.name,
    required this.category,
    required this.price,
    required this.change,
    required this.changePercent,
    this.interpretation,
    this.updatedAt,
  });

  factory MacroAsset.fromJson(Map<String, dynamic> json) {
    final closePrice = (json['close_price'] ?? json['price'] as num?)?.toDouble() ?? 0;
    final prevClose = (json['prev_close'] as num?)?.toDouble() ?? closePrice;
    final changeRate = (json['change_rate'] ?? json['changePercent'] as num?)?.toDouble() ?? 0;
    final change = (json['change'] as num?)?.toDouble() ?? (closePrice - prevClose);
    final symbol = json['symbol'] as String? ?? '';
    final apiCategory = json['category'] as String? ?? '';

    return MacroAsset(
      symbol: symbol,
      name: json['name'] as String? ?? '',
      category: apiCategory.isNotEmpty
          ? apiCategory
          : (symbolCategoryMap[symbol] ?? 'etc'),
      price: closePrice,
      change: change,
      changePercent: changeRate,
      interpretation: json['interpretation'] as String?,
      updatedAt: json['trade_date'] != null
          ? DateTime.tryParse(json['trade_date'] as String)
          : json['updatedAt'] != null
              ? DateTime.tryParse(json['updatedAt'] as String)
              : null,
    );
  }
}

class MacroHistory {
  final DateTime date;
  final double close;
  final double? high;
  final double? low;

  MacroHistory({
    required this.date,
    required this.close,
    this.high,
    this.low,
  });

  factory MacroHistory.fromJson(Map<String, dynamic> json) {
    return MacroHistory(
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      close: (json['close'] as num?)?.toDouble() ?? 0,
      high: (json['high'] as num?)?.toDouble(),
      low: (json['low'] as num?)?.toDouble(),
    );
  }
}

class FearGreedData {
  final double vixValue;
  final String level;
  final String label;

  FearGreedData({
    required this.vixValue,
    required this.level,
    required this.label,
  });

  factory FearGreedData.fromJson(Map<String, dynamic> json) {
    final vix = (json['vix'] ?? json['vixValue'] as num?)?.toDouble() ?? 0;
    final level = json['level'] as String? ?? _calcLevel(vix);
    return FearGreedData(
      vixValue: vix,
      level: level,
      label: _levelLabel(level),
    );
  }

  static String _calcLevel(double vix) {
    if (vix >= 30) return 'EXTREME_FEAR';
    if (vix >= 25) return 'FEAR';
    if (vix >= 15) return 'NEUTRAL';
    if (vix >= 12) return 'GREED';
    return 'EXTREME_GREED';
  }

  static String _levelLabel(String level) {
    switch (level) {
      case 'EXTREME_FEAR': return '극단적 공포';
      case 'FEAR': return '공포';
      case 'NEUTRAL': return '중립';
      case 'GREED': return '탐욕';
      case 'EXTREME_GREED': return '극단적 탐욕';
      default: return '중립';
    }
  }
}

class YieldSpreadData {
  final double spread;
  final double us10y;
  final double us2y;
  final bool recessionWarning;

  YieldSpreadData({
    required this.spread,
    required this.us10y,
    required this.us2y,
    required this.recessionWarning,
  });

  factory YieldSpreadData.fromJson(Map<String, dynamic> json) {
    final spread = (json['spread'] as num?)?.toDouble() ?? 0;
    return YieldSpreadData(
      spread: spread,
      us10y: (json['us10y'] as num?)?.toDouble() ?? 0,
      us2y: (json['us2y'] as num?)?.toDouble() ?? 0,
      recessionWarning: json['inverted'] as bool? ?? json['recessionWarning'] as bool? ?? spread < 0,
    );
  }
}

class CrossSignal {
  final String type; // positive, negative, warning, opportunity, neutral
  final String message;

  CrossSignal({required this.type, required this.message});
}

class StockCandle {
  final DateTime date;
  final double open;
  final double high;
  final double low;
  final double close;
  final int volume;
  final double? ma5;
  final double? ma20;
  final double? ma60;
  final double changeRate;

  StockCandle({
    required this.date,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
    this.ma5,
    this.ma20,
    this.ma60,
    this.changeRate = 0,
  });

  factory StockCandle.fromJson(Map<String, dynamic> json) {
    final dateStr = json['trade_date'] as String? ?? '';
    DateTime date;
    if (dateStr.length == 8) {
      date = DateTime.tryParse(
        '${dateStr.substring(0, 4)}-${dateStr.substring(4, 6)}-${dateStr.substring(6, 8)}',
      ) ?? DateTime.now();
    } else {
      date = DateTime.tryParse(dateStr) ?? DateTime.now();
    }

    return StockCandle(
      date: date,
      open: (json['open_price'] as num?)?.toDouble() ?? 0,
      high: (json['high_price'] as num?)?.toDouble() ?? 0,
      low: (json['low_price'] as num?)?.toDouble() ?? 0,
      close: (json['close_price'] as num?)?.toDouble() ?? 0,
      volume: (json['volume'] as num?)?.toInt() ?? 0,
      ma5: (json['ma5'] as num?)?.toDouble(),
      ma20: (json['ma20'] as num?)?.toDouble(),
      ma60: (json['ma60'] as num?)?.toDouble(),
      changeRate: (json['change_rate'] as num?)?.toDouble() ?? 0,
    );
  }
}

class StockSearchResult {
  final String code;
  final String name;
  final String marketName;
  final String? upName; // 업종
  final String? lastPrice;

  StockSearchResult({
    required this.code,
    required this.name,
    required this.marketName,
    this.upName,
    this.lastPrice,
  });

  factory StockSearchResult.fromJson(Map<String, dynamic> json) {
    return StockSearchResult(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      marketName: json['marketName'] as String? ?? '',
      upName: json['upName'] as String?,
      lastPrice: json['lastPrice'] as String?,
    );
  }

  /// lastPrice는 "00317000" 형식 → 숫자로 변환
  int get parsedPrice {
    if (lastPrice == null) return 0;
    return int.tryParse(lastPrice!.replaceAll(RegExp(r'^0+'), '')) ?? 0;
  }
}

class WatchlistGroup {
  final int id;
  final String groupName;
  final int stockCount;
  final int sortOrder;

  WatchlistGroup({
    required this.id,
    required this.groupName,
    required this.stockCount,
    required this.sortOrder,
  });

  factory WatchlistGroup.fromJson(Map<String, dynamic> json) {
    return WatchlistGroup(
      id: json['id'] as int? ?? json['group_id'] as int? ?? 0,
      groupName: json['group_name'] as String? ?? '',
      stockCount: json['stock_count'] as int? ?? 0,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }
}

class WatchlistStock {
  final String stockCode;
  final String stockName;
  final int? groupId;
  final int sortOrder;
  final double curPrice;
  final double fluRate;
  final String? sectorName;
  final String? marketType;
  final String? memo;

  // 기간수익률 (클라이언트에서 추가 세팅)
  Map<String, double> returns;

  WatchlistStock({
    required this.stockCode,
    required this.stockName,
    this.groupId,
    this.sortOrder = 0,
    this.curPrice = 0,
    this.fluRate = 0,
    this.sectorName,
    this.marketType,
    this.memo,
    Map<String, double>? returns,
  }) : returns = returns ?? {};

  factory WatchlistStock.fromJson(Map<String, dynamic> json) {
    return WatchlistStock(
      stockCode: json['stock_code'] as String? ?? '',
      stockName: json['stock_name'] as String? ?? '',
      groupId: json['group_id'] as int?,
      sortOrder: json['sort_order'] as int? ?? 0,
      curPrice: (json['cur_prc'] as num?)?.toDouble() ?? 0,
      fluRate: (json['flu_rt'] as num?)?.toDouble() ?? 0,
      sectorName: json['sector_name'] as String?,
      marketType: json['market_type'] as String?,
      memo: json['memo'] as String?,
    );
  }
}

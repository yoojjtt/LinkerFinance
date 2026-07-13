// Design Ref: §3.1 — 실시간 체결가 데이터 모델
// STOMP /topic/kiwoom/price/{stockCode} 메시지 파싱

class RealtimePrice {
  final double curPrice;
  final double diffPrice;
  final double diffRate;
  final int volume;
  final int cumVolume;
  final String tradeTime; // HHMMSS
  final DateTime receivedAt;

  RealtimePrice({
    required this.curPrice,
    required this.diffPrice,
    required this.diffRate,
    required this.volume,
    required this.cumVolume,
    required this.tradeTime,
    required this.receivedAt,
  });

  factory RealtimePrice.fromJson(Map<String, dynamic> json) {
    return RealtimePrice(
      curPrice: (json['cur_price'] as num?)?.toDouble() ?? 0,
      diffPrice: (json['diff_price'] as num?)?.toDouble() ?? 0,
      diffRate: (json['diff_rate'] as num?)?.toDouble() ?? 0,
      volume: (json['volume'] as num?)?.toInt() ?? 0,
      cumVolume: (json['cum_volume'] as num?)?.toInt() ?? 0,
      tradeTime: json['trade_time'] as String? ?? '',
      receivedAt: DateTime.now(),
    );
  }

  bool get isUp => diffRate > 0;
  bool get isDown => diffRate < 0;
}

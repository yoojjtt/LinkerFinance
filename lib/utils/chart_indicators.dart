import 'dart:math';

import '../models/stock_model.dart';

// ─── 피보나치 되돌림 ───

class FibLevel {
  final double ratio;
  final String label;
  final double price;

  FibLevel({required this.ratio, required this.label, required this.price});
}

List<FibLevel> calcFibonacci(List<StockCandle> candles) {
  if (candles.length < 10) return [];

  final periodHigh = candles.map((c) => c.high).reduce(max);
  final periodLow = candles.map((c) => c.low).reduce(min);
  final diff = periodHigh - periodLow;
  if (diff <= 0) return [];

  const ratios = [
    (ratio: 0.0, label: '0%'),
    (ratio: 0.236, label: '23.6%'),
    (ratio: 0.382, label: '38.2%'),
    (ratio: 0.5, label: '50%'),
    (ratio: 0.618, label: '61.8%'),
    (ratio: 0.786, label: '78.6%'),
    (ratio: 1.0, label: '100%'),
  ];

  return ratios
      .map((r) => FibLevel(
            ratio: r.ratio,
            label: r.label,
            price: periodHigh - diff * r.ratio,
          ))
      .toList();
}

// ─── 지지/저항 ───

class SRLevel {
  final double price;
  final String label;
  final bool isSupport; // true=지지, false=저항
  final int level; // 1,2,3

  SRLevel({required this.price, required this.label, required this.isSupport, required this.level});
}

List<SRLevel> calcSupportResistance(List<StockCandle> candles) {
  if (candles.length < 20) return [];

  final recent20 = candles.sublist(candles.length - 20);
  final currentPrice = candles.last.close;

  final high20 = recent20.map((c) => c.high).reduce(max);
  final low20 = recent20.map((c) => c.low).reduce(min);
  final pivot = (high20 + low20 + currentPrice) / 3;
  final range20 = high20 - low20;

  // Classic Pivot
  final r1 = 2 * pivot - low20;
  final s1 = 2 * pivot - high20;
  final r2 = pivot + range20;
  final s2 = pivot - range20;
  final r3 = high20 + 2 * (pivot - low20);
  final s3 = low20 - 2 * (high20 - pivot);

  final levels = <SRLevel>[];

  // 저항 (현재가 위)
  if (r1 > currentPrice) {
    levels.add(SRLevel(price: r1, label: 'R1', isSupport: false, level: 1));
  }
  if (r2 > currentPrice && (r2 - r1).abs() / currentPrice > 0.02) {
    levels.add(SRLevel(price: r2, label: 'R2', isSupport: false, level: 2));
  }
  if (r3 > currentPrice && (r3 - r2).abs() / currentPrice > 0.02) {
    levels.add(SRLevel(price: r3, label: 'R3', isSupport: false, level: 3));
  }

  // 지지 (현재가 아래)
  if (s1 < currentPrice) {
    levels.add(SRLevel(price: s1, label: 'S1', isSupport: true, level: 1));
  }
  if (s2 < currentPrice && (s1 - s2).abs() / currentPrice > 0.02) {
    levels.add(SRLevel(price: s2, label: 'S2', isSupport: true, level: 2));
  }
  if (s3 < currentPrice && (s2 - s3).abs() / currentPrice > 0.02) {
    levels.add(SRLevel(price: s3, label: 'S3', isSupport: true, level: 3));
  }

  return levels;
}

// ─── 추세선 (소/중/대) ───

class SwingPoint {
  final int index;
  final double price;
  final bool isHigh;

  SwingPoint({required this.index, required this.price, required this.isHigh});
}

class TrendLine {
  final String type; // 'small', 'medium', 'large'
  final String label; // '소', '중', '대'
  final List<SwingPoint> swingHighs;
  final List<SwingPoint> swingLows;
  // 저항 추세선 (최근 2개 고점 연결)
  final SwingPoint? resistP1;
  final SwingPoint? resistP2;
  // 지지 추세선 (최근 2개 저점 연결)
  final SwingPoint? supportP1;
  final SwingPoint? supportP2;
  // 박스권 여부
  final bool isBox;
  final double? boxTop;
  final double? boxBottom;

  TrendLine({
    required this.type,
    required this.label,
    required this.swingHighs,
    required this.swingLows,
    this.resistP1,
    this.resistP2,
    this.supportP1,
    this.supportP2,
    this.isBox = false,
    this.boxTop,
    this.boxBottom,
  });
}

List<SwingPoint> detectSwings(List<StockCandle> candles, int lookback, {required bool findHighs}) {
  final points = <SwingPoint>[];
  for (var i = lookback; i < candles.length - lookback; i++) {
    bool isExtreme = true;
    for (var j = 1; j <= lookback; j++) {
      if (findHighs) {
        if (candles[i].high <= candles[i - j].high || candles[i].high <= candles[i + j].high) {
          isExtreme = false;
          break;
        }
      } else {
        if (candles[i].low >= candles[i - j].low || candles[i].low >= candles[i + j].low) {
          isExtreme = false;
          break;
        }
      }
    }
    if (isExtreme) {
      points.add(SwingPoint(
        index: i,
        price: findHighs ? candles[i].high : candles[i].low,
        isHigh: findHighs,
      ));
    }
  }
  return points;
}

List<TrendLine> calcTrendLines(List<StockCandle> candles) {
  if (candles.length < 30) return [];

  const waveDefs = [
    (type: 'small', lookback: 3, label: '소'),
    (type: 'medium', lookback: 10, label: '중'),
    (type: 'large', lookback: 25, label: '대'),
  ];

  final results = <TrendLine>[];

  for (final def in waveDefs) {
    if (candles.length < def.lookback * 3) continue;

    final highs = detectSwings(candles, def.lookback, findHighs: true);
    final lows = detectSwings(candles, def.lookback, findHighs: false);

    SwingPoint? rp1, rp2, sp1, sp2;
    bool isBox = false;
    double? boxTop, boxBottom;

    if (highs.length >= 2) {
      rp1 = highs[highs.length - 2];
      rp2 = highs[highs.length - 1];
    }
    if (lows.length >= 2) {
      sp1 = lows[lows.length - 2];
      sp2 = lows[lows.length - 1];
    }

    // 박스권 판단
    if (rp1 != null && rp2 != null && sp1 != null && sp2 != null) {
      final avgPrice = (rp2.price + sp2.price) / 2;
      final highSlope = (rp2.price - rp1.price).abs() / avgPrice;
      final lowSlope = (sp2.price - sp1.price).abs() / avgPrice;

      if (highSlope < 0.03 && lowSlope < 0.03) {
        isBox = true;
        boxTop = max(rp1.price, rp2.price);
        boxBottom = min(sp1.price, sp2.price);
      }
    }

    results.add(TrendLine(
      type: def.type,
      label: def.label,
      swingHighs: highs,
      swingLows: lows,
      resistP1: rp1,
      resistP2: rp2,
      supportP1: sp1,
      supportP2: sp2,
      isBox: isBox,
      boxTop: boxTop,
      boxBottom: boxBottom,
    ));
  }

  return results;
}

/// 두 점을 잇는 추세선의 특정 인덱스에서의 가격
double trendPriceAt(SwingPoint p1, SwingPoint p2, int index) {
  if (p1.index == p2.index) return p1.price;
  final slope = (p2.price - p1.price) / (p2.index - p1.index);
  return p1.price + slope * (index - p1.index);
}

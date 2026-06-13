import 'dart:math';

import '../models/stock_model.dart';

// ─── 볼린저밴드 ───

class BollingerBands {
  final List<double?> upper;
  final List<double?> middle;
  final List<double?> lower;

  BollingerBands({required this.upper, required this.middle, required this.lower});
}

BollingerBands calcBollinger(List<double?> closes, {int period = 20, double multiplier = 2}) {
  final n = closes.length;
  final upper = List<double?>.filled(n, null);
  final middle = List<double?>.filled(n, null);
  final lower = List<double?>.filled(n, null);

  if (n < period) return BollingerBands(upper: upper, middle: middle, lower: lower);

  for (var i = period - 1; i < n; i++) {
    final slice = closes.sublist(i - period + 1, i + 1).whereType<double>().toList();
    if (slice.length < period) continue;

    final avg = slice.reduce((a, b) => a + b) / slice.length;
    final variance = slice.map((v) => (v - avg) * (v - avg)).reduce((a, b) => a + b) / slice.length;
    final stdDev = sqrt(variance);

    middle[i] = avg;
    upper[i] = avg + multiplier * stdDev;
    lower[i] = avg - multiplier * stdDev;
  }

  return BollingerBands(upper: upper, middle: middle, lower: lower);
}

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

// ─── RSI (Relative Strength Index) ───

List<double?> calcRSI(List<double> closes, {int period = 14}) {
  final n = closes.length;
  final result = List<double?>.filled(n, null);
  if (n < period + 1) return result;

  // 초기 평균 상승/하락
  var avgGain = 0.0;
  var avgLoss = 0.0;
  for (var i = 1; i <= period; i++) {
    final diff = closes[i] - closes[i - 1];
    if (diff > 0) avgGain += diff;
    if (diff < 0) avgLoss += diff.abs();
  }
  avgGain /= period;
  avgLoss /= period;

  result[period] = avgLoss == 0 ? 100 : 100 - (100 / (1 + avgGain / avgLoss));

  // Wilder smoothing
  for (var i = period + 1; i < n; i++) {
    final diff = closes[i] - closes[i - 1];
    final gain = diff > 0 ? diff : 0.0;
    final loss = diff < 0 ? diff.abs() : 0.0;
    avgGain = (avgGain * (period - 1) + gain) / period;
    avgLoss = (avgLoss * (period - 1) + loss) / period;
    result[i] = avgLoss == 0 ? 100 : 100 - (100 / (1 + avgGain / avgLoss));
  }

  return result;
}

// ─── MACD ───

class MACDData {
  final List<double?> macdLine;    // MACD = EMA12 - EMA26
  final List<double?> signalLine;  // Signal = EMA9(MACD)
  final List<double?> histogram;   // MACD - Signal

  MACDData({required this.macdLine, required this.signalLine, required this.histogram});
}

List<double?> _calcEMA(List<double> data, int period) {
  final n = data.length;
  final result = List<double?>.filled(n, null);
  if (n < period) return result;

  // 첫 EMA = SMA
  var sum = 0.0;
  for (var i = 0; i < period; i++) sum += data[i];
  result[period - 1] = sum / period;

  final multiplier = 2.0 / (period + 1);
  for (var i = period; i < n; i++) {
    result[i] = (data[i] - result[i - 1]!) * multiplier + result[i - 1]!;
  }
  return result;
}

MACDData calcMACD(List<double> closes, {int fast = 12, int slow = 26, int signal = 9}) {
  final n = closes.length;
  final emaFast = _calcEMA(closes, fast);
  final emaSlow = _calcEMA(closes, slow);

  // MACD line
  final macdLine = List<double?>.filled(n, null);
  for (var i = 0; i < n; i++) {
    if (emaFast[i] != null && emaSlow[i] != null) {
      macdLine[i] = emaFast[i]! - emaSlow[i]!;
    }
  }

  // Signal line (EMA of MACD)
  final macdValues = <double>[];
  final macdIndices = <int>[];
  for (var i = 0; i < n; i++) {
    if (macdLine[i] != null) {
      macdValues.add(macdLine[i]!);
      macdIndices.add(i);
    }
  }

  final signalLine = List<double?>.filled(n, null);
  final histogram = List<double?>.filled(n, null);

  if (macdValues.length >= signal) {
    final sigEma = _calcEMA(macdValues, signal);
    for (var j = 0; j < macdValues.length; j++) {
      final i = macdIndices[j];
      if (sigEma[j] != null) {
        signalLine[i] = sigEma[j];
        histogram[i] = macdLine[i]! - sigEma[j]!;
      }
    }
  }

  return MACDData(macdLine: macdLine, signalLine: signalLine, histogram: histogram);
}

import 'package:flutter/material.dart';

import '../../models/stock_model.dart';
import '../../utils/chart_indicators.dart';

class ChartOverlayPainter extends CustomPainter {
  final List<StockCandle> candles;
  final bool showFibonacci;
  final bool showSR;
  final String? trendType; // null, 'small', 'medium', 'large'
  final double chartHeight;

  ChartOverlayPainter({
    required this.candles,
    required this.showFibonacci,
    required this.showSR,
    this.trendType,
    required this.chartHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;

    final allPrices = candles.expand((c) => [c.high, c.low]).toList();
    final minPrice = allPrices.reduce((a, b) => a < b ? a : b) * 0.98;
    final maxPrice = allPrices.reduce((a, b) => a > b ? a : b) * 1.02;
    final priceRange = maxPrice - minPrice;
    if (priceRange <= 0) return;

    double priceToY(double price) {
      return size.height - ((price - minPrice) / priceRange * size.height);
    }

    double indexToX(int index) {
      return index / candles.length * size.width;
    }

    // 피보나치
    if (showFibonacci) {
      final fibs = calcFibonacci(candles);
      for (final fib in fibs) {
        final y = priceToY(fib.price);
        final color = _fibColor(fib.ratio);
        final isStrong = fib.ratio == 0.5 || fib.ratio == 0.618;

        final paint = Paint()
          ..color = color.withValues(alpha: 0.6)
          ..strokeWidth = isStrong ? 1.5 : 0.8
          ..style = PaintingStyle.stroke;

        // 점선
        _drawDashedLine(canvas, Offset(0, y), Offset(size.width, y), paint);

        // 라벨
        final tp = TextPainter(
          text: TextSpan(
            text: 'Fib ${fib.label}',
            style: TextStyle(fontSize: 9, color: color, fontWeight: isStrong ? FontWeight.w700 : FontWeight.w400),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(4, y - tp.height - 2));
      }
    }

    // 지지/저항
    if (showSR) {
      final levels = calcSupportResistance(candles);
      for (final sr in levels) {
        final y = priceToY(sr.price);
        final color = sr.isSupport ? const Color(0xFF4CAF50) : const Color(0xFFF44336);
        final lineWidth = sr.level == 1 ? 1.5 : sr.level == 2 ? 1.0 : 0.7;

        final paint = Paint()
          ..color = color.withValues(alpha: 0.7)
          ..strokeWidth = lineWidth
          ..style = PaintingStyle.stroke;

        _drawDashedLine(canvas, Offset(0, y), Offset(size.width, y), paint);

        final tp = TextPainter(
          text: TextSpan(
            text: sr.label,
            style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(size.width - tp.width - 4, y - tp.height - 2));
      }
    }

    // 추세선
    if (trendType != null) {
      final trendLines = calcTrendLines(candles);
      final trend = trendLines.where((t) => t.type == trendType).firstOrNull;
      if (trend == null) return;

      final colors = {
        'small': const Color(0xFF9CA3AF),
        'medium': const Color(0xFFF59E0B),
        'large': const Color(0xFFEF4444),
      };
      final color = colors[trendType] ?? const Color(0xFF9CA3AF);
      final lineWidth = trendType == 'large' ? 2.0 : trendType == 'medium' ? 1.5 : 1.0;

      if (trend.isBox && trend.boxTop != null && trend.boxBottom != null) {
        // 박스권
        final topY = priceToY(trend.boxTop!);
        final bottomY = priceToY(trend.boxBottom!);
        final boxPaint = Paint()
          ..color = color.withValues(alpha: 0.08)
          ..style = PaintingStyle.fill;
        canvas.drawRect(Rect.fromLTRB(0, topY, size.width, bottomY), boxPaint);

        final borderPaint = Paint()
          ..color = color.withValues(alpha: 0.5)
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke;
        canvas.drawRect(Rect.fromLTRB(0, topY, size.width, bottomY), borderPaint);
      } else {
        // 저항 추세선
        if (trend.resistP1 != null && trend.resistP2 != null) {
          final p1 = trend.resistP1!;
          final p2 = trend.resistP2!;
          final startIdx = p1.index;
          final endIdx = candles.length - 1;

          final paint = Paint()
            ..color = color.withValues(alpha: 0.8)
            ..strokeWidth = lineWidth
            ..style = PaintingStyle.stroke;

          canvas.drawLine(
            Offset(indexToX(startIdx), priceToY(trendPriceAt(p1, p2, startIdx))),
            Offset(indexToX(endIdx), priceToY(trendPriceAt(p1, p2, endIdx))),
            paint,
          );
        }

        // 지지 추세선
        if (trend.supportP1 != null && trend.supportP2 != null) {
          final p1 = trend.supportP1!;
          final p2 = trend.supportP2!;
          final startIdx = p1.index;
          final endIdx = candles.length - 1;

          final paint = Paint()
            ..color = color.withValues(alpha: 0.8)
            ..strokeWidth = lineWidth
            ..style = PaintingStyle.stroke;

          canvas.drawLine(
            Offset(indexToX(startIdx), priceToY(trendPriceAt(p1, p2, startIdx))),
            Offset(indexToX(endIdx), priceToY(trendPriceAt(p1, p2, endIdx))),
            paint,
          );
        }
      }

      // 라벨
      final tp = TextPainter(
        text: TextSpan(
          text: '${trend.label}추세${trend.isBox ? " (박스)" : ""}',
          style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(size.width - tp.width - 4, 4));
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashWidth = 4.0;
    const gapWidth = 3.0;
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final distance = (dx * dx + dy * dy);
    final totalLen = distance > 0 ? distance.sqrt() : 0.0;
    final ux = totalLen > 0 ? dx / totalLen : 0.0;
    final uy = totalLen > 0 ? dy / totalLen : 0.0;

    var drawn = 0.0;
    while (drawn < totalLen) {
      final segEnd = (drawn + dashWidth).clamp(0, totalLen);
      canvas.drawLine(
        Offset(start.dx + ux * drawn, start.dy + uy * drawn),
        Offset(start.dx + ux * segEnd, start.dy + uy * segEnd),
        paint,
      );
      drawn += dashWidth + gapWidth;
    }
  }

  Color _fibColor(double ratio) {
    if (ratio == 0 || ratio == 1) return const Color(0xFF9CA3AF);
    if (ratio == 0.236) return const Color(0xFF3B82F6);
    if (ratio == 0.382) return const Color(0xFF22C55E);
    if (ratio == 0.5) return const Color(0xFFF59E0B);
    if (ratio == 0.618) return const Color(0xFFEF4444);
    if (ratio == 0.786) return const Color(0xFF8B5CF6);
    return const Color(0xFF9CA3AF);
  }

  @override
  bool shouldRepaint(covariant ChartOverlayPainter oldDelegate) {
    return oldDelegate.showFibonacci != showFibonacci ||
        oldDelegate.showSR != showSR ||
        oldDelegate.trendType != trendType ||
        oldDelegate.candles.length != candles.length;
  }
}

extension on double {
  double sqrt() => this > 0 ? _sqrt(this) : 0;
  static double _sqrt(double v) {
    double x = v;
    for (var i = 0; i < 20; i++) {
      x = (x + v / x) / 2;
    }
    return x;
  }
}

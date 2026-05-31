import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/macro_asset_model.dart';

// Design Ref: §7 — 위험도 평가, 시그널 생성, 포맷팅

String getAssetDanger(MacroAsset asset) {
  final p = asset.price;
  final cp = asset.changePercent;
  final s = asset.symbol;

  if (s == 'WTI' || s == 'BRENT') {
    if (p > 100) return '경고';
    if (p > 85) return '주의';
    if (p < 40) return '경고';
    return '안전';
  }
  if (s == 'NATGAS') {
    if (p > 6) return '위험';
    if (p > 4) return '경고';
    return '안전';
  }
  if (s == 'VIX') {
    if (p > 30) return '위험';
    if (p > 25) return '경고';
    if (p > 20) return '주의';
    if (p < 12) return '주의';
    return '안전';
  }
  if (s == 'USDKRW') {
    if (p > 1400) return '경고';
    if (p > 1350) return '주의';
    return '안전';
  }
  if (s == 'GOLD') {
    if (cp > 3) return '주의';
    return '안전';
  }
  if (s == 'COPPER') {
    if (cp < -5) return '경고';
    if (cp < -3) return '주의';
    return '안전';
  }
  if (s == 'BTC') {
    if (cp.abs() > 10) return '경고';
    if (cp.abs() > 5) return '주의';
    return '안전';
  }
  if (s == 'US10Y' || s == 'US2Y') {
    if (p > 5) return '경고';
    if (p > 4.5) return '주의';
    return '안전';
  }
  if (['KOSPI', 'KOSDAQ', 'SP500', 'NDX100'].contains(s)) {
    if (cp < -3) return '경고';
    if (cp < -2) return '주의';
    return '안전';
  }
  return '안전';
}

Color getDangerColor(String danger) {
  switch (danger) {
    case '안전': return const Color(0xFF4CAF50);
    case '주의': return const Color(0xFFFF9800);
    case '경고': return const Color(0xFFF44336);
    case '위험': return const Color(0xFFB71C1C);
    default: return const Color(0xFF9E9E9E);
  }
}

Color getChangeColor(double changePercent) {
  if (changePercent > 0) return const Color(0xFFE53935);
  if (changePercent < 0) return const Color(0xFF1E88E5);
  return const Color(0xFF9E9E9E);
}

Color getFearGreedColor(String level) {
  switch (level) {
    case 'EXTREME_FEAR': return const Color(0xFFB71C1C);
    case 'FEAR': return const Color(0xFFF44336);
    case 'NEUTRAL': return const Color(0xFFFF9800);
    case 'GREED': return const Color(0xFF4CAF50);
    case 'EXTREME_GREED': return const Color(0xFF1B5E20);
    default: return const Color(0xFF9E9E9E);
  }
}

({String signal, String emoji, Color color}) getMarketSignal(
  FearGreedData? fearGreed,
  YieldSpreadData? yieldSpread,
) {
  if (fearGreed == null || yieldSpread == null) {
    return (signal: '데이터 로딩 중', emoji: '⏳', color: const Color(0xFF9E9E9E));
  }

  int score = 0;
  // VIX 점수
  if (fearGreed.vixValue < 15) {
    score += 2;
  } else if (fearGreed.vixValue < 20) {
    score += 1;
  } else if (fearGreed.vixValue > 30) {
    score -= 2;
  } else if (fearGreed.vixValue > 25) {
    score -= 1;
  }

  // 금리차 점수
  if (yieldSpread.spread > 0.5) {
    score += 1;
  } else if (yieldSpread.spread < 0) {
    score -= 2;
  } else if (yieldSpread.spread < 0.2) {
    score -= 1;
  }

  if (score >= 2) return (signal: '매수 유리', emoji: '🟢', color: const Color(0xFF4CAF50));
  if (score <= -2) return (signal: '매수 주의', emoji: '🔴', color: const Color(0xFFF44336));
  return (signal: '중립', emoji: '🟡', color: const Color(0xFFFF9800));
}

List<CrossSignal> generateCrossSignals(List<MacroAsset> assets) {
  final signals = <CrossSignal>[];
  final map = {for (final a in assets) a.symbol: a};

  final vix = map['VIX'];
  final usdkrw = map['USDKRW'];
  final gold = map['GOLD'];
  final wti = map['WTI'];
  final copper = map['COPPER'];
  final btc = map['BTC'];
  final kospi = map['KOSPI'];
  final sp500 = map['SP500'];

  if (vix != null && vix.price > 25) {
    signals.add(CrossSignal(type: 'warning', message: 'VIX ${vix.price.toStringAsFixed(1)} — 시장 변동성 확대, 리스크 관리 필요'));
  }
  if (usdkrw != null && usdkrw.price > 1380) {
    signals.add(CrossSignal(type: 'negative', message: '원/달러 ${formatPrice(usdkrw.price, 'USDKRW')} — 외국인 자금 이탈 압력'));
  }
  if (gold != null && gold.changePercent > 2) {
    signals.add(CrossSignal(type: 'warning', message: '금 ${gold.changePercent.toStringAsFixed(1)}% 급등 — 안전자산 선호 강화'));
  }
  if (wti != null && wti.price > 90) {
    signals.add(CrossSignal(type: 'negative', message: 'WTI \$${wti.price.toStringAsFixed(1)} — 인플레 압력 재부각'));
  }
  if (copper != null && copper.changePercent < -3) {
    signals.add(CrossSignal(type: 'warning', message: '구리 ${copper.changePercent.toStringAsFixed(1)}% — 경기 둔화 선행 신호'));
  }
  if (btc != null && btc.changePercent.abs() > 7) {
    signals.add(CrossSignal(type: 'warning', message: 'BTC ${btc.changePercent > 0 ? "+" : ""}${btc.changePercent.toStringAsFixed(1)}% — 유동성 변동 신호'));
  }
  if (kospi != null && sp500 != null) {
    if (kospi.changePercent < -2 && sp500.changePercent > 0) {
      signals.add(CrossSignal(type: 'opportunity', message: 'KOSPI 약세 vs S&P 강세 — 디커플링, 반등 기회 모색'));
    }
    if (kospi.changePercent > 1 && sp500.changePercent > 1) {
      signals.add(CrossSignal(type: 'positive', message: '글로벌 동반 상승 — 위험자산 선호 강화'));
    }
  }

  if (signals.isEmpty) {
    signals.add(CrossSignal(type: 'neutral', message: '특별한 교차 신호 없음 — 시장 안정적'));
  }

  return signals;
}

Color getSignalColor(String type) {
  switch (type) {
    case 'positive': return const Color(0xFF4CAF50);
    case 'negative': return const Color(0xFFF44336);
    case 'warning': return const Color(0xFFFF9800);
    case 'opportunity': return const Color(0xFF1E88E5);
    default: return const Color(0xFF9E9E9E);
  }
}

IconData getSignalIcon(String type) {
  switch (type) {
    case 'positive': return Icons.trending_up;
    case 'negative': return Icons.trending_down;
    case 'warning': return Icons.warning_amber;
    case 'opportunity': return Icons.lightbulb_outline;
    default: return Icons.remove;
  }
}

String formatPrice(double price, String symbol) {
  if (symbol == 'USDKRW') return '${NumberFormat('#,##0').format(price)}원';
  if (symbol == 'BTC') return '\$${NumberFormat('#,##0').format(price)}';
  if (['KOSPI', 'KOSDAQ'].contains(symbol)) return NumberFormat('#,##0.00').format(price);
  if (['US10Y', 'US2Y'].contains(symbol)) return '${price.toStringAsFixed(3)}%';
  if (price > 1000) return NumberFormat('#,##0.00').format(price);
  return price.toStringAsFixed(2);
}

String formatChange(double change, double changePercent) {
  final sign = change >= 0 ? '+' : '';
  return '$sign${change.toStringAsFixed(2)} ($sign${changePercent.toStringAsFixed(2)}%)';
}

String getCategoryLabel(String category) {
  switch (category) {
    case 'index': return '지수';
    case 'futures': return '선물';
    case 'currency': return '환율';
    case 'bond': return '채권';
    case 'volatility': return '변동성';
    case 'crypto': return '암호화폐';
    case 'commodity': return '원자재';
    case 'sentiment': return '투자심리';
    default: return category;
  }
}

const List<String> categoryKeys = [
  'all', 'index', 'futures', 'currency', 'bond',
  'volatility', 'crypto', 'commodity', 'sentiment',
];

const List<String> categoryLabels = [
  '전체', '지수', '선물', '환율', '채권',
  '변동성', '암호화폐', '원자재', '투자심리',
];

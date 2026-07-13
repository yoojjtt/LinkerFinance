import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/investor_model.dart';
import '../../../models/macro_asset_model.dart';

// Design Ref: §5.2① — 한줄 진단 카드 (킬러 피처)
// Plan SC: SC-01 — 홈 탭 오픈 시 한줄 진단이 3초 내 표시

class MarketDiagnosisCard extends StatelessWidget {
  final FearGreedData? fearGreed;
  final List<MacroAsset> macroAssets;
  final MarketSummary? marketSummary;

  const MarketDiagnosisCard({
    super.key,
    this.fearGreed,
    required this.macroAssets,
    this.marketSummary,
  });

  @override
  Widget build(BuildContext context) {
    final diagnosis = _calculateDiagnosis();
    final kospi = macroAssets.where((a) => a.symbol == 'KOSPI').firstOrNull;
    final kosdaq = macroAssets.where((a) => a.symbol == 'KOSDAQ').firstOrNull;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1B2E5C),
            const Color(0xFF1B2E5C).withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 진단 레벨 + 아이콘
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: diagnosis.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  diagnosis.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                if (fearGreed != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'F&G ${fearGreed!.vixValue.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            // 진단 설명
            Text(
              diagnosis.description,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            // 코스피 / 코스닥 지수
            Row(
              children: [
                if (kospi != null) _buildIndexChip('코스피', kospi),
                if (kospi != null && kosdaq != null) const SizedBox(width: 12),
                if (kosdaq != null) _buildIndexChip('코스닥', kosdaq),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndexChip(String name, MacroAsset asset) {
    final isPositive = asset.changePercent >= 0;
    final fmt = NumberFormat('#,##0.##');
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Flexible(
                  child: Text(
                    fmt.format(asset.price),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${isPositive ? '+' : ''}${asset.changePercent.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: isPositive
                        ? const Color(0xFFFF6B6B)
                        : const Color(0xFF64B5F6),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  _DiagnosisResult _calculateDiagnosis() {
    if (fearGreed == null && macroAssets.isEmpty && marketSummary == null) {
      return _DiagnosisResult(
        score: 50,
        label: '데이터 로딩 중',
        description: '시장 데이터를 불러오고 있습니다...',
        color: const Color(0xFF9E9E9E),
      );
    }

    int score = 50; // 중립 시작
    final reasons = <String>[];

    // 1) 코스피 등락률 — 가중치 최대 ±35점 (가장 큰 영향, 직접적 시장 지표)
    //    한국 시장 앱이므로 코스피가 진단의 핵심
    final kospi = macroAssets.where((a) => a.symbol == 'KOSPI').firstOrNull;
    if (kospi != null) {
      final pct = kospi.changePercent;
      if (pct <= -5.0) {
        score -= 35;
        reasons.add('코스피 ${pct.toStringAsFixed(1)}% 폭락');
      } else if (pct <= -3.0) {
        score -= 28;
        reasons.add('코스피 ${pct.toStringAsFixed(1)}% 급락');
      } else if (pct <= -1.5) {
        score -= 18;
        reasons.add('코스피 ${pct.toStringAsFixed(1)}% 하락');
      } else if (pct <= -0.5) {
        score -= 10;
        reasons.add('코스피 ${pct.toStringAsFixed(1)}% 하락');
      } else if (pct >= 5.0) {
        score += 35;
        reasons.add('코스피 +${pct.toStringAsFixed(1)}% 폭등');
      } else if (pct >= 3.0) {
        score += 28;
        reasons.add('코스피 +${pct.toStringAsFixed(1)}% 급등');
      } else if (pct >= 1.5) {
        score += 18;
        reasons.add('코스피 +${pct.toStringAsFixed(1)}% 상승');
      } else if (pct >= 0.5) {
        score += 10;
        reasons.add('코스피 +${pct.toStringAsFixed(1)}% 상승');
      }
    }

    // 2) Fear&Greed (VIX 기반) — 가중치 ±15점 (보조 지표)
    //    미국 VIX라 한국 시장과 즉시 연동 안 될 수 있음 → 보조로 사용
    if (fearGreed != null) {
      final vix = fearGreed!.vixValue;
      switch (fearGreed!.level) {
        case 'EXTREME_FEAR':
          score -= 15;
          reasons.add('VIX ${vix.toStringAsFixed(1)}(${fearGreed!.label})');
        case 'FEAR':
          score -= 8;
          reasons.add('VIX ${vix.toStringAsFixed(1)}(${fearGreed!.label})');
        case 'GREED':
          score += 8;
          reasons.add('VIX ${vix.toStringAsFixed(1)}(${fearGreed!.label})');
        case 'EXTREME_GREED':
          score += 15;
          reasons.add('VIX ${vix.toStringAsFixed(1)}(${fearGreed!.label})');
        default:
          break;
      }
    }

    // 3) 외국인+기관 수급 — 가중치 ±10점 (kospi/kosdaq 데이터만, etc 제외)
    final flowData = marketSummary?.kospi ?? marketSummary?.kosdaq;
    if (flowData != null) {
      final netBuy = flowData.foreignTotal + flowData.institutionTotal;
      if (netBuy > 0) {
        score += 10;
        reasons.add('외인+기관 순매수');
      } else if (netBuy < 0) {
        score -= 10;
        reasons.add('외인 매도 우세');
      }
    }

    score = score.clamp(0, 100);

    // 점수 → 진단 레벨 (5단계)
    // 0~20: 약세, 20~35: 약세 주의, 35~55: 중립, 55~70: 강세 기대, 70~100: 강세
    String label;
    Color color;
    if (score >= 70) {
      label = '강세';
      color = const Color(0xFF4CAF50);
    } else if (score >= 55) {
      label = '강세 기대';
      color = const Color(0xFF4CAF50);
    } else if (score >= 35) {
      label = '중립';
      color = const Color(0xFF9E9E9E);
    } else if (score >= 20) {
      label = '약세 주의';
      color = const Color(0xFFFF9800);
    } else {
      label = '약세';
      color = const Color(0xFFF44336);
    }

    return _DiagnosisResult(
      score: score,
      label: label,
      description: reasons.isNotEmpty ? reasons.join(', ') : '시장 데이터 분석 중',
      color: color,
    );
  }
}

class _DiagnosisResult {
  final int score;
  final String label;
  final String description;
  final Color color;

  _DiagnosisResult({
    required this.score,
    required this.label,
    required this.description,
    required this.color,
  });
}

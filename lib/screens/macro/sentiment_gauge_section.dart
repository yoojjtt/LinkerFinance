import 'package:flutter/material.dart';

import '../../models/macro_asset_model.dart';
import '../../utils/macro_utils.dart';

class SentimentGaugeSection extends StatelessWidget {
  final FearGreedData? fearGreed;
  final YieldSpreadData? yieldSpread;
  final List<MacroAsset> assets;

  const SentimentGaugeSection({
    super.key,
    this.fearGreed,
    this.yieldSpread,
    required this.assets,
  });

  static const double _cardHeight = 110;

  @override
  Widget build(BuildContext context) {
    final signal = getMarketSignal(fearGreed, yieldSpread);
    final deposit = assets.where((a) => a.symbol == 'DEPOSIT').firstOrNull;
    final credit = assets.where((a) => a.symbol == 'CREDIT').firstOrNull;

    return Column(
      children: [
        // 2x2 메인 카드 (높이 고정)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(child: _buildSignalCard(signal)),
              const SizedBox(width: 8),
              Expanded(child: _buildFearGreedCard()),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(child: _buildYieldSpreadCard()),
              const SizedBox(width: 8),
              Expanded(child: _buildCreditDepositCard(deposit, credit)),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 빠른 지표 (가로 스크롤)
        SizedBox(
          height: 60,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: ['WTI', 'USDKRW', 'GOLD', 'COPPER']
                .map((s) => assets.where((a) => a.symbol == s).firstOrNull)
                .where((a) => a != null)
                .map((a) => _buildQuickCard(a!))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSignalCard(({String signal, String emoji, Color color}) signal) {
    return _fixedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('시장 신호', style: _labelStyle),
          const Spacer(),
          Row(
            children: [
              Text(signal.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  signal.signal,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: signal.color),
                ),
              ),
            ],
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildFearGreedCard() {
    if (fearGreed == null) return _fixedCard(child: _loading('공포/탐욕'));

    return _fixedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('공포/탐욕', style: _labelStyle),
          const Spacer(),
          Text(
            'VIX ${fearGreed!.vixValue.toStringAsFixed(1)}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: getFearGreedColor(fearGreed!.level).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              fearGreed!.label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: getFearGreedColor(fearGreed!.level)),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildYieldSpreadCard() {
    if (yieldSpread == null) return _fixedCard(child: _loading('금리차'));

    return _fixedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('장단기 금리차', style: _labelStyle),
          const Spacer(),
          Text(
            '${yieldSpread!.spread >= 0 ? "+" : ""}${yieldSpread!.spread.toStringAsFixed(3)}%',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: yieldSpread!.recessionWarning ? const Color(0xFFF44336) : const Color(0xFF4CAF50),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            yieldSpread!.recessionWarning ? '⚠️ 역전 경고' : '정상 구간',
            style: TextStyle(
              fontSize: 11,
              color: yieldSpread!.recessionWarning ? const Color(0xFFF44336) : const Color(0xFF9E9E9E),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildCreditDepositCard(MacroAsset? deposit, MacroAsset? credit) {
    if (deposit == null && credit == null) {
      return _fixedCard(child: _loading('신용/예탁'));
    }

    // 신용/예탁 비율 계산
    final ratio = (deposit != null && credit != null && deposit.price > 0)
        ? (credit.price / deposit.price * 100)
        : null;

    // 억 → 조 변환 (데이터가 억 단위)
    String toTril(double v) {
      final tril = v / 10000;
      return '${tril.toStringAsFixed(1)}조';
    }

    return _fixedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('신용/예탁', style: _labelStyle),
          const Spacer(),
          if (ratio != null)
            Text(
              '${ratio.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: ratio > 35 ? const Color(0xFFF44336) : ratio > 30 ? const Color(0xFFFF9800) : const Color(0xFF4CAF50),
              ),
            ),
          const SizedBox(height: 4),
          if (deposit != null)
            Text('예탁 ${toTril(deposit.price)}', style: const TextStyle(fontSize: 11, color: Color(0xFF6B6B6B))),
          if (credit != null)
            Text('신용 ${toTril(credit.price)}', style: const TextStyle(fontSize: 11, color: Color(0xFF6B6B6B))),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildQuickCard(MacroAsset asset) {
    return Container(
      width: 110,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(asset.name, style: const TextStyle(fontSize: 11, color: Color(0xFF6B6B6B))),
          const SizedBox(height: 2),
          Text(
            formatPrice(asset.price, asset.symbol),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: getChangeColor(asset.changePercent)),
          ),
        ],
      ),
    );
  }

  Widget _fixedCard({required Widget child}) {
    return Container(
      height: _cardHeight,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: child,
    );
  }

  Widget _loading(String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _labelStyle),
        const Spacer(),
        const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
        const Spacer(),
      ],
    );
  }

  TextStyle get _labelStyle => const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B6B6B));
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/macro_asset_model.dart';
import '../../macro/macro_dashboard_screen.dart';

// Design Ref: §5.2④ — 거시경제 핵심 지표 축약 카드

class MacroSummarySection extends StatelessWidget {
  final List<MacroAsset> assets;

  const MacroSummarySection({super.key, required this.assets});

  // 핵심 5개 심볼 필터
  static const _keySymbols = ['US10Y', 'USDKRW', 'WTI', 'VIX', 'GOLD'];
  static const _displayNames = {
    'US10Y': '미국채10Y',
    'USDKRW': '달러/원',
    'WTI': 'WTI',
    'VIX': 'VIX',
    'GOLD': '금',
  };

  @override
  Widget build(BuildContext context) {
    final keyAssets = assets
        .where((a) => _keySymbols.contains(a.symbol))
        .toList();

    if (keyAssets.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                '거시경제 핵심',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1B2E5C),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(
                          title: const Text('거시경제 대시보드'),
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF1B2E5C),
                          elevation: 0,
                        ),
                        backgroundColor: const Color(0xFFF5F5F7),
                        body: const MacroDashboardScreen(),
                      ),
                    ),
                  );
                },
                child: const Text(
                  '상세 보기 >',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 85,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: keyAssets.length,
              itemBuilder: (context, index) {
                return _buildMacroCard(keyAssets[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroCard(MacroAsset asset) {
    final isPositive = asset.changePercent >= 0;
    final fmt = NumberFormat('#,##0.##');
    final displayName = _displayNames[asset.symbol] ?? asset.name;

    return Container(
      width: 95,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            displayName,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Text(
            fmt.format(asset.price),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${isPositive ? '+' : ''}${asset.changePercent.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isPositive
                  ? const Color(0xFFD32F2F)
                  : const Color(0xFF1976D2),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/scanner_model.dart';

// Design Ref: §5.2② — 섹터별 시장 스캐너 가로 스크롤
// 실제 API: sector-flow는 수급 금액만 제공 (등락률 없음)

class SectorScannerSection extends StatelessWidget {
  final List<SectorFlow> sectorFlows;

  const SectorScannerSection({super.key, required this.sectorFlows});

  @override
  Widget build(BuildContext context) {
    if (sectorFlows.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '섹터별 시장 스캐너',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1B2E5C),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 115,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: sectorFlows.length,
              itemBuilder: (context, index) {
                return _buildSectorCard(sectorFlows[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectorCard(SectorFlow sector) {
    final isBuying = sector.isNetBuying;
    final fmt = NumberFormat('#,##0');
    // 억원 단위
    final smartMoney = sector.smartMoneyNet / 100000000;
    final foreignBil = sector.foreignTotal / 100000000;

    return Container(
      width: 110,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isBuying
              ? const Color(0xFFD32F2F).withValues(alpha: 0.2)
              : const Color(0xFF1976D2).withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sector.sectorName,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF333333),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          // 외국인+기관 순매수 합계
          Text(
            '${isBuying ? '+' : ''}${fmt.format(smartMoney.round())}억',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: isBuying
                  ? const Color(0xFFD32F2F)
                  : const Color(0xFF1976D2),
            ),
          ),
          const SizedBox(height: 4),
          // 외국인 세부
          Row(
            children: [
              Icon(
                foreignBil >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                size: 11,
                color: foreignBil >= 0
                    ? const Color(0xFFD32F2F)
                    : const Color(0xFF1976D2),
              ),
              const SizedBox(width: 2),
              Text(
                '외인 ${fmt.format(foreignBil.abs().round())}억',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

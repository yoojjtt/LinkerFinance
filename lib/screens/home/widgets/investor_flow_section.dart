import 'package:flutter/material.dart';

import '../../../models/investor_model.dart';

// Design Ref: §5.2⑤ — 투자자 수급 요약 테이블

class InvestorFlowSection extends StatelessWidget {
  final MarketSummary? summary;

  const InvestorFlowSection({super.key, this.summary});

  @override
  Widget build(BuildContext context) {
    if (summary == null ||
        (summary!.kospi == null && summary!.kosdaq == null && summary!.etc == null)) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '투자자 수급 요약',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1B2E5C),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '수급 데이터 없음',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '투자자 수급 요약',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1B2E5C),
                ),
              ),
              const Spacer(),
              () {
                final date = summary!.kospi?.latestDate ??
                    summary!.kosdaq?.latestDate ??
                    summary!.etc?.latestDate;
                if (date != null) {
                  return Text(
                    date,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  );
                }
                return const SizedBox.shrink();
              }(),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(1.2),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1),
                3: FlexColumnWidth(1),
              },
              children: [
                // 헤더
                TableRow(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  children: [
                    _headerCell(''),
                    _headerCell('외국인'),
                    _headerCell('기관'),
                    _headerCell('개인'),
                  ],
                ),
                // 코스피
                if (summary!.kospi != null)
                  _buildFlowRow('코스피', summary!.kospi!),
                // 코스닥
                if (summary!.kosdaq != null)
                  _buildFlowRow('코스닥', summary!.kosdaq!),
                // 전체(etc) — kospi/kosdaq 없을 때 표시
                if (summary!.kospi == null && summary!.kosdaq == null && summary!.etc != null)
                  _buildFlowRow('전체', summary!.etc!),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey,
        ),
      ),
    );
  }

  TableRow _buildFlowRow(String market, MarketFlowData data) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Text(
            market,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF333333),
            ),
          ),
        ),
        _flowCell(data.foreignTotal),
        _flowCell(data.institutionTotal),
        _flowCell(data.individualTotal),
      ],
    );
  }

  Widget _flowCell(double value) {
    // 웹과 동일한 동적 단위 변환 (InvestorFlow.js formatNet 참고)
    final abs = value.abs();
    final isPositive = value >= 0;
    final prefix = isPositive ? '+' : '';
    String displayValue;
    if (abs >= 1e8) {
      displayValue = '$prefix${(value / 1e8).toStringAsFixed(1)}억';
    } else if (abs >= 1e4) {
      displayValue = '$prefix${(value / 1e4).toStringAsFixed(0)}만';
    } else if (abs >= 1e3) {
      displayValue = '$prefix${(value / 1e3).toStringAsFixed(0)}K';
    } else {
      displayValue = '$prefix${value.toStringAsFixed(0)}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Text(
        displayValue,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isPositive
              ? const Color(0xFFD32F2F)
              : const Color(0xFF1976D2),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/scanner_model.dart';
import '../../stock/stock_detail_screen.dart';

// Design Ref: §5.2③ — AI 스캔 종목 리스트
// 실제 API: total_score, chart_score, financial_score, chart_detail 제공

class AiScanSection extends StatelessWidget {
  final List<ScanResult> scanResults;

  const AiScanSection({super.key, required this.scanResults});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'AI 스캔 종목',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1B2E5C),
                ),
              ),
              const Spacer(),
              if (scanResults.isNotEmpty)
                Text(
                  scanResults.first.scanDate.toString().substring(0, 10),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (scanResults.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '오늘의 스캔 결과가 없습니다',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: scanResults.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: Colors.grey.shade200,
                ),
                itemBuilder: (context, index) {
                  return _buildScanItem(context, scanResults[index]);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScanItem(BuildContext context, ScanResult result) {
    Color gradeColor;
    switch (result.grade) {
      case 'S':
        gradeColor = const Color(0xFFFFD700);
      case 'A':
        gradeColor = const Color(0xFF1976D2);
      default:
        gradeColor = const Color(0xFF9E9E9E);
    }

    final priceFmt = NumberFormat('#,##0');

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StockDetailScreen(
              stockCode: result.stockCode,
              stockName: result.stockName,
              currentPrice: result.closePrice,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Grade 뱃지
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: gradeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text(
                  result.grade,
                  style: TextStyle(
                    color: gradeColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 종목 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          result.stockName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF333333),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        result.marketType,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    result.aiComment ?? '종합점수 ${result.totalScore.toStringAsFixed(0)}점',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // 가격 + 점수
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (result.closePrice != null)
                  Text(
                    priceFmt.format(result.closePrice),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF333333),
                    ),
                  ),
                Text(
                  '${result.totalScore.toStringAsFixed(0)}점',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: result.totalScore >= 70
                        ? const Color(0xFFD32F2F)
                        : const Color(0xFF666666),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

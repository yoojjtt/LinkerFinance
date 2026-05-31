import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../models/macro_asset_model.dart';
import '../../services/macro_service.dart';
import '../../utils/macro_utils.dart';

class AssetHistoryChart extends StatefulWidget {
  final String symbol;
  final String name;

  const AssetHistoryChart({
    super.key,
    required this.symbol,
    required this.name,
  });

  @override
  State<AssetHistoryChart> createState() => _AssetHistoryChartState();
}

class _AssetHistoryChartState extends State<AssetHistoryChart> {
  String _period = '1m';
  List<MacroHistory> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void didUpdateWidget(AssetHistoryChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.symbol != widget.symbol) {
      _loadHistory();
    }
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final data = await MacroService.getHistory(widget.symbol, period: _period);
    if (mounted) {
      setState(() {
        _history = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(widget.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1B2E5C))),
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: Color(0xFF6B6B6B)),
                onPressed: () {},
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 기간 선택
          Row(
            children: ['1w', '1m', '3m', '6m', '1y'].map((p) {
              final isSelected = _period == p;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () {
                    setState(() => _period = p);
                    _loadHistory();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF1B2E5C) : const Color(0xFFF5F5F7),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      p.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : const Color(0xFF6B6B6B),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // 차트
          SizedBox(
            height: 180,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _history.isEmpty
                    ? const Center(child: Text('차트 데이터 없음', style: TextStyle(color: Color(0xFF9E9E9E))))
                    : _buildChart(),
          ),

          // 통계
          if (_history.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildStats(),
          ],
        ],
      ),
    );
  }

  Widget _buildChart() {
    final spots = _history.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.close);
    }).toList();

    final minY = _history.map((h) => h.close).reduce((a, b) => a < b ? a : b);
    final maxY = _history.map((h) => h.close).reduce((a, b) => a > b ? a : b);
    final padding = (maxY - minY) * 0.1;

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        minY: minY - padding,
        maxY: maxY + padding,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots.map((s) {
              return LineTooltipItem(
                formatPrice(s.y, widget.symbol),
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: const Color(0xFF1B2E5C),
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF1B2E5C).withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    final closes = _history.map((h) => h.close).toList();
    final high = closes.reduce((a, b) => a > b ? a : b);
    final low = closes.reduce((a, b) => a < b ? a : b);
    final current = closes.last;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _statItem('고가', formatPrice(high, widget.symbol), const Color(0xFFE53935)),
        _statItem('저가', formatPrice(low, widget.symbol), const Color(0xFF1E88E5)),
        _statItem('현재', formatPrice(current, widget.symbol), const Color(0xFF1B2E5C)),
      ],
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}

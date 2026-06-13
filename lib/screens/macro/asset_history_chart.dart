import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

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
  late ZoomPanBehavior _zoomPanBehavior;

  @override
  void initState() {
    super.initState();
    _zoomPanBehavior = ZoomPanBehavior(
      enablePanning: true,
      enablePinching: true,
      zoomMode: ZoomMode.x,
    );
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
            height: 250,
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
    final currentPrice = _history.last.close;

    // 미래 여백: X축 max를 데이터 끝 + 20% 확장
    final lastDate = _history.last.date;
    final firstDate = _history.first.date;
    final totalDuration = lastDate.difference(firstDate);
    final futureMargin = Duration(milliseconds: (totalDuration.inMilliseconds * 0.2).toInt());
    final maxDate = lastDate.add(futureMargin);

    return SfCartesianChart(
      zoomPanBehavior: _zoomPanBehavior,
      plotAreaBorderWidth: 0,

      // X축: 날짜
      primaryXAxis: DateTimeAxis(
        dateFormat: _xAxisDateFormat(),
        majorGridLines: const MajorGridLines(width: 0),
        axisLine: const AxisLine(width: 0.5, color: Color(0xFFE0E0E0)),
        labelStyle: TextStyle(fontSize: 10, color: Colors.grey.shade500),
        maximum: maxDate,
        edgeLabelPlacement: EdgeLabelPlacement.shift,
      ),

      // Y축: 가격 (오른쪽 표시)
      primaryYAxis: NumericAxis(
        opposedPosition: true,
        numberFormat: _yAxisNumberFormat(),
        majorGridLines: MajorGridLines(width: 0.5, color: Colors.grey.shade200),
        axisLine: const AxisLine(width: 0),
        labelStyle: TextStyle(fontSize: 10, color: Colors.grey.shade500),
        // 현재가 마커 라인 (보라색 점선)
        plotBands: [
          PlotBand(
            start: currentPrice,
            end: currentPrice,
            borderWidth: 1.2,
            borderColor: const Color(0xFF7C4DFF),
            dashArray: const <double>[4, 3],
            color: Colors.transparent,
          ),
        ],
      ),

      // 현재가 Y축 태그
      annotations: <CartesianChartAnnotation>[
        CartesianChartAnnotation(
          widget: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF7C4DFF),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              _formatAxisPrice(currentPrice),
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
          coordinateUnit: CoordinateUnit.point,
          region: AnnotationRegion.chart,
          x: maxDate,
          y: currentPrice,
        ),
      ],

      // 크로스헤어 (터치 시 값 표시)
      crosshairBehavior: CrosshairBehavior(
        enable: true,
        activationMode: ActivationMode.singleTap,
        lineType: CrosshairLineType.vertical,
        lineDashArray: const <double>[4, 3],
      ),

      // 툴팁
      tooltipBehavior: TooltipBehavior(
        enable: true,
        header: '',
        format: 'point.x\npoint.y',
      ),

      series: <CartesianSeries>[
        // 영역 채우기
        AreaSeries<MacroHistory, DateTime>(
          dataSource: _history,
          xValueMapper: (h, _) => h.date,
          yValueMapper: (h, _) => h.close,
          color: const Color(0xFF1B2E5C).withValues(alpha: 0.08),
          borderColor: const Color(0xFF1B2E5C),
          borderWidth: 2,
        ),
      ],
    );
  }

  DateFormat _xAxisDateFormat() {
    return switch (_period) {
      '1w' => DateFormat('M/d'),
      '1m' => DateFormat('M/d'),
      '3m' => DateFormat('M/d'),
      '6m' => DateFormat('yy/M'),
      '1y' => DateFormat('yy/M'),
      _ => DateFormat('M/d'),
    };
  }

  NumberFormat _yAxisNumberFormat() {
    if (['US10Y', 'US2Y'].contains(widget.symbol)) {
      return NumberFormat('#,##0.000');
    }
    if (['KOSPI', 'KOSDAQ'].contains(widget.symbol)) {
      return NumberFormat('#,##0.00');
    }
    if (['USDKRW'].contains(widget.symbol)) {
      return NumberFormat('#,##0');
    }
    return NumberFormat('#,##0.00');
  }

  String _formatAxisPrice(double price) {
    return formatPrice(price, widget.symbol);
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

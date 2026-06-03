import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:interactive_chart/interactive_chart.dart';

import '../../models/stock_model.dart';
import '../../services/stock_service.dart';
import '../../utils/chart_indicators.dart';
import '../../utils/macro_utils.dart';

class StockDetailScreen extends StatefulWidget {
  final String stockCode;
  final String stockName;
  final double? currentPrice;
  final double? changeRate;

  const StockDetailScreen({
    super.key,
    required this.stockCode,
    required this.stockName,
    this.currentPrice,
    this.changeRate,
  });

  @override
  State<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends State<StockDetailScreen> {
  List<CandleData> _candles = [];
  List<StockCandle> _rawCandles = [];
  bool _isLoading = true;

  String _chartType = 'daily';
  int _days = 250;

  // 지표 토글
  bool _showMA = true;
  bool _showBB = false;
  bool _showFib = false;
  bool _showSR = false;

  // 캐시된 계산 결과
  List<FibLevel> _fibLevels = [];
  List<SRLevel> _srLevels = [];

  static const _chartTypes = [
    (type: 'daily', label: '일봉'),
    (type: 'weekly', label: '주봉'),
    (type: 'monthly', label: '월봉'),
  ];

  static const _dayOptions = [
    (days: 60, label: '3M'),
    (days: 120, label: '6M'),
    (days: 250, label: '1Y'),
    (days: 500, label: '2Y'),
  ];

  @override
  void initState() {
    super.initState();
    _loadChart();
  }

  Future<void> _loadChart() async {
    setState(() => _isLoading = true);

    List<dynamic> raw;
    switch (_chartType) {
      case 'weekly':
        raw = await StockService.getWeeklyChart(widget.stockCode, weeks: 104);
        break;
      case 'monthly':
        raw = await StockService.getMonthlyChart(widget.stockCode, months: 36);
        break;
      default:
        raw = await StockService.getChart(widget.stockCode, days: _days);
    }

    _rawCandles = raw.cast<StockCandle>();
    _rebuildCandles();

    if (mounted) setState(() => _isLoading = false);
  }

  void _rebuildCandles() {
    final n = _rawCandles.length;
    if (n == 0) { _candles = []; return; }

    // 기본 캔들
    var candles = _rawCandles.map((c) => CandleData(
      timestamp: c.date.millisecondsSinceEpoch,
      open: c.open, high: c.high, low: c.low, close: c.close,
      volume: c.volume.toDouble(),
    )).toList();

    // trends 구성: [MA5, MA20, MA60, BB_upper, BB_middle, BB_lower, fib0..6, SR0..5]
    final List<List<double?>> trendLists = [];
    final List<Paint> trendStyles = [];

    // MA (5, 20, 60)
    if (_showMA) {
      trendLists.add(CandleData.computeMA(candles, 5));
      trendStyles.add(Paint()..color = const Color(0xFFFF9800)..strokeWidth = 1);
      trendLists.add(CandleData.computeMA(candles, 20));
      trendStyles.add(Paint()..color = const Color(0xFF4CAF50)..strokeWidth = 1);
      trendLists.add(CandleData.computeMA(candles, 60));
      trendStyles.add(Paint()..color = const Color(0xFFF44336)..strokeWidth = 1);
    }

    // 볼린저밴드
    if (_showBB) {
      final closes = candles.map((c) => c.close).toList();
      final bb = calcBollinger(closes);
      trendLists.add(bb.upper);
      trendStyles.add(Paint()..color = const Color(0xFF7C4DFF).withValues(alpha: 0.6)..strokeWidth = 1);
      trendLists.add(bb.middle);
      trendStyles.add(Paint()..color = const Color(0xFF7C4DFF).withValues(alpha: 0.3)..strokeWidth = 0.8);
      trendLists.add(bb.lower);
      trendStyles.add(Paint()..color = const Color(0xFF7C4DFF).withValues(alpha: 0.6)..strokeWidth = 1);
    }

    // 피보나치 (수평선 = 모든 캔들에 동일 값)
    _fibLevels = [];
    if (_showFib && _rawCandles.length >= 10) {
      _fibLevels = calcFibonacci(_rawCandles);
      for (final f in _fibLevels) {
        trendLists.add(List.filled(n, f.price));
        final isStrong = f.ratio == 0.5 || f.ratio == 0.618;
        trendStyles.add(Paint()
          ..color = _fibColor(f.ratio).withValues(alpha: isStrong ? 0.7 : 0.4)
          ..strokeWidth = isStrong ? 1.5 : 0.8);
      }
    }

    // 지지/저항 (수평선)
    _srLevels = [];
    if (_showSR && _rawCandles.length >= 20) {
      _srLevels = calcSupportResistance(_rawCandles);
      for (final sr in _srLevels) {
        trendLists.add(List.filled(n, sr.price));
        final color = sr.isSupport ? const Color(0xFF4CAF50) : const Color(0xFFF44336);
        trendStyles.add(Paint()
          ..color = color.withValues(alpha: sr.level == 1 ? 0.7 : 0.4)
          ..strokeWidth = sr.level == 1 ? 1.5 : 0.8);
      }
    }

    // trends 합성
    if (trendLists.isNotEmpty) {
      candles = List.generate(n, (i) => CandleData(
        timestamp: candles[i].timestamp,
        open: candles[i].open, high: candles[i].high,
        low: candles[i].low, close: candles[i].close,
        volume: candles[i].volume,
        trends: trendLists.map((t) => t[i]).toList(),
      ));
    }

    _candles = candles;
    _trendStyles = trendStyles;
  }

  List<Paint> _trendStyles = [];

  void _showSettingsSheet() {
    final pf = NumberFormat('#,##0');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.55,
            maxChildSize: 0.85,
            minChildSize: 0.3,
            builder: (ctx, scrollController) => SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 36, height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 16),
                  const Text('차트 설정', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1B2E5C))),
                  const SizedBox(height: 16),

                  // MA
                  _settingRow('이동평균선 (MA5/20/60)', _showMA, (v) {
                    setSheet(() {}); setState(() { _showMA = v; _rebuildCandles(); });
                  }),

                  // BB
                  _settingRow('볼린저밴드 (BB20)', _showBB, (v) {
                    setSheet(() {}); setState(() { _showBB = v; _rebuildCandles(); });
                  }),

                  const Divider(height: 24),

                  // 피보나치
                  _settingRow('피보나치 되돌림', _showFib, (v) {
                    setSheet(() {}); setState(() { _showFib = v; _rebuildCandles(); });
                  }),
                  if (_showFib && _fibLevels.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(spacing: 6, runSpacing: 4, children: _fibLevels.map((f) {
                      final strong = f.ratio == 0.5 || f.ratio == 0.618;
                      return _valueChip('${f.label} ${pf.format(f.price)}', _fibColor(f.ratio), strong: strong);
                    }).toList()),
                    const SizedBox(height: 8),
                  ],

                  // 지지/저항
                  _settingRow('지지/저항선', _showSR, (v) {
                    setSheet(() {}); setState(() { _showSR = v; _rebuildCandles(); });
                  }),
                  if (_showSR && _srLevels.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(spacing: 6, runSpacing: 4, children: _srLevels.map((sr) {
                      final c = sr.isSupport ? const Color(0xFF4CAF50) : const Color(0xFFF44336);
                      return _valueChip('${sr.label} ${pf.format(sr.price)}', c);
                    }).toList()),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _settingRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF3A3A3A))),
        Switch.adaptive(value: value, activeTrackColor: const Color(0xFF1B2E5C), onChanged: onChanged),
      ],
    );
  }

  Widget _valueChip(String text, Color color, {bool strong = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6),
        border: strong ? Border.all(color: color, width: 1.5) : null,
      ),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: strong ? FontWeight.w700 : FontWeight.w500, color: color)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final priceFormat = NumberFormat('#,##0');
    final price = widget.currentPrice ?? (_rawCandles.isNotEmpty ? _rawCandles.last.close : 0);
    final change = widget.changeRate ?? (_rawCandles.isNotEmpty ? _rawCandles.last.changeRate : 0);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0, toolbarHeight: 48,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1B2E5C), size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(children: [
          Text(widget.stockName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1B2E5C))),
          const SizedBox(width: 8),
          Text(widget.stockCode, style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
        ]),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${priceFormat.format(price)}원',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1B2E5C))),
                Text('${change >= 0 ? "+" : ""}${change.toStringAsFixed(2)}%',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: getChangeColor(change))),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.tune, color: Color(0xFF1B2E5C), size: 20), onPressed: _showSettingsSheet),
        ],
      ),
      body: Column(
        children: [
          // 봉 타입 + 기간
          Container(
            color: Colors.white, padding: const EdgeInsets.symmetric(vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(children: [
                ..._chartTypes.map((ct) => _topChip(ct.label, selected: _chartType == ct.type, onTap: () {
                  setState(() => _chartType = ct.type); _loadChart();
                })),
                const SizedBox(width: 6),
                if (_chartType == 'daily')
                  ..._dayOptions.map((opt) => _topChip(opt.label, selected: _days == opt.days, small: true, onTap: () {
                    setState(() => _days = opt.days); _loadChart();
                  })),
              ]),
            ),
          ),

          // 차트 (화면 전체)
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _candles.isEmpty
                    ? const Center(child: Text('차트 데이터 없음'))
                    : InteractiveChart(
                        candles: _candles,
                        style: ChartStyle(
                          priceGainColor: const Color(0xFFE53935),
                          priceLossColor: const Color(0xFF1E88E5),
                          volumeColor: Colors.grey.shade300,
                          trendLineStyles: _trendStyles,
                          priceGridLineColor: Colors.grey.shade200,
                          priceLabelStyle: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                          timeLabelStyle: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                          selectionHighlightColor: const Color(0xFF1B2E5C).withValues(alpha: 0.1),
                          overlayBackgroundColor: const Color(0xFF1B2E5C).withValues(alpha: 0.9),
                          overlayTextStyle: const TextStyle(fontSize: 12, color: Colors.white),
                          volumeHeightFactor: 0.15,
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Color _fibColor(double r) => switch (r) {
    0.0 || 1.0 => const Color(0xFF9CA3AF), 0.236 => const Color(0xFF3B82F6),
    0.382 => const Color(0xFF22C55E), 0.5 => const Color(0xFFF59E0B),
    0.618 => const Color(0xFFEF4444), 0.786 => const Color(0xFF8B5CF6),
    _ => const Color(0xFF9CA3AF),
  };

  Widget _topChip(String label, {required bool selected, bool small = false, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: GestureDetector(onTap: onTap, child: Container(
        padding: EdgeInsets.symmetric(horizontal: small ? 10 : 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1B2E5C) : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(label, style: TextStyle(
          fontSize: small ? 11 : 13, fontWeight: FontWeight.w600,
          color: selected ? Colors.white : const Color(0xFF6B6B6B),
        )),
      )),
    );
  }
}

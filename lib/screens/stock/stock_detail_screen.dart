import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:k_chart/chart_translations.dart';
import 'package:k_chart/flutter_k_chart.dart';

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
  List<KLineEntity>? _kLineData;
  List<StockCandle> _rawCandles = [];
  bool _isLoading = true;

  String _chartType = 'daily';
  int _days = 250;
  bool _isLine = false;
  MainState _mainState = MainState.MA;
  SecondaryState _secondaryState = SecondaryState.NONE;
  bool _volHidden = true;

  bool _showFibPanel = false;
  bool _showSRPanel = false;
  String? _trendType;

  final ChartStyle _chartStyle = ChartStyle();
  final ChartColors _chartColors = ChartColors();

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
    _chartColors.bgColor = [Colors.white, Colors.white];
    _chartColors.kLineColor = const Color(0xFF1B2E5C);
    _chartColors.lineFillColor = const Color(0xFF1B2E5C).withValues(alpha: 0.1);
    _chartColors.upColor = const Color(0xFFE53935);
    _chartColors.dnColor = const Color(0xFF1E88E5);
    _chartColors.ma5Color = const Color(0xFFFF9800);
    _chartColors.ma10Color = const Color(0xFF4CAF50);
    _chartColors.ma30Color = const Color(0xFFF44336);
    _chartColors.defaultTextColor = const Color(0xFF6B6B6B);
    _chartColors.nowPriceUpColor = const Color(0xFFE53935);
    _chartColors.nowPriceDnColor = const Color(0xFF1E88E5);
    _chartStyle.candleWidth = 4;
    _chartStyle.candleLineWidth = 0.8;
    _loadChart();
  }

  Future<void> _loadChart() async {
    setState(() => _isLoading = true);
    List<dynamic> candles;
    switch (_chartType) {
      case 'weekly':
        candles = await StockService.getWeeklyChart(widget.stockCode, weeks: 104);
        break;
      case 'monthly':
        candles = await StockService.getMonthlyChart(widget.stockCode, months: 36);
        break;
      default:
        candles = await StockService.getChart(widget.stockCode, days: _days);
    }
    _rawCandles = candles.cast<StockCandle>();
    final kLineData = candles.map((c) {
      return KLineEntity.fromCustom(
        time: c.date.millisecondsSinceEpoch,
        open: c.open, high: c.high, low: c.low, close: c.close,
        vol: c.volume.toDouble(), change: c.changeRate,
      );
    }).toList();
    DataUtil.calculate(kLineData);
    if (mounted) setState(() { _kLineData = kLineData; _isLoading = false; });
  }

  // ─── 보조지표 설정 팝업 ───
  void _showIndicatorSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(width: 36, height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                  ),
                  const SizedBox(height: 16),
                  const Text('차트 설정', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1B2E5C))),
                  const SizedBox(height: 16),

                  // 메인 지표
                  const Text('메인 지표', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B6B6B))),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, children: [
                    _sheetChip('MA', _mainState == MainState.MA, () {
                      setSheetState(() {}); setState(() => _mainState = _mainState == MainState.MA ? MainState.NONE : MainState.MA);
                    }),
                    _sheetChip('BOLL', _mainState == MainState.BOLL, () {
                      setSheetState(() {}); setState(() => _mainState = _mainState == MainState.BOLL ? MainState.NONE : MainState.BOLL);
                    }),
                  ]),
                  const SizedBox(height: 16),

                  // 보조 지표
                  const Text('보조 지표', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B6B6B))),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, children: [
                    _sheetChip('MACD', _secondaryState == SecondaryState.MACD, () {
                      setSheetState(() {}); setState(() => _secondaryState = _secondaryState == SecondaryState.MACD ? SecondaryState.NONE : SecondaryState.MACD);
                    }),
                    _sheetChip('RSI', _secondaryState == SecondaryState.RSI, () {
                      setSheetState(() {}); setState(() => _secondaryState = _secondaryState == SecondaryState.RSI ? SecondaryState.NONE : SecondaryState.RSI);
                    }),
                    _sheetChip('KDJ', _secondaryState == SecondaryState.KDJ, () {
                      setSheetState(() {}); setState(() => _secondaryState = _secondaryState == SecondaryState.KDJ ? SecondaryState.NONE : SecondaryState.KDJ);
                    }),
                  ]),
                  const SizedBox(height: 16),

                  // 거래량
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('거래량 표시', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF3A3A3A))),
                      Switch.adaptive(
                        value: !_volHidden,
                        activeTrackColor: const Color(0xFF1B2E5C),
                        onChanged: (v) { setSheetState(() {}); setState(() => _volHidden = !v); },
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // 분석 도구
                  const Text('분석 도구', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B6B6B))),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    _sheetChip('피보나치', _showFibPanel, () {
                      setSheetState(() {}); setState(() => _showFibPanel = !_showFibPanel);
                    }),
                    _sheetChip('지지/저항', _showSRPanel, () {
                      setSheetState(() {}); setState(() => _showSRPanel = !_showSRPanel);
                    }),
                    _sheetChip('소추세', _trendType == 'small', () {
                      setSheetState(() {}); setState(() => _trendType = _trendType == 'small' ? null : 'small');
                    }),
                    _sheetChip('중추세', _trendType == 'medium', () {
                      setSheetState(() {}); setState(() => _trendType = _trendType == 'medium' ? null : 'medium');
                    }),
                    _sheetChip('대추세', _trendType == 'large', () {
                      setSheetState(() {}); setState(() => _trendType = _trendType == 'large' ? null : 'large');
                    }),
                  ]),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _sheetChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1B2E5C) : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600,
          color: selected ? Colors.white : const Color(0xFF6B6B6B),
        )),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final priceFormat = NumberFormat('#,##0');
    final price = widget.currentPrice ??
        (_kLineData != null && _kLineData!.isNotEmpty ? _kLineData!.last.close : 0);
    final change = widget.changeRate ??
        (_kLineData != null && _kLineData!.isNotEmpty ? _kLineData!.last.change ?? 0 : 0);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 48,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1B2E5C), size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Text(widget.stockName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1B2E5C))),
            const SizedBox(width: 8),
            Text(widget.stockCode, style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
          ],
        ),
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
          // 설정 버튼
          IconButton(
            icon: const Icon(Icons.tune, color: Color(0xFF1B2E5C), size: 20),
            onPressed: _showIndicatorSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          // 상단 바 (봉 타입 + 기간 + 캔들/라인)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  ..._chartTypes.map((ct) => _topChip(ct.label, selected: _chartType == ct.type, onTap: () {
                    setState(() => _chartType = ct.type);
                    _loadChart();
                  })),
                  const SizedBox(width: 6),
                  if (_chartType == 'daily')
                    ..._dayOptions.map((opt) => _topChip(opt.label, selected: _days == opt.days, small: true, onTap: () {
                      setState(() => _days = opt.days);
                      _loadChart();
                    })),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => setState(() => _isLine = !_isLine),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(10)),
                      child: Icon(_isLine ? Icons.show_chart : Icons.candlestick_chart, size: 14, color: const Color(0xFF1B2E5C)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 차트
          Expanded(
            child: _isLoading || _kLineData == null
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _kLineData!.isEmpty
                    ? const Center(child: Text('차트 데이터 없음'))
                    : KChartWidget(
                        _kLineData, _chartStyle, _chartColors,
                        isLine: _isLine, isTrendLine: false,
                        mainState: _mainState, volHidden: _volHidden,
                        secondaryState: _secondaryState, fixedLength: 0,
                        timeFormat: TimeFormat.YEAR_MONTH_DAY,
                        translations: kChartTranslations, showNowPrice: true,
                        hideGrid: false, isTapShowInfoDialog: false,
                        maDayList: const [5, 20, 60],
                        verticalTextAlignment: VerticalTextAlignment.right,
                      ),
          ),

          // 분석 패널 (토글 시)
          if (_showFibPanel || _showSRPanel || _trendType != null)
            _buildAnalysisPanel(),
        ],
      ),
    );
  }

  Widget _buildAnalysisPanel() {
    final pf = NumberFormat('#,##0');
    return Container(
      constraints: const BoxConstraints(maxHeight: 140),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_showFibPanel && _rawCandles.length >= 10) ...[
              _panelTitle('피보나치 되돌림'),
              Wrap(spacing: 6, runSpacing: 4, children: calcFibonacci(_rawCandles).map((f) {
                final c = _fibColor(f.ratio);
                final strong = f.ratio == 0.5 || f.ratio == 0.618;
                return _levelChip('${f.label} ${pf.format(f.price)}', c, strong: strong);
              }).toList()),
              const SizedBox(height: 8),
            ],
            if (_showSRPanel && _rawCandles.length >= 20) ...[
              _panelTitle('지지 / 저항'),
              Wrap(spacing: 6, runSpacing: 4, children: calcSupportResistance(_rawCandles).map((sr) {
                final c = sr.isSupport ? const Color(0xFF4CAF50) : const Color(0xFFF44336);
                return _levelChip('${sr.label} ${pf.format(sr.price)}', c);
              }).toList()),
              const SizedBox(height: 8),
            ],
            if (_trendType != null && _rawCandles.length >= 30)
              Builder(builder: (_) {
                final trend = calcTrendLines(_rawCandles).where((t) => t.type == _trendType).firstOrNull;
                if (trend == null) return const SizedBox.shrink();
                final labels = {'small': '소추세', 'medium': '중추세', 'large': '대추세'};
                final colors = {'small': const Color(0xFF9CA3AF), 'medium': const Color(0xFFF59E0B), 'large': const Color(0xFFEF4444)};
                final color = colors[_trendType]!;
                String dir = '횡보';
                if (trend.resistP1 != null && trend.resistP2 != null) {
                  dir = trend.resistP2!.price > trend.resistP1!.price ? '상승' : '하락';
                }
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _panelTitle('${labels[_trendType]} 분석'),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    if (trend.isBox) _levelChip('박스 ${pf.format(trend.boxBottom!)}~${pf.format(trend.boxTop!)}', color)
                    else ...[
                      _levelChip('추세: $dir', color),
                      if (trend.resistP2 != null) _levelChip('저항 ${pf.format(trend.resistP2!.price)}', const Color(0xFFF44336)),
                      if (trend.supportP2 != null) _levelChip('지지 ${pf.format(trend.supportP2!.price)}', const Color(0xFF4CAF50)),
                    ],
                  ]),
                ]);
              }),
          ],
        ),
      ),
    );
  }

  Widget _panelTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1B2E5C))),
  );

  Widget _levelChip(String text, Color color, {bool strong = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: strong ? Border.all(color: color, width: 1.5) : null,
      ),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: strong ? FontWeight.w700 : FontWeight.w500, color: color)),
    );
  }

  Color _fibColor(double r) => switch (r) {
    0.0 || 1.0 => const Color(0xFF9CA3AF),
    0.236 => const Color(0xFF3B82F6),
    0.382 => const Color(0xFF22C55E),
    0.5 => const Color(0xFFF59E0B),
    0.618 => const Color(0xFFEF4444),
    0.786 => const Color(0xFF8B5CF6),
    _ => const Color(0xFF9CA3AF),
  };

  Widget _topChip(String label, {required bool selected, bool small = false, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: small ? 10 : 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF1B2E5C) : const Color(0xFFF0F0F0),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(label, style: TextStyle(
            fontSize: small ? 11 : 13, fontWeight: FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF6B6B6B),
          )),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:k_chart/chart_translations.dart';
import 'package:k_chart/flutter_k_chart.dart';

import '../../services/stock_service.dart';
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
  bool _isLoading = true;

  // 차트 설정
  String _chartType = 'daily';
  int _days = 60;
  bool _isLine = false; // false=캔들, true=라인
  MainState _mainState = MainState.MA;
  SecondaryState _secondaryState = SecondaryState.MACD;
  bool _volHidden = false;

  final ChartStyle _chartStyle = ChartStyle();
  final ChartColors _chartColors = ChartColors();

  static const _chartTypes = [
    (type: 'daily', label: '일봉'),
    (type: 'weekly', label: '주봉'),
    (type: 'monthly', label: '월봉'),
  ];

  static const _dayOptions = [
    (days: 30, label: '1M'),
    (days: 60, label: '3M'),
    (days: 120, label: '6M'),
    (days: 250, label: '1Y'),
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

    final kLineData = candles.map((c) {
      return KLineEntity.fromCustom(
        time: c.date.millisecondsSinceEpoch,
        open: c.open,
        high: c.high,
        low: c.low,
        close: c.close,
        vol: c.volume.toDouble(),
        change: c.changeRate,
      );
    }).toList();

    // MA/MACD/KDJ/RSI 등 기술적 지표 계산
    DataUtil.calculate(kLineData);

    if (mounted) {
      setState(() {
        _kLineData = kLineData;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final priceFormat = NumberFormat('#,##0');
    final price = widget.currentPrice ??
        (_kLineData != null && _kLineData!.isNotEmpty ? _kLineData!.last.close : 0);
    final change = widget.changeRate ??
        (_kLineData != null && _kLineData!.isNotEmpty ? _kLineData!.last.change ?? 0 : 0);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1B2E5C)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.stockName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1B2E5C))),
            Text(widget.stockCode,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 현재가 헤더
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${priceFormat.format(price)}원',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF1B2E5C)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${change >= 0 ? "+" : ""}${change.toStringAsFixed(2)}%',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: getChangeColor(change)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),

            // 봉 타입 + 차트 모드 토글
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    ..._chartTypes.map((ct) => _chipButton(
                          ct.label,
                          selected: _chartType == ct.type,
                          onTap: () {
                            setState(() => _chartType = ct.type);
                            _loadChart();
                          },
                        )),
                    const SizedBox(width: 8),
                    if (_chartType == 'daily')
                      ..._dayOptions.map((opt) => _chipButton(
                            opt.label,
                            selected: _days == opt.days,
                            small: true,
                            onTap: () {
                              setState(() => _days = opt.days);
                              _loadChart();
                            },
                          )),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() => _isLine = !_isLine),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _isLine ? Icons.show_chart : Icons.candlestick_chart,
                          size: 16,
                          color: const Color(0xFF1B2E5C),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // k_chart 메인 차트
            Container(
              color: Colors.white,
              height: 420,
              child: _isLoading || _kLineData == null
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : _kLineData!.isEmpty
                      ? const Center(child: Text('차트 데이터 없음'))
                      : KChartWidget(
                          _kLineData,
                          _chartStyle,
                          _chartColors,
                          isLine: _isLine,
                          isTrendLine: false,
                          mainState: _mainState,
                          volHidden: _volHidden,
                          secondaryState: _secondaryState,
                          fixedLength: 0,
                          timeFormat: TimeFormat.YEAR_MONTH_DAY,
                          translations: kChartTranslations,
                          showNowPrice: true,
                          hideGrid: false,
                          isTapShowInfoDialog: false,
                          maDayList: const [5, 20, 60],
                          verticalTextAlignment: VerticalTextAlignment.right,
                        ),
            ),
            const SizedBox(height: 4),

            // 보조지표 선택 바
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    const Text('메인 ', style: TextStyle(fontSize: 11, color: Color(0xFF9E9E9E))),
                    _chipButton('MA', selected: _mainState == MainState.MA,
                        small: true, onTap: () => setState(() => _mainState = MainState.MA)),
                    _chipButton('BOLL', selected: _mainState == MainState.BOLL,
                        small: true, onTap: () => setState(() => _mainState = MainState.BOLL)),
                    _chipButton('숨김', selected: _mainState == MainState.NONE,
                        small: true, onTap: () => setState(() => _mainState = MainState.NONE)),
                    const SizedBox(width: 10),
                    const Text('보조 ', style: TextStyle(fontSize: 11, color: Color(0xFF9E9E9E))),
                    _chipButton('MACD', selected: _secondaryState == SecondaryState.MACD,
                        small: true, onTap: () => setState(() => _secondaryState = SecondaryState.MACD)),
                    _chipButton('RSI', selected: _secondaryState == SecondaryState.RSI,
                        small: true, onTap: () => setState(() => _secondaryState = SecondaryState.RSI)),
                    _chipButton('KDJ', selected: _secondaryState == SecondaryState.KDJ,
                        small: true, onTap: () => setState(() => _secondaryState = SecondaryState.KDJ)),
                    _chipButton('숨김', selected: _secondaryState == SecondaryState.NONE,
                        small: true, onTap: () => setState(() => _secondaryState = SecondaryState.NONE)),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => setState(() => _volHidden = !_volHidden),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _volHidden ? const Color(0xFFF5F5F7) : const Color(0xFF1B2E5C),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'VOL',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _volHidden ? const Color(0xFF9E9E9E) : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _chipButton(String label, {
    required bool selected,
    bool small = false,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: small ? 8 : 12,
            vertical: small ? 4 : 6,
          ),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF1B2E5C) : const Color(0xFFF5F5F7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: small ? 10 : 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : const Color(0xFF6B6B6B),
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../models/realtime_price_model.dart';
import '../../models/stock_model.dart';
import '../../services/stock_service.dart';
import '../../services/stomp_service.dart';
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
  List<StockCandle> _rawCandles = [];
  bool _isLoading = true;

  String _chartType = 'daily';
  int _days = 250;

  // 오버레이 지표 (메인 차트 위)
  bool _showMA = true;
  bool _showBB = false;
  bool _showFib = false;
  bool _showSR = false;
  bool _showTrend = false;
  String _trendWave = 'medium'; // 'small', 'medium', 'large'

  // 하단 패널 지표
  bool _showVolume = true;
  bool _showRSI = false;
  bool _showMACD = false;

  // 캐시된 계산
  List<FibLevel> _fibLevels = [];
  List<SRLevel> _srLevels = [];
  BollingerBands? _bbData;
  List<double?> _rsiData = [];
  MACDData? _macdData;
  List<TrendLine> _trendLines = [];

  // Design Ref: §5 — 실시간 모니터링 상태
  bool _isRealtimeOn = false;
  RealtimePrice? _realtimePrice;
  Timer? _blinkTimer;
  bool _blinkVisible = true;
  bool _priceHighlight = false;

  // 차트 간 줌/스크롤 동기화 (axisController 방식)
  DateTimeAxisController? _mainAxisCtrl;
  final List<DateTimeAxisController> _subAxisCtrls = [];
  bool _isSyncing = false;

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

  @override
  void dispose() {
    _stopRealtime();
    super.dispose();
  }

  // Plan SC: SC-02, SC-03 — 실시간 토글 ON/OFF
  void _toggleRealtime() async {
    if (_isRealtimeOn) {
      _stopRealtime();
    } else {
      setState(() => _isRealtimeOn = true);
      final connected = await StompService().connect();
      if (!connected) {
        if (mounted) {
          setState(() => _isRealtimeOn = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('실시간 연결에 실패했습니다'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      // Gap Fix #2: 최대 재시도 초과 시 토글 자동 OFF
      StompService().onMaxRetriesReached = () {
        if (mounted) {
          _stopRealtime();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('실시간 연결이 끊어졌습니다'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      };
      StompService().subscribe(widget.stockCode, _onRealtimePrice);
      _startBlink();
    }
  }

  void _stopRealtime() {
    _blinkTimer?.cancel();
    _blinkTimer = null;
    if (_isRealtimeOn) {
      StompService().unsubscribe(widget.stockCode);
    }
    if (mounted) {
      setState(() {
        _isRealtimeOn = false;
        _realtimePrice = null;
      });
    }
  }

  void _onRealtimePrice(RealtimePrice price) {
    if (!mounted) return;
    setState(() {
      _realtimePrice = price;
      _priceHighlight = true;
    });
    // 하이라이트 200ms 후 해제
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _priceHighlight = false);
    });
  }

  void _startBlink() {
    _blinkTimer?.cancel();
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      if (mounted) setState(() => _blinkVisible = !_blinkVisible);
    });
  }

  /// 메인 차트 줌/팬 → 서브 차트에 동기화
  void _syncFromMain() {
    if (_isSyncing || _mainAxisCtrl == null) return;
    _isSyncing = true;
    for (final ctrl in _subAxisCtrls) {
      ctrl.visibleMinimum = _mainAxisCtrl!.visibleMinimum;
      ctrl.visibleMaximum = _mainAxisCtrl!.visibleMaximum;
    }
    _isSyncing = false;
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
    _subAxisCtrls.clear();
    _recalcIndicators();

    if (mounted) setState(() => _isLoading = false);
  }

  void _recalcIndicators() {
    if (_rawCandles.isEmpty) return;
    final closes = _rawCandles.map((c) => c.close).toList();

    _bbData = _showBB ? calcBollinger(closes.cast<double?>()) : null;
    _fibLevels = _showFib && _rawCandles.length >= 10 ? calcFibonacci(_rawCandles) : [];
    _srLevels = _showSR && _rawCandles.length >= 20 ? calcSupportResistance(_rawCandles) : [];
    _rsiData = _showRSI ? calcRSI(closes) : [];
    _macdData = _showMACD ? calcMACD(closes) : null;
    _trendLines = _showTrend && _rawCandles.length >= 30 ? calcTrendLines(_rawCandles) : [];
  }

  // 미래 여백 날짜
  DateTime get _futureMaxDate {
    if (_rawCandles.isEmpty) return DateTime.now();
    final last = _rawCandles.last.date;
    final first = _rawCandles.first.date;
    final margin = Duration(milliseconds: (last.difference(first).inMilliseconds * 0.15).toInt());
    return last.add(margin);
  }

  // 메인 차트 X축 (줌/팬 가능, 컨트롤러 저장)
  DateTimeAxis _mainXAxis() {
    return DateTimeAxis(
      dateFormat: DateFormat('yy/MM/dd'),
      majorGridLines: const MajorGridLines(width: 0),
      axisLine: const AxisLine(width: 0.5, color: Color(0xFFE0E0E0)),
      labelStyle: TextStyle(fontSize: 10, color: Colors.grey.shade500),
      maximum: _futureMaxDate,
      onRendererCreated: (DateTimeAxisController ctrl) {
        _mainAxisCtrl = ctrl;
      },
    );
  }

  // 서브 차트 X축 (메인에 의해 동기화됨)
  DateTimeAxis _subXAxis() {
    return DateTimeAxis(
      dateFormat: DateFormat('yy/MM/dd'),
      majorGridLines: const MajorGridLines(width: 0),
      axisLine: const AxisLine(width: 0.5, color: Color(0xFFE0E0E0)),
      labelStyle: TextStyle(fontSize: 10, color: Colors.grey.shade500),
      maximum: _futureMaxDate,
      onRendererCreated: (DateTimeAxisController ctrl) {
        if (!_subAxisCtrls.contains(ctrl)) {
          _subAxisCtrls.add(ctrl);
        }
      },
    );
  }

  // 공유 ZoomPanBehavior 생성
  ZoomPanBehavior _makeZoomPan() {
    return ZoomPanBehavior(
      enablePanning: true,
      enablePinching: true,
      zoomMode: ZoomMode.x,
    );
  }

  @override
  Widget build(BuildContext context) {
    final priceFormat = NumberFormat('#,##0');
    // 실시간 데이터 우선, 없으면 기존 정적 데이터
    final price = _realtimePrice?.curPrice ?? widget.currentPrice ?? (_rawCandles.isNotEmpty ? _rawCandles.last.close : 0);
    final change = _realtimePrice?.diffRate ?? widget.changeRate ?? (_rawCandles.isNotEmpty ? _rawCandles.last.changeRate : 0);
    final volume = _realtimePrice?.cumVolume;

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
          // Design Ref: §5.1 — 실시간 가격 + 토글
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _priceHighlight
                    ? (change >= 0 ? const Color(0xFFD32F2F).withValues(alpha: 0.08) : const Color(0xFF1976D2).withValues(alpha: 0.08))
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isRealtimeOn)
                        AnimatedOpacity(
                          opacity: _blinkVisible ? 1.0 : 0.3,
                          duration: const Duration(milliseconds: 300),
                          child: Container(
                            width: 6, height: 6,
                            margin: const EdgeInsets.only(right: 4),
                            decoration: const BoxDecoration(
                              color: Color(0xFFD32F2F),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      Text('${priceFormat.format(price)}원',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1B2E5C))),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${change >= 0 ? "+" : ""}${change.toStringAsFixed(2)}%',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: getChangeColor(change))),
                      if (volume != null) ...[
                        const SizedBox(width: 4),
                        Text(NumberFormat.compact().format(volume),
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          // 실시간 토글 버튼
          IconButton(
            icon: Icon(
              _isRealtimeOn ? Icons.cell_tower : Icons.cell_tower_outlined,
              color: _isRealtimeOn ? const Color(0xFFD32F2F) : const Color(0xFF1B2E5C),
              size: 20,
            ),
            tooltip: _isRealtimeOn ? '실시간 OFF' : '실시간 ON',
            onPressed: _toggleRealtime,
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

          // 차트 영역
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _rawCandles.isEmpty
                    ? const Center(child: Text('차트 데이터 없음'))
                    : Column(
                        children: [
                          // 메인 캔들차트
                          Expanded(child: _buildMainChart()),

                          // 하단 패널: 거래량
                          if (_showVolume) _buildSubPanel(_buildVolumeChart(), height: 80, label: '거래량'),

                          // 하단 패널: RSI
                          if (_showRSI) _buildSubPanel(_buildRSIChart(), height: 80, label: 'RSI'),

                          // 하단 패널: MACD
                          if (_showMACD) _buildSubPanel(_buildMACDChart(), height: 90, label: 'MACD'),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  /// 하단 서브 패널 래퍼 (구분선 + 라벨)
  Widget _buildSubPanel(Widget chart, {required double height, required String label}) {
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          // 구분선
          Positioned(top: 0, left: 0, right: 0, child: Divider(height: 1, color: Colors.grey.shade300)),
          // 라벨
          Positioned(
            top: 4, left: 8,
            child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.grey.shade400)),
          ),
          // 차트
          Positioned.fill(child: Padding(padding: const EdgeInsets.only(top: 2), child: chart)),
        ],
      ),
    );
  }

  // ─── 메인 캔들 차트 ───

  Widget _buildMainChart() {
    final currentPrice = _rawCandles.last.close;

    final plotBands = <PlotBand>[
      // 현재가 마커 (보라색 점선)
      PlotBand(
        start: currentPrice, end: currentPrice,
        borderWidth: 1.2, borderColor: const Color(0xFF7C4DFF),
        dashArray: const <double>[4, 3],
        color: Colors.transparent,
      ),
    ];

    // 피보나치 수평선
    for (final f in _fibLevels) {
      final isStrong = f.ratio == 0.5 || f.ratio == 0.618;
      plotBands.add(PlotBand(
        start: f.price, end: f.price,
        borderWidth: isStrong ? 1.2 : 0.6,
        borderColor: _fibColor(f.ratio).withValues(alpha: isStrong ? 0.7 : 0.4),
        dashArray: const <double>[4, 4],
        text: '${f.label} ${NumberFormat("#,##0").format(f.price)}',
        textStyle: TextStyle(fontSize: 8, color: _fibColor(f.ratio).withValues(alpha: 0.8)),
        horizontalTextAlignment: TextAnchor.end,
        color: Colors.transparent,
      ));
    }

    // 지지/저항 수평선
    for (final sr in _srLevels) {
      final color = sr.isSupport ? const Color(0xFF4CAF50) : const Color(0xFFF44336);
      plotBands.add(PlotBand(
        start: sr.price, end: sr.price,
        borderWidth: sr.level == 1 ? 1.2 : 0.6,
        borderColor: color.withValues(alpha: sr.level == 1 ? 0.7 : 0.4),
        dashArray: const <double>[6, 3],
        text: '${sr.label} ${NumberFormat("#,##0").format(sr.price)}',
        textStyle: TextStyle(fontSize: 8, color: color.withValues(alpha: 0.8)),
        horizontalTextAlignment: TextAnchor.end,
        color: Colors.transparent,
      ));
    }

    return SfCartesianChart(
      zoomPanBehavior: _makeZoomPan(),
      onZooming: (_) => _syncFromMain(),
      plotAreaBorderWidth: 0,
      margin: const EdgeInsets.only(right: 0, left: 0, top: 8),

      primaryXAxis: _mainXAxis(),
      primaryYAxis: NumericAxis(
        opposedPosition: true,
        numberFormat: NumberFormat('#,##0'),
        majorGridLines: MajorGridLines(width: 0.5, color: Colors.grey.shade200),
        axisLine: const AxisLine(width: 0),
        labelStyle: TextStyle(fontSize: 10, color: Colors.grey.shade500),
        plotBands: plotBands,
      ),

      // 현재가 Y축 태그 (오른쪽에 태그처럼 표시)
      annotations: <CartesianChartAnnotation>[
        CartesianChartAnnotation(
          widget: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF7C4DFF),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              NumberFormat('#,##0').format(currentPrice),
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
          coordinateUnit: CoordinateUnit.point,
          region: AnnotationRegion.chart,
          x: _futureMaxDate,
          y: currentPrice,
        ),
      ],

      trackballBehavior: TrackballBehavior(
        enable: true,
        activationMode: ActivationMode.singleTap,
        lineType: TrackballLineType.vertical,
      ),

      series: _buildMainSeries(),
    );
  }

  List<CartesianSeries> _buildMainSeries() {
    final series = <CartesianSeries>[];

    // 캔들스틱
    series.add(CandleSeries<StockCandle, DateTime>(
      dataSource: _rawCandles,
      xValueMapper: (c, _) => c.date,
      openValueMapper: (c, _) => c.open,
      highValueMapper: (c, _) => c.high,
      lowValueMapper: (c, _) => c.low,
      closeValueMapper: (c, _) => c.close,
      bullColor: const Color(0xFFE53935),
      bearColor: const Color(0xFF1E88E5),
      enableSolidCandles: true,
    ));

    // MA 이동평균선
    if (_showMA) {
      final closes = _rawCandles.map((c) => c.close).toList();
      for (final (period, color) in [(5, const Color(0xFFFF9800)), (20, const Color(0xFF4CAF50)), (60, const Color(0xFFF44336))]) {
        final maValues = _calcMA(closes, period);
        final maData = <_ChartPoint>[];
        for (var i = 0; i < _rawCandles.length; i++) {
          if (maValues[i] != null) maData.add(_ChartPoint(_rawCandles[i].date, maValues[i]!));
        }
        series.add(LineSeries<_ChartPoint, DateTime>(
          dataSource: maData,
          xValueMapper: (p, _) => p.date,
          yValueMapper: (p, _) => p.value,
          color: color, width: 1, animationDuration: 0,
        ));
      }
    }

    // 볼린저밴드
    if (_showBB && _bbData != null) {
      final bb = _bbData!;
      for (final (values, alpha) in [(bb.upper, 0.6), (bb.middle, 0.3), (bb.lower, 0.6)]) {
        final data = <_ChartPoint>[];
        for (var i = 0; i < _rawCandles.length; i++) {
          if (values[i] != null) data.add(_ChartPoint(_rawCandles[i].date, values[i]!));
        }
        series.add(LineSeries<_ChartPoint, DateTime>(
          dataSource: data,
          xValueMapper: (p, _) => p.date,
          yValueMapper: (p, _) => p.value,
          color: const Color(0xFF7C4DFF).withValues(alpha: alpha),
          width: alpha > 0.5 ? 1 : 0.8, animationDuration: 0,
        ));
      }
    }

    // 추세선 (소/중/대)
    if (_showTrend && _trendLines.isNotEmpty) {
      final selected = _trendLines.where((t) => t.type == _trendWave).firstOrNull;
      if (selected != null) {
        final n = _rawCandles.length;
        final lineWidth = switch (selected.type) { 'large' => 2.0, 'medium' => 1.5, _ => 1.0 };
        final color = switch (selected.type) {
          'large' => const Color(0xFFEF4444),
          'medium' => const Color(0xFFF59E0B),
          _ => const Color(0xFF9CA3AF),
        };

        if (selected.isBox && selected.boxTop != null && selected.boxBottom != null) {
          // 박스권: 상단/하단 수평선
          final boxTopData = List.generate(n, (i) => _ChartPoint(_rawCandles[i].date, selected.boxTop!));
          final boxBtmData = List.generate(n, (i) => _ChartPoint(_rawCandles[i].date, selected.boxBottom!));
          series.add(LineSeries<_ChartPoint, DateTime>(
            dataSource: boxTopData, xValueMapper: (p, _) => p.date, yValueMapper: (p, _) => p.value,
            color: color.withValues(alpha: 0.6), width: lineWidth, dashArray: const <double>[6, 3], animationDuration: 0,
          ));
          series.add(LineSeries<_ChartPoint, DateTime>(
            dataSource: boxBtmData, xValueMapper: (p, _) => p.date, yValueMapper: (p, _) => p.value,
            color: color.withValues(alpha: 0.6), width: lineWidth, dashArray: const <double>[6, 3], animationDuration: 0,
          ));
        } else {
          // 저항 추세선 (최근 2개 고점 연결 → 차트 끝까지 연장)
          if (selected.resistP1 != null && selected.resistP2 != null) {
            final rData = <_ChartPoint>[];
            final startIdx = selected.resistP1!.index;
            for (var i = startIdx; i < n; i++) {
              rData.add(_ChartPoint(_rawCandles[i].date, trendPriceAt(selected.resistP1!, selected.resistP2!, i)));
            }
            series.add(LineSeries<_ChartPoint, DateTime>(
              dataSource: rData, xValueMapper: (p, _) => p.date, yValueMapper: (p, _) => p.value,
              color: const Color(0xFFF44336).withValues(alpha: 0.7), width: lineWidth, animationDuration: 0,
            ));
          }
          // 지지 추세선 (최근 2개 저점 연결 → 차트 끝까지 연장)
          if (selected.supportP1 != null && selected.supportP2 != null) {
            final sData = <_ChartPoint>[];
            final startIdx = selected.supportP1!.index;
            for (var i = startIdx; i < n; i++) {
              sData.add(_ChartPoint(_rawCandles[i].date, trendPriceAt(selected.supportP1!, selected.supportP2!, i)));
            }
            series.add(LineSeries<_ChartPoint, DateTime>(
              dataSource: sData, xValueMapper: (p, _) => p.date, yValueMapper: (p, _) => p.value,
              color: const Color(0xFF4CAF50).withValues(alpha: 0.7), width: lineWidth, animationDuration: 0,
            ));
          }
        }
      }
    }

    return series;
  }

  // ─── 거래량 차트 ───

  Widget _buildVolumeChart() {
    return SfCartesianChart(
      plotAreaBorderWidth: 0,
      margin: const EdgeInsets.only(right: 0, left: 0),
      primaryXAxis: _subXAxis(),
      primaryYAxis: NumericAxis(
        opposedPosition: true,
        isVisible: true,
        majorGridLines: const MajorGridLines(width: 0),
        axisLine: const AxisLine(width: 0),
        labelStyle: TextStyle(fontSize: 8, color: Colors.grey.shade400),
        numberFormat: NumberFormat.compact(),
        maximumLabels: 2,
      ),
      series: <CartesianSeries>[
        ColumnSeries<StockCandle, DateTime>(
          dataSource: _rawCandles,
          xValueMapper: (c, _) => c.date,
          yValueMapper: (c, _) => c.volume.toDouble(),
          pointColorMapper: (c, _) => c.close >= c.open
              ? const Color(0xFFE53935).withValues(alpha: 0.7)
              : const Color(0xFF1E88E5).withValues(alpha: 0.7),
          width: 0.7, animationDuration: 0,
        ),
      ],
    );
  }

  // ─── RSI 차트 ───

  Widget _buildRSIChart() {
    final data = <_ChartPoint>[];
    for (var i = 0; i < _rawCandles.length; i++) {
      if (_rsiData.length > i && _rsiData[i] != null) {
        data.add(_ChartPoint(_rawCandles[i].date, _rsiData[i]!));
      }
    }

    return SfCartesianChart(
      plotAreaBorderWidth: 0,
      margin: const EdgeInsets.only(right: 0, left: 0),
      primaryXAxis: _subXAxis(),
      primaryYAxis: NumericAxis(
        opposedPosition: true,
        minimum: 0, maximum: 100,
        majorGridLines: const MajorGridLines(width: 0),
        axisLine: const AxisLine(width: 0),
        labelStyle: TextStyle(fontSize: 8, color: Colors.grey.shade400),
        maximumLabels: 3,
        plotBands: [
          PlotBand(start: 70, end: 70, borderWidth: 0.5, borderColor: Colors.red.shade200,
            dashArray: const <double>[3, 3], color: Colors.transparent),
          PlotBand(start: 30, end: 30, borderWidth: 0.5, borderColor: Colors.blue.shade200,
            dashArray: const <double>[3, 3], color: Colors.transparent),
        ],
      ),
      series: <CartesianSeries>[
        LineSeries<_ChartPoint, DateTime>(
          dataSource: data,
          xValueMapper: (p, _) => p.date,
          yValueMapper: (p, _) => p.value,
          color: const Color(0xFF8B5CF6), width: 1.2, animationDuration: 0,
        ),
      ],
    );
  }

  // ─── MACD 차트 ───

  Widget _buildMACDChart() {
    if (_macdData == null) return const SizedBox();

    final macdPoints = <_ChartPoint>[];
    final signalPoints = <_ChartPoint>[];
    final histPoints = <_HistPoint>[];

    for (var i = 0; i < _rawCandles.length; i++) {
      final date = _rawCandles[i].date;
      if (_macdData!.macdLine[i] != null) {
        macdPoints.add(_ChartPoint(date, _macdData!.macdLine[i]!));
      }
      if (_macdData!.signalLine[i] != null) {
        signalPoints.add(_ChartPoint(date, _macdData!.signalLine[i]!));
      }
      if (_macdData!.histogram[i] != null) {
        histPoints.add(_HistPoint(date, _macdData!.histogram[i]!));
      }
    }

    return SfCartesianChart(
      plotAreaBorderWidth: 0,
      margin: const EdgeInsets.only(right: 0, left: 0),
      primaryXAxis: _subXAxis(),
      primaryYAxis: NumericAxis(
        opposedPosition: true,
        majorGridLines: const MajorGridLines(width: 0),
        axisLine: const AxisLine(width: 0),
        labelStyle: TextStyle(fontSize: 8, color: Colors.grey.shade400),
        maximumLabels: 2,
        plotBands: [
          PlotBand(start: 0, end: 0, borderWidth: 0.5, borderColor: Colors.grey.shade300, color: Colors.transparent),
        ],
      ),
      series: <CartesianSeries>[
        // 히스토그램 바
        ColumnSeries<_HistPoint, DateTime>(
          dataSource: histPoints,
          xValueMapper: (p, _) => p.date,
          yValueMapper: (p, _) => p.value,
          pointColorMapper: (p, _) => p.value >= 0
              ? const Color(0xFFE53935).withValues(alpha: 0.6)
              : const Color(0xFF1E88E5).withValues(alpha: 0.6),
          width: 0.6, animationDuration: 0,
        ),
        // MACD 라인
        LineSeries<_ChartPoint, DateTime>(
          dataSource: macdPoints,
          xValueMapper: (p, _) => p.date,
          yValueMapper: (p, _) => p.value,
          color: const Color(0xFF1B2E5C), width: 1.2, animationDuration: 0,
        ),
        // Signal 라인
        LineSeries<_ChartPoint, DateTime>(
          dataSource: signalPoints,
          xValueMapper: (p, _) => p.date,
          yValueMapper: (p, _) => p.value,
          color: const Color(0xFFFF9800), width: 1, animationDuration: 0,
        ),
      ],
    );
  }

  // ─── 공통 유틸 ───

  List<double?> _calcMA(List<double> closes, int period) {
    final result = List<double?>.filled(closes.length, null);
    if (closes.length < period) return result;
    for (var i = period - 1; i < closes.length; i++) {
      var sum = 0.0;
      for (var j = i - period + 1; j <= i; j++) sum += closes[j];
      result[i] = sum / period;
    }
    return result;
  }

  // ─── 설정 시트 ───

  void _showSettingsSheet() {
    final pf = NumberFormat('#,##0');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          return DraggableScrollableSheet(
            expand: false, initialChildSize: 0.65, maxChildSize: 0.85, minChildSize: 0.3,
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

                  // ─ 오버레이 지표
                  const SizedBox(height: 12),
                  Text('오버레이 지표', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
                  const SizedBox(height: 4),

                  _settingRow('이동평균선 (MA5/20/60)', _showMA, (v) {
                    setSheet(() {}); setState(() { _showMA = v; _recalcIndicators(); });
                  }),
                  _settingRow('볼린저밴드 (BB20)', _showBB, (v) {
                    setSheet(() {}); setState(() { _showBB = v; _recalcIndicators(); });
                  }),
                  _settingRow('피보나치 되돌림', _showFib, (v) {
                    setSheet(() {}); setState(() { _showFib = v; _recalcIndicators(); });
                  }),
                  if (_showFib && _fibLevels.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(spacing: 6, runSpacing: 4, children: _fibLevels.map((f) {
                      final strong = f.ratio == 0.5 || f.ratio == 0.618;
                      return _valueChip('${f.label} ${pf.format(f.price)}', _fibColor(f.ratio), strong: strong);
                    }).toList()),
                    const SizedBox(height: 8),
                  ],
                  _settingRow('지지/저항선', _showSR, (v) {
                    setSheet(() {}); setState(() { _showSR = v; _recalcIndicators(); });
                  }),
                  if (_showSR && _srLevels.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(spacing: 6, runSpacing: 4, children: _srLevels.map((sr) {
                      final c = sr.isSupport ? const Color(0xFF4CAF50) : const Color(0xFFF44336);
                      return _valueChip('${sr.label} ${pf.format(sr.price)}', c);
                    }).toList()),
                    const SizedBox(height: 8),
                  ],

                  // 추세선
                  _settingRow('추세선 (소/중/대)', _showTrend, (v) {
                    setSheet(() {}); setState(() { _showTrend = v; _recalcIndicators(); });
                  }),
                  if (_showTrend) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      for (final (key, label, color) in [
                        ('small', '소파동', const Color(0xFF9CA3AF)),
                        ('medium', '중파동', const Color(0xFFF59E0B)),
                        ('large', '대파동', const Color(0xFFEF4444)),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: GestureDetector(
                            onTap: () { setSheet(() {}); setState(() { _trendWave = key; _recalcIndicators(); }); },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: _trendWave == key ? color.withValues(alpha: 0.15) : const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(8),
                                border: _trendWave == key ? Border.all(color: color, width: 1.5) : null,
                              ),
                              child: Text(label, style: TextStyle(
                                fontSize: 11, fontWeight: _trendWave == key ? FontWeight.w700 : FontWeight.w500,
                                color: _trendWave == key ? color : const Color(0xFF6B6B6B),
                              )),
                            ),
                          ),
                        ),
                    ]),
                    if (_trendLines.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Builder(builder: (_) {
                        final t = _trendLines.where((t) => t.type == _trendWave).firstOrNull;
                        if (t == null) return const SizedBox();
                        if (t.isBox) {
                          return _valueChip('박스권 ${pf.format(t.boxTop!)} ~ ${pf.format(t.boxBottom!)}', const Color(0xFFF59E0B), strong: true);
                        }
                        return Wrap(spacing: 6, runSpacing: 4, children: [
                          if (t.resistP2 != null) _valueChip('저항 ${pf.format(t.resistP2!.price)}', const Color(0xFFF44336)),
                          if (t.supportP2 != null) _valueChip('지지 ${pf.format(t.supportP2!.price)}', const Color(0xFF4CAF50)),
                        ]);
                      }),
                    ],
                    const SizedBox(height: 8),
                  ],

                  // ─ 하단 패널 지표
                  const Divider(height: 24),
                  Text('하단 패널', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
                  const SizedBox(height: 4),

                  _settingRow('거래량', _showVolume, (v) {
                    setSheet(() {}); setState(() => _showVolume = v);
                  }),
                  _settingRow('RSI (14)', _showRSI, (v) {
                    setSheet(() {}); setState(() { _showRSI = v; _recalcIndicators(); });
                  }),
                  _settingRow('MACD (12/26/9)', _showMACD, (v) {
                    setSheet(() {}); setState(() { _showMACD = v; _recalcIndicators(); });
                  }),
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

class _ChartPoint {
  final DateTime date;
  final double value;
  _ChartPoint(this.date, this.value);
}

class _HistPoint {
  final DateTime date;
  final double value;
  _HistPoint(this.date, this.value);
}

import 'package:flutter/material.dart';

import '../../models/macro_asset_model.dart';
import '../../services/macro_service.dart';
import '../../utils/macro_utils.dart';
import 'asset_card_grid.dart';
import 'asset_history_chart.dart';
import 'category_filter.dart';
import 'cross_signal_section.dart';
import 'sentiment_gauge_section.dart';

class MacroDashboardScreen extends StatefulWidget {
  const MacroDashboardScreen({super.key});

  @override
  State<MacroDashboardScreen> createState() => _MacroDashboardScreenState();
}

class _MacroDashboardScreenState extends State<MacroDashboardScreen> {
  List<MacroAsset> _assets = [];
  FearGreedData? _fearGreed;
  YieldSpreadData? _yieldSpread;
  bool _isLoading = true;
  String _selectedCategory = 'all';
  String? _selectedSymbol;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // 캐시 데이터 + 심리 지표 병렬 로드
    final results = await Future.wait([
      MacroService.getLatest(),
      MacroService.getFearGreed(),
      MacroService.getYieldSpread(),
    ]);

    if (!mounted) return;
    setState(() {
      _assets = results[0] as List<MacroAsset>;
      _fearGreed = results[1] as FearGreedData?;
      _yieldSpread = results[2] as YieldSpreadData?;
      _isLoading = false;
    });
  }

  Future<void> _refreshRealtime() async {
    setState(() => _isLoading = true);

    final results = await Future.wait([
      MacroService.getCurrent(
        category: _selectedCategory == 'all' ? null : _selectedCategory,
      ),
      MacroService.getFearGreed(),
      MacroService.getYieldSpread(),
    ]);

    if (!mounted) return;
    setState(() {
      _assets = results[0] as List<MacroAsset>;
      _fearGreed = results[1] as FearGreedData?;
      _yieldSpread = results[2] as YieldSpreadData?;
      _isLoading = false;
    });
  }

  List<MacroAsset> get _filteredAssets {
    if (_selectedCategory == 'all') return _assets;
    return _assets.where((a) => a.category == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refreshRealtime,
      child: _isLoading && _assets.isEmpty
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1B2E5C)))
          : SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),

                  // 시장 심리 게이지
                  SentimentGaugeSection(
                    fearGreed: _fearGreed,
                    yieldSpread: _yieldSpread,
                    assets: _assets,
                  ),
                  const SizedBox(height: 16),

                  // 카테고리 필터
                  CategoryFilter(
                    selected: _selectedCategory,
                    onChanged: (cat) => setState(() {
                      _selectedCategory = cat;
                      _selectedSymbol = null;
                    }),
                  ),
                  const SizedBox(height: 12),

                  // 크로스시그널 (전체 카테고리 시)
                  if (_selectedCategory == 'all') ...[
                    CrossSignalSection(signals: generateCrossSignals(_assets)),
                    const SizedBox(height: 12),
                  ],

                  // 자산 카드 그리드
                  AssetCardGrid(
                    assets: _filteredAssets,
                    selectedSymbol: _selectedSymbol,
                    onSelect: (symbol) {
                      setState(() {
                        _selectedSymbol = _selectedSymbol == symbol ? null : symbol;
                      });
                    },
                  ),
                  const SizedBox(height: 12),

                  // 히스토리 차트 (선택된 자산)
                  if (_selectedSymbol != null) ...[
                    AssetHistoryChart(
                      symbol: _selectedSymbol!,
                      name: _assets
                              .where((a) => a.symbol == _selectedSymbol)
                              .firstOrNull
                              ?.name ??
                          _selectedSymbol!,
                    ),
                    const SizedBox(height: 16),
                  ],

                  const SizedBox(height: 80), // BottomNav 여백
                ],
              ),
            ),
    );
  }
}

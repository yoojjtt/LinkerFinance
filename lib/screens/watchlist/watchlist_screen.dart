import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/watchlist_model.dart';
import '../../services/watchlist_service.dart';
import '../../utils/macro_utils.dart';
import '../stock/stock_detail_screen.dart';

class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key});

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

// Design Ref: §6 — 관심종목 1분 자동 갱신 + AppLifecycle
class _WatchlistScreenState extends State<WatchlistScreen>
    with WidgetsBindingObserver {
  List<WatchlistGroup> _groups = [];
  List<WatchlistStock> _stocks = [];
  bool _isLoading = true;
  int? _activeGroupId; // null = 전체
  String _activePeriod = '1m';

  // Plan SC: SC-01 — 1분 자동 갱신
  Timer? _autoRefreshTimer;
  bool _isAutoRefreshing = false;

  static const _periods = ['1w', '1m', '6m', '1y'];
  static const _periodLabels = ['1주', '1개월', '6개월', '1년'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Plan SC: SC-05 — 백그라운드 → 포그라운드 복원
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (state == AppLifecycleState.paused) {
      _autoRefreshTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      _loadData();
      _startAutoRefresh();
    }
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _silentRefresh(),
    );
  }

  Future<void> _silentRefresh() async {
    if (_isAutoRefreshing || !mounted) return;
    _isAutoRefreshing = true;

    try {
      final results = await Future.wait([
        WatchlistService.getGroups(),
        WatchlistService.getStocks(groupId: _activeGroupId),
      ]);

      final groups = results[0] as List<WatchlistGroup>;
      final stocks = results[1] as List<WatchlistStock>;

      if (stocks.isNotEmpty) {
        final codes = stocks.map((s) => s.stockCode).toList();
        final returns = await WatchlistService.getReturns(codes, period: _activePeriod);
        for (final stock in stocks) {
          if (returns.containsKey(stock.stockCode)) {
            stock.returns = returns[stock.stockCode]!;
          }
        }
      }

      if (mounted) {
        setState(() {
          _groups = groups;
          _stocks = stocks;
        });
      }
    } catch (_) {
      // 조용히 스킵 — 다음 주기에 재시도
    }

    _isAutoRefreshing = false;
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final results = await Future.wait([
      WatchlistService.getGroups(),
      WatchlistService.getStocks(groupId: _activeGroupId),
    ]);

    if (!mounted) return;

    final groups = results[0] as List<WatchlistGroup>;
    final stocks = results[1] as List<WatchlistStock>;

    // 수익률 조회
    if (stocks.isNotEmpty) {
      final codes = stocks.map((s) => s.stockCode).toList();
      final returns = await WatchlistService.getReturns(codes, period: _activePeriod);
      for (final stock in stocks) {
        if (returns.containsKey(stock.stockCode)) {
          stock.returns = returns[stock.stockCode]!;
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _groups = groups;
      _stocks = stocks;
      _isLoading = false;
    });
  }

  Future<void> _onPeriodChanged(String period) async {
    setState(() {
      _activePeriod = period;
      _isLoading = true;
    });

    if (_stocks.isNotEmpty) {
      final codes = _stocks.map((s) => s.stockCode).toList();
      final returns = await WatchlistService.getReturns(codes, period: period);
      for (final stock in _stocks) {
        if (returns.containsKey(stock.stockCode)) {
          stock.returns = returns[stock.stockCode]!;
        }
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  List<WatchlistStock> get _filteredStocks {
    if (_activeGroupId == null) return _stocks;
    return _stocks.where((s) => s.groupId == _activeGroupId).toList();
  }

  double get _avgReturn {
    final stocks = _filteredStocks;
    if (stocks.isEmpty) return 0;
    final rates = stocks
        .map((s) => s.returns[_activePeriod] ?? 0.0)
        .toList();
    return rates.reduce((a, b) => a + b) / rates.length;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: _isLoading && _stocks.isEmpty
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1B2E5C)))
          : SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),

                  // 기간 선택 탭
                  _buildPeriodTabs(),
                  const SizedBox(height: 12),

                  // 그룹 필터
                  _buildGroupFilter(),
                  const SizedBox(height: 12),

                  // 포트폴리오 요약
                  _buildSummary(),
                  const SizedBox(height: 12),

                  // 종목 카드 리스트
                  if (_filteredStocks.isEmpty)
                    _buildEmpty()
                  else
                    ..._buildGroupedCards(),

                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }

  Widget _buildPeriodTabs() {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _periods.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isSelected = _activePeriod == _periods[index];
          return GestureDetector(
            onTap: () => _onPeriodChanged(_periods[index]),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF1B2E5C) : const Color(0xFFF5F5F7),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                _periodLabels[index],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF6B6B6B),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGroupFilter() {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _groups.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isAll = index == 0;
          final isSelected = isAll ? _activeGroupId == null : _activeGroupId == _groups[index - 1].id;
          final label = isAll ? '전체' : _groups[index - 1].groupName;
          final count = isAll ? _stocks.length : _groups[index - 1].stockCount;

          return GestureDetector(
            onTap: () {
              setState(() => _activeGroupId = isAll ? null : _groups[index - 1].id);
              _loadData();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF1B2E5C).withValues(alpha: 0.1) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected ? const Color(0xFF1B2E5C) : Colors.grey.shade300,
                ),
              ),
              child: Text(
                '$label ($count)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? const Color(0xFF1B2E5C) : const Color(0xFF6B6B6B),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummary() {
    final stocks = _filteredStocks;
    final upCount = stocks.where((s) => s.fluRate > 0).length;
    final downCount = stocks.where((s) => s.fluRate < 0).length;
    final avg = _avgReturn;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _summaryItem('평균수익률', '${avg >= 0 ? "+" : ""}${avg.toStringAsFixed(2)}%', getChangeColor(avg)),
              _divider(),
              _summaryItem('종목수', '${stocks.length}', const Color(0xFF1B2E5C)),
              _divider(),
              _summaryItem('상승/하락', '$upCount / $downCount', const Color(0xFF6B6B6B)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.autorenew, size: 12, color: Colors.grey.shade400),
              const SizedBox(width: 4),
              Text(
                '1분마다 자동갱신',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value, Color valueColor) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: valueColor)),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(width: 1, height: 30, color: Colors.grey.shade200);
  }

  List<Widget> _buildGroupedCards() {
    if (_activeGroupId != null) {
      // 특정 그룹 선택 시 그룹 헤더 없이 카드만
      return _filteredStocks.map((s) => _buildStockCard(s)).toList();
    }

    // 전체: 그룹별 섹션
    final widgets = <Widget>[];
    final grouped = <int?, List<WatchlistStock>>{};
    for (final s in _stocks) {
      grouped.putIfAbsent(s.groupId, () => []).add(s);
    }

    for (final group in _groups) {
      final groupStocks = grouped[group.id] ?? [];
      if (groupStocks.isEmpty) continue;

      final groupAvg = groupStocks.isEmpty
          ? 0.0
          : groupStocks.map((s) => s.returns[_activePeriod] ?? 0.0).reduce((a, b) => a + b) / groupStocks.length;

      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Text(
                '${group.groupName} (${groupStocks.length})',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1B2E5C)),
              ),
              const Spacer(),
              Text(
                '${groupAvg >= 0 ? "+" : ""}${groupAvg.toStringAsFixed(2)}%',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: getChangeColor(groupAvg)),
              ),
            ],
          ),
        ),
      );
      widgets.addAll(groupStocks.map((s) => _buildStockCard(s)));
    }

    // 미분류 종목
    final unclassified = grouped[null] ?? [];
    if (unclassified.isNotEmpty) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            '미분류 (${unclassified.length})',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF6B6B6B)),
          ),
        ),
      );
      widgets.addAll(unclassified.map((s) => _buildStockCard(s)));
    }

    return widgets;
  }

  Widget _buildStockCard(WatchlistStock stock) {
    final returnRate = stock.returns[_activePeriod] ?? 0.0;
    final priceFormat = NumberFormat('#,##0');

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StockDetailScreen(
            stockCode: stock.stockCode,
            stockName: stock.stockName,
            currentPrice: stock.curPrice,
            changeRate: stock.fluRate,
          ),
        ),
      ),
      child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // 종목 정보 (왼쪽)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stock.stockName,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1B2E5C)),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      stock.stockCode,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                    ),
                    if (stock.sectorName != null) ...[
                      Text(' · ', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                      Text(stock.sectorName!, style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                    ],
                  ],
                ),
                if (stock.memo != null && stock.memo!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    stock.memo!,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          // 가격 + 수익률 (오른쪽)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                stock.curPrice > 0 ? '${priceFormat.format(stock.curPrice)}원' : '-',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF3A3A3A)),
              ),
              const SizedBox(height: 2),
              Text(
                '${stock.fluRate >= 0 ? "+" : ""}${stock.fluRate.toStringAsFixed(2)}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: getChangeColor(stock.fluRate),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: getChangeColor(returnRate).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${returnRate >= 0 ? "+" : ""}${returnRate.toStringAsFixed(2)}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: getChangeColor(returnRate),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Icon(Icons.star_outline, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              '관심종목이 없습니다',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 8),
            Text(
              '웹에서 관심종목을 추가해주세요',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../models/investor_model.dart';
import '../../models/macro_asset_model.dart';
import '../../models/scanner_model.dart';
import '../../services/investor_service.dart';
import '../../services/macro_service.dart';
import '../../services/scanner_service.dart';
import 'widgets/ai_scan_section.dart';
import 'widgets/investor_flow_section.dart';
import 'widgets/macro_summary_section.dart';
import 'widgets/market_diagnosis_card.dart';
import 'widgets/sector_scanner_section.dart';

// Design Ref: §5.1 — 새 홈 탭 (5개 섹션 스크롤)
// 각 섹션 독립 로딩 — 빠른 데이터 먼저 표시, 느린 데이터는 개별 로딩

class MarketHomeScreen extends StatefulWidget {
  const MarketHomeScreen({super.key});

  @override
  State<MarketHomeScreen> createState() => _MarketHomeScreenState();
}

class _MarketHomeScreenState extends State<MarketHomeScreen> {
  // 데이터
  FearGreedData? _fearGreed;
  List<MacroAsset> _macroAssets = [];
  List<SectorFlow> _sectorFlows = [];
  List<ScanResult> _scanResults = [];
  MarketSummary? _marketSummary;

  // 섹션별 로딩 상태
  bool _macroLoading = true;
  bool _sectorLoading = true;
  bool _scanLoading = true;
  bool _investorLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    // 모든 로딩 상태 초기화
    if (mounted) {
      setState(() {
        _macroLoading = true;
        _sectorLoading = true;
        _scanLoading = true;
        _investorLoading = true;
      });
    }

    // 각 섹션 독립적으로 로딩 — 먼저 완료되는 것부터 화면에 표시
    _loadMacro();
    _loadSectors();
    _loadScanner();
    _loadInvestor();
  }

  Future<void> _loadMacro() async {
    try {
      final results = await Future.wait([
        MacroService.getFearGreed(),
        MacroService.getCurrent(),
      ]);
      if (!mounted) return;
      setState(() {
        _fearGreed = results[0] as FearGreedData?;
        _macroAssets = results[1] as List<MacroAsset>;
        _macroLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _macroLoading = false);
    }
  }

  Future<void> _loadSectors() async {
    try {
      final flows = await ScannerService.getSectorFlow();
      if (!mounted) return;
      setState(() {
        _sectorFlows = flows;
        _sectorLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _sectorLoading = false);
    }
  }

  Future<void> _loadScanner() async {
    try {
      final results = await ScannerService.getResults();
      if (!mounted) return;
      setState(() {
        _scanResults = results;
        _scanLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _scanLoading = false);
    }
  }

  Future<void> _loadInvestor() async {
    try {
      final summary = await InvestorService.getMarketSummary();
      debugPrint('[Home] investor summary: kospi=${summary?.kospi != null}, etc=${summary?.etc != null}');
      if (!mounted) return;
      setState(() {
        _marketSummary = summary;
        _investorLoading = false;
      });
    } catch (e) {
      debugPrint('[Home] investor 로딩 에러: $e');
      if (mounted) setState(() => _investorLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadAllData,
      color: const Color(0xFF1B2E5C),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ① 한줄 진단 — macro 로딩 완료 시 표시, 아니면 스켈레톤
            if (_macroLoading)
              _buildSkeleton(height: 140)
            else
              MarketDiagnosisCard(
                fearGreed: _fearGreed,
                macroAssets: _macroAssets,
                marketSummary: _marketSummary,
              ),

            // ② 섹터 스캐너
            if (_sectorLoading)
              _buildSkeleton(height: 130, label: '섹터별 시장 스캐너')
            else
              SectorScannerSection(sectorFlows: _sectorFlows),

            // ③ AI 스캔 종목
            if (_scanLoading)
              _buildSkeleton(height: 120, label: 'AI 스캔 종목')
            else
              AiScanSection(scanResults: _scanResults),

            // ④ 거시경제 축약
            if (_macroLoading)
              _buildSkeleton(height: 110, label: '거시경제 핵심')
            else
              MacroSummarySection(assets: _macroAssets),

            // ⑤ 투자자 수급
            if (_investorLoading)
              _buildSkeleton(height: 120, label: '투자자 수급 요약')
            else
              InvestorFlowSection(summary: _marketSummary),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeleton({required double height, String? label}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1B2E5C),
                ),
              ),
            ),
          Container(
            width: double.infinity,
            height: height,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF1B2E5C),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

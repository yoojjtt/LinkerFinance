import 'package:flutter/material.dart';

import '../../../models/psych_model.dart';
import '../../../services/psych_service.dart';

class PsychTab extends StatefulWidget {
  const PsychTab({super.key});
  @override
  State<PsychTab> createState() => _PsychTabState();
}

class _PsychTabState extends State<PsychTab> {
  List<TradingRule> _rules = [];
  List<PsychChecklist> _checklists = [];
  ComplianceStats? _stats;
  bool _isLoading = true;

  // 원칙 추가/편집
  String? _editId;
  String _editCategory = 'PSYCH';
  final _editCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _editCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      PsychService.getRules(),
      PsychService.getChecklists(),
      PsychService.getComplianceStats(),
    ]);
    if (mounted) {
      setState(() {
        _rules = results[0] as List<TradingRule>;
        _checklists = results[1] as List<PsychChecklist>;
        _stats = results[2] as ComplianceStats?;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveRule() async {
    if (_editCtrl.text.trim().isEmpty) return;
    final rule = TradingRule(category: _editCategory, title: _editCtrl.text.trim());
    final ok = _editId != null
        ? await PsychService.updateRule(_editId!, rule)
        : await PsychService.createRule(rule);
    if (ok) {
      _editCtrl.clear();
      _editId = null;
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF1B2E5C)))
        : RefreshIndicator(
            onRefresh: _loadData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 준수율 통계
                  if (_stats != null) _buildStatsCard(),
                  const SizedBox(height: 16),

                  // 투자 원칙
                  _buildRulesSection(),
                  const SizedBox(height: 16),

                  // 체크리스트 이력
                  _buildChecklistSection(),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          );
  }

  Widget _buildStatsCard() {
    final s = _stats!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
      child: Row(children: [
        Expanded(child: _complianceCol('원칙 준수', s.compliantTrades, s.compliantWinRate, s.compliantAvgReturn, const Color(0xFF22C55E))),
        Container(width: 1, height: 60, color: Colors.grey.shade200),
        Expanded(child: _complianceCol('미준수', s.nonCompliantTrades, s.nonCompliantWinRate, s.nonCompliantAvgReturn, const Color(0xFFEF4444))),
      ]),
    );
  }

  Widget _complianceCol(String label, int trades, double winRate, double avgReturn, Color color) {
    return Column(children: [
      Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      const SizedBox(height: 6),
      Text('$trades건', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      Text('승률 ${winRate.toStringAsFixed(1)}%', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      Text('수익률 ${avgReturn >= 0 ? "+" : ""}${avgReturn.toStringAsFixed(1)}%',
          style: TextStyle(fontSize: 11, color: avgReturn >= 0 ? const Color(0xFFE53935) : const Color(0xFF1E88E5))),
    ]);
  }

  Widget _buildRulesSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('투자 원칙', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1B2E5C))),
            const Spacer(),
            Text('${_rules.length}개', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ]),
          const SizedBox(height: 10),

          // 카테고리별 원칙
          ..._buildRulesByCategory(),

          // 추가/편집 폼
          const Divider(height: 20),
          Row(children: [
            // 카테고리 드롭다운
            DropdownButton<String>(
              value: _editCategory,
              underline: const SizedBox(),
              style: const TextStyle(fontSize: 12, color: Color(0xFF3A3A3A)),
              items: ruleCategories.entries.map((e) =>
                DropdownMenuItem(value: e.key, child: Text(e.value.$1))).toList(),
              onChanged: (v) { if (v != null) setState(() => _editCategory = v); },
            ),
            const SizedBox(width: 8),
            Expanded(child: TextField(
              controller: _editCtrl,
              decoration: const InputDecoration(
                hintText: '원칙을 입력하세요', isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFE0E0E0))),
              ),
              style: const TextStyle(fontSize: 13),
            )),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _saveRule,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xFF1B2E5C), borderRadius: BorderRadius.circular(6)),
                child: Text(_editId != null ? '수정' : '추가', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  List<Widget> _buildRulesByCategory() {
    final widgets = <Widget>[];
    for (final entry in ruleCategories.entries) {
      final cat = entry.key;
      final (label, colorVal) = entry.value;
      final catRules = _rules.where((r) => r.category == cat).toList();
      if (catRules.isNotEmpty) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: Color(colorVal).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
            child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(colorVal))),
          ),
        ));
        for (final r in catRules) {
          widgets.add(Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Row(children: [
              const Text('• ', style: TextStyle(color: Color(0xFF6B6B6B))),
              Expanded(child: Text(r.title, style: const TextStyle(fontSize: 13, color: Color(0xFF3A3A3A)))),
              GestureDetector(
                onTap: () => setState(() { _editId = r.id; _editCategory = r.category; _editCtrl.text = r.title; }),
                child: Icon(Icons.edit, size: 14, color: Colors.grey.shade400),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () async { if (r.id != null) { await PsychService.deleteRule(r.id!); _loadData(); } },
                child: Icon(Icons.close, size: 14, color: Colors.grey.shade400),
              ),
            ]),
          ));
        }
      }
    }
    return widgets;
  }

  Widget _buildChecklistSection() {
    if (_checklists.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('체크리스트 이력', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1B2E5C))),
        const SizedBox(height: 8),
        ..._checklists.take(20).map((c) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)]),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: c.passed ? const Color(0xFF22C55E).withValues(alpha: 0.1) : const Color(0xFFEF4444).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(c.passed ? 'PASS' : 'FAIL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                  color: c.passed ? const Color(0xFF22C55E) : const Color(0xFFEF4444))),
            ),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${c.stockName} ${c.stockCode}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Text('준수 ${c.complianceRate.toStringAsFixed(0)}%  현금 ${c.cashRatio.toStringAsFixed(0)}%  비중 ${c.betRatio.toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ])),
          ]),
        )),
      ],
    );
  }
}

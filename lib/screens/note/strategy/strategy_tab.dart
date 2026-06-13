import 'package:flutter/material.dart';

import '../../../models/strategy_model.dart';
import '../../../services/strategy_service.dart';
import 'strategy_form.dart';

class StrategyTab extends StatefulWidget {
  const StrategyTab({super.key});
  @override
  State<StrategyTab> createState() => _StrategyTabState();
}

class _StrategyTabState extends State<StrategyTab> {
  List<TradingStrategy> _strategies = [];
  bool _isLoading = true;
  String? _expandedId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _strategies = await StrategyService.getList();
    if (mounted) setState(() => _isLoading = false);
  }

  void _openForm({TradingStrategy? edit}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => StrategyFormScreen(strategy: edit)),
    );
    if (result == true) _loadData();
  }

  Future<void> _expandAndLoadDetail(String id) async {
    if (_expandedId == id) {
      setState(() => _expandedId = null);
      return;
    }
    final detail = await StrategyService.getDetail(id);
    if (detail != null && mounted) {
      final idx = _strategies.indexWhere((s) => s.id == id);
      if (idx >= 0) _strategies[idx] = detail;
      setState(() => _expandedId = id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1B2E5C),
        onPressed: () => _openForm(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1B2E5C)))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _strategies.isEmpty
                  ? const Center(child: Text('매매기법이 없습니다', style: TextStyle(color: Color(0xFF9E9E9E))))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _strategies.length,
                      itemBuilder: (ctx, i) => _buildStrategyCard(_strategies[i]),
                    ),
            ),
    );
  }

  Widget _buildStrategyCard(TradingStrategy s) {
    final isExpanded = _expandedId == s.id;
    final catInfo = strategyCategories[s.category];
    final catLabel = catInfo?.$1 ?? s.category;
    final catColor = Color(catInfo?.$2 ?? 0xFF9CA3AF);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
      child: Column(
        children: [
          // 헤더
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () { if (s.id != null) _expandAndLoadDetail(s.id!); },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: catColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                  child: Text(catLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: catColor)),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(s.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF3A3A3A)))),
                Text('${s.stepCount}단계', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                const SizedBox(width: 4),
                Icon(isExpanded ? Icons.expand_less : Icons.expand_more, size: 20, color: Colors.grey.shade400),
              ]),
            ),
          ),

          // 확장: 상세
          if (isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (s.description != null && s.description!.isNotEmpty) ...[
                    Text(s.description!, style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4)),
                    const SizedBox(height: 10),
                  ],

                  // 단계
                  ...s.steps.map((step) {
                    final stInfo = stepTypes[step.stepType];
                    final stLabel = stInfo?.$1 ?? step.stepType;
                    final stColor = Color(stInfo?.$2 ?? 0xFF9CA3AF);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(children: [
                        Container(
                          width: 22, height: 22,
                          decoration: BoxDecoration(color: stColor.withValues(alpha: 0.15), shape: BoxShape.circle),
                          child: Center(child: Text('${step.order + 1}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: stColor))),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(color: stColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                          child: Text(stLabel, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: stColor)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(step.title, style: const TextStyle(fontSize: 13, color: Color(0xFF3A3A3A)))),
                      ]),
                    );
                  }),

                  // 액션 버튼
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TextButton.icon(
                      onPressed: () => _openForm(edit: s),
                      icon: const Icon(Icons.edit, size: 14),
                      label: const Text('수정', style: TextStyle(fontSize: 12)),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        if (s.id == null) return;
                        final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                          title: const Text('삭제'), content: const Text('이 전략을 삭제하시겠습니까?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
                            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('삭제', style: TextStyle(color: Colors.red))),
                          ],
                        ));
                        if (ok == true) { await StrategyService.delete(s.id!); _loadData(); }
                      },
                      icon: const Icon(Icons.delete, size: 14, color: Colors.red),
                      label: const Text('삭제', style: TextStyle(fontSize: 12, color: Colors.red)),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

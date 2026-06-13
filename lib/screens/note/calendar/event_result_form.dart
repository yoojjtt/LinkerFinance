import 'package:flutter/material.dart';

import '../../../models/event_model.dart';
import '../../../services/event_service.dart';

class EventResultForm extends StatefulWidget {
  final StockEvent event;
  const EventResultForm({super.key, required this.event});
  @override
  State<EventResultForm> createState() => _EventResultFormState();
}

class _EventResultFormState extends State<EventResultForm> {
  final _noteCtrl = TextEditingController();
  bool _saving = false;

  // 공통 결과 필드
  final _resultFields = <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    _noteCtrl.text = widget.event.resultNote ?? '';

    // 타입별 결과 필드 초기화
    for (final key in _fieldsForType(widget.event.eventType)) {
      _resultFields[key] = TextEditingController(
        text: widget.event.result?[key]?.toString() ?? '',
      );
    }
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    for (final c in _resultFields.values) { c.dispose(); }
    super.dispose();
  }

  List<String> _fieldsForType(String type) {
    return switch (type) {
      'EARNINGS' => ['actual_revenue', 'actual_op', 'surprise', 'price_1d', 'price_5d'],
      'ECONOMIC' => ['actual_value', 'surprise_direction', 'market_reaction', 'sp500_change', 'kospi_change'],
      'FED_SPEECH' => ['summary', 'market_interpretation', 'rate_reaction', 'sp500_change'],
      'CORPORATE' => ['result_detail', 'price_1d'],
      _ => ['result_detail'],
    };
  }

  String _fieldLabel(String key) {
    return switch (key) {
      'actual_revenue' => '실제 매출',
      'actual_op' => '실제 영업이익',
      'surprise' => '서프라이즈 (beat/miss/inline)',
      'price_1d' => '1일 주가 변동(%)',
      'price_5d' => '5일 주가 변동(%)',
      'actual_value' => '실제 발표값',
      'surprise_direction' => '서프라이즈 방향 (above/inline/below)',
      'market_reaction' => '시장 반응 (rally/selloff/flat)',
      'sp500_change' => 'S&P500 변동(%)',
      'kospi_change' => 'KOSPI 변동(%)',
      'summary' => '요약',
      'market_interpretation' => '시장 해석',
      'rate_reaction' => '금리 반응',
      'result_detail' => '결과 상세',
      _ => key,
    };
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final result = <String, dynamic>{};
    for (final entry in _resultFields.entries) {
      final v = entry.value.text.trim();
      if (v.isNotEmpty) result[entry.key] = v;
    }
    final ok = await EventService.recordResult(
      widget.event.id!,
      result,
      _noteCtrl.text.trim().isNotEmpty ? _noteCtrl.text.trim() : null,
    );
    if (mounted) {
      if (ok) Navigator.pop(context, true);
      else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('저장 실패')));
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final typeInfo = eventTypes[widget.event.eventType];
    final typeLabel = typeInfo?.$1 ?? widget.event.eventType;
    final typeColor = Color(typeInfo?.$2 ?? 0xFF9CA3AF);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close, color: Color(0xFF1B2E5C)), onPressed: () => Navigator.pop(context)),
        title: const Text('복기 기록', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1B2E5C))),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('저장', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1B2E5C))),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 이벤트 요약
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(12),
                border: Border(left: BorderSide(color: typeColor, width: 3)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: typeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                    child: Text(typeLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: typeColor)),
                  ),
                  const SizedBox(width: 8),
                  Text(widget.event.eventDate, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ]),
                const SizedBox(height: 6),
                Text(widget.event.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF3A3A3A))),
                if (widget.event.stockName != null)
                  Text(widget.event.stockName!, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ]),
            ),
            const SizedBox(height: 20),

            // 타입별 결과 입력 필드
            _label('결과 입력'),
            ...(_resultFields.entries.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_fieldLabel(entry.key), style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                const SizedBox(height: 4),
                TextField(
                  controller: entry.value,
                  maxLines: entry.key == 'summary' || entry.key == 'market_interpretation' ? 3 : 1,
                  decoration: InputDecoration(
                    hintText: _fieldLabel(entry.key),
                    filled: true, fillColor: const Color(0xFFFAF8F0),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ]),
            ))),

            // 복기 메모
            const SizedBox(height: 8),
            _label('복기 메모'),
            TextField(
              controller: _noteCtrl,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: '이 이벤트에서 배운 점, 다음에 적용할 사항...',
                filled: true, fillColor: const Color(0xFFFAF8F0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B6B6B))),
  );
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/event_model.dart';
import '../../../services/event_service.dart';

class EventFormScreen extends StatefulWidget {
  final StockEvent? event;
  final DateTime? initialDate;
  const EventFormScreen({super.key, this.event, this.initialDate});
  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  String _type = 'ECONOMIC';
  String _impact = 'MEDIUM';
  DateTime _date = DateTime.now();
  bool _saving = false;

  bool get _isEdit => widget.event != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final e = widget.event!;
      _titleCtrl.text = e.title;
      _descCtrl.text = e.description ?? '';
      _timeCtrl.text = e.eventTime ?? '';
      _stockCtrl.text = e.stockName ?? e.stockCode ?? '';
      _type = e.eventType;
      _impact = e.impact;
      _date = DateTime.tryParse(e.eventDate) ?? DateTime.now();
    } else if (widget.initialDate != null) {
      _date = widget.initialDate!;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _timeCtrl.dispose();
    _stockCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('제목을 입력해주세요')));
      return;
    }
    setState(() => _saving = true);
    final event = StockEvent(
      eventType: _type,
      title: _titleCtrl.text.trim(),
      eventDate: DateFormat('yyyy-MM-dd').format(_date),
      eventTime: _timeCtrl.text.trim().isNotEmpty ? _timeCtrl.text.trim() : null,
      impact: _impact,
      description: _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
      stockName: _stockCtrl.text.trim().isNotEmpty ? _stockCtrl.text.trim() : null,
    );
    final ok = _isEdit
        ? await EventService.update(widget.event!.id!, event)
        : await EventService.create(event);
    if (mounted) {
      if (ok) Navigator.pop(context, true);
      else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('저장 실패')));
      setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (widget.event?.id == null) return;
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('삭제'), content: const Text('이 이벤트를 삭제하시겠습니까?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('삭제', style: TextStyle(color: Colors.red))),
      ],
    ));
    if (ok == true) {
      await EventService.delete(widget.event!.id!);
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close, color: Color(0xFF1B2E5C)), onPressed: () => Navigator.pop(context)),
        title: Text(_isEdit ? '이벤트 수정' : '새 이벤트', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1B2E5C))),
        actions: [
          if (_isEdit)
            IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: _delete),
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
            // 이벤트 타입
            _label('이벤트 유형'),
            Wrap(spacing: 8, runSpacing: 8, children: eventTypes.entries.map((e) {
              final selected = _type == e.key;
              final color = Color(e.value.$2);
              return GestureDetector(
                onTap: () => setState(() => _type = e.key),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? color.withValues(alpha: 0.15) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: selected ? color : Colors.grey.shade300),
                  ),
                  child: Text(e.value.$1, style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? color : const Color(0xFF6B6B6B))),
                ),
              );
            }).toList()),
            const SizedBox(height: 16),

            // 제목
            _label('제목'),
            TextField(controller: _titleCtrl, decoration: _inputDeco('이벤트 제목'), style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 16),

            // 날짜
            _label('날짜'),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(context: context, initialDate: _date,
                    firstDate: DateTime(2020), lastDate: DateTime(2030));
                if (picked != null) setState(() => _date = picked);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(color: const Color(0xFFFAF8F0), borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  const Icon(Icons.calendar_today, size: 16, color: Color(0xFF6B6B6B)),
                  const SizedBox(width: 8),
                  Text(DateFormat('yyyy.MM.dd (E)', 'ko').format(_date), style: const TextStyle(fontSize: 14)),
                ]),
              ),
            ),
            const SizedBox(height: 16),

            // 시간
            _label('시간 (선택)'),
            TextField(controller: _timeCtrl, decoration: _inputDeco('HH:MM'), style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 16),

            // 중요도
            _label('중요도'),
            Row(children: impactLevels.entries.map((e) {
              final selected = _impact == e.key;
              final color = Color(e.value.$2);
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(e.value.$1),
                  selected: selected,
                  selectedColor: color.withValues(alpha: 0.2),
                  labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: selected ? color : const Color(0xFF6B6B6B)),
                  onSelected: (_) => setState(() => _impact = e.key),
                ),
              );
            }).toList()),
            const SizedBox(height: 16),

            // 종목
            _label('관련 종목 (선택)'),
            TextField(controller: _stockCtrl, decoration: _inputDeco('종목명'), style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 16),

            // 설명
            _label('설명 (선택)'),
            TextField(controller: _descCtrl, maxLines: 4, decoration: _inputDeco('상세 설명'), style: const TextStyle(fontSize: 14)),

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

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint, filled: true, fillColor: const Color(0xFFFAF8F0),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
  );
}

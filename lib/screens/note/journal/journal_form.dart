import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/journal_model.dart';
import '../../../services/journal_service.dart';

class JournalFormScreen extends StatefulWidget {
  final MarketJournal? journal;
  const JournalFormScreen({super.key, this.journal});
  @override
  State<JournalFormScreen> createState() => _JournalFormScreenState();
}

class _JournalFormScreenState extends State<JournalFormScreen> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  String _type = 'DAILY';
  String _mood = 'NEUTRAL';
  DateTime _date = DateTime.now();
  bool _saving = false;
  bool _aiLoading = false;

  bool get _isEdit => widget.journal != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final j = widget.journal!;
      _titleCtrl.text = j.title ?? '';
      _contentCtrl.text = j.content;
      _tagsCtrl.text = j.tags ?? '';
      _type = j.journalType;
      _mood = j.mood;
      if (j.journalDate.length == 8) {
        _date = DateTime.tryParse(
          '${j.journalDate.substring(0, 4)}-${j.journalDate.substring(4, 6)}-${j.journalDate.substring(6, 8)}',
        ) ?? DateTime.now();
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_contentCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('내용을 입력해주세요')));
      return;
    }
    setState(() => _saving = true);
    final journal = MarketJournal(
      journalDate: DateFormat('yyyyMMdd').format(_date),
      journalType: _type,
      mood: _mood,
      title: _titleCtrl.text.trim().isNotEmpty ? _titleCtrl.text.trim() : null,
      content: _contentCtrl.text.trim(),
      tags: _tagsCtrl.text.trim().isNotEmpty ? _tagsCtrl.text.trim() : null,
    );
    final ok = _isEdit
        ? await JournalService.update(widget.journal!.id!, journal)
        : await JournalService.create(journal);
    if (mounted) {
      if (ok) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('저장 실패')));
      }
      setState(() => _saving = false);
    }
  }

  Future<void> _generateAiDraft() async {
    setState(() => _aiLoading = true);
    final draft = await JournalService.getAiDraft(date: DateFormat('yyyy-MM-dd').format(_date));
    if (mounted && draft != null) {
      _contentCtrl.text = draft;
    }
    setState(() => _aiLoading = false);
  }

  Future<void> _suggestAiTags() async {
    if (_contentCtrl.text.trim().isEmpty) return;
    setState(() => _aiLoading = true);
    final tags = await JournalService.getAiTags(_contentCtrl.text.trim());
    if (mounted && tags.isNotEmpty) {
      _tagsCtrl.text = tags.join(',');
    }
    setState(() => _aiLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close, color: Color(0xFF1B2E5C)), onPressed: () => Navigator.pop(context)),
        title: Text(_isEdit ? '일지 수정' : '새 일지', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1B2E5C))),
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
            // 날짜 선택
            _sectionLabel('날짜'),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context, initialDate: _date,
                  firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 1)),
                );
                if (picked != null) setState(() => _date = picked);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: _inputDecoration(),
                child: Row(children: [
                  const Icon(Icons.calendar_today, size: 16, color: Color(0xFF6B6B6B)),
                  const SizedBox(width: 8),
                  Text(DateFormat('yyyy.MM.dd (E)', 'ko').format(_date),
                      style: const TextStyle(fontSize: 14, color: Color(0xFF3A3A3A))),
                ]),
              ),
            ),
            const SizedBox(height: 16),

            // 타입 선택
            _sectionLabel('유형'),
            Row(children: ['DAILY', 'EVENT', 'CONCEPT'].map((t) {
              final selected = _type == t;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(journalTypeLabel[t] ?? t),
                  selected: selected,
                  selectedColor: const Color(0xFF1B2E5C),
                  labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : const Color(0xFF6B6B6B)),
                  onSelected: (_) => setState(() => _type = t),
                ),
              );
            }).toList()),
            const SizedBox(height: 16),

            // 기분 선택
            _sectionLabel('기분'),
            Row(children: ['FEAR', 'ANXIETY', 'NEUTRAL', 'OPTIMISM', 'GREED'].map((m) {
              final selected = _mood == m;
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: GestureDetector(
                  onTap: () => setState(() => _mood = m),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFF1B2E5C).withValues(alpha: 0.1) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: selected ? const Color(0xFF1B2E5C) : Colors.grey.shade300),
                    ),
                    child: Text('${moodEmoji[m]} ${moodLabel[m]}',
                        style: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
                  ),
                ),
              );
            }).toList()),
            const SizedBox(height: 16),

            // 제목
            _sectionLabel('제목 (선택)'),
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                hintText: '제목을 입력하세요',
                filled: true, fillColor: const Color(0xFFFAF8F0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),

            // 내용 + AI 초안
            Row(children: [
              _sectionLabel('내용'),
              const Spacer(),
              if (!_isEdit)
                TextButton.icon(
                  onPressed: _aiLoading ? null : _generateAiDraft,
                  icon: const Icon(Icons.auto_awesome, size: 14),
                  label: Text(_aiLoading ? '생성 중...' : 'AI 초안', style: const TextStyle(fontSize: 11)),
                ),
            ]),
            TextField(
              controller: _contentCtrl,
              maxLines: 8,
              decoration: InputDecoration(
                hintText: '오늘의 시장 기록을 남겨보세요',
                filled: true, fillColor: const Color(0xFFFAF8F0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 16),

            // 태그 + AI 태그 추천
            Row(children: [
              _sectionLabel('태그'),
              const Spacer(),
              TextButton.icon(
                onPressed: _aiLoading ? null : _suggestAiTags,
                icon: const Icon(Icons.auto_awesome, size: 14),
                label: const Text('AI 태그', style: TextStyle(fontSize: 11)),
              ),
            ]),
            TextField(
              controller: _tagsCtrl,
              decoration: InputDecoration(
                hintText: '쉼표로 구분 (예: 반도체,실적,금리)',
                filled: true, fillColor: const Color(0xFFFAF8F0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
              style: const TextStyle(fontSize: 14),
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B6B6B))),
  );

  BoxDecoration _inputDecoration() => BoxDecoration(
    color: const Color(0xFFFAF8F0),
    borderRadius: BorderRadius.circular(10),
  );
}

import 'package:flutter/material.dart';

import '../../../models/strategy_model.dart';
import '../../../services/strategy_service.dart';

class StrategyFormScreen extends StatefulWidget {
  final TradingStrategy? strategy;
  const StrategyFormScreen({super.key, this.strategy});
  @override
  State<StrategyFormScreen> createState() => _StrategyFormScreenState();
}

class _StrategyFormScreenState extends State<StrategyFormScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _category = 'CUSTOM';
  List<_StepEdit> _steps = [];
  bool _saving = false;

  bool get _isEdit => widget.strategy != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final s = widget.strategy!;
      _nameCtrl.text = s.name;
      _descCtrl.text = s.description ?? '';
      _category = s.category;
      _steps = s.steps.map((st) => _StepEdit(type: st.stepType, ctrl: TextEditingController(text: st.title))).toList();
    }
    if (_steps.isEmpty) _addStep();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    for (final s in _steps) { s.ctrl.dispose(); }
    super.dispose();
  }

  void _addStep() => setState(() => _steps.add(_StepEdit(type: 'SIGNAL', ctrl: TextEditingController())));

  void _removeStep(int i) {
    if (_steps.length <= 1) return;
    _steps[i].ctrl.dispose();
    setState(() => _steps.removeAt(i));
  }

  void _moveStep(int from, int to) {
    if (to < 0 || to >= _steps.length) return;
    setState(() {
      final item = _steps.removeAt(from);
      _steps.insert(to, item);
    });
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('기법명을 입력해주세요')));
      return;
    }
    setState(() => _saving = true);
    final strategy = TradingStrategy(
      name: _nameCtrl.text.trim(),
      category: _category,
      description: _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
      steps: _steps.asMap().entries.map((e) => StrategyStep(
        stepType: e.value.type, title: e.value.ctrl.text.trim(), order: e.key,
      )).where((s) => s.title.isNotEmpty).toList(),
    );
    final ok = _isEdit
        ? await StrategyService.update(widget.strategy!.id!, strategy)
        : await StrategyService.create(strategy);
    if (mounted) {
      if (ok) Navigator.pop(context, true);
      else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('저장 실패')));
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close, color: Color(0xFF1B2E5C)), onPressed: () => Navigator.pop(context)),
        title: Text(_isEdit ? '전략 수정' : '새 전략', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1B2E5C))),
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
            // 기법명
            _label('기법명'),
            TextField(
              controller: _nameCtrl,
              decoration: _inputDeco('기법명을 입력하세요'),
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),

            // 카테고리
            _label('카테고리'),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: strategyCategories.entries.map((e) {
                final selected = _category == e.key;
                final color = Color(e.value.$2);
                return GestureDetector(
                  onTap: () => setState(() => _category = e.key),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: selected ? color.withValues(alpha: 0.15) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: selected ? color : Colors.grey.shade300),
                    ),
                    child: Text(e.value.$1, style: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? color : const Color(0xFF6B6B6B))),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // 설명
            _label('설명 (선택)'),
            TextField(
              controller: _descCtrl, maxLines: 3,
              decoration: _inputDeco('전략 설명'),
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),

            // 단계
            Row(children: [
              _label('조건 단계'),
              const Spacer(),
              TextButton.icon(onPressed: _addStep, icon: const Icon(Icons.add, size: 16), label: const Text('추가', style: TextStyle(fontSize: 12))),
            ]),
            ...List.generate(_steps.length, (i) {
              final step = _steps[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
                child: Row(children: [
                  // 순서 이동
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    GestureDetector(onTap: () => _moveStep(i, i - 1), child: Icon(Icons.arrow_drop_up, size: 20, color: i > 0 ? Colors.grey.shade600 : Colors.grey.shade300)),
                    Text('${i + 1}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                    GestureDetector(onTap: () => _moveStep(i, i + 1), child: Icon(Icons.arrow_drop_down, size: 20, color: i < _steps.length - 1 ? Colors.grey.shade600 : Colors.grey.shade300)),
                  ]),
                  const SizedBox(width: 8),
                  // 타입 선택
                  DropdownButton<String>(
                    value: step.type, underline: const SizedBox(),
                    style: const TextStyle(fontSize: 11, color: Color(0xFF3A3A3A)),
                    items: stepTypes.entries.map((e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value.$1, style: TextStyle(color: Color(e.value.$2), fontWeight: FontWeight.w600)),
                    )).toList(),
                    onChanged: (v) { if (v != null) setState(() => step.type = v); },
                  ),
                  const SizedBox(width: 8),
                  // 조건 입력
                  Expanded(child: TextField(
                    controller: step.ctrl,
                    decoration: const InputDecoration(hintText: '조건 입력', isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFE0E0E0)))),
                    style: const TextStyle(fontSize: 13),
                  )),
                  // 삭제
                  GestureDetector(onTap: () => _removeStep(i),
                    child: Padding(padding: const EdgeInsets.only(left: 6), child: Icon(Icons.close, size: 16, color: Colors.grey.shade400))),
                ]),
              );
            }),

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

class _StepEdit {
  String type;
  final TextEditingController ctrl;
  _StepEdit({required this.type, required this.ctrl});
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/event_model.dart';
import '../../../services/event_service.dart';
import 'event_form.dart';
import 'event_result_form.dart';

class CalendarTab extends StatefulWidget {
  const CalendarTab({super.key});
  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<CalendarTab> {
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDate = DateTime.now();
  List<StockEvent> _events = [];
  bool _isLoading = true;
  String? _typeFilter;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    final start = DateFormat('yyyy-MM-dd').format(DateTime(_currentMonth.year, _currentMonth.month, 1));
    final end = DateFormat('yyyy-MM-dd').format(DateTime(_currentMonth.year, _currentMonth.month + 1, 0));
    _events = await EventService.getList(startDate: start, endDate: end, eventType: _typeFilter);
    if (mounted) setState(() => _isLoading = false);
  }

  void _changeMonth(int delta) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + delta);
    });
    _loadEvents();
  }

  void _openForm({StockEvent? edit}) async {
    final result = await Navigator.push<bool>(context,
      MaterialPageRoute(builder: (_) => EventFormScreen(event: edit, initialDate: _selectedDate)));
    if (result == true) _loadEvents();
  }

  List<StockEvent> _eventsForDate(DateTime date) {
    final ds = DateFormat('yyyy-MM-dd').format(date);
    return _events.where((e) => e.eventDate == ds).toList();
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final firstWeekday = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday % 7; // 0=일
    final today = DateTime.now();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1B2E5C),
        onPressed: () => _openForm(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: _loadEvents,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // 월 헤더
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(children: [
                  IconButton(icon: const Icon(Icons.chevron_left, color: Color(0xFF1B2E5C)), onPressed: () => _changeMonth(-1)),
                  const Spacer(),
                  Text('${_currentMonth.year}년 ${_currentMonth.month}월',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1B2E5C))),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.chevron_right, color: Color(0xFF1B2E5C)), onPressed: () => _changeMonth(1)),
                ]),
              ),

              // 타입 필터
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    _filterChip(null, '전체'),
                    ...eventTypes.entries.map((e) => _filterChip(e.key, e.value.$1)),
                  ]),
                ),
              ),

              // 요일 헤더
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(children: ['일', '월', '화', '수', '목', '금', '토'].map((d) =>
                  Expanded(child: Center(child: Text(d, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                      color: d == '일' ? Colors.red : d == '토' ? Colors.blue : Colors.grey.shade600))))).toList()),
              ),

              // 캘린더 그리드
              _isLoading
                  ? const Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(strokeWidth: 2))
                  : Container(
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 0.85),
                        itemCount: firstWeekday + daysInMonth,
                        itemBuilder: (ctx, i) {
                          if (i < firstWeekday) return const SizedBox();
                          final day = i - firstWeekday + 1;
                          final date = DateTime(_currentMonth.year, _currentMonth.month, day);
                          final dayEvents = _eventsForDate(date);
                          final isSelected = date.year == _selectedDate.year && date.month == _selectedDate.month && date.day == _selectedDate.day;
                          final isToday = date.year == today.year && date.month == today.month && date.day == today.day;

                          return GestureDetector(
                            onTap: () => setState(() => _selectedDate = date),
                            child: Container(
                              margin: const EdgeInsets.all(1),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF1B2E5C).withValues(alpha: 0.1) : null,
                                borderRadius: BorderRadius.circular(6),
                                border: isToday ? Border.all(color: const Color(0xFF1B2E5C), width: 1.5) : null,
                              ),
                              child: Column(mainAxisAlignment: MainAxisAlignment.start, children: [
                                const SizedBox(height: 4),
                                Text('$day', style: TextStyle(fontSize: 12, fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected ? const Color(0xFF1B2E5C) : Colors.grey.shade800)),
                                const SizedBox(height: 2),
                                // 이벤트 도트 (최대 3개)
                                if (dayEvents.isNotEmpty)
                                  Row(mainAxisAlignment: MainAxisAlignment.center, children: dayEvents.take(3).map((e) {
                                    final c = eventTypes[e.eventType]?.$2 ?? 0xFF9CA3AF;
                                    return Container(width: 5, height: 5, margin: const EdgeInsets.symmetric(horizontal: 1),
                                      decoration: BoxDecoration(color: Color(c), shape: BoxShape.circle));
                                  }).toList()),
                              ]),
                            ),
                          );
                        },
                      ),
                    ),

              // 선택된 날짜의 이벤트
              const SizedBox(height: 8),
              _buildSelectedDateEvents(),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterChip(String? type, String label) {
    final selected = _typeFilter == type;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () { setState(() => _typeFilter = type); _loadEvents(); },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF1B2E5C) : const Color(0xFFF5F5F7),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
              color: selected ? Colors.white : const Color(0xFF6B6B6B))),
        ),
      ),
    );
  }

  Widget _buildSelectedDateEvents() {
    final dayEvents = _eventsForDate(_selectedDate);
    final dateStr = DateFormat('M월 d일 (E)', 'ko').format(_selectedDate);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(dateStr, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1B2E5C))),
            const Spacer(),
            GestureDetector(
              onTap: () => _openForm(),
              child: const Icon(Icons.add_circle_outline, size: 20, color: Color(0xFF1B2E5C)),
            ),
          ]),
          const SizedBox(height: 8),
          if (dayEvents.isEmpty)
            Center(child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text('이벤트 없음', style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
            )),
          ...dayEvents.map((e) {
            final typeInfo = eventTypes[e.eventType];
            final typeLabel = typeInfo?.$1 ?? e.eventType;
            final typeColor = Color(typeInfo?.$2 ?? 0xFF9CA3AF);
            final impactInfo = impactLevels[e.impact];
            final impactLabel = impactInfo?.$1 ?? e.impact;
            final impactColor = Color(impactInfo?.$2 ?? 0xFF9CA3AF);

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(10),
                border: Border(left: BorderSide(color: typeColor, width: 3)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
              ),
              child: InkWell(
                onTap: () => _openForm(edit: e),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: typeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                      child: Text(typeLabel, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: typeColor)),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: impactColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                      child: Text(impactLabel, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: impactColor)),
                    ),
                    if (e.eventTime != null) ...[
                      const Spacer(),
                      Text(e.eventTime!, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    ],
                  ]),
                  const SizedBox(height: 6),
                  Text(e.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF3A3A3A))),
                  if (e.stockName != null) ...[
                    const SizedBox(height: 2),
                    Text(e.stockName!, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  ],
                  if (e.description != null && e.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(e.description!, style: TextStyle(fontSize: 12, color: Colors.grey.shade600), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 6),
                  if (e.completed)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFF22C55E).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                      child: const Text('복기 완료', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF22C55E))),
                    )
                  else if (e.id != null)
                    GestureDetector(
                      onTap: () async {
                        final result = await Navigator.push<bool>(context,
                          MaterialPageRoute(builder: (_) => EventResultForm(event: e)));
                        if (result == true) _loadEvents();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: const Color(0xFFF59E0B).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                        child: const Text('복기하기', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFFF59E0B))),
                      ),
                    ),
                ]),
              ),
            );
          }),
        ],
      ),
    );
  }
}

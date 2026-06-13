import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/journal_model.dart';
import '../../../services/journal_service.dart';
import 'journal_form.dart';

class JournalTab extends StatefulWidget {
  const JournalTab({super.key});
  @override
  State<JournalTab> createState() => _JournalTabState();
}

class _JournalTabState extends State<JournalTab> {
  List<MarketJournal> _journals = [];
  JournalStreak? _streak;
  bool _isLoading = true;
  String? _typeFilter;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      JournalService.getList(page: 1, journalType: _typeFilter),
      JournalService.getStreak(),
    ]);
    if (mounted) {
      setState(() {
        _journals = results[0] as List<MarketJournal>;
        _streak = results[1] as JournalStreak?;
        _page = 1;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    final more = await JournalService.getList(page: _page + 1, journalType: _typeFilter);
    if (mounted && more.isNotEmpty) {
      setState(() {
        _journals.addAll(more);
        _page++;
      });
    }
  }

  void _openForm({MarketJournal? edit}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => JournalFormScreen(journal: edit)),
    );
    if (result == true) _loadData();
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
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _isLoading && _journals.isEmpty
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF1B2E5C)))
            : CustomScrollView(
                slivers: [
                  // 통계 카드
                  if (_streak != null) SliverToBoxAdapter(child: _buildStreakCard()),

                  // 타입 필터
                  SliverToBoxAdapter(child: _buildTypeFilter()),

                  // 일지 리스트
                  _journals.isEmpty
                      ? const SliverFillRemaining(
                          child: Center(child: Text('일지가 없습니다', style: TextStyle(color: Color(0xFF9E9E9E)))))
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) {
                              if (i == _journals.length) {
                                _loadMore();
                                return const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                );
                              }
                              return _buildJournalCard(_journals[i]);
                            },
                            childCount: _journals.length + 1,
                          ),
                        ),
                ],
              ),
      ),
    );
  }

  Widget _buildStreakCard() {
    final s = _streak!;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statCol('연속 기록', '${s.currentStreak}일', const Color(0xFFFF9800)),
          _statCol('최장 기록', '${s.longestStreak}일', const Color(0xFF1B2E5C)),
          _statCol('총 기록', '${s.totalDays}일', const Color(0xFF4CAF50)),
        ],
      ),
    );
  }

  Widget _statCol(String label, String value, Color color) {
    return Column(children: [
      Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
    ]);
  }

  Widget _buildTypeFilter() {
    const types = [null, 'DAILY', 'EVENT', 'CONCEPT'];
    const labels = ['전체', '일간', '이벤트', '컨셉'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: List.generate(types.length, (i) {
          final selected = _typeFilter == types[i];
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () { setState(() => _typeFilter = types[i]); _loadData(); },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFF1B2E5C) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: selected ? const Color(0xFF1B2E5C) : Colors.grey.shade300),
                ),
                child: Text(labels[i], style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : const Color(0xFF6B6B6B),
                )),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildJournalCard(MarketJournal j) {
    final dateStr = j.journalDate.length == 8
        ? '${j.journalDate.substring(4, 6)}.${j.journalDate.substring(6, 8)}'
        : j.journalDate;
    final emoji = moodEmoji[j.mood] ?? '😐';
    final typeLabel = journalTypeLabel[j.journalType] ?? j.journalType;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: j.isPinned ? Border.all(color: const Color(0xFFFFD700), width: 1.5) : null,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openForm(edit: j),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더: 날짜 + 기분 + 타입 + 핀
              Row(children: [
                Text(dateStr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1B2E5C))),
                const SizedBox(width: 6),
                Text(emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B2E5C).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(typeLabel, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF1B2E5C))),
                ),
                const Spacer(),
                if (j.isPinned) const Icon(Icons.push_pin, size: 14, color: Color(0xFFFFD700)),
                // 삭제
                GestureDetector(
                  onTap: () async {
                    if (j.id == null) return;
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('삭제'),
                        content: const Text('이 일지를 삭제하시겠습니까?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('삭제', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await JournalService.delete(j.id!);
                      _loadData();
                    }
                  },
                  child: Icon(Icons.more_vert, size: 18, color: Colors.grey.shade400),
                ),
              ]),

              // 제목
              if (j.title != null && j.title!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(j.title!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF3A3A3A))),
              ],

              // 내용 미리보기
              if (j.content.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  j.content.length > 150 ? '${j.content.substring(0, 150)}...' : j.content,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
                ),
              ],

              // 태그
              if (j.tags != null && j.tags!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4, runSpacing: 4,
                  children: j.tags!.split(',').map((t) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(10)),
                    child: Text('#${t.trim()}', style: const TextStyle(fontSize: 10, color: Color(0xFF6B6B6B))),
                  )).toList(),
                ),
              ],

              // AI 요약
              if (j.aiSummary != null && j.aiSummary!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F0FF), borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.auto_awesome, size: 14, color: Color(0xFF7C4DFF)),
                    const SizedBox(width: 6),
                    Expanded(child: Text(j.aiSummary!, style: const TextStyle(fontSize: 11, color: Color(0xFF6B6B6B)))),
                  ]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

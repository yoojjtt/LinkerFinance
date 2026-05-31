import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/fcm_service.dart';

class NotificationListScreen extends StatefulWidget {
  const NotificationListScreen({super.key});

  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  final List<Map<String, dynamic>> _logs = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _offset = 0;
  final int _size = 20;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs({bool refresh = false}) async {
    if (_isLoading) return;
    if (!refresh && !_hasMore) return;

    setState(() => _isLoading = true);
    if (refresh) {
      _offset = 0;
      _logs.clear();
      _hasMore = true;
    }

    try {
      final user = AuthService().currentUser;
      if (user == null) return;

      final data = await ApiService.get(
        ApiConfig.fcmLogMy,
        params: {
          'user_id': user.userId,
          'app_type': 'FINANCE',
          'offset': '$_offset',
          'size': '$_size',
        },
      );

      if (data['resultCode'] == '200' && data['res'] != null) {
        final res = Map<String, dynamic>.from(data['res'] as Map);
        final list = (res['list'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [];
        final total = (res['totalRecords'] as int?) ?? list.length;

        _logs.addAll(list);
        _offset += list.length;
        _hasMore = _logs.length < total;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('알림 이력 로드 실패: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAllAsRead() async {
    await FcmService().markAllLogsAsRead();
    for (final log in _logs) {
      log['is_read'] = 1;
    }
    if (mounted) setState(() {});
  }

  Future<void> _markAsRead(Map<String, dynamic> log) async {
    if (log['is_read'] == 1) return;
    final seq = log['seq'] as int?;
    if (seq == null) return;

    await FcmService().markLogAsRead(seq);
    setState(() => log['is_read'] = 1);
    FcmService().fetchUnreadCount();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '알림',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1B2E5C),
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1B2E5C)),
        actions: [
          if (_logs.any((l) => l['is_read'] != 1))
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text(
                '모두 읽음',
                style: TextStyle(
                  color: Color(0xFF1B2E5C),
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading && _logs.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? _buildEmpty()
              : _buildList(),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            '알림이 없습니다',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '새로운 알림이 오면 여기에 표시됩니다',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final log in _logs) {
      final dateStr = log['create_DT'] as String? ?? '';
      final label = _dateGroupLabel(dateStr);
      grouped.putIfAbsent(label, () => []).add(log);
    }

    return RefreshIndicator(
      onRefresh: () => _loadLogs(refresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _buildItems(grouped).length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          final items = _buildItems(grouped);
          if (index == items.length) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _loadLogs());
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final item = items[index];
          if (item is String) {
            return _buildDateHeader(item);
          }

          final log = item as Map<String, dynamic>;
          final isRead = log['is_read'] == 1;

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: isRead ? Colors.white : const Color(0xFFE8EDF5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isRead
                    ? Colors.grey.shade200
                    : const Color(0xFF1B2E5C).withValues(alpha: 0.2),
              ),
            ),
            child: InkWell(
              onTap: () {
                _markAsRead(log);
                _showDetail(log);
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isRead
                            ? Colors.grey.shade100
                            : const Color(0xFF1B2E5C).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isRead
                            ? Icons.notifications_none
                            : Icons.notifications_active,
                        color: isRead
                            ? Colors.grey.shade400
                            : const Color(0xFF1B2E5C),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  log['title'] as String? ?? '알림',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: isRead
                                        ? FontWeight.w500
                                        : FontWeight.w700,
                                    color: const Color(0xFF1B2E5C),
                                  ),
                                ),
                              ),
                              if (!isRead)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF1B5EC8),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            log['body'] as String? ?? '',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _formatTime(log['create_DT'] as String? ?? ''),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<dynamic> _buildItems(Map<String, List<Map<String, dynamic>>> grouped) {
    final items = <dynamic>[];
    for (final entry in grouped.entries) {
      items.add(entry.key);
      items.addAll(entry.value);
    }
    return items;
  }

  Widget _buildDateHeader(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade500,
        ),
      ),
    );
  }

  void _showDetail(Map<String, dynamic> log) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                log['title'] as String? ?? '알림',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1B2E5C),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _formatTime(log['create_DT'] as String? ?? ''),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
              ),
              const SizedBox(height: 16),
              Text(
                log['body'] as String? ?? '',
                style: const TextStyle(fontSize: 15, height: 1.5),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  String _dateGroupLabel(String dateStr) {
    if (dateStr.isEmpty) return '기타';
    try {
      final dt = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final logDate = DateTime(dt.year, dt.month, dt.day);

      if (logDate == today) return '오늘';
      if (logDate == yesterday) return '어제';
      if (now.difference(dt).inDays < 7) return '이번 주';
      return '${dt.month}월 ${dt.day}일';
    } catch (_) {
      return '기타';
    }
  }

  String _formatTime(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return '방금 전';
      if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
      if (diff.inHours < 24) return '${diff.inHours}시간 전';
      return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }
}

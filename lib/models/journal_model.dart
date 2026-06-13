class MarketJournal {
  final String? id;
  final String journalDate; // YYYYMMDD
  final String journalType; // DAILY, EVENT, CONCEPT
  final String mood; // FEAR, ANXIETY, NEUTRAL, OPTIMISM, GREED
  final String? title;
  final String content;
  final String? tags;
  final String? stockCodes;
  final List<String> imageUrls;
  final bool isPinned;
  final String? aiSummary;
  final String? aiAnalysis;
  final DateTime? createdAt;

  MarketJournal({
    this.id,
    required this.journalDate,
    this.journalType = 'DAILY',
    this.mood = 'NEUTRAL',
    this.title,
    this.content = '',
    this.tags,
    this.stockCodes,
    this.imageUrls = const [],
    this.isPinned = false,
    this.aiSummary,
    this.aiAnalysis,
    this.createdAt,
  });

  factory MarketJournal.fromJson(Map<String, dynamic> json) {
    List<String> urls = [];
    if (json['image_urls'] != null) {
      if (json['image_urls'] is List) {
        urls = (json['image_urls'] as List).map((e) => e.toString()).toList();
      } else if (json['image_urls'] is String) {
        final s = json['image_urls'] as String;
        if (s.isNotEmpty) urls = s.split(',');
      }
    }

    return MarketJournal(
      id: json['id']?.toString(),
      journalDate: json['journal_date'] as String? ?? '',
      journalType: json['journal_type'] as String? ?? 'DAILY',
      mood: json['mood'] as String? ?? 'NEUTRAL',
      title: json['title'] as String?,
      content: json['content'] as String? ?? '',
      tags: json['tags'] as String?,
      stockCodes: json['stock_codes'] as String?,
      imageUrls: urls,
      isPinned: json['is_pinned'] == true || json['is_pinned'] == 1,
      aiSummary: json['ai_summary'] as String?,
      aiAnalysis: json['ai_analysis'] as String?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'journal_date': journalDate,
    'journal_type': journalType,
    'mood': mood,
    if (title != null) 'title': title,
    'content': content,
    if (tags != null) 'tags': tags,
    if (stockCodes != null) 'stock_codes': stockCodes,
    if (imageUrls.isNotEmpty) 'image_urls': imageUrls.join(','),
  };
}

class JournalStreak {
  final int currentStreak;
  final int longestStreak;
  final int totalDays;

  JournalStreak({this.currentStreak = 0, this.longestStreak = 0, this.totalDays = 0});

  factory JournalStreak.fromJson(Map<String, dynamic> json) => JournalStreak(
    currentStreak: (json['current_streak'] as num?)?.toInt() ?? 0,
    longestStreak: (json['longest_streak'] as num?)?.toInt() ?? 0,
    totalDays: (json['total_days'] as num?)?.toInt() ?? 0,
  );
}

// 기분 이모지/색상 매핑
const Map<String, String> moodEmoji = {
  'FEAR': '😨', 'ANXIETY': '😰', 'NEUTRAL': '😐', 'OPTIMISM': '😊', 'GREED': '🤑',
};
const Map<String, String> moodLabel = {
  'FEAR': '공포', 'ANXIETY': '불안', 'NEUTRAL': '중립', 'OPTIMISM': '낙관', 'GREED': '탐욕',
};
const Map<String, String> journalTypeLabel = {
  'DAILY': '일간', 'EVENT': '이벤트', 'CONCEPT': '컨셉',
};

class StockEvent {
  final String? id;
  final String eventType; // EARNINGS, ECONOMIC, FED_SPEECH, CORPORATE
  final String title;
  final String eventDate; // YYYY-MM-DD
  final String? eventTime;
  final String impact; // HIGH, MEDIUM, LOW
  final String? description;
  final String? stockCode;
  final String? stockName;
  final Map<String, dynamic>? eventDetail;
  final Map<String, dynamic>? result;
  final String? resultNote;
  final bool completed;
  final DateTime? createdAt;

  StockEvent({
    this.id,
    required this.eventType,
    required this.title,
    required this.eventDate,
    this.eventTime,
    this.impact = 'MEDIUM',
    this.description,
    this.stockCode,
    this.stockName,
    this.eventDetail,
    this.result,
    this.resultNote,
    this.completed = false,
    this.createdAt,
  });

  factory StockEvent.fromJson(Map<String, dynamic> json) => StockEvent(
    id: json['id']?.toString(),
    eventType: json['event_type'] as String? ?? 'ECONOMIC',
    title: json['title'] as String? ?? '',
    eventDate: json['event_date'] as String? ?? '',
    eventTime: json['event_time'] as String?,
    impact: json['impact'] as String? ?? 'MEDIUM',
    description: json['description'] as String?,
    stockCode: json['stock_code'] as String?,
    stockName: json['stock_name'] as String?,
    eventDetail: json['event_detail'] is Map ? Map<String, dynamic>.from(json['event_detail']) : null,
    result: json['result'] is Map ? Map<String, dynamic>.from(json['result']) : null,
    resultNote: json['result_note'] as String?,
    completed: json['completed'] == true || json['completed'] == 1,
    createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
  );

  Map<String, dynamic> toJson() => {
    'event_type': eventType,
    'title': title,
    'event_date': eventDate,
    if (eventTime != null) 'event_time': eventTime,
    'impact': impact,
    if (description != null) 'description': description,
    if (stockCode != null) 'stock_code': stockCode,
    if (stockName != null) 'stock_name': stockName,
    if (eventDetail != null) 'event_detail': eventDetail,
  };
}

// 이벤트 타입 상수
const Map<String, (String label, int color, String icon)> eventTypes = {
  'EARNINGS': ('실적발표', 0xFF3B82F6, 'bar_chart'),
  'ECONOMIC': ('경제지표', 0xFFF59E0B, 'public'),
  'FED_SPEECH': ('연준발언', 0xFF8B5CF6, 'mic'),
  'CORPORATE': ('기업이벤트', 0xFF22C55E, 'business'),
};

const Map<String, (String label, int color)> impactLevels = {
  'HIGH': ('높음', 0xFFEF4444),
  'MEDIUM': ('보통', 0xFFF59E0B),
  'LOW': ('낮음', 0xFF9CA3AF),
};

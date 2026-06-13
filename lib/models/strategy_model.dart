class TradingStrategy {
  final String? id;
  final String name;
  final String category;
  final String? description;
  final int stepCount;
  final List<StrategyStep> steps;

  TradingStrategy({
    this.id,
    required this.name,
    this.category = 'CUSTOM',
    this.description,
    this.stepCount = 0,
    this.steps = const [],
  });

  factory TradingStrategy.fromJson(Map<String, dynamic> json) {
    List<StrategyStep> steps = [];
    if (json['steps'] is List) {
      steps = (json['steps'] as List).map((e) => StrategyStep.fromJson(e as Map<String, dynamic>)).toList();
    }
    return TradingStrategy(
      id: json['id']?.toString(),
      name: json['name'] as String? ?? '',
      category: json['category'] as String? ?? 'CUSTOM',
      description: json['description'] as String?,
      stepCount: (json['step_count'] as num?)?.toInt() ?? steps.length,
      steps: steps,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'category': category,
    if (description != null) 'description': description,
    'steps': steps.map((s) => s.toJson()).toList(),
  };
}

class StrategyStep {
  final String? id;
  final String stepType; // SIGNAL, CONFIRM, EXECUTE
  final String title;
  final int order;

  StrategyStep({this.id, required this.stepType, required this.title, this.order = 0});

  factory StrategyStep.fromJson(Map<String, dynamic> json) => StrategyStep(
    id: json['id']?.toString(),
    stepType: json['step_type'] as String? ?? 'SIGNAL',
    title: json['title'] as String? ?? '',
    order: (json['order'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => {'step_type': stepType, 'title': title, 'order': order};
}

// 카테고리 상수
const Map<String, (String label, int color)> strategyCategories = {
  'TREND': ('추세추종', 0xFF22C55E),
  'SWING': ('스윙', 0xFF3B82F6),
  'SCALP': ('스캘핑', 0xFFF59E0B),
  'VALUE': ('가치투자', 0xFF8B5CF6),
  'BREAKOUT': ('돌파', 0xFFEF4444),
  'DIVIDEND': ('배당', 0xFF14B8A6),
  'CONTRARIAN': ('역발상', 0xFFEC4899),
  'STOP_LOSS': ('손절', 0xFFEF4444),
  'TAKE_PROFIT': ('익절', 0xFF22C55E),
  'EXIT_STRATEGY': ('청산전략', 0xFF6366F1),
  'CUSTOM': ('기타', 0xFF9CA3AF),
};

const Map<String, (String label, int color)> stepTypes = {
  'SIGNAL': ('시그널', 0xFF3B82F6),
  'CONFIRM': ('확인', 0xFFF59E0B),
  'EXECUTE': ('실행', 0xFF22C55E),
};

# Note Tab Plan

## Executive Summary

| 관점 | 내용 |
|------|------|
| **Problem** | 투자 기록/심리/전략/일정을 관리할 수 있는 노트 기능이 앱에 없음 (웹에만 존재) |
| **Solution** | 하단 탭 "노트" 추가, 4개 서브탭(시장일지/심리/매매기법/일정관리) + AI 기능 구현 |
| **UX Effect** | 모바일에서 매매 기록, 심리 체크, 전략 관리, 일정 확인을 즉시 수행 가능 |
| **Core Value** | 웹과 동일한 투자 노트 경험을 모바일로 확장, 실시간 기록 습관 형성 |

## Context Anchor

| Key | Value |
|-----|-------|
| **WHY** | 투자 기록/분석은 즉시성이 중요한데 모바일 앱에 해당 기능 부재 |
| **WHO** | 개인 투자자 (매매 기록, 심리 관리, 전략 정리 필요) |
| **RISK** | API 엔드포인트 다수 (4개 서비스), UI 페이지 수 많음 |
| **SUCCESS** | 4개 서브탭 전체 CRUD + AI 기능 동작, 웹과 동일한 데이터 공유 |
| **SCOPE** | 하단 네비게이션 탭 추가 + 노트 4개 서브탭 전체 |

---

## 1. 네비게이션 변경

현재: `홈 | 관심종목 | 내정보` (3탭)
변경: `홈 | 관심종목 | 노트 | 내정보` (4탭)

- `home_screen.dart`의 `_pages`와 `BottomNavigationBar`에 노트 탭 추가
- 아이콘: `Icons.edit_note_outlined` / `Icons.edit_note`

---

## 2. 서브탭 구조

```
노트 (NoteScreen)
├── 시장일지 (MarketJournalTab)
├── 심리 (PsychTab)
├── 매매기법 (StrategyTab)
└── 일정관리 (CalendarTab)
```

상단 TabBar + TabBarView로 서브탭 전환

---

## 3. 서브탭 1: 시장일지

### 3.1 데이터 모델

```dart
class MarketJournal {
  String? id;
  String journalDate;        // YYYYMMDD
  String journalType;        // DAILY, EVENT, CONCEPT
  String mood;               // FEAR, ANXIETY, NEUTRAL, OPTIMISM, GREED
  String? title;
  String content;
  String? tags;              // comma-separated
  String? stockCodes;        // comma-separated
  List<String> imageUrls;
  bool isPinned;
  String? aiSummary;
  String? aiAnalysis;
}
```

### 3.2 API 엔드포인트

| 기능 | Method | Path |
|------|--------|------|
| 목록 조회 | GET | `/api/IV/journal` |
| 생성 | POST | `/api/IV/journal` |
| 수정 | PUT | `/api/IV/journal/{id}` |
| 삭제 | DELETE | `/api/IV/journal/{id}` |
| 핀 토글 | PUT | `/api/IV/journal/{id}/pin` |
| 검색 | GET | `/api/IV/journal/search` |
| 태그 통계 | GET | `/api/IV/journal/stats/tags` |
| 기분 통계 | GET | `/api/IV/journal/stats/mood` |
| 연속 기록 | GET | `/api/IV/journal/stats/streak` |
| AI 초안 | GET | `/api/IV/journal/ai-draft` |
| AI 태그 | POST | `/api/IV/journal/ai-tags` |
| AI 분석 | POST | `/api/IV/journal/{id}/ai-analyze` |
| AI 리포트 | GET | `/api/IV/journal/ai-report` |

### 3.3 UI 구성

- **목록 화면**: 타입 필터(전체/DAILY/EVENT/CONCEPT), 카드 리스트, 검색 버튼
- **카드**: 날짜 + 기분이모지 + 타입배지 + 제목 + 내용미리보기 + 태그 + AI요약
- **작성/수정 폼**: BottomSheet 또는 별도 화면
  - 날짜, 타입, 기분 선택, 제목, 내용, 태그, 종목코드, 이미지URL
  - AI 초안 생성 버튼, AI 태그 추천 버튼
- **통계**: 연속 기록(streak), 기분 트렌드, 태그 빈도

---

## 4. 서브탭 2: 심리

### 4.1 데이터 모델

```dart
class TradingRule {
  String? id;
  String category;    // PSYCH, ENTRY, EXIT, RISK
  String title;       // 원칙 내용
}

class PsychChecklist {
  String? id;
  String stockCode;
  String stockName;
  bool passed;
  double complianceRate;
  double cashRatio;
  double betRatio;
  String? memo;
}

class ComplianceStats {
  int compliantTrades;
  double compliantWinRate;
  double compliantAvgReturn;
  int nonCompliantTrades;
  double nonCompliantWinRate;
  double nonCompliantAvgReturn;
}
```

### 4.2 API 엔드포인트

| 기능 | Method | Path |
|------|--------|------|
| 원칙 목록 | GET | `/api/IV/psych/rules` |
| 원칙 생성 | POST | `/api/IV/psych/rules` |
| 원칙 수정 | PUT | `/api/IV/psych/rules/{id}` |
| 원칙 삭제 | DELETE | `/api/IV/psych/rules/{id}` |
| 체크리스트 이력 | GET | `/api/IV/psych/checklists` |
| 준수율 통계 | GET | `/api/IV/psych/stats/compliance` |

### 4.3 UI 구성

- **투자 원칙 패널**: 카테고리별(심리/진입/청산/리스크) 원칙 리스트 + 추가/편집/삭제
- **준수율 통계**: 원칙 준수 vs 미준수 매매 비교 카드 (매매수, 승률, 평균수익률)
- **체크리스트 이력**: PASS/FAIL 배지 + 종목 + 준수율 타임라인

---

## 5. 서브탭 3: 매매기법

### 5.1 데이터 모델

```dart
class TradingStrategy {
  String? id;
  String name;
  String category;      // TREND, SWING, SCALP, VALUE, BREAKOUT, ...
  String? description;
  int stepCount;
  List<StrategyStep> steps;
}

class StrategyStep {
  String? id;
  String stepType;      // SIGNAL, CONFIRM, EXECUTE
  String title;
  int order;
}
```

### 5.2 API 엔드포인트

| 기능 | Method | Path |
|------|--------|------|
| 전략 목록 | GET | `/api/IV/strategy` |
| 전략 생성 | POST | `/api/IV/strategy` |
| 전략 상세 | GET | `/api/IV/strategy/{id}` |
| 전략 수정 | PUT | `/api/IV/strategy/{id}` |
| 전략 삭제 | DELETE | `/api/IV/strategy/{id}` |
| 단계 수정 | PUT | `/api/IV/strategy/{id}/steps` |

### 5.3 UI 구성

- **전략 카드 리스트**: 카테고리 배지 + 이름 + 단계 수 + 확장 상세
- **상세 뷰**: 설명 + 단계 리스트 (SIGNAL→CONFIRM→EXECUTE 시각화)
- **생성/수정 폼**: 이름, 카테고리 선택, 설명, 단계 추가/삭제/순서변경

---

## 6. 서브탭 4: 일정관리

### 6.1 데이터 모델

```dart
class StockEvent {
  String? id;
  String eventType;     // EARNINGS, ECONOMIC, FED_SPEECH, CORPORATE
  String title;
  String eventDate;     // YYYY-MM-DD
  String? eventTime;
  String impact;        // HIGH, MEDIUM, LOW
  String? description;
  String? stockCode;
  String? stockName;
  Map<String, dynamic>? eventDetail;   // 타입별 세부 정보
  Map<String, dynamic>? result;        // 복기 결과
  String? resultNote;
  bool completed;
}
```

### 6.2 API 엔드포인트

| 기능 | Method | Path |
|------|--------|------|
| 이벤트 목록 | GET | `/api/IV/quant/events` |
| 이벤트 생성 | POST | `/api/IV/quant/events` |
| 이벤트 상세 | GET | `/api/IV/quant/events/{id}` |
| 이벤트 수정 | PUT | `/api/IV/quant/events/{id}` |
| 이벤트 삭제 | DELETE | `/api/IV/quant/events/{id}` |
| 복기 기록 | PUT | `/api/IV/quant/events/{id}/result` |
| 실적 크롤링 | POST | `/api/IV/quant/events/crawl/earnings` |

### 6.3 UI 구성

- **캘린더 그리드**: 월간 뷰, 날짜셀에 이벤트 도트, 좌우 월 이동
- **이벤트 필터**: 타입별 필터 칩, "관심종목만" 토글
- **선택일 패널**: 해당 날짜 이벤트 리스트 + 추가 버튼
- **이벤트 폼**: 타입, 제목, 날짜, 시간, 종목, 중요도, 설명 + 타입별 세부필드
- **복기 모달**: 실제 결과 입력 + 메모

---

## 7. 파일 구조

```
lib/screens/note/
├── note_screen.dart              # 메인 (TabBar + 4개 서브탭)
├── journal/
│   ├── journal_tab.dart          # 시장일지 목록
│   ├── journal_card.dart         # 일지 카드 위젯
│   ├── journal_form.dart         # 작성/수정 폼
│   ├── journal_search.dart       # 검색
│   └── journal_stats.dart        # 통계 (streak, mood, tags)
├── psych/
│   ├── psych_tab.dart            # 심리 메인
│   ├── trading_rules_panel.dart  # 투자 원칙 CRUD
│   └── compliance_panel.dart     # 준수율 통계 + 이력
├── strategy/
│   ├── strategy_tab.dart         # 매매기법 목록
│   ├── strategy_card.dart        # 전략 카드 (확장 가능)
│   └── strategy_form.dart        # 생성/수정 폼
└── calendar/
    ├── calendar_tab.dart         # 캘린더 그리드 + 이벤트 리스트
    ├── event_form.dart           # 이벤트 생성/수정
    └── event_result_form.dart    # 복기 입력

lib/services/
├── journal_service.dart          # 시장일지 API
├── psych_service.dart            # 심리 API
├── strategy_service.dart         # 매매기법 API
└── event_service.dart            # 일정관리 API

lib/models/
├── journal_model.dart
├── psych_model.dart
├── strategy_model.dart
└── event_model.dart

lib/config/api_config.dart        # 엔드포인트 추가
lib/screens/home_screen.dart      # 하단탭 4개로 확장
```

---

## 8. 성공 기준

| # | 기준 |
|---|------|
| SC1 | 하단 네비게이션 4탭 (홈/관심종목/노트/내정보) 동작 |
| SC2 | 시장일지 CRUD + 타입필터 + 검색 + 통계 + AI초안/태그/분석 |
| SC3 | 투자 원칙 CRUD + 준수율 통계 + 체크이력 |
| SC4 | 매매기법 CRUD + 단계 관리 (추가/삭제/순서변경) |
| SC5 | 일정관리 캘린더 + 이벤트 CRUD + 복기 + 실적크롤링 |
| SC6 | 웹과 동일한 데이터 동기화 (같은 API 사용) |

## 9. 예상 작업량

- 신규 파일: ~20개
- 수정 파일: 2개 (home_screen.dart, api_config.dart)
- 예상 변경: ~3,000줄

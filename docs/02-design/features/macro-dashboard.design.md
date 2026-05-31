# Design: 거시경제 대시보드 (macro-dashboard)

> Feature: macro-dashboard
> Created: 2026-05-31
> Architecture: Option C — Pragmatic Balance
> Plan: docs/01-plan/features/macro-dashboard.plan.md

---

## Context Anchor

| 항목 | 내용 |
|------|------|
| **WHY** | HomeScreen 홈 탭이 빈 placeholder 상태. 재무 앱의 첫인상이자 핵심 가치를 보여줄 화면이 필요하다 |
| **WHO** | LinkerBiz 관리자 중 주식/재무 담당자 — 매일 시장 상황을 확인하는 사용자 |
| **RISK** | API 서버 부하 (22개 자산 동시 조회), 실시간 데이터 지연, 모바일 화면에 정보 과밀 |
| **SUCCESS** | 홈 화면에서 시장 심리 게이지 + 자산 카드 그리드 정상 표시, 카테고리 필터, 자산 선택 시 히스토리 차트 표시 |
| **SCOPE** | API 6개 연동, 22개 자산, 시장 심리 게이지, 카테고리 필터, 위험도 평가, 크로스시그널, 히스토리 차트 |

---

## 1. Overview

### 1.1 설계 방향
- **Pragmatic Balance**: MacroService에서 API 호출, 섹션별 위젯으로 UI 분리
- MacroDashboardScreen이 전체 상태 관리 (setState), 각 섹션 위젯에 데이터 전달
- 위험도 평가/크로스시그널 로직은 macro_utils.dart로 분리 (웹의 로직 포팅)

### 1.2 핵심 결정사항

| 결정 | 선택 | 이유 |
|------|------|------|
| 차트 | `fl_chart` (AreaChart) | Flutter 네이티브, 가볍고 커스터마이징 용이 |
| 숫자 포맷 | `intl` (NumberFormat) | 한국어 숫자/날짜 포맷팅 표준 |
| 데이터 로딩 | 캐시 우선 + 수동 실시간 | 초기 빠른 표시, 사용자 요청 시만 실시간 호출 |
| 상태관리 | StatefulWidget + setState | admin-account과 동일 패턴 유지 |
| 위젯 분리 | 섹션별 5개 위젯 | 각 섹션 독립 수정 가능, 재사용성 |

---

## 2. 프로젝트 구조

```
lib/
├── config/
│   └── api_config.dart                    # [수정] macro API 엔드포인트 6개 추가
├── models/
│   └── macro_asset_model.dart             # [신규] MacroAsset + MacroHistory 모델
├── services/
│   └── macro_service.dart                 # [신규] MacroService (API 호출)
├── screens/
│   ├── home_screen.dart                   # [수정] _HomePlaceholder → MacroDashboardScreen
│   └── macro/
│       ├── macro_dashboard_screen.dart    # [신규] 대시보드 메인 (상태관리 + 조합)
│       ├── sentiment_gauge_section.dart   # [신규] 시장 심리 게이지 (4카드)
│       ├── category_filter.dart           # [신규] 카테고리 필터 칩
│       ├── asset_card_grid.dart           # [신규] 자산 카드 그리드
│       ├── asset_history_chart.dart       # [신규] fl_chart 히스토리 차트
│       └── cross_signal_section.dart      # [신규] 크로스시그널 목록
└── utils/
    └── macro_utils.dart                   # [신규] 위험도 평가, 시그널 생성, 포맷팅
```

**파일 수**: 신규 9 + 수정 2 = 11개

---

## 3. 데이터 모델

### 3.1 MacroAsset (`lib/models/macro_asset_model.dart`)

```dart
class MacroAsset {
  final String symbol;       // "KOSPI", "SP500", "VIX" 등
  final String name;         // "코스피", "S&P 500" 등
  final String category;     // "index", "futures", "currency" 등
  final double price;        // 현재가
  final double change;       // 변동폭
  final double changePercent;// 변동률 (%)
  final String? interpretation; // 카테고리별 해석 텍스트
  final DateTime? updatedAt;

  factory MacroAsset.fromJson(Map<String, dynamic> json);
}

class MacroHistory {
  final DateTime date;
  final double close;
  final double? high;
  final double? low;

  factory MacroHistory.fromJson(Map<String, dynamic> json);
}

class FearGreedData {
  final double vixValue;
  final String level;        // EXTREME_FEAR ~ EXTREME_GREED
  final String label;        // "극단적 공포" ~ "극단적 탐욕"

  factory FearGreedData.fromJson(Map<String, dynamic> json);
}

class YieldSpreadData {
  final double spread;       // 10Y - 2Y 금리차
  final double us10y;
  final double us2y;
  final bool recessionWarning; // 역전 시 true

  factory YieldSpreadData.fromJson(Map<String, dynamic> json);
}
```

---

## 4. API 계약 (Contract)

### 4.1 공통
- Base: `${ApiConfig.baseUrl}/api/IV/quant/macro`
- 응답: `{ "resultCode": "200", "res": ... }`

### 4.2 엔드포인트 상세

#### API-01: 캐시 데이터 (초기 로드용)
```
GET /api/IV/quant/macro/latest
Success: { "resultCode": "200", "res": [MacroAsset, ...] }
```

#### API-02: 실시간 데이터
```
GET /api/IV/quant/macro/current?category={category}
Success: { "resultCode": "200", "res": [MacroAsset, ...] }
```
> category 생략 시 전체 반환

#### API-03: 히스토리 차트
```
GET /api/IV/quant/macro/history?symbol={symbol}&period={period}
period: "1w", "1m", "3m", "6m", "1y"
Success: { "resultCode": "200", "res": [MacroHistory, ...] }
```

#### API-04: 장단기 금리차
```
GET /api/IV/quant/macro/yield-spread
Success: { "resultCode": "200", "res": YieldSpreadData }
```

#### API-05: 공포/탐욕 지수
```
GET /api/IV/quant/macro/fear-greed
Success: { "resultCode": "200", "res": FearGreedData }
```

#### API-06: 카테고리 목록
```
GET /api/IV/quant/macro/categories
Success: { "resultCode": "200", "res": ["index", "futures", ...] }
```

---

## 5. Service 설계

### 5.1 ApiConfig 추가 (`lib/config/api_config.dart`)

```dart
// 거시경제 대시보드
static const String macroLatest = '/api/IV/quant/macro/latest';
static const String macroCurrent = '/api/IV/quant/macro/current';
static const String macroHistory = '/api/IV/quant/macro/history';
static const String macroYieldSpread = '/api/IV/quant/macro/yield-spread';
static const String macroFearGreed = '/api/IV/quant/macro/fear-greed';
static const String macroCategories = '/api/IV/quant/macro/categories';
```

### 5.2 MacroService (`lib/services/macro_service.dart`)

```dart
class MacroService {
  /// 캐시 데이터 (초기 빠른 로드)
  static Future<List<MacroAsset>> getLatest() async { ... }

  /// 실시간 데이터 (수동 새로고침)
  static Future<List<MacroAsset>> getCurrent({String? category}) async { ... }

  /// 히스토리 차트 데이터
  static Future<List<MacroHistory>> getHistory(String symbol, {String period = '1m'}) async { ... }

  /// 장단기 금리차
  static Future<YieldSpreadData?> getYieldSpread() async { ... }

  /// 공포/탐욕 지수
  static Future<FearGreedData?> getFearGreed() async { ... }
}
```

---

## 6. 화면 설계

### 6.1 MacroDashboardScreen (메인)

```
┌─────────────────────────────┐
│ (AppBar는 HomeScreen에서 제공)│
├─────────────────────────────┤
│                             │
│  ┌─ 시장 심리 게이지 ──────┐ │
│  │ 📊 시장신호  😱 공포/탐욕│ │
│  │ 📈 금리차    💰 신용/예탁│ │
│  │                         │ │
│  │ WTI│USD/KRW│GOLD│COPPER │ │
│  └─────────────────────────┘ │
│                             │
│  [전체][지수][선물][환율]... │  ← 카테고리 필터
│  "카테고리 해석 텍스트"      │
│                             │
│  ┌─ 크로스시그널 ──────────┐ │  ← 전체 선택 시
│  │ 📈 VIX+금리차 시그널    │ │
│  │ ⚠️ 달러+유가 경고       │ │
│  └─────────────────────────┘ │
│                             │
│  ┌──────┐ ┌──────┐          │
│  │KOSPI │ │KOSDAQ│ ...      │  ← 자산 카드 2열 그리드
│  │2,847 │ │892   │          │
│  │+1.2% │ │-0.3% │          │
│  │🟢안전│ │🟡주의│          │
│  └──────┘ └──────┘          │
│                             │
│  ┌─ 히스토리 차트 ────────┐  │  ← 카드 터치 시 펼쳐짐
│  │ KOSPI                  │  │
│  │ ┌───────────────────┐  │  │
│  │ │   AreaChart        │  │  │
│  │ └───────────────────┘  │  │
│  │ [1W][1M][3M][6M][1Y]  │  │
│  │ 고가:2,900 저가:2,750  │  │
│  └────────────────────────┘  │
└─────────────────────────────┘
```

### 6.2 SentimentGaugeSection

4개 메인 카드 (2x2 그리드):
| 카드 | 데이터 소스 | 표시 |
|------|------------|------|
| 시장 신호 | VIX + 금리차 조합 | 매수 유리/중립/매수 주의 + 이모지 |
| 공포/탐욕 | `/fear-greed` | VIX 값 + 레벨 텍스트 + 색상 |
| 금리차 | `/yield-spread` | 10Y-2Y 스프레드 + 역전 경고 |
| 신용/예탁 | `/latest` (DEPOSIT, CREDIT) | 비율 + 과열 판단 |

4개 빠른 지표 카드 (가로 스크롤):
WTI, USD/KRW, GOLD, COPPER — 현재가 + 등락률

### 6.3 CategoryFilter

- 9개 필터 칩: 전체/지수/선물/환율/채권/변동성/암호화폐/원자재/투자심리
- `ChoiceChip` 또는 커스텀 `FilterChip` 사용
- 선택 시 콜백으로 부모에 카테고리 전달

### 6.4 AssetCardGrid

- `GridView.builder` 2열
- 각 카드: 이름, 심볼, 현재가, 등락률(색상), 위험도 뱃지
- 터치 시 선택 상태 토글 → 히스토리 차트 표시

### 6.5 AssetHistoryChart

- `fl_chart` LineChart를 AreaChart 스타일로 (belowBarData)
- 기간 선택 칩: 1W, 1M, 3M, 6M, 1Y
- 하단 통계: 고가/저가/현재가
- 선택된 자산이 없으면 숨김

### 6.6 CrossSignalSection

- 전체 카테고리 선택 시만 표시
- `macro_utils.dart`의 `generateCrossSignals()` 결과 표시
- 시그널 타입별 아이콘/색상: positive(초록), negative(빨강), warning(주황), opportunity(파랑), neutral(회색)

---

## 7. 유틸리티 설계 (`macro_utils.dart`)

웹 MacroDashboard.js의 로직을 Dart로 포팅:

```dart
/// 자산별 위험도 평가 (안전/주의/경고/위험)
String getAssetDanger(MacroAsset asset) { ... }

/// 위험도별 색상
Color getDangerColor(String danger) { ... }

/// 등락률 색상 (상승=빨강, 하락=파랑)
Color getChangeColor(double changePercent) { ... }

/// 시장 신호 판단 (VIX + 금리차 기반)
({String signal, String emoji, Color color}) getMarketSignal(
  FearGreedData? fearGreed,
  YieldSpreadData? yieldSpread,
) { ... }

/// 크로스시그널 생성
List<CrossSignal> generateCrossSignals(List<MacroAsset> assets) { ... }

/// 숫자 포맷 (소수점, 콤마, %, 원)
String formatPrice(double price, String symbol) { ... }
String formatChange(double change, double changePercent) { ... }
```

---

## 8. 에러 처리

| 상황 | 처리 |
|------|------|
| API 실패 | "데이터를 불러올 수 없습니다" + 재시도 버튼 |
| 부분 데이터 | 가용한 데이터만 표시, 빈 섹션은 "데이터 없음" |
| 장외시간 | 마지막 데이터 표시 + "장 마감" 뱃지 |
| 히스토리 없음 | "차트 데이터를 불러올 수 없습니다" 메시지 |

---

## 9. 패키지 의존성

```yaml
# pubspec.yaml에 추가
dependencies:
  fl_chart: ^0.70.2
  intl: ^0.20.2
```

---

## 10. 디자인 토큰 (추가)

기존 admin-account 토큰 + 대시보드 전용:

| 토큰 | 값 | 용도 |
|------|-----|------|
| `upColor` | `#E53935` (빨강) | 상승 |
| `downColor` | `#1E88E5` (파랑) | 하락 |
| `dangerSafe` | `#4CAF50` (초록) | 안전 뱃지 |
| `dangerCaution` | `#FF9800` (주황) | 주의 뱃지 |
| `dangerWarning` | `#F44336` (빨강) | 경고 뱃지 |
| `dangerCritical` | `#B71C1C` (진빨강) | 위험 뱃지 |
| `chartFill` | `primaryColor 10%` | 차트 영역 채우기 |
| `chipSelected` | `primaryColor` | 선택된 필터 칩 |
| `chipUnselected` | `#E0E0E0` | 미선택 필터 칩 |

---

## 11. Implementation Guide

### 11.1 구현 순서

| 단계 | 파일 | 작업 | 예상 라인 |
|:----:|------|------|:---------:|
| 1 | `pubspec.yaml` | fl_chart, intl 추가 | ~2 |
| 2 | `lib/config/api_config.dart` | macro 엔드포인트 6개 추가 | ~8 |
| 3 | `lib/models/macro_asset_model.dart` | MacroAsset, MacroHistory, FearGreed, YieldSpread 모델 | ~120 |
| 4 | `lib/services/macro_service.dart` | API 호출 5개 메서드 | ~80 |
| 5 | `lib/utils/macro_utils.dart` | 위험도, 시그널, 포맷팅 로직 | ~200 |
| 6 | `lib/screens/macro/category_filter.dart` | 카테고리 필터 칩 UI | ~60 |
| 7 | `lib/screens/macro/sentiment_gauge_section.dart` | 시장 심리 4카드 + 빠른 지표 | ~250 |
| 8 | `lib/screens/macro/asset_card_grid.dart` | 자산 카드 2열 그리드 | ~150 |
| 9 | `lib/screens/macro/asset_history_chart.dart` | fl_chart AreaChart + 기간 선택 | ~200 |
| 10 | `lib/screens/macro/cross_signal_section.dart` | 크로스시그널 목록 | ~100 |
| 11 | `lib/screens/macro/macro_dashboard_screen.dart` | 전체 조합 + 상태관리 | ~200 |
| 12 | `lib/screens/home_screen.dart` | placeholder → dashboard 교체 | ~5 |

**총 예상**: ~1,375 라인

### 11.2 의존성 그래프

```
api_config ──→ macro_service ──→ macro_dashboard_screen
                    │                    │
macro_asset_model ──┘              ┌─────┼─────────────┐
                              sentiment  asset_card  history_chart
macro_utils ──────────────→  gauge      grid        
                              cross_signal
                              category_filter
```

### 11.3 Session Guide

**Module Map**:

| Module | 파일 | 설명 |
|--------|------|------|
| module-1 | pubspec, api_config, macro_asset_model, macro_service, macro_utils | 기반 레이어 (데이터+로직) |
| module-2 | category_filter, sentiment_gauge_section, asset_card_grid | 핵심 UI 위젯 |
| module-3 | asset_history_chart, cross_signal_section | 차트 + 시그널 |
| module-4 | macro_dashboard_screen, home_screen 수정 | 조합 + 연결 |

**Recommended Session Plan**:

| 세션 | Module | 소요 | 설명 |
|:----:|--------|:----:|------|
| 1 | module-1 + module-2 | ~60min | 기반 + 핵심 UI (데이터 로드→카드 표시) |
| 2 | module-3 + module-4 | ~50min | 차트 + 시그널 + 전체 조합 |

> 1회 세션으로 전체 구현 가능 (~110min). 분할 시 module-1,2 먼저 완성하여 데이터 로드 확인 후 진행 권장.

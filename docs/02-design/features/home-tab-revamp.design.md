# home-tab-revamp Design

> **Feature**: 홈 탭 개편 — 시장 종합 진단 + 5탭 네비게이션 전환
> **Created**: 2026-07-13
> **Architecture**: Option C — Pragmatic Balance
> **Plan Reference**: `docs/01-plan/features/home-tab-revamp.plan.md`

## Context Anchor

| Key | Value |
|-----|-------|
| **WHY** | 현재 앱은 데이터 나열형 → 사용자가 직접 해석 필요 → 앱 열 이유 부족. "앱이 시장을 해석해주는" 경험으로 전환 |
| **WHO** | 개인 투자자 (한국 주식, 매일 시장 체크, 중급 이상) |
| **RISK** | scanner/investor API 모바일 첫 사용 — 응답 형식 검증 필요. 진단 로직은 클라이언트 계산 |
| **SUCCESS** | 홈 탭 3초 내 시장 방향 파악. 5개 섹션 로딩 성공. 5탭 네비게이션 정상 작동 |
| **SCOPE** | Phase 1: 홈 탭 5개 섹션 + 5탭 전환 + 더보기 껍데기 |

---

## 1. Overview

### 1.1 설계 방향
- **Option C — Pragmatic Balance**: 위젯은 섹션별 분리, 서비스/모델은 적정 통합
- 기존 MacroDashboardScreen은 그대로 보존 (거시경제 상세 보기용)
- 새 MarketHomeScreen이 홈 탭 역할을 대체

### 1.2 주요 결정사항
- 진단 로직: 별도 서비스 없이 `MarketDiagnosisCard` 위젯 내부에 유틸 함수로 구현
- scanner + sector-flow API: `ScannerService` 하나로 통합
- investor market-summary API: `InvestorService`로 분리 (응답 형식이 다름)
- 기존 MacroService: 그대로 재활용 (Fear&Greed, macro/current)

---

## 2. File Structure

```
lib/
├── config/
│   └── api_config.dart                    ← 수정: 신규 엔드포인트 4개 추가
├── models/
│   ├── scanner_model.dart                 ← 신규: ScanResult, SectorFlow
│   └── investor_model.dart                ← 신규: MarketSummary
├── services/
│   ├── scanner_service.dart               ← 신규: 스캐너 + 섹터플로우 API
│   └── investor_service.dart              ← 신규: 투자자 수급 API
├── screens/
│   ├── home_screen.dart                   ← 수정: 4탭→5탭, 홈 페이지 교체
│   ├── home/
│   │   ├── market_home_screen.dart        ← 신규: 새 홈 탭 (5개 섹션 스크롤)
│   │   └── widgets/
│   │       ├── market_diagnosis_card.dart  ← 신규: 한줄 진단 카드
│   │       ├── sector_scanner_section.dart ← 신규: 섹터 스캐너 가로 스크롤
│   │       ├── ai_scan_section.dart        ← 신규: AI 스캔 종목 리스트
│   │       ├── macro_summary_section.dart  ← 신규: 거시경제 축약 카드
│   │       └── investor_flow_section.dart  ← 신규: 투자자 수급 테이블
│   └── more/
│       └── more_screen.dart               ← 신규: 더보기 메뉴 화면
```

### 파일별 역할 요약

| 파일 | 신규/수정 | 역할 | 예상 LOC |
|------|----------|------|---------|
| `api_config.dart` | 수정 | 엔드포인트 4개 추가 | +8 |
| `scanner_model.dart` | 신규 | ScanResult + SectorFlow 데이터 모델 | ~80 |
| `investor_model.dart` | 신규 | MarketSummary 데이터 모델 | ~50 |
| `scanner_service.dart` | 신규 | 스캐너 결과 + 섹터 플로우 API | ~60 |
| `investor_service.dart` | 신규 | 시장 수급 요약 API | ~35 |
| `home_screen.dart` | 수정 | 5탭 전환 + import 변경 | ~15 변경 |
| `market_home_screen.dart` | 신규 | 홈 탭 메인 화면 (데이터 로딩 + 섹션 조합) | ~180 |
| `market_diagnosis_card.dart` | 신규 | 한줄 진단 위젯 + 진단 로직 | ~150 |
| `sector_scanner_section.dart` | 신규 | 섹터 가로 스크롤 카드 | ~100 |
| `ai_scan_section.dart` | 신규 | AI 스캔 종목 리스트 | ~90 |
| `macro_summary_section.dart` | 신규 | 거시경제 5개 핵심 지표 카드 | ~80 |
| `investor_flow_section.dart` | 신규 | 코스피/코스닥 수급 테이블 | ~90 |
| `more_screen.dart` | 신규 | 더보기 메뉴 리스트 | ~80 |
| **합계** | | | **~1,000** |

---

## 3. Data Models

### 3.1 ScanResult (`scanner_model.dart`)

```dart
class ScanResult {
  final String stockCode;
  final String stockName;
  final String grade;        // 'S', 'A', 'B'
  final double changeRate;
  final String? aiComment;   // AI 코멘트 한줄
  final DateTime scanDate;
}
```

**API 응답 매핑** (`GET /api/IV/scanner/results?scanDate=YYYY-MM-DD&minGrade=B`):
- 응답: `{ res: [...] }` — `res` 필드가 배열
- 웹 코드 참고: `return res?.res || []`

### 3.2 SectorFlow (`scanner_model.dart`)

```dart
class SectorFlow {
  final String sectorName;
  final String? etfCode;
  final double changeRate;
  final double foreignNet;   // 외국인 순매수
  final double institutionNet; // 기관 순매수
}
```

**API 응답 매핑** (`GET /api/IV/quant/investor/sector-flow?days=20`):
- 응답: `{ res: 'success', count: N, data: [...] }` — 표준 quant 응답

### 3.3 MarketSummary (`investor_model.dart`)

```dart
class MarketSummary {
  final MarketFlowData? kospi;
  final MarketFlowData? kosdaq;
  final MarketFlowData? etc;
}

class MarketFlowData {
  final double foreignTotal;
  final double institutionTotal;
  final double individualTotal;
  final double? pensionTotal;
  final int stockCount;
  final int tradingDays;
  final String? latestDate;
}
```

**API 응답 매핑** (`GET /api/IV/quant/investor/market-summary`):
- 응답: 직접 JSON 객체 반환 (표준 `{ res, data }` 래퍼 없음)
- 웹 코드 참고: `return resp.json()` — `{ kospi: {...}, kosdaq: {...}, etc: {...} }`

### 3.4 기존 모델 재활용

| 모델 | 용도 |
|------|------|
| `FearGreedData` | 한줄 진단 — vixValue, level, label |
| `MacroAsset` | 거시경제 축약 — symbol, name, price, change, changePercent |
| `CrossSignal` | (사용 안 함 — 새 진단 로직으로 대체) |

---

## 4. API Contract

### 4.1 신규 엔드포인트 (`api_config.dart` 추가)

```dart
// 스캐너
static const String scannerResults = '/api/IV/scanner/results';

// 투자자 수급
static const String investorSectorFlow = '/api/IV/quant/investor/sector-flow';
static const String investorMarketSummary = '/api/IV/quant/investor/market-summary';
static const String investorSmartMoney = '/api/IV/quant/investor/smart-money';
```

### 4.2 서비스별 API 호출

| 서비스 | 메서드 | API | 파라미터 | 응답 처리 |
|--------|--------|-----|---------|----------|
| `ScannerService` | `getResults(date, minGrade)` | `GET scannerResults` | `scanDate`, `minGrade?` | `res` 배열 → `List<ScanResult>` |
| `ScannerService` | `getSectorFlow(days)` | `GET investorSectorFlow` | `days` (default 20) | `data` 배열 → `List<SectorFlow>` |
| `InvestorService` | `getMarketSummary(days)` | `GET investorMarketSummary` | `days?` | 직접 JSON → `MarketSummary` |

### 4.3 기존 API 재활용

| 서비스 | 메서드 | 용도 |
|--------|--------|------|
| `MacroService.getFearGreed()` | 한줄 진단 — Fear&Greed 점수 |
| `MacroService.getCurrent()` | 거시경제 축약 — 핵심 5개 지표 |

---

## 5. Screen Design

### 5.1 MarketHomeScreen (새 홈 탭)

**역할**: 5개 API를 병렬 호출하고, 각 섹션 위젯에 데이터 전달

```dart
class MarketHomeScreen extends StatefulWidget { ... }

class _MarketHomeScreenState extends State<MarketHomeScreen> {
  // 상태
  FearGreedData? _fearGreed;
  List<MacroAsset> _macroAssets = [];
  List<SectorFlow> _sectorFlows = [];
  List<ScanResult> _scanResults = [];
  MarketSummary? _marketSummary;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);

    // 5개 API 병렬 호출 — 각각 try-catch로 독립 에러 처리
    final results = await Future.wait([
      _safeCall(() => MacroService.getFearGreed()),
      _safeCall(() => MacroService.getCurrent()),
      _safeCall(() => ScannerService.getSectorFlow()),
      _safeCall(() => ScannerService.getResults()),
      _safeCall(() => InvestorService.getMarketSummary()),
    ]);

    if (!mounted) return;
    setState(() {
      _fearGreed = results[0] as FearGreedData?;
      _macroAssets = results[1] as List<MacroAsset>? ?? [];
      _sectorFlows = results[2] as List<SectorFlow>? ?? [];
      _scanResults = results[3] as List<ScanResult>? ?? [];
      _marketSummary = results[4] as MarketSummary?;
      _isLoading = false;
    });
  }

  // 개별 API 실패 시 null 반환 (다른 섹션 정상 표시)
  Future<T?> _safeCall<T>(Future<T> Function() fn) async {
    try { return await fn(); } catch (_) { return null; }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(children: [
          // ① 한줄 진단
          MarketDiagnosisCard(
            fearGreed: _fearGreed,
            macroAssets: _macroAssets,
            marketSummary: _marketSummary,
          ),
          // ② 섹터 스캐너
          SectorScannerSection(sectorFlows: _sectorFlows),
          // ③ AI 스캔 종목
          AiScanSection(scanResults: _scanResults),
          // ④ 거시경제 축약
          MacroSummarySection(assets: _macroAssets),
          // ⑤ 투자자 수급
          InvestorFlowSection(summary: _marketSummary),
          const SizedBox(height: 80), // BottomNav 여백
        ]),
      ),
    );
  }
}
```

### 5.2 섹션 위젯 상세

#### ① MarketDiagnosisCard

```
┌─────────────────────────────────────────┐
│ 🟡 약세 주의                              │
│ 외인 매도 우세, Fear&Greed 35(공포)        │
├─────────────────────────────────────────┤
│ 코스피 2,680.5 (-1.2%)  코스닥 845.3 (-0.8%)│
└─────────────────────────────────────────┘
```

**진단 로직** (위젯 내 `_calculateDiagnosis` 함수):

```dart
MarketDiagnosis _calculateDiagnosis({
  FearGreedData? fearGreed,
  List<MacroAsset> macroAssets,
  MarketSummary? summary,
}) {
  int score = 50; // 중립 시작

  // 1) Fear&Greed 기반 (±20점)
  if (fearGreed != null) {
    if (fearGreed.level == 'EXTREME_FEAR') score -= 20;
    else if (fearGreed.level == 'FEAR') score -= 10;
    else if (fearGreed.level == 'GREED') score += 10;
    else if (fearGreed.level == 'EXTREME_GREED') score += 20;
  }

  // 2) 코스피 등락률 기반 (±15점)
  final kospi = macroAssets.where((a) => a.symbol == 'KOSPI').firstOrNull;
  if (kospi != null) {
    if (kospi.changePercent < -1.5) score -= 15;
    else if (kospi.changePercent < -0.5) score -= 8;
    else if (kospi.changePercent > 1.5) score += 15;
    else if (kospi.changePercent > 0.5) score += 8;
  }

  // 3) 외국인+기관 수급 방향 (±15점)
  if (summary?.kospi != null) {
    final netBuy = summary!.kospi!.foreignTotal + summary.kospi!.institutionTotal;
    if (netBuy > 0) score += 15;
    else if (netBuy < 0) score -= 15;
  }

  // score → 진단 레벨
  // 0-25: 약세 🔴, 25-40: 약세주의 🟡, 40-60: 중립 ⚪, 60-75: 강세기대 🟢, 75-100: 강세 🟢
  return MarketDiagnosis(score: score.clamp(0, 100), ...);
}
```

#### ② SectorScannerSection

```
섹터별 시장 스캐너
┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐
│반도체│ │2차전│ │방산 │ │AI  │ │바이오│  ← 가로 스크롤
│+3.2%│ │-1.5%│ │+2.1%│ │-0.8%│ │+0.5%│
│외↑  │ │기↓  │ │외↑  │ │개↑  │ │기↑  │
└────┘ └────┘ └────┘ └────┘ └────┘
```

- `SizedBox(height: 120)` + `ListView.builder(scrollDirection: Axis.horizontal)`
- 각 카드: `Container(width: 100)` + 섹터명 + 등락률 + 수급 방향 아이콘
- 등락률 색상: 양수 빨강, 음수 파랑 (한국 주식 컨벤션)

#### ③ AiScanSection

```
AI 스캔 종목
┌─────────────────────────────────────────┐
│ S │ 삼성전자 (005930)     +2.3%         │
│   │ 외인 순매수 전환, 거래량 급증         │
├─────────────────────────────────────────┤
│ A │ SK하이닉스 (000660)   -1.1%         │
│   │ 기관 매도 주의, 지지선 이탈           │
└─────────────────────────────────────────┘
```

- `ListView.separated` (shrinkWrap: true, physics: NeverScrollable)
- 최대 5개 항목. 탭 시 `StockDetailScreen` 이동
- grade 뱃지 색상: S=금색, A=파랑, B=회색

#### ④ MacroSummarySection

```
거시경제 핵심                          [상세 보기 >]
┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐
│미국채  │ │달러/원│ │ WTI  │ │ VIX  │ │  금  │
│10Y    │ │      │ │      │ │      │ │      │
│4.25%  │ │1,320 │ │$72.5 │ │18.5  │ │$2,350│
│-0.03  │ │+5.2  │ │-1.2% │ │+0.8  │ │+0.3% │
└──────┘ └──────┘ └──────┘ └──────┘ └──────┘
```

- 가로 스크롤 카드 or Wrap
- `macroAssets`에서 symbol 필터: `['US10Y', 'USDKRW', 'WTI', 'VIX', 'GOLD']`
- "상세 보기" 탭 시 기존 `MacroDashboardScreen`으로 `Navigator.push`

#### ⑤ InvestorFlowSection

```
투자자 수급 요약
┌──────────┬──────────┬──────────┬──────────┐
│          │  외국인   │   기관    │   개인    │
├──────────┼──────────┼──────────┼──────────┤
│  코스피  │ -1,200억  │  +800억  │  +400억  │
│  코스닥  │  -300억   │  +150억  │  +150억  │
└──────────┴──────────┴──────────┴──────────┘
```

- `Table` 또는 `Row` + `Column` 조합
- 금액 단위: 억원 (값 / 100,000,000)
- 색상: 순매수(+) 파랑, 순매도(-) 빨강

### 5.3 MoreScreen (더보기)

```
┌─────────────────────────────────────────┐
│ 📡 AI 스캐너                    준비 중 > │
├─────────────────────────────────────────┤
│ 🔔 알림센터                          >   │
├─────────────────────────────────────────┤
│ 🗺️ 인사이트맵                   준비 중 > │
├─────────────────────────────────────────┤
│ ⏰ 가격알림                     준비 중 > │
├─────────────────────────────────────────┤
│ 📊 퀀트 스크리너                 준비 중 > │
└─────────────────────────────────────────┘
```

- `ListView` + `ListTile` 기반
- 알림센터만 `NotificationListScreen`으로 연결
- 나머지는 `SnackBar`로 "준비 중" 안내

---

## 6. HomeScreen 수정 (5탭 전환)

### 6.1 변경 내용

```dart
// 변경 전
final _pages = const [
  MacroDashboardScreen(),  // 홈
  WatchlistScreen(),
  NoteScreen(),
  MyInfoScreen(),
];

// 변경 후
final _pages = const [
  MarketHomeScreen(),      // 새 홈
  WatchlistScreen(),
  NoteScreen(),
  MoreScreen(),            // 더보기 (신규)
  MyInfoScreen(),
];
```

### 6.2 BottomNavigationBar 변경

```dart
items: const [
  BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: '홈'),
  BottomNavigationBarItem(icon: Icon(Icons.star_outline), activeIcon: Icon(Icons.star), label: '관심종목'),
  BottomNavigationBarItem(icon: Icon(Icons.edit_note_outlined), activeIcon: Icon(Icons.edit_note), label: '노트'),
  BottomNavigationBarItem(icon: Icon(Icons.apps_outlined), activeIcon: Icon(Icons.apps), label: '더보기'),
  BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: '내정보'),
],
```

### 6.3 FCM 딥링크 영향

- 기존 FCM의 `flushPendingDetail()`은 알림 상세 화면으로 직접 이동하므로 탭 인덱스에 의존하지 않음 → **영향 없음**
- 만약 탭 인덱스 기반 이동 로직이 있다면 수정 필요 (확인 결과 없음)

---

## 7. Design Tokens

| 토큰 | 값 | 용도 |
|------|-----|------|
| `primaryColor` | `#1B2E5C` | 헤더, 진단 카드 배경 |
| `accentColor` | `#FFD700` | S등급 뱃지, 강조 |
| `backgroundColor` | `#F5F5F7` | Scaffold 배경 |
| `positiveColor` | `#D32F2F` | 상승 (한국식 빨강) |
| `negativeColor` | `#1976D2` | 하락 (한국식 파랑) |
| `diagnosisGreen` | `#4CAF50` | 강세 진단 🟢 |
| `diagnosisYellow` | `#FF9800` | 약세주의 진단 🟡 |
| `diagnosisRed` | `#F44336` | 약세 진단 🔴 |
| `diagnosisGray` | `#9E9E9E` | 중립 진단 ⚪ |
| `cardRadius` | `16` | 섹션 카드 radius |
| `sectionPadding` | `16` | 섹션 간 좌우 패딩 |
| `sectionGap` | `12` | 섹션 간 상하 간격 |

---

## 8. Error Handling

### 8.1 섹션별 독립 에러 처리

각 섹션은 데이터가 null/빈 리스트일 때 자체적으로 fallback UI 표시:

| 섹션 | 에러 시 표시 |
|------|-------------|
| 한줄 진단 | "시장 데이터를 불러오는 중..." (shimmer) |
| 섹터 스캐너 | 섹션 숨김 (빈 리스트 → 렌더링 안 함) |
| AI 스캔 종목 | "스캔 결과 없음" 메시지 |
| 거시경제 | 섹션 숨김 |
| 수급 요약 | "수급 데이터 없음" 메시지 |

### 8.2 전체 로딩 실패

- 5개 API 모두 실패 시: 중앙 에러 메시지 + 재시도 버튼
- `_isLoading && 모든 데이터 null` 조건으로 판단

---

## 9. Dependencies

### 9.1 기존 패키지 (추가 없음)
- `http` — API 호출
- `flutter_secure_storage` — 인증 토큰
- `intl` — 숫자/날짜 포맷 (이미 사용 중)

### 9.2 신규 패키지
- 없음 (기존 패키지로 충분)

---

## 10. Test Plan

| ID | 테스트 | 방법 |
|----|--------|------|
| T-01 | 5탭 네비게이션 전환 | 각 탭 터치 → 화면 전환 확인 |
| T-02 | 홈 탭 5개 섹션 로딩 | 앱 실행 → 데이터 표시 확인 |
| T-03 | 한줄 진단 정확성 | Fear&Greed 극단값에서 진단 레벨 확인 |
| T-04 | Pull-to-refresh | 아래로 당김 → 전체 새로고침 |
| T-05 | 개별 API 실패 | 네트워크 차단 후 부분 로딩 확인 |
| T-06 | 더보기 → 알림센터 이동 | 알림센터 ListTile 탭 → 화면 이동 |
| T-07 | AI 종목 탭 → 상세 이동 | 종목 리스트 아이템 탭 → StockDetailScreen |
| T-08 | 거시경제 상세 보기 이동 | "상세 보기" 탭 → MacroDashboardScreen |
| T-09 | 기존 기능 회귀 | 관심종목/노트/내정보 기존 기능 정상 동작 |

---

## 11. Implementation Guide

### 11.1 구현 순서

| 순서 | 작업 | 의존성 |
|------|------|--------|
| 1 | `api_config.dart` — 신규 엔드포인트 추가 | 없음 |
| 2 | `scanner_model.dart` + `investor_model.dart` — 데이터 모델 | 없음 |
| 3 | `scanner_service.dart` + `investor_service.dart` — API 서비스 | 1, 2 |
| 4 | `market_diagnosis_card.dart` — 한줄 진단 위젯 | 없음 (모델만 import) |
| 5 | `sector_scanner_section.dart` — 섹터 스캐너 위젯 | 2 |
| 6 | `ai_scan_section.dart` — AI 스캔 종목 위젯 | 2 |
| 7 | `macro_summary_section.dart` — 거시경제 축약 위젯 | 기존 모델 |
| 8 | `investor_flow_section.dart` — 수급 요약 위젯 | 2 |
| 9 | `market_home_screen.dart` — 새 홈 탭 화면 조합 | 3~8 |
| 10 | `more_screen.dart` — 더보기 메뉴 | 없음 |
| 11 | `home_screen.dart` — 5탭 전환 | 9, 10 |

### 11.2 구현 우선순위
- **Critical Path**: 1→2→3→9→11 (데이터 흐름 완성)
- **병렬 가능**: 4, 5, 6, 7, 8 (위젯들은 독립적)
- **독립**: 10 (더보기 화면)

### 11.3 Session Guide

#### Module Map

| Module | 파일 | 설명 |
|--------|------|------|
| `module-1` | api_config + models + services | 데이터 레이어 (API + 모델 + 서비스) |
| `module-2` | 5개 위젯 | UI 레이어 (섹션 위젯들) |
| `module-3` | market_home_screen + more_screen + home_screen | 화면 조합 + 네비게이션 전환 |

#### Recommended Session Plan

| Session | Module | 예상 작업 | 검증 |
|---------|--------|----------|------|
| Session 1 | `module-1` | API 엔드포인트, 모델 3개, 서비스 2개 | API 호출 + JSON 파싱 확인 |
| Session 2 | `module-2` | 위젯 5개 구현 | 개별 위젯 렌더링 확인 |
| Session 3 | `module-3` | 홈 화면 조합 + 더보기 + 5탭 전환 | 전체 통합 테스트 |

# realtime-monitor Design

> **Feature**: 실시간 모니터링 — 관심종목 자동갱신 + 차트 실시간 스트림
> **Created**: 2026-07-13
> **Architecture**: Option C — Pragmatic Balance
> **Plan Reference**: `docs/01-plan/features/realtime-monitor.plan.md`

## Context Anchor

| Key | Value |
|-----|-------|
| **WHY** | 정적 데이터 → 새로고침 필요 → 장중 모니터링 불편. 자동 갱신 + 실시간 스트림으로 "켜놓고 싶은 앱" |
| **WHO** | 장중 시장을 모니터링하는 개인 투자자 |
| **RISK** | WebSocket 연결 안정성, STOMP 라이브러리 의존성, 장외 시간 데이터 없음 |
| **SUCCESS** | 관심종목 1분 자동갱신. 차트 실시간 토글 ON → 체결가 수신. 화면 이탈 시 자동 해제 |
| **SCOPE** | Phase 1: 관심종목 Timer + 차트 STOMP 토글. Phase 2: 관심종목 WebSocket |

---

## 1. Overview

### 1.1 설계 방향
- **Option C — Pragmatic Balance**: StompService 싱글톤 + RealtimePrice 모델만 분리
- 기존 StockDetailScreen과 WatchlistScreen에 직접 통합
- STOMP 연결 로직은 재사용 가능한 서비스로 추출

### 1.2 주요 결정사항
- STOMP 라이브러리: `stomp_dart_client` (pub.dev 인기, SockJS 지원)
- 관심종목 갱신: Timer.periodic (WebSocket보다 간단, 기존 API 재활용)
- 차트 실시간: STOMP WebSocket (틱 단위 체결가)
- 생명주기: WidgetsBindingObserver (별도 유틸 불필요)

---

## 2. File Structure

```
lib/
├── config/
│   └── api_config.dart                         ← 수정: streamConnect 엔드포인트
├── models/
│   └── realtime_price_model.dart               ← 신규: RealtimePrice 체결가 모델
├── services/
│   └── stomp_service.dart                      ← 신규: STOMP WebSocket 싱글톤
├── screens/
│   ├── stock/
│   │   └── stock_detail_screen.dart            ← 수정: 실시간 토글 + 가격 헤더
│   └── watchlist/
│       └── watchlist_screen.dart               ← 수정: 1분 Timer + AppLifecycle
└── pubspec.yaml                                ← 수정: stomp_dart_client 추가
```

| 파일 | 신규/수정 | 예상 LOC |
|------|----------|---------|
| `realtime_price_model.dart` | 신규 | ~30 |
| `stomp_service.dart` | 신규 | ~120 |
| `stock_detail_screen.dart` | 수정 | +80 |
| `watchlist_screen.dart` | 수정 | +40 |
| `api_config.dart` | 수정 | +3 |
| `pubspec.yaml` | 수정 | +1 |
| **합계** | | **~270** |

---

## 3. Data Model

### 3.1 RealtimePrice (`realtime_price_model.dart`)

```dart
class RealtimePrice {
  final double curPrice;      // 현재가
  final double diffPrice;     // 전일대비
  final double diffRate;      // 등락률 (%)
  final int volume;           // 체결량
  final int cumVolume;        // 누적거래량
  final String tradeTime;     // 체결시간 (HHMMSS)
  final DateTime receivedAt;  // 수신 시각

  factory RealtimePrice.fromJson(Map<String, dynamic> json);
}
```

**웹 STOMP 메시지 형식** (`/topic/kiwoom/price/{code}`):
```json
{
  "cur_price": 76800,
  "diff_price": 1200,
  "diff_rate": 1.58,
  "volume": 500,
  "cum_volume": 1234567,
  "trade_time": "100530"
}
```

---

## 4. StompService 설계

### 4.1 싱글톤 구조

```dart
class StompService {
  static final StompService _instance = StompService._();
  factory StompService() => _instance;
  StompService._();

  StompClient? _client;
  final Map<String, StompUnsubscribe> _subscriptions = {};
  bool _isConnected = false;
  int _retryCount = 0;
  static const _maxRetries = 3;
}
```

### 4.2 메서드

| 메서드 | 역할 | 반환 |
|--------|------|------|
| `connect()` | STOMP 연결 시작 + streamConnect REST 호출 | `Future<bool>` |
| `subscribe(stockCode, onPrice)` | 체결가 토픽 구독 | `void` |
| `unsubscribe(stockCode)` | 특정 종목 구독 해제 | `void` |
| `unsubscribeAll()` | 모든 구독 해제 (백그라운드 전환 시) |`void` |
| `disconnect()` | STOMP 연결 종료 | `void` |
| `isConnected` | 연결 상태 getter | `bool` |

### 4.3 연결 흐름

```
1. connect() 호출
   ├─ POST /api/IV/quant/screener/streamConnect (서버↔키움 연결 확인)
   └─ StompClient.activate()
       ├─ webSocketFactory: SockJS({BASE_URL}/ws)
       ├─ onConnect → _isConnected = true, _retryCount = 0
       ├─ onDisconnect → _isConnected = false
       └─ onStompError → _retryConnect() (3초 후, 최대 3회)

2. subscribe(stockCode, onPrice) 호출
   ├─ if (!_isConnected) → connect() 먼저
   └─ client.subscribe('/topic/kiwoom/price/{stockCode}')
       └─ msg → RealtimePrice.fromJson(jsonDecode(msg.body)) → onPrice(price)

3. unsubscribe(stockCode) 호출
   ├─ _subscriptions[stockCode]?.call() (STOMP unsubscribe)
   └─ _subscriptions.remove(stockCode)
   └─ if (_subscriptions.isEmpty) → disconnect() (마지막 구독 해제 시)
```

### 4.4 STOMP 설정

```dart
StompClient(
  config: StompConfig.sockJS(
    url: '${ApiConfig.baseUrl}/ws',
    reconnectDelay: Duration(seconds: 3),
    stompConnectHeaders: {},
    webSocketConnectHeaders: {},
  ),
);
```

- `stomp_dart_client` 패키지의 `StompConfig.sockJS()` 사용
- `reconnectDelay: 3초` — 자체 재연결 메커니즘

---

## 5. StockDetailScreen 수정

### 5.1 실시간 토글 UI

기존 가격 표시 영역에 토글 버튼 추가:

```
┌──────────────────────────────────────────────┐
│ 삼성전자 (005930)                              │
│                                                │
│  76,800원  +1,200 (+1.58%)     [🔴 실시간] 토글│
│  거래량: 1,234,567                             │
└──────────────────────────────────────────────┘
```

- 토글 OFF: 기존 정적 가격 (`widget.currentPrice`, `widget.changeRate`)
- 토글 ON: `StompService().subscribe(stockCode, _onRealtimePrice)` → 가격 실시간 갱신
- 실시간 뱃지: 빨간 원 깜빡이는 애니메이션 (`AnimatedOpacity` 0.3↔1.0, 1초 주기)
- 가격 변경 시: 배경 하이라이트 (`AnimatedContainer` 200ms 페이드)

### 5.2 상태 추가

```dart
// 실시간 모니터링 상태
bool _isRealtimeOn = false;
RealtimePrice? _realtimePrice;
```

### 5.3 생명주기

```dart
@override
void dispose() {
  if (_isRealtimeOn) {
    StompService().unsubscribe(widget.stockCode);
  }
  super.dispose();
}
```

---

## 6. WatchlistScreen 수정

### 6.1 1분 자동 갱신

```dart
Timer? _autoRefreshTimer;

@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addObserver(this);  // AppLifecycle
  _loadData();
  _startAutoRefresh();
}

void _startAutoRefresh() {
  _autoRefreshTimer?.cancel();
  _autoRefreshTimer = Timer.periodic(
    const Duration(minutes: 1),
    (_) => _loadData(),
  );
}

@override
void dispose() {
  _autoRefreshTimer?.cancel();
  WidgetsBinding.instance.removeObserver(this);
  super.dispose();
}
```

### 6.2 AppLifecycle 관리

```dart
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.paused) {
    _autoRefreshTimer?.cancel();
  } else if (state == AppLifecycleState.resumed) {
    _loadData();        // 즉시 갱신
    _startAutoRefresh(); // Timer 재시작
  }
}
```

### 6.3 갱신 인디케이터

상단 요약 카드 옆에 작은 "자동갱신" 뱃지:

```
┌────────────────────────────────────────┐
│ 평균수익률  │  종목수  │  상승/하락     │
│  +1.23%    │   12    │   7 / 5       │
│                        [🔄 자동갱신 ON] │
└────────────────────────────────────────┘
```

---

## 7. API Config 추가

```dart
// 키움 스트림
static const String streamConnect = '/api/IV/quant/screener/streamConnect';
```

---

## 8. Dependencies

### 8.1 신규 패키지

```yaml
# pubspec.yaml
dependencies:
  stomp_dart_client: ^2.0.0
```

### 8.2 기존 패키지 (변경 없음)
- `http`, `intl`, `syncfusion_flutter_charts` 등

---

## 9. Error Handling

| 상황 | 처리 |
|------|------|
| STOMP 연결 실패 | 토글 자동 OFF + SnackBar "실시간 연결 실패" |
| STOMP 연결 중 끊김 | 자동 재연결 (3초, 최대 3회). 3회 실패 시 토글 OFF |
| streamConnect REST 실패 | 연결 시도는 하되, 실패해도 STOMP 구독은 시도 (서버가 이미 연결 상태일 수 있음) |
| 장외 시간 데이터 없음 | 토글 ON 상태 유지, 데이터 없으면 "장외 시간" 메시지 표시 |
| Timer 중 API 실패 | 조용히 스킵 (다음 주기에 재시도) |

---

## 10. Test Plan

| ID | 테스트 | 방법 |
|----|--------|------|
| T-01 | STOMP 연결 성공 | 앱에서 토글 ON → 서버 로그 확인 |
| T-02 | 실시간 가격 수신 | 장중 토글 ON → 가격 변동 확인 |
| T-03 | 토글 OFF → 구독 해제 | 토글 OFF → 서버 구독 목록 확인 |
| T-04 | 화면 이탈 → 구독 해제 | 뒤로가기 → 구독 해제 확인 |
| T-05 | 관심종목 1분 갱신 | 화면 열고 1분 대기 → 가격 변화 |
| T-06 | 백그라운드 → 포그라운드 | 앱 최소화 → 복원 → Timer 재시작 확인 |
| T-07 | 연결 실패 → 토글 OFF | 네트워크 끊김 → 토글 자동 OFF + 에러 메시지 |
| T-08 | 기존 기능 회귀 | 토글 OFF 상태에서 차트/관심종목 기존 동작 확인 |

---

## 11. Implementation Guide

### 11.1 구현 순서

| 순서 | 작업 | 의존성 |
|------|------|--------|
| 1 | `pubspec.yaml` — `stomp_dart_client` 추가 + `flutter pub get` | 없음 |
| 2 | `api_config.dart` — streamConnect 엔드포인트 추가 | 없음 |
| 3 | `realtime_price_model.dart` — 데이터 모델 | 없음 |
| 4 | `stomp_service.dart` — STOMP 싱글톤 서비스 | 1, 2, 3 |
| 5 | `stock_detail_screen.dart` — 실시간 토글 + 가격 헤더 | 4 |
| 6 | `watchlist_screen.dart` — 1분 Timer + AppLifecycle | 없음 (독립) |

### 11.2 구현 우선순위
- **Critical Path**: 1→2→3→4→5 (STOMP 연결 → 차트 실시간)
- **독립**: 6 (관심종목 Timer, STOMP 불필요)

### 11.3 Session Guide

#### Module Map

| Module | 파일 | 설명 |
|--------|------|------|
| `module-1` | pubspec + api_config + model + stomp_service | STOMP 인프라 |
| `module-2` | stock_detail_screen | 차트 실시간 토글 UI |
| `module-3` | watchlist_screen | 관심종목 1분 자동갱신 |

#### Recommended Session Plan

| Session | Module | 예상 작업 | 검증 |
|---------|--------|----------|------|
| Session 1 | `module-1` + `module-2` | STOMP 서비스 + 차트 실시간 토글 | 장중 체결가 수신 확인 |
| Session 2 | `module-3` | 관심종목 Timer + AppLifecycle | 1분 갱신 + 백그라운드 테스트 |

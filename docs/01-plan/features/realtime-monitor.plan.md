# realtime-monitor Plan

> **Feature**: 실시간 모니터링 — 관심종목 자동갱신 + 차트 실시간 스트림
> **Created**: 2026-07-13
> **Phase**: Plan
> **Priority**: High

## Executive Summary

| 관점 | 설명 |
|------|------|
| **Problem** | 관심종목과 차트 화면의 가격이 정적 — 새로고침해야만 갱신되어 장중 모니터링 불편 |
| **Solution** | 관심종목: 1분 자동 갱신 + 수동 리프레시. 차트 상세: 토글로 STOMP WebSocket 실시간 체결가 스트림 |
| **기능 UX 효과** | 관심종목 화면만 열어두면 1분마다 가격 자동 갱신. 차트에서 실시간 토글 ON하면 틱 단위로 가격/등락률/거래량 실시간 반영 |
| **Core Value** | 장중에 앱을 켜놓고 싶게 만드는 핵심 기능 — 실시간 데이터가 앱의 존재 이유 |

## Context Anchor

| Key | Value |
|-----|-------|
| **WHY** | 정적 데이터 → 새로고침 필요 → 장중 모니터링 불편. 자동 갱신 + 실시간 스트림으로 "켜놓고 싶은 앱" |
| **WHO** | 장중 시장을 모니터링하는 개인 투자자 |
| **RISK** | WebSocket 연결 안정성 (백그라운드 전환, 네트워크 끊김). STOMP 라이브러리 의존성 추가 |
| **SUCCESS** | 관심종목 1분 자동 갱신 동작. 차트에서 실시간 토글 ON 시 체결가 수신. 화면 이탈 시 자동 해제 |
| **SCOPE** | Phase 1: 관심종목 자동갱신 + 차트 실시간 토글. Phase 2: 관심종목 리스트도 WebSocket 연결 |

---

## 1. 배경 및 목적

### 1.1 현재 상태
- **관심종목 (WatchlistScreen)**: 진입 시 1회 로딩. Pull-to-refresh로만 갱신
- **차트 상세 (StockDetailScreen)**: 진입 시 일봉/주봉 차트 1회 로딩. 실시간 데이터 없음
- **기존 인프라**: 백엔드에 Kiwoom STOMP WebSocket 서버 구축 완료 (웹에서 사용 중)

### 1.2 목표
- 관심종목: **1분 주기 자동 갱신** + 수동 리프레시 버튼
- 차트 상세: **토글 ON 시 STOMP WebSocket으로 실시간 체결가** 수신
- 화면 이탈/앱 백그라운드 시 **자동 구독 해제** (리소스 관리)

### 1.3 기존 인프라 (웹 참고)
- **WebSocket 엔드포인트**: `{BASE_URL}/ws` (SockJS + STOMP)
- **스트림 시작**: `POST /api/IV/quant/screener/streamConnect` (서버↔키움 연결)
- **구독 토픽**: `/topic/kiwoom/price/{stockCode}` (체결가), `/topic/kiwoom/orderbook/{stockCode}` (호가)
- **체결가 필드**: `cur_price`, `diff_price`, `diff_rate`, `volume`, `cum_volume`, `trade_time`

---

## 2. 요구사항

### 2.1 기능 요구사항

#### FR-01: 관심종목 1분 자동 갱신
- WatchlistScreen 진입 시 `Timer.periodic(Duration(minutes: 1))` 시작
- 기존 `WatchlistService.getStocks()` + `getReturns()` API 재호출
- 화면 이탈 시 Timer 해제 (`dispose`)
- 갱신 중 표시: 상단에 "갱신 중..." 인디케이터 (침습적이지 않게)
- 수동 리프레시: 기존 Pull-to-refresh 유지 + Timer 리셋

#### FR-02: 차트 실시간 토글
- StockDetailScreen 상단 가격 영역에 **실시간 토글 버튼** 추가
- 토글 OFF (기본): 기존처럼 정적 데이터
- 토글 ON: STOMP WebSocket 연결 → 해당 종목 구독 → 가격/등락률/거래량 실시간 갱신
- 토글 ON 시 가격 영역에 **실시간 뱃지** 표시 (빨간 점 깜빡임)
- 가격 변경 시 **하이라이트 애니메이션** (잠깐 배경색 반짝)

#### FR-03: STOMP WebSocket 서비스
- `StompService` 싱글톤 — 앱 전체에서 하나의 STOMP 연결 관리
- `connect()`: SockJS + STOMP 연결
- `subscribe(stockCode, callback)`: 체결가 구독
- `unsubscribe(stockCode)`: 구독 해제
- `disconnect()`: 연결 종료
- 자동 재연결: 연결 끊김 시 3초 후 재시도 (최대 3회)

#### FR-04: 생명주기 관리
- 화면 이탈 (`dispose`): 해당 종목 구독 해제
- 앱 백그라운드 (`AppLifecycleState.paused`): 모든 구독 일시 해제
- 앱 포그라운드 (`AppLifecycleState.resumed`): 활성 구독 복원
- 관심종목 Timer도 동일하게 백그라운드에서 중지

### 2.2 비기능 요구사항

| ID | 요구사항 | 기준 |
|----|---------|------|
| NFR-01 | WebSocket 연결 시간 | 3초 이내 |
| NFR-02 | 실시간 데이터 수신 지연 | < 500ms (네트워크 환경 의존) |
| NFR-03 | 배터리 영향 | 백그라운드에서 WebSocket/Timer 해제 |
| NFR-04 | 기존 기능 보존 | 토글 OFF 시 기존 동작 100% 동일 |

---

## 3. 사용할 API / 프로토콜

| 용도 | 엔드포인트 | 프로토콜 | 상태 |
|------|-----------|---------|------|
| 스트림 연결 시작 | `POST /api/IV/quant/screener/streamConnect` | REST | 웹에서 사용 중 |
| WebSocket | `{BASE_URL}/ws` | SockJS + STOMP | 웹에서 사용 중 |
| 체결가 구독 | `/topic/kiwoom/price/{stockCode}` | STOMP 토픽 | 웹에서 사용 중 |
| 관심종목 갱신 | 기존 watchlist API | REST | ✅ 앱에서 사용 중 |

---

## 4. 성공 기준 (Success Criteria)

| ID | 기준 | 측정 방법 |
|----|------|----------|
| SC-01 | 관심종목 화면에서 1분마다 가격 자동 갱신 | 1분 대기 후 가격 변화 확인 |
| SC-02 | 차트에서 실시간 토글 ON → 체결가 수신 시작 | 장중 테스트로 가격 변동 확인 |
| SC-03 | 토글 OFF → WebSocket 구독 해제 | 서버 로그에서 구독 해제 확인 |
| SC-04 | 화면 이탈 시 자동 정리 | dispose 후 메모리 누수 없음 |
| SC-05 | 앱 백그라운드 → 포그라운드 복원 | 백그라운드 갔다 돌아와도 정상 동작 |
| SC-06 | 토글 OFF 시 기존 동작 100% 동일 | 실시간 기능 비활성화 상태에서 회귀 테스트 |

---

## 5. 리스크 및 완화

| 리스크 | 영향 | 완화 |
|--------|------|------|
| Flutter STOMP 라이브러리 안정성 | WebSocket 연결 실패 | `stomp_dart_client` 패키지 검증 (pub.dev 3K+ likes) |
| 장외 시간 스트림 데이터 없음 | 토글 ON해도 데이터 안 옴 | 장외 시간 안내 메시지 + 토글 비활성화 |
| 백그라운드에서 WebSocket 끊김 | 포그라운드 복원 시 누락 | AppLifecycle 감지 + 자동 재연결 |
| 서버 스트림 미시작 상태 | 구독해도 데이터 없음 | `streamConnect` REST 호출로 서버 스트림 확인/시작 |

---

## 6. 구현 범위

### 신규 파일

| 파일 | 역할 |
|------|------|
| `lib/services/stomp_service.dart` | STOMP WebSocket 싱글톤 서비스 |
| `lib/models/realtime_price_model.dart` | 실시간 체결가 데이터 모델 |

### 수정 파일

| 파일 | 작업 |
|------|------|
| `lib/screens/stock/stock_detail_screen.dart` | 실시간 토글 + 가격 실시간 갱신 UI |
| `lib/screens/watchlist/watchlist_screen.dart` | 1분 자동 갱신 Timer + AppLifecycle |
| `lib/config/api_config.dart` | streamConnect 엔드포인트 추가 |
| `pubspec.yaml` | `stomp_dart_client` 패키지 추가 |

### 패키지 추가

| 패키지 | 용도 |
|--------|------|
| `stomp_dart_client` | STOMP over WebSocket 클라이언트 |

---

## 7. 후속 계획

| Phase | Feature | 설명 |
|-------|---------|------|
| Phase 2 | watchlist-websocket | 관심종목 리스트도 WebSocket으로 실시간 갱신 (Timer 대체) |
| Phase 2 | multi-stock-monitor | 여러 종목 동시 WebSocket 구독 (모니터링 전용 화면) |

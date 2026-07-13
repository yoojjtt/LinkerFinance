# home-tab-revamp Plan

> **Feature**: 홈 탭 개편 — 시장 종합 진단 + 5탭 네비게이션 전환
> **Created**: 2026-07-13
> **Phase**: Plan
> **Priority**: High

## Executive Summary

| 관점 | 설명 |
|------|------|
| **Problem** | 현재 홈 탭은 거시경제 자산 카드만 나열하여 "그래서 오늘 시장이 좋은지 나쁜지" 즉각적 판단 불가. 사용자가 데이터를 직접 해석해야 하므로 앱을 열 동기가 약함 |
| **Solution** | 홈 탭을 "오늘의 시장 한눈에" 대시보드로 개편. 한줄 진단 → 시장 스캐너 → AI 스캔 종목 → 거시경제 → 투자자 수급 5개 섹션 스크롤 구조. 4탭→5탭 전환(더보기 탭 추가) |
| **기능 UX 효과** | 앱 오픈 3초 내 시장 방향성 파악 가능. 섹터별 핫/콜드 시각화로 투자 아이디어 즉시 발견. 수급 요약으로 외인/기관 동향 확인 |
| **Core Value** | 매일 열고 싶은 앱 — "한줄 진단"이 킬러 피처로 앱 재방문율(DAU) 극대화 |

## Context Anchor

| Key | Value |
|-----|-------|
| **WHY** | 현재 앱은 데이터 나열형 → 사용자가 직접 해석 필요 → 앱 열 이유 부족. "앱이 시장을 해석해주는" 경험으로 전환하여 실용성과 매력 확보 |
| **WHO** | 개인 투자자 (한국 주식, 매일 시장 체크, 중급 이상) |
| **RISK** | 백엔드 API 중 scanner/investor 엔드포인트가 모바일에서 첫 사용 — 응답 형식 검증 필요. Fear&Greed + 수급 + 스캐너 종합 진단 로직은 클라이언트 계산 |
| **SUCCESS** | 홈 탭에서 3초 내 시장 방향 파악. 5개 섹션 모두 데이터 로딩 성공. 5탭 네비게이션 정상 작동 |
| **SCOPE** | Phase 1: 홈 탭 + 5탭 전환 + 더보기 탭 껍데기. Phase 2+: 관심종목 강화, 노트 통계, 더보기 메뉴 구현 |

---

## 1. 배경 및 목적

### 1.1 현재 상태
- **홈 탭**: MacroDashboardScreen — 거시경제 자산 카드 그리드 + 히스토리 차트 + Fear&Greed 게이지
- **네비게이션**: 4탭 (홈/관심종목/노트/내정보)
- **문제**: 데이터는 풍부하나 "해석"이 없음. 사용자가 수치를 보고 스스로 판단해야 함

### 1.2 목표
- 홈 탭을 **"오늘의 시장 한눈에"** 대시보드로 재구성
- 앱이 시장 데이터를 **종합 해석**하여 한줄 진단 제공
- 실시간 시장 스캐너(ETF/ETN) + AI 스캔 종목 + 투자자 수급 통합
- 5탭 네비게이션 전환으로 향후 기능 확장(AI스캐너, 인사이트맵 등) 준비

### 1.3 참고 소스
- **웹 클라이언트**: `linker-biz-manager/src/app/finance-quant/` (MarketScanner, InvestorFlow, MacroDashboard)
- **기존 앱**: `lib/screens/macro/` (거시경제 대시보드 — 부분 재활용)

---

## 2. 요구사항

### 2.1 기능 요구사항

#### FR-01: 5탭 네비게이션 전환
- 현재 4탭 → 5탭: **홈 / 관심종목 / 노트 / 더보기 / 내정보**
- 더보기 탭: 메뉴 리스트 화면 (껍데기만, 각 메뉴 상세는 Phase 2+)
- 더보기 메뉴 항목: AI 스캐너, 알림센터, 인사이트맵, 가격알림, 퀀트 스크리너

#### FR-02: 한줄 진단 섹션 (킬러 피처)
- Fear&Greed 지수 + 투자자 수급 방향 + 주요 지수 등락을 종합하여 **한줄 시장 진단** 생성
- 예: "🟡 약세 주의 — 외인 매도 우세, Fear&Greed 35(공포)"
- 진단 레벨: 강세 🟢 / 중립 ⚪ / 약세 주의 🟡 / 약세 🔴
- 진단 로직 (클라이언트 계산):
  - Fear&Greed 점수 구간 (0-25 극도공포, 25-45 공포, 45-55 중립, 55-75 탐욕, 75-100 극도탐욕)
  - 코스피/코스닥 등락률
  - 외국인+기관 순매수 합산 방향
- 하단에 코스피/코스닥 현재가 + 등락률 표시

#### FR-03: 실시간 시장 스캐너 섹션
- **가로 스크롤 카드** 형태로 섹터별 ETF/ETN 등락률 표시
- API: `GET /api/IV/quant/investor/sector-flow` → 섹터별 수급 + 등락
- 각 카드: 섹터명 + 대표 ETF 등락률 + 수급 방향 아이콘(↑↓)
- 탭하면 해당 섹터 종목 리스트 (Phase 2에서 상세 구현, Phase 1은 카드만)

#### FR-04: AI 스캔 종목 섹션
- AI가 감지한 급등/급락/이상신호 종목 리스트 (3~5개)
- API: `GET /api/IV/scanner/results?days=1&limit=5`
- 각 항목: 종목명 + 등락률 + AI 코멘트 한줄
- 탭하면 StockDetailScreen으로 이동

#### FR-05: 거시경제 핵심 지표 섹션 (기존 축약)
- 기존 MacroDashboard의 핵심 지표만 추출하여 **컴팩트 카드** 형태
- 미국채 10Y, 달러/원, 유가(WTI), VIX, 금 — 5개 핵심 지표
- API: 기존 `GET /api/IV/quant/macro/current` 재활용
- 카드 탭 시 기존 MacroDashboard 전체 뷰로 이동 (상세 보기)

#### FR-06: 투자자 수급 요약 섹션
- 코스피/코스닥 외국인·기관·개인 순매수 금액 요약
- API: `GET /api/IV/quant/investor/market-summary`
- 컴팩트 테이블 형태: 시장 | 외국인 | 기관 | 개인
- 색상 코딩: 순매수 파랑, 순매도 빨강

#### FR-07: 더보기 탭 (메뉴 껍데기)
- 메뉴 리스트 화면 (ListTile 기반)
- 각 메뉴 탭 시 "준비 중" 안내 또는 기존 화면 연결
  - **알림센터**: 기존 NotificationListScreen 연결 (AppBar에서 이동)
  - **AI 스캐너**: "준비 중" placeholder
  - **인사이트맵**: "준비 중" placeholder
  - **가격알림**: "준비 중" placeholder
  - **퀀트 스크리너**: "준비 중" placeholder

### 2.2 비기능 요구사항

| ID | 요구사항 | 기준 |
|----|---------|------|
| NFR-01 | 홈 탭 초기 로딩 | 3초 이내 (병렬 API 호출) |
| NFR-02 | 에러 핸들링 | 각 섹션 독립 로딩 — 하나 실패해도 나머지 표시 |
| NFR-03 | Pull-to-refresh | 전체 섹션 새로고침 |
| NFR-04 | 기존 기능 보존 | 관심종목/노트/내정보 기존 기능 그대로 유지 |

---

## 3. 사용할 API 엔드포인트

| 섹션 | API | 상태 |
|------|-----|------|
| 한줄 진단 | `GET /api/IV/quant/macro/fear-greed` | ✅ 기존 사용 중 |
| 한줄 진단 | `GET /api/IV/quant/macro/current` | ✅ 기존 사용 중 |
| 시장 스캐너 | `GET /api/IV/quant/investor/sector-flow` | 🆕 신규 연동 |
| AI 스캔 종목 | `GET /api/IV/scanner/results` | 🆕 신규 연동 |
| 거시경제 | `GET /api/IV/quant/macro/current` | ✅ 기존 사용 중 |
| 투자자 수급 | `GET /api/IV/quant/investor/market-summary` | 🆕 신규 연동 |

---

## 4. 성공 기준 (Success Criteria)

| ID | 기준 | 측정 방법 |
|----|------|----------|
| SC-01 | 홈 탭 오픈 시 한줄 진단이 3초 내 표시됨 | 수동 테스트 |
| SC-02 | 5개 섹션 모두 데이터 정상 로딩 및 표시 | 각 섹션 데이터 확인 |
| SC-03 | 5탭 네비게이션 정상 전환 | 각 탭 이동 테스트 |
| SC-04 | 더보기 탭에서 알림센터 진입 가능 | 알림센터 화면 이동 확인 |
| SC-05 | 기존 관심종목/노트/내정보 기능 깨지지 않음 | 기존 기능 회귀 테스트 |
| SC-06 | Pull-to-refresh로 전체 섹션 새로고침 | RefreshIndicator 동작 확인 |
| SC-07 | 개별 섹션 API 실패 시 다른 섹션 정상 표시 | 네트워크 에러 시뮬레이션 |

---

## 5. 리스크 및 완화

| 리스크 | 영향 | 완화 |
|--------|------|------|
| `sector-flow`, `scanner/results`, `investor/market-summary` API가 모바일에서 첫 사용 — 응답 형식 다를 수 있음 | 파싱 실패 | 웹 API 코드에서 응답 구조 확인 후 모델 작성. 각 섹션 독립 에러 처리 |
| 5개 API 동시 호출 시 초기 로딩 지연 | UX 저하 | Future.wait 병렬 호출 + 섹션별 Shimmer 로딩 |
| 한줄 진단 로직의 정확성 | 잘못된 시그널 | 단순 규칙 기반으로 시작, 추후 백엔드 AI 진단 API로 교체 가능 |
| 5탭 전환 시 기존 화면 인덱스 변경 | 기존 딥링크/FCM 탭 이동 깨짐 | FCM 알림 탭 이동 로직 업데이트 |

---

## 6. 구현 범위 (Phase 1 Only)

### 변경 파일

| 파일 | 작업 |
|------|------|
| `lib/screens/home_screen.dart` | 4탭→5탭 전환, 더보기 탭 추가 |
| `lib/screens/home/market_home_screen.dart` | **신규** — 새 홈 탭 화면 (5개 섹션 스크롤) |
| `lib/screens/home/widgets/` | **신규** — 한줄진단, 스캐너카드, AI종목, 거시경제축약, 수급요약 위젯 |
| `lib/screens/more/more_screen.dart` | **신규** — 더보기 탭 메뉴 화면 |
| `lib/services/scanner_service.dart` | **신규** — 스캐너 API 연동 |
| `lib/services/investor_service.dart` | **신규** — 투자자 수급 API 연동 |
| `lib/models/scanner_model.dart` | **신규** — 스캐너 결과 모델 |
| `lib/models/investor_model.dart` | **신규** — 투자자 수급 모델 |
| `lib/config/api_config.dart` | 신규 API 엔드포인트 추가 |

### 재활용 파일

| 파일 | 내용 |
|------|------|
| `lib/services/macro_service.dart` | Fear&Greed, macro/current 기존 API 그대로 사용 |
| `lib/models/macro_asset_model.dart` | FearGreedData, MacroAsset 모델 재활용 |
| `lib/screens/macro/macro_dashboard_screen.dart` | 거시경제 상세 보기로 네비게이션 연결 |

---

## 7. 후속 Plan (Phase 2+)

| Phase | Feature | 설명 |
|-------|---------|------|
| Phase 2 | watchlist-enhancement | 관심종목 미니차트 확장 + 실시간 모니터링 모드 |
| Phase 3 | note-analytics | 노트 탭 매매 통계 대시보드 + AI 복기 요약 |
| Phase 4 | more-menu-features | 더보기 메뉴 각 기능 구현 (AI스캐너, 인사이트맵, 가격알림, 퀀트스크리너) |

# Plan: 거시경제 대시보드 (macro-dashboard)

> Feature: macro-dashboard
> Created: 2026-05-31
> Status: Draft
> Level: Dynamic

---

## Executive Summary

| 항목 | 내용 |
|------|------|
| Feature | 거시경제 대시보드 (홈 화면) |
| 생성일 | 2026-05-31 |
| 예상 기간 | 3~4일 |

| 관점 | 내용 |
|------|------|
| **Problem** | 로그인 후 홈 화면이 placeholder 상태로 아무 정보가 없어 앱의 핵심 가치를 제공하지 못한다 |
| **Solution** | 22개 글로벌 매크로 자산의 실시간 데이터, 시장 심리 게이지, 위험도 평가, 크로스시그널을 제공하는 대시보드를 구현한다 |
| **Function UX Effect** | 앱을 열면 즉시 글로벌 시장 상황을 한눈에 파악하고, 카테고리별 필터와 자산 상세 차트로 세부 분석이 가능하다 |
| **Core Value** | 투자자가 매일 가장 먼저 확인하는 '시장 온도계' — 앱 진입 후 첫 화면에서 투자 판단의 기초 정보를 제공한다 |

---

## Context Anchor

| 항목 | 내용 |
|------|------|
| **WHY** | HomeScreen 홈 탭이 빈 placeholder 상태. 재무 앱의 첫인상이자 핵심 가치를 보여줄 화면이 필요하다 |
| **WHO** | LinkerBiz 관리자 중 주식/재무 담당자 — 매일 시장 상황을 확인하는 사용자 |
| **RISK** | API 서버 부하 (22개 자산 동시 조회), 실시간 데이터 지연, 모바일 화면에 정보 과밀 |
| **SUCCESS** | 홈 화면에서 시장 심리 게이지 + 자산 카드 그리드 정상 표시, 카테고리 필터, 자산 선택 시 히스토리 차트 표시 |
| **SCOPE** | API 6개 연동, 22개 자산 모니터링, 시장 심리 게이지, 카테고리 필터, 위험도 평가, 크로스시그널, 히스토리 차트 |

---

## 1. 배경 및 목적

### 1.1 현재 상태
- HomeScreen에 3탭 BottomNavigationBar 구현 완료 (홈/Finance/내정보)
- 홈 탭은 `_HomePlaceholder` 위젯 — "추후 기능이 추가될 예정입니다" 텍스트만 표시
- 웹 클라이언트(`linker-biz-manager`)에 MacroDashboard.js (717줄)로 동일 기능 구현 완료
- 백엔드 API (`/api/IV/quant/macro/*`) 6개 엔드포인트 운영 중

### 1.2 목적
홈 탭의 placeholder를 거시경제 대시보드로 교체하여 앱의 핵심 가치를 제공한다.
웹 클라이언트의 MacroDashboard를 모바일에 맞게 재구성한다.

---

## 2. 요구사항

### 2.1 기능 요구사항

#### FR-01: 시장 심리 게이지 섹션
- 시장 신호 카드 (매수 유리 / 중립 / 매수 주의)
- 공포/탐욕 지수 카드 (VIX 기반)
- 장단기 금리차 카드 (10Y-2Y, 경기침체 경고)
- 신용/예탁 비율 카드 (레버리지 과열 판단)
- 빠른 지표 카드: WTI, USDKRW, GOLD, COPPER

#### FR-02: 카테고리 필터
- 9개 카테고리 필터 칩: 전체/지수/선물/환율/채권/변동성/암호화폐/원자재/투자심리
- 선택 시 해당 카테고리 자산만 표시
- 카테고리별 해석 텍스트 표시

#### FR-03: 자산 카드 그리드
- 22개 글로벌 매크로 자산 카드 (이름, 심볼, 현재가, 등락률, 위험도 뱃지)
- 등락에 따른 색상 (상승=빨강, 하락=파랑)
- 위험도 평가 뱃지 (안전/주의/경고/위험)

#### FR-04: 히스토리 차트
- 자산 카드 터치 시 하단에 히스토리 차트 표시 (fl_chart AreaChart)
- 기간 선택: 1주, 1개월, 3개월, 6개월, 1년
- 고가/저가/현재가 통계

#### FR-05: 크로스시그널
- 전체 카테고리 선택 시 다중 자산 상관관계 시그널 표시
- VIX+금리차, 달러+유가, 금+채권, 비트코인 변동성 등 조합 분석
- 시그널 유형: positive/negative/warning/opportunity/neutral

#### FR-06: 새로고침
- Pull-to-refresh로 최신 데이터 갱신
- 캐시 데이터 우선 로드 (빠른 초기 표시) + 실시간 데이터 갱신 옵션

### 2.2 비기능 요구사항

| 항목 | 기준 |
|------|------|
| 성능 | 캐시 데이터로 1초 내 초기 화면 표시, 실시간은 별도 갱신 |
| UX | 스크롤 가능한 대시보드, 카드 터치 인터랙션, 로딩 인디케이터 |
| 데이터 | 22개 자산 × 9 카테고리, API 6개 엔드포인트 |
| 차트 | fl_chart 패키지 사용 (AreaChart) |

---

## 3. 기술 스택

### 3.1 추가 패키지

| 패키지 | 용도 |
|--------|------|
| `fl_chart` | 히스토리 차트 (Area Chart) |
| `intl` | 숫자/날짜 포맷팅 |

### 3.2 프로젝트 구조 (신규/수정 파일)

```
lib/
├── config/
│   └── api_config.dart                    # [수정] macro API 엔드포인트 6개 추가
├── models/
│   └── macro_asset_model.dart             # [신규] 매크로 자산 데이터 모델
├── services/
│   └── macro_service.dart                 # [신규] 매크로 API 호출 서비스
├── screens/
│   ├── home_screen.dart                   # [수정] _HomePlaceholder → MacroDashboard
│   └── macro/
│       ├── macro_dashboard_screen.dart    # [신규] 대시보드 메인 화면
│       ├── sentiment_gauge_section.dart   # [신규] 시장 심리 게이지
│       ├── category_filter.dart           # [신규] 카테고리 필터 칩
│       ├── asset_card_grid.dart           # [신규] 자산 카드 그리드
│       ├── asset_history_chart.dart       # [신규] 히스토리 차트
│       └── cross_signal_section.dart      # [신규] 크로스시그널
└── utils/
    └── macro_utils.dart                   # [신규] 위험도 평가, 시그널 생성 로직
```

---

## 4. API 매핑

| 기능 | Method | Endpoint | 설명 |
|------|--------|----------|------|
| 캐시 데이터 | GET | `/api/IV/quant/macro/latest` | 최근 캐시 데이터 (빠른 로드) |
| 실시간 데이터 | GET | `/api/IV/quant/macro/current?category=` | Yahoo 실시간 (카테고리 필터) |
| 히스토리 | GET | `/api/IV/quant/macro/history?symbol=&period=` | 자산별 과거 데이터 |
| 금리차 | GET | `/api/IV/quant/macro/yield-spread` | 10Y-2Y 금리차 |
| 공포/탐욕 | GET | `/api/IV/quant/macro/fear-greed` | VIX 기반 심리지수 |
| 카테고리 | GET | `/api/IV/quant/macro/categories` | 카테고리 목록 |

---

## 5. 22개 매크로 자산 목록

| 카테고리 | 심볼 |
|----------|------|
| 지수 | KOSPI, KOSDAQ, SP500, NDX100 |
| 선물 | ES, NQ, YM, RTY |
| 환율 | USDKRW, USDJPY, EURUSD |
| 채권 | US2Y, US10Y |
| 변동성 | VIX |
| 암호화폐 | BTC |
| 원자재 | GOLD, SILVER, WTI, BRENT, NATGAS, COPPER, NICKEL |
| 투자심리 | DEPOSIT(투자자예탁금), CREDIT(신용융자잔고) |

---

## 6. 구현 우선순위

| 순서 | 모듈 | 설명 | 의존성 |
|:----:|------|------|--------|
| 1 | api_config + macro_asset_model | API 엔드포인트 + 데이터 모델 | 없음 |
| 2 | macro_service | API 호출 서비스 | api_config, model |
| 3 | macro_utils | 위험도 평가, 시그널 생성 로직 | model |
| 4 | category_filter | 카테고리 필터 칩 UI | 없음 |
| 5 | asset_card_grid | 자산 카드 그리드 UI | model, utils |
| 6 | sentiment_gauge_section | 시장 심리 게이지 UI | service, utils |
| 7 | asset_history_chart | fl_chart 히스토리 차트 | service |
| 8 | cross_signal_section | 크로스시그널 UI | utils |
| 9 | macro_dashboard_screen | 전체 조합 화면 | 위 모든 모듈 |
| 10 | home_screen 수정 | placeholder → dashboard 교체 | dashboard screen |

---

## 7. 리스크

| 리스크 | 영향 | 대응 |
|--------|------|------|
| 22개 자산 동시 로드 시 느림 | UX 저하 | 캐시(`/latest`) 우선 로드 후 실시간 갱신 |
| API 서버 부하 | 데이터 지연 | 캐시 데이터 활용, 수동 새로고침만 실시간 호출 |
| 모바일 화면에 정보 과밀 | 가독성 저하 | 카테고리 필터로 분류, 스크롤 가능한 레이아웃 |
| fl_chart 학습곡선 | 개발 지연 | AreaChart만 사용 (단순한 형태) |
| 장외시간 데이터 없음 | 빈 데이터 | 마지막 데이터 표시 + "장 마감" 표시 |

---

## 8. 성공 기준

| # | 기준 | 검증 방법 |
|---|------|-----------|
| SC-01 | 홈 탭에서 거시경제 대시보드 정상 표시 | 수동 테스트 |
| SC-02 | 22개 자산의 현재가/등락률 표시 | API 응답 확인 |
| SC-03 | 시장 심리 게이지 (공포/탐욕, 금리차, 신용/예탁) 표시 | 수동 테스트 |
| SC-04 | 9개 카테고리 필터 동작 | 카테고리 선택 시 필터링 확인 |
| SC-05 | 자산 카드 터치 시 히스토리 차트 표시 | fl_chart AreaChart 렌더링 |
| SC-06 | 크로스시그널 표시 (전체 카테고리 시) | 시그널 목록 확인 |
| SC-07 | Pull-to-refresh로 데이터 갱신 | 새로고침 동작 확인 |
| SC-08 | 캐시 데이터로 빠른 초기 로드 (1초 내) | 로딩 시간 확인 |

---

## 9. 웹 클라이언트 참고

이 Plan은 웹 클라이언트의 MacroDashboard.js (717줄)를 참고하여 작성되었다.
- **동일**: API 엔드포인트, 22개 자산 목록, 위험도 평가 로직, 크로스시그널 로직
- **변경**: 웹의 recharts → Flutter의 fl_chart, 반응형 그리드 → 모바일 스크롤 레이아웃
- **참고 경로**: `/Users/yujongtae/Dropbox/SOFTWARE/dev_react/linker-biz-manager/src/app/finance-quant/MacroDashboard.js`

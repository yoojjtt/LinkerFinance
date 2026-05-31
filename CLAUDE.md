# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**LinkFin** — 주식/재무 관리 모바일 앱 (Flutter, iOS/Android)
- Bundle ID: `com.linkerlab.finance`
- Dart SDK ^3.9.2
- LinkerBiz 백엔드 API 연동 (`main-api.linkerbiz.net`)
- worker_manager 프로젝트 기반 구조 (로그인/계정/FCM 동일)

## Common Commands

- **Run app:** `flutter run` (add `-d chrome` for web, `-d macos` for macOS, etc.)
- **Run tests:** `flutter test`
- **Analyze code:** `flutter analyze`
- **Get dependencies:** `flutter pub get`
- **Format code:** `dart format .`
- **Generate icons:** `dart run flutter_launcher_icons`

## Architecture

```
lib/
├── main.dart                    # 앱 진입점 (Firebase + FCM 초기화)
├── firebase_options.dart        # Firebase 프로젝트 설정
├── config/
│   └── api_config.dart          # API Base URL + 엔드포인트 상수
├── models/                      # 데이터 모델
├── services/                    # API/인증/FCM 서비스 (싱글톤)
├── screens/                     # 화면 (StatefulWidget + setState)
└── widgets/                     # 공통 위젯
```

- **상태관리**: StatefulWidget + setState + 싱글톤 서비스
- **HTTP**: `http` 패키지, 15초 타임아웃
- **인증**: `flutter_secure_storage` (OS 키체인)
- **푸시**: `firebase_messaging`, app_type: `"FINANCE"`

## 참고 프로젝트

- **웹 클라이언트**: `/Users/yujongtae/Dropbox/SOFTWARE/dev_react/linker-biz-manager/src/app/finance-quant/`
- **API 문서**: `/Users/yujongtae/Dropbox/SOFTWARE/dev_java/LinkerMain/docs/api/`
- **worker_manager**: `/Users/yujongtae/Dropbox/SOFTWARE/dev_flutter/worker_manager/`

## Feature Roadmap (우선순위)

### Phase 1: 기반 완료 ✅
- [x] admin-account — 로그인/계정관리 (API 7개)
- [x] fcm-token-management — FCM 푸시 알림 (API 7개)

### Phase 2: 재무 핵심 기능 (진행 예정)

| 순서 | Feature | 설명 | API 문서 | 상태 |
|:----:|---------|------|----------|:----:|
| 1 | `macro-dashboard` | 거시경제 대시보드 (홈 화면) | - | 대기 |
| 2 | `watchlist` | 관심종목/업종분석 | watchlist-sector-analysis-api.md | 대기 |
| 3 | `stock-detail` | 종목검색 + 종목상세 (차트/재무/공시/배당/수급/일지) | ai-stock-analysis-api.md 등 | 대기 |
| 4 | `trade-journal` | 매매일지/노트 | trade-journal-api-guide.md | 대기 |
| 5 | `ai-scanner` | AI스캐너 + 알림센터 연동 | stock-scanner-api-guide.md | 대기 |

### Phase 3: 확장 기능 (리스트업만)

| Feature | 설명 | API 문서 |
|---------|------|----------|
| `quant-screener` | 퀀트 스크리너 | kiwoom-quant-screener-api-guide.md |
| `trading-strategy` | 매매전략 관리 | trading-strategy-api.md |
| `trend-detector` | 트렌드 감지 | trend-detector-api.md |
| `event-calendar` | 주식이벤트 캘린더 | stock-event-calendar-api.md |
| `ai-trade-check` | AI 매매체크 (사전검증) | trade-ai-check-api.md |
| `price-alert` | 가격 알림 | - |
| `realtime-monitor` | 실시간 모니터링 | - |

## 디자인 토큰

| 토큰 | 값 | 용도 |
|------|-----|------|
| primaryColor | `#1B2E5C` | 로고, 헤더, 포커스 |
| accentColor | `#FFD700` | 버튼 강조 |
| backgroundColor | `#F5F5F7` | Scaffold 배경 |
| inputFillColor | `#FAF8F0` | 입력 필드 |
| borderRadius | 16/12/10 | 카드/버튼/입력 |

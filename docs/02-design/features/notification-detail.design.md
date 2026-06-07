# Design: 알림 상세 페이지 + 푸시 딥링크 (notification-detail)

> Feature: notification-detail
> Created: 2026-06-08
> Architecture: Option C — Pragmatic Balance
> Plan: docs/01-plan/features/notification-detail.plan.md

---

## Context Anchor

| 항목 | 내용 |
|------|------|
| **WHY** | 푸시 알림의 핵심 가치(내용 전달)가 끊겨 있음. 탭해도 내용에 도달 못 하고, 긴 내용은 보텀시트에서 잘려 보임 |
| **WHO** | 푸시 알림을 받는 모든 LinkFin 사용자 |
| **RISK** | 푸시 페이로드(`message.data`)에 식별자(seq) 포함 여부 미확인. 콜드 스타트 탭 시 navigatorKey/로그인 미준비 타이밍 |
| **SUCCESS** | 푸시 탭 시 상세 진입, 목록 탭 시 상세 진입, 긴 내용 전체 스크롤, 읽음 처리 유지 |
| **SCOPE** | 상세 페이지 신설 + 푸시 딥링크(포그라운드/백그라운드/종료) + 보텀시트 제거. 알림 종류별 화면 분기는 제외 |

---

## 1. Overview

### 1.1 설계 방향
- **Pragmatic Balance**: 목록(`log` Map)과 푸시(`RemoteMessage`)라는 두 데이터 출처를 **경량 값 객체 `NotificationDetail`** 한 곳에서 정규화한다.
- 상세 화면은 이 값 객체만 받아 표시 — 출처를 모른다(출처 무관).
- 콜드스타트(앱 종료 상태) 푸시 탭은 `FcmService`에 **pending 변수 1개**를 두고, navigatorKey/로그인 준비 후 flush한다.
- 기존 보텀시트(`_showDetail`)는 제거하고 `Navigator.push`로 교체.

### 1.2 핵심 결정사항

| 결정 | 선택 | 이유 |
|------|------|------|
| 데이터 전달 | 경량 값 객체 `NotificationDetail` (팩토리 `fromLog`/`fromMessage`) | 두 출처 정규화 단일 지점, 타입 안전, 과설계 회피 |
| 상세 화면 진입 | `Navigator.push(MaterialPageRoute)` + 인자 생성자 | named route 미사용(현 앱이 대부분 push 방식), 인자 전달 단순 |
| 푸시 네비게이션 | `navigatorKey.currentState.push` | main.dart 전역 navigatorKey 재사용 |
| 콜드스타트 처리 | `FcmService._pendingDetail` + 진입점에서 flush | 앱/로그인 준비 전 도착한 네비게이션 보존 |
| 읽음 처리 | 상세 진입 시 seq 있으면 `markLogAsRead` + `fetchUnreadCount` | 기존 메서드 재사용, 미읽음/뱃지 동기화 |
| 본문 출처 | 목록=보유 log, 푸시=`notification.body`(잘림 없음) | 단건 조회 API 부재, body 데이터는 이미 완전 |

---

## 2. 프로젝트 구조

```
lib/
├── main.dart                              # [수정] 콜드스타트 pending flush 트리거(앱 첫 진입 후)
├── models/
│   └── notification_detail.dart           # [신규] NotificationDetail 값 객체 + 팩토리 2개
├── services/
│   └── fcm_service.dart                   # [수정] 탭 핸들러 네비게이션 + pending 처리 + 스낵바 '보기'
└── screens/
    ├── notification_list_screen.dart      # [수정] 보텀시트 제거 → 상세 페이지 push
    └── notification_detail_screen.dart    # [신규] 알림 상세 전체 화면
```

---

## 3. 데이터 모델

### 3.1 `NotificationDetail` (신규)

```dart
class NotificationDetail {
  final int? seq;          // 서버 로그 식별자 (푸시 data에 없으면 null)
  final String title;
  final String body;       // 전체 본문 (잘리지 않음)
  final String? createDT;  // ISO 문자열 (목록은 보유, 푸시는 수신시각 fallback)

  const NotificationDetail({this.seq, required this.title, required this.body, this.createDT});

  // 목록 항목(log Map) → 상세
  factory NotificationDetail.fromLog(Map<String, dynamic> log) => NotificationDetail(
        seq: log['seq'] as int?,
        title: log['title'] as String? ?? '알림',
        body: log['body'] as String? ?? '',
        createDT: log['create_DT'] as String?,
      );

  // 푸시(RemoteMessage) → 상세
  factory NotificationDetail.fromMessage(RemoteMessage m) {
    final data = m.data;
    final seqRaw = data['seq'];                 // 서버가 data에 seq 실어주면 사용 (V-01)
    return NotificationDetail(
      seq: seqRaw is int ? seqRaw : int.tryParse('${seqRaw ?? ''}'),
      title: m.notification?.title ?? data['title'] as String? ?? '알림',
      body: m.notification?.body ?? data['body'] as String? ?? '',
      createDT: null,                            // 푸시엔 생성시각 없음 → '방금 전' 처리
    );
  }
}
```

> 시간 표시는 `createDT`가 null이면 상세 화면에서 "방금 전"으로 표기.

---

## 4. 네비게이션 흐름

### 4.1 진입 경로별 처리

| 경로 | 트리거 | 처리 |
|------|--------|------|
| 목록 탭 | `InkWell.onTap` | `_markAsRead(log)` → `Navigator.push(NotificationDetailScreen(detail: fromLog(log)))` |
| 포그라운드 스낵바 '보기' | `SnackBarAction` | `_openDetail(fromMessage(m))` |
| 백그라운드 탭 | `onMessageOpenedApp` | `_openDetail(fromMessage(m))` |
| 종료상태 탭 | `getInitialMessage` | `_pendingDetail = fromMessage(m)` → 앱 진입 후 flush |

### 4.2 `FcmService` 네비게이션 로직 (수정)

```dart
NotificationDetail? _pendingDetail;   // 콜드스타트 보존

void _openDetail(NotificationDetail detail) {
  final nav = navigatorKey?.currentState;
  if (nav == null) { _pendingDetail = detail; return; }   // 아직 준비 안됨 → 보류
  nav.push(MaterialPageRoute(builder: (_) => NotificationDetailScreen(detail: detail)));
  if (detail.seq != null) {                                 // 읽음 처리
    markLogAsRead(detail.seq!);
    fetchUnreadCount();
  }
}

// 앱이 로그인/홈까지 준비된 뒤 호출 (main.dart 또는 홈 진입 시)
void flushPendingDetail() {
  final d = _pendingDetail;
  if (d != null) { _pendingDetail = null; _openDetail(d); }
}
```

- `_handleMessageOpenedApp(m)` → `_addNotification(m, isRead: true); fetchUnreadCount(); _openDetail(fromMessage(m));`
- `getInitialMessage` (initialize 내) → `_pendingDetail = NotificationDetail.fromMessage(initialMessage);` (push는 _openDetail가 navigatorKey null이면 자동 보류하나, initialize 시점엔 명시적으로 pending 저장)
- 스낵바 '보기' → 기존 `pushNamed('/notifications')` 대신 `_openDetail(fromMessage(message))`

### 4.3 콜드스타트 flush 지점
- 로그인 완료 후 홈 화면(`HomeScreen`)이 마운트되는 시점에 `FcmService().flushPendingDetail()` 호출.
- 미로그인 상태로 종료→푸시 탭 시: 로그인 화면을 거치므로, 홈 진입 후 flush 되어 안전.

---

## 5. UI — NotificationDetailScreen (신규)

- Scaffold + AppBar(제목 "알림", 뒤로가기, primaryColor `#1B2E5C`)
- body: `SingleChildScrollView` (전체 스크롤)
  - 제목 (fontSize 18, w700, `#1B2E5C`)
  - 시간 (`_formatTime` 재사용, createDT null이면 "방금 전")
  - 구분선
  - 본문 (fontSize 15, height 1.6) — `SelectableText` 권장(복사 가능)
- 디자인 토큰: backgroundColor `#F5F5F7`, 카드 흰색 영역 borderRadius 16

> `_formatTime` / 시간 포맷 로직은 목록 화면과 중복되므로 상세 화면에 동일 헬퍼를 두거나 추후 utils로 추출(현 단계는 화면 내 복제 허용).

---

## 6. 변경 상세 (파일별)

| 파일 | 변경 |
|------|------|
| `models/notification_detail.dart` | [신규] 값 객체 + `fromLog`/`fromMessage` |
| `screens/notification_detail_screen.dart` | [신규] 전체 화면 상세 |
| `screens/notification_list_screen.dart` | [수정] `_showDetail` 보텀시트 제거 → `Navigator.push`. onTap에서 `_markAsRead` 후 push |
| `services/fcm_service.dart` | [수정] `_pendingDetail`/`_openDetail`/`flushPendingDetail`, `_handleMessageOpenedApp` 네비게이션, `getInitialMessage` pending 저장, 스낵바 '보기' → 상세 |
| `main.dart` 또는 `home_screen.dart` | [수정] 홈 마운트 시 `flushPendingDetail()` 호출 |

---

## 7. 엣지 케이스

| 케이스 | 처리 |
|--------|------|
| 푸시 data에 seq 없음 | seq=null → 읽음 처리 스킵, 본문은 notification.body로 표시 (V-01) |
| body 비어있음 | "내용이 없습니다" placeholder |
| 콜드스타트, navigatorKey null | `_pendingDetail` 보존 후 홈 진입 시 flush |
| 미로그인 중 푸시 탭 | 로그인 후 홈 진입 → flush (pending 유지) |
| 목록에서 이미 읽은 알림 탭 | `_markAsRead`가 is_read==1이면 조기 return, push만 수행 |

---

## 8. Test Plan

| ID | 시나리오 | 기대 |
|----|----------|------|
| T-01 | 목록 항목 탭 | 상세 페이지 진입, 보텀시트 안 뜸 |
| T-02 | 긴 본문 알림 상세 | 끝까지 스크롤되어 전체 표시 |
| T-03 | 포그라운드 수신 후 스낵바 '보기' | 상세 페이지 진입 |
| T-04 | 백그라운드 상태 푸시 탭 | 앱 열리며 상세 자동 진입 |
| T-05 | 종료 상태 푸시 탭 | 앱 시작 후 상세 진입 (pending flush) |
| T-06 | 상세 진입 후 목록 복귀 | 해당 알림 읽음 처리, 미읽음 카운트/뱃지 감소 |
| T-07 | 푸시 data 로깅 확인 | `dev.log('data: ...')`로 seq 포함 여부 검증 (V-01) |

---

## 9. 미해결 → Do 단계 검증

- **V-01**: 실제 푸시 수신 시 `message.data`에 seq가 오는지 로그 확인. 없으면 읽음 처리는 목록 진입 시점에만 동작(허용).
- **V-02**: flush 호출 지점이 홈 마운트로 충분한지(스플래시→로그인→홈 경로) 실기기 확인.

---

## 11. Implementation Guide

### 11.1 구현 순서
1. `models/notification_detail.dart` 생성 (값 객체 + 팩토리)
2. `screens/notification_detail_screen.dart` 생성 (전체 화면 UI)
3. `notification_list_screen.dart`: `_showDetail` 제거 → push로 교체
4. `fcm_service.dart`: pending/openDetail/flush + 핸들러 3종 연결 + 스낵바 수정
5. `main.dart`/`home_screen.dart`: `flushPendingDetail()` 호출
6. 실기기 검증 (T-01~T-07, 특히 V-01 로그)

### 11.3 Session Guide (Module Map)

| 모듈 | scope 키 | 파일 | 의존 |
|------|----------|------|------|
| 모델+상세화면 | `module-1` | notification_detail.dart, notification_detail_screen.dart | 없음 |
| 목록 연결 | `module-2` | notification_list_screen.dart | module-1 |
| 푸시 딥링크 | `module-3` | fcm_service.dart, main.dart/home_screen.dart | module-1 |

**권장 세션 분할**: 1세션에 전부 가능(소규모). 분할 시 module-1 → (module-2 + module-3).

---

## 다음 단계

`/pdca do notification-detail` — 전체 구현 (또는 `--scope module-1`부터 단계 구현)

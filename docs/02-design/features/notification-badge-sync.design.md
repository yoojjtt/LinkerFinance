# Design: 전체 알림 뱃지 숫자 동기화 (notification-badge-sync)

> Feature: notification-badge-sync
> Created: 2026-06-13
> Status: Draft
> Level: Dynamic
> Selected Architecture: **Option C — 실용(Pragmatic): 공유 헬퍼 sendFinanceWithBadge**

---

## Context Anchor

| 항목 | 내용 |
|------|------|
| **WHY** | 뱃지 숫자가 실제와 어긋나 알림 신뢰도가 깨짐 |
| **WHO** | iOS(주)/Android 푸시를 받는 모든 LinkFin 사용자 |
| **RISK** | off-by-one(발송/로그 순서), iOS는 payload badge 없으면 닫힌 상태 미변경, 멀티기기 동일 뱃지 |
| **SUCCESS** | 아이콘=서버 countUnread, 모두읽음 즉시 0, 재진입 없이 동기화, off-by-one ±0 |
| **SCOPE** | 서버 badge payload 주입(FINANCE) + 앱 뱃지/카운트 동기화 + 단일 진실(서버) |

## 1. Overview

뱃지 불일치의 근본 원인은 **(서버) 푸시 payload에 `aps.badge`가 전혀 실리지 않음** + **(앱) 읽음 처리 시 OS 뱃지 즉시 미반영 및 읽음/조회 경합**이다. 본 설계는:

- **서버**: FINANCE 발송 공통 헬퍼 `LbFcmTokenService.sendFinanceWithBadge(userId, title, body, alertRef)` 를 신설하고, 발송 직전 `countUnread+1`을 `aps.badge`로 주입한다. 기존 6개 FINANCE 발송부를 이 헬퍼로 이관한다.
- **앱**: 읽음 처리 후 뱃지 즉시 반영, 읽음 PUT await 후 카운트 조회, AppLifecycle resume 재조회, 안읽음 수 단일 진실을 서버로 통일한다.

## 2. 선택 아키텍처 근거 (Option C)

| 비교 | A.최소 | B.클린 | **C.실용(선택)** |
|------|--------|--------|------------------|
| badge 로직 위치 | funnel 1곳 | sendNotification 최하단 | **헬퍼 1곳** |
| 커버리지 | AI 알림만 | 전체(타앱 포함) | **FINANCE 전체** |
| 시그니처 변경 범위 | 작음 | 큼(전 호출부) | **중간(FINANCE 6곳)** |
| 위험 | 비AI 빈틈 | 타앱 영향 | **낮음** |

→ badge 로직을 한 곳에 두면서 FINANCE 발송만 깔끔히 커버. B의 광범위 시그니처 변경 위험 회피.

## 3. 현행 구조

### 3.1 FINANCE 발송부 (모두 동일 패턴 — 이관 대상)

| # | 위치 | 비고 |
|---|------|------|
| 1 | `GeminiService.sendPush(title, body, alertRef)` :207 | AI 알림 공통 funnel (Macro/Briefing/Realtime/Watchlist) |
| 2 | `TrendDetectorService.sendPushNotification` :173 | |
| 3 | `StockAlertService` :225 | 가격알림 |
| 4 | `StockSignalService.sendPushNotification` :140 | |
| 5 | `StockScannerService` :245 | 스캐너 |
| 6 | `DbBackup` :218, :592 | **saveSendLog 없음** → 카운트 비대상. badge 주입 선택(현재 count 전달 or 생략) |

공통 코드:
```java
String token = result.get(0).get("token").toString();
firebaseNotificationService.sendNotification(title, body, token, "FINANCE");          // badge=null
lbFcmTokenService.saveSendLog(null, "sun07x", "FINANCE", token, title, body, "PUSH", true, null, null, alertRef);
```

### 3.2 인프라 (이미 존재 — 재사용)

- `FirebaseNotificationService.sendNotification(..., Integer badge)` :109 + `createNotificationData` :160 → `aps.badge` 주입 로직 **이미 있음**. badge 인자만 채우면 됨.
- `fcmSendLogMapper.countUnread` (user_id + success=1 + is_read=0 + app_type) → badge 계산 재사용.

## 4. 서버 설계

### 4.1 신규 헬퍼 — `LbFcmTokenService.sendFinanceWithBadge`

```java
// Design Ref: §4.1 — FINANCE 푸시 단일 진입점 (badge 주입 + 로그)
public void sendFinanceWithBadge(String userId, String title, String body, Long alertRef) {
    try {
        // 1) 60분 중복 방지 (기존 GeminiService 로직 승계)
        if (isDuplicate(userId, title, 60)) {
            logger.info("[FCM] 중복 알림 스킵: {}", title);
            return;
        }
        // 2) 활성 토큰 조회
        FcmToken q = new FcmToken();
        q.setUser_id(userId);
        q.setApp_type("FINANCE");
        ArrayList<HashMap<String, Object>> tokens = fcmTokenMapper.selectActiveTokens(q);
        if (tokens == null || tokens.isEmpty()) return;

        // 3) badge = 현재 안읽음 + 1 (이번 알림은 곧 is_read=0으로 적재되므로 포함)
        Map<String, Object> cp = new HashMap<>();
        cp.put("user_id", userId);
        cp.put("app_type", "FINANCE");
        int badge = countUnread(cp) + 1;   // off-by-one 보정

        // 4) 발송 (badge 포함) + 로그 적재
        String token = tokens.get(0).get("token").toString();
        String resp = firebaseNotificationService.sendNotification(title, body, token, "FINANCE", badge);
        saveSendLog(null, userId, "FINANCE", token, title, body, "PUSH", true, null, resp, alertRef);
    } catch (Exception e) {
        logger.warn("[FCM] FINANCE 푸시 실패: {}", e.getMessage());
    }
}
```

**핵심 — off-by-one 처리**: badge는 `countUnread(현재) + 1`. 이유: 푸시 발송 시점에는 아직 `saveSendLog`(is_read=0) 전이므로 현재 count에 이번 알림이 빠져 있다. +1 하면 적재 직후 실제 count와 일치. 앱이 fetchUnreadCount로 재확인 시에도 같은 값.

> 대안(insert 선행 후 count)도 가능하나 success 플래그/실패 처리 흐름이 꼬여 +1 보정을 채택.

### 4.2 발송부 이관

각 발송부의 inline `sendNotification + saveSendLog` 2줄을 헬퍼 호출 1줄로 교체:
```java
// 예) GeminiService.sendPush(title, body, alertRef) 본문
lbFcmTokenService.sendFinanceWithBadge("sun07x", title, body, alertRef);
```
- 중복방지·토큰조회·로그까지 헬퍼가 흡수 → 발송부는 호출만.
- TrendDetector/StockAlert/StockSignal/StockScanner 동일하게 교체.
- DbBackup: 카운트 비대상(로그 없음). 현 상태 유지하거나, 원하면 `sendNotification(..., countUnread)` 로 "현재값 동기화"만. **본 설계 기본: DbBackup 미변경**(범위 최소화).

### 4.3 멀티기기

현행과 동일하게 첫 활성 토큰에만 발송(behavior 유지). 멀티기기 전체 발송은 Out of Scope.

## 5. 앱 설계 (lib/services/fcm_service.dart 중심)

### 5.1 모두읽음 — 즉시 뱃지 클리어 (증상②)

```dart
// Design Ref: §5.1 — Plan SC: SC-03
Future<void> markAllLogsAsRead() async {
  final user = AuthService().currentUser;
  if (user == null) return;
  try {
    await ApiService.put(ApiConfig.fcmLogReadAll, params: {...});  // await 보장
    unreadCount.value = 0;
    _updateAppBadge(0);          // ★ OS 아이콘 즉시 제거 (기존 누락)
  } catch (_) {}
}
```

### 5.2 단건 읽음 — 경합 제거 (증상 보강)

```dart
// Design Ref: §5.2 — Plan SC: SC-04
Future<void> markLogAsRead(int seq) async {
  try { await ApiService.put(ApiConfig.fcmLogRead, params: {'seq': '$seq'}); } catch (_) {}
}

// _openDetail: 읽음 PUT 완료 후 카운트 조회 (순서 보장)
if (detail.seq != null) {
  markLogAsRead(detail.seq!).then((_) => fetchUnreadCount());   // ★ await→fetch 체인
}
```

### 5.3 AppLifecycle resume 재조회 (SC-05)

`main.dart` 루트 위젯에 옵저버 추가:
```dart
// Design Ref: §5.3 — Plan SC: SC-05
class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); }
  @override void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  @override void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) FcmService().fetchUnreadCount();
  }
}
```

### 5.4 단일 진실 = 서버 (SC-07)

- `unreadCount.value`는 **오직 `fetchUnreadCount`** 가 갱신한다.
- `_addNotification`/`markAsRead`/`markAllAsRead`(인메모리, id기반)의 `_updateUnreadCount()` 호출 제거 → 인메모리 `notifications` 리스트는 스낵바/표시용으로만 유지.
- 포그라운드 수신 `_handleForegroundMessage`는 이미 `fetchUnreadCount()` 호출 → 그대로 단일 경로 사용(숫자 1회 변동).

## 6. 데이터 흐름

```
[발송]  AI/가격/스캐너 → sendFinanceWithBadge(userId,…)
          → countUnread+1 = badge → sendNotification(…, badge) → APNs aps.badge
          → saveSendLog(is_read=0)
[수신/닫힘] iOS가 payload badge로 아이콘 숫자 표시 (앱 실행 없이도 정확)  ← SC-01
[열기]  fetchUnreadCount → unreadCount.value + _updateAppBadge          ← SC-02
[읽음]  markLogAsRead(await) → fetchUnreadCount                          ← SC-04
[모두읽음] readAll(await) → unreadCount=0 + _updateAppBadge(0)            ← SC-03
[복귀]  resumed → fetchUnreadCount                                       ← SC-05
```

## 7. 영향도 / 하위호환

- 서버: 신규 헬퍼 추가 + 6개 발송부 1줄 교체. `sendNotification(badge)`/`createNotificationData` 변경 없음(기존 인자 사용). 기존 `GeminiService.sendPush` 시그니처 유지(본문만 위임) → 호출부 영향 0.
- 앱: 메서드 내부 동작 강화, 공개 시그니처 거의 불변(`markLogAsRead`/`markAllLogsAsRead`는 이미 Future 반환).
- Android: `aps`는 iOS 전용. Android badge는 런처 의존 → 본 설계 영향 없음(무시).

## 8. Test Plan

| Level | 시나리오 | 기대 |
|-------|----------|------|
| L1 서버 | 알림 1건 발송 후 APNs payload 확인 | `aps.badge` = countUnread+1 |
| L1 서버 | 안읽음 3건 상태에서 1건 더 발송 | badge=4 (off-by-one 없음) SC-06 |
| L2 앱 | 앱 종료 → 푸시 수신 → 아이콘 | 숫자=서버 안읽음 SC-01 |
| L2 앱 | 진입 후 카운트 vs 아이콘 | 일치 SC-02 |
| L2 앱 | 모두읽음 → 홈 → 백그라운드 → 아이콘 | 즉시 0/제거 SC-03 |
| L2 앱 | 상세 1건 읽음 → 뒤로 | 카운트 -1 정확 SC-04 |
| L3 앱 | 타기기 읽음 → 포그라운드 복귀 | 자동 갱신 SC-05 |
| L3 앱 | 포그라운드 수신 | 숫자 1회만 변동(깜빡임 없음) SC-07 |

## 9. 리스크 & 대응

| 리스크 | 대응 |
|--------|------|
| off-by-one | badge=count+1 보정, L1 테스트로 검증 |
| 발송 실패 시 badge만 오르고 로그 없음 | sendNotification 예외 시 saveSendLog 미수행(현행 try-catch) → count 불변, 다음 발송/열기 시 자기교정 |
| 멀티기기 badge 불일치 | user 단위 count로 통일(의도), 첫 토큰 발송 한계는 Out of Scope 명시 |
| 중복방지로 skip된 알림 | 로그 미적재 → count 영향 없음(정상) |

## 10. Out of Scope

- 멀티기기 전체 토큰 발송, Android 런처별 뱃지, 알림 그룹핑/카테고리별 카운트, 푸시 data alert_ref 딥링크(별도).

## 11. Implementation Guide

### 11.1 구현 순서

**서버 (LinkerMain)**
1. `LbFcmTokenService.sendFinanceWithBadge(userId, title, body, alertRef)` 신설 (§4.1)
2. `GeminiService.sendPush(title, body, alertRef)` 본문을 헬퍼 위임으로 교체 (§4.2)
3. TrendDetectorService / StockAlertService / StockSignalService / StockScannerService 발송부를 헬퍼 호출로 교체
4. `compileJava` 검증

**앱 (linker_finance)**
5. `markAllLogsAsRead` — await + `_updateAppBadge(0)` (§5.1)
6. `_openDetail` 읽음→fetch 체인 (§5.2)
7. `main.dart` WidgetsBindingObserver resume 재조회 (§5.3)
8. 단일 진실 정리 — `_updateUnreadCount` 호출 제거, 인메모리 카운트 미사용 (§5.4)
9. `flutter analyze` 검증

### 11.2 핵심 파일

| 파일 | 변경 |
|------|------|
| `service/LB/LbFcmTokenService.java` | 헬퍼 신설 |
| `service/IV/GeminiService.java` | sendPush 위임 |
| `service/IV/{TrendDetector,StockAlert,StockSignal,StockScanner}Service.java` | 발송부 교체 |
| `lib/services/fcm_service.dart` | 5.1/5.2/5.4 |
| `lib/main.dart` | 5.3 lifecycle |

### 11.3 Session Guide

| Module | 범위 | 키 |
|--------|------|-----|
| **module-1 서버 badge** | §4 전체 (헬퍼 + 6 발송부 이관 + 컴파일) | `server` |
| **module-2 앱 동기화** | §5.1/5.2/5.4 (fcm_service) | `app-sync` |
| **module-3 앱 lifecycle** | §5.3 (main.dart resume) | `app-lifecycle` |

권장 분할: module-1(서버) → module-2+3(앱) 순. 서버 먼저 배포해야 SC-01 검증 가능.

## 다음 단계

`/pdca do notification-badge-sync --scope server` (서버부터) 또는 `/pdca do notification-badge-sync` (전체).

# Analysis: 전체 알림 뱃지 숫자 동기화 (notification-badge-sync)

> Feature: notification-badge-sync
> Created: 2026-06-13
> Phase: Check (Gap Analysis)
> Match Rate: **100%** (static — G1 정리 완료. 런타임 SC-01/06은 서버 배포+실기기 필요)

---

## Context Anchor

| 항목 | 내용 |
|------|------|
| WHY | 뱃지 숫자가 실제와 어긋나 알림 신뢰도 붕괴 |
| SUCCESS | 아이콘=서버 countUnread, 모두읽음 즉시 0, 재진입 없이 동기화, off-by-one ±0 |
| SCOPE | 서버 badge 주입(FINANCE) + 앱 뱃지/카운트 동기화 + 단일 진실(서버) |

## 1. 전략 정합성 (Strategic Alignment)

- **WHY 충족**: 근본 원인(서버 payload badge 부재 + 앱 읽음 시 뱃지 미반영)을 양쪽 모두 해소. ✅
- **핵심 설계결정 준수**: Option C(공유 헬퍼) 그대로 구현, 서버 단일 진실 통일. ✅

## 2. Success Criteria 평가

| SC | 상태 | 근거 |
|----|------|------|
| SC-01 닫힌 상태 아이콘=서버값 | ⚠️ 코드 충족 / 런타임 미검증 | `sendFinanceWithBadge`가 `aps.badge` 주입 (LbFcmTokenService:285). 실기기 검증 필요 |
| SC-02 진입후 일치 | ✅ Met | `fetchUnreadCount` → `_updateAppBadge` (기존) |
| SC-03 모두읽음 즉시 0 | ✅ Met | `markAllLogsAsRead` await→`_updateAppBadge(0)` (fcm_service:275) |
| SC-04 단건 정확 | ✅ Met | `markLogAsRead().then(fetchUnreadCount)` (fcm_service:102) |
| SC-05 resume 갱신 | ✅ Met | `WidgetsBindingObserver` resumed→fetch (main.dart:54-57) |
| SC-06 off-by-one 없음 | ⚠️ 코드 충족 / 런타임 미검증 | `countUnread(cp) + 1` (LbFcmTokenService:282) |
| SC-07 깜빡임 없음 | ✅ Met | `_addNotification`의 `_updateUnreadCount()` 제거 → 서버 단일 경로 |

## 3. 정적 분석 (Static)

### 3.1 Structural Match — 100%
| 항목 | 설계 | 구현 | 일치 |
|------|------|------|:----:|
| 헬퍼 `sendFinanceWithBadge` | §4.1 | LbFcmTokenService:264 | ✅ |
| 6 FINANCE 발송부 이관 | §4.2 | Gemini/Trend/StockAlert/StockSignal/StockScanner | ✅ |
| DbBackup 제외 | §4.2 | 미변경 (218/592) | ✅ (의도) |
| 앱 §5.1/5.2/5.4 | §5 | fcm_service.dart | ✅ |
| 앱 §5.3 lifecycle | §5.3 | main.dart | ✅ |

### 3.2 Functional Depth — 100%
- off-by-one 보정 `countUnread+1` ✅
- badge 주입은 기존 `createNotificationData`의 `aps.badge` 경로 재사용 ✅
- await→fetch 경합 제거 ✅
- **G1 해결(2026-06-13)**: 미사용 in-memory 메서드(`markAsRead`/`markAllAsRead`/`deleteNotification`) + `_updateUnreadCount` 제거 → `unreadCount`는 서버 단일 경로로 완전 통일. `flutter analyze lib/` 통과.

### 3.3 API Contract — 100%
- 헬퍼 시그니처 = 설계 §4.1 일치 ✅
- `sendNotification(…, badge)` → `aps.badge` 계약 유지 ✅
- 앱 `/fcm/log/unreadCount` 계약 불변 ✅

### 3.4 빌드 검증
- 서버 `compileJava` → **BUILD SUCCESSFUL** ✅
- 앱 `flutter analyze lib/` → **No issues found** ✅

## 4. Match Rate

```
Static only (런타임 미실행):
Overall = Structural×0.2 + Functional×0.4 + Contract×0.4
        = 100×0.2 + 100×0.4 + 100×0.4
        = 20 + 40 + 40 = 100%
```

## 5. Gap 목록

| ID | 심각도 | 내용 | 조치 |
|----|--------|------|------|
| G1 | ~~Minor~~ | 미사용 in-memory 메서드의 `_updateUnreadCount` 호출 | ✅ **해결** — 메서드 제거 |
| G2 | Info(외부) | SC-01/06 런타임 미검증 | **서버 재배포 + 실기기** 필요 |
| G3 | Info | DbBackup 푸시 badge 없음 | 설계상 의도(카운트 비대상) |

→ **Critical/Important 0건. G1 해결.** 코드 일치율 100%.

## 6. 결론

설계 대비 구현 일치율 **100%**(static), 90% 임계 통과. 잔여는 런타임 검증(서버 배포+실기기)뿐. Report 진행 가능.

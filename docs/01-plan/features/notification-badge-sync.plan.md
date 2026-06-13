# Plan: 전체 알림 뱃지 숫자 동기화 (notification-badge-sync)

> Feature: notification-badge-sync
> Created: 2026-06-13
> Status: Draft
> Level: Dynamic

---

## Executive Summary

| 관점 | 내용 |
|------|------|
| **Problem** | ① 앱 아이콘 뱃지(예: 46)와 앱에 들어가서 보이는 실제 안읽음 수가 다르다. ② 알림을 모두 읽고 앱을 나오면 뱃지가 바뀌지만 "이전 숫자"이고, 한 번 더 들어갔다 나와야 맞춰진다 |
| **Solution** | 서버는 모든 푸시 APNs payload에 `badge=현재 안읽음 수`를 실어 보내고, 앱은 (a) 읽음 처리 후 즉시 뱃지 반영 (b) 읽음 PUT을 await한 뒤 카운트 조회 (c) 포그라운드 복귀(resume) 시 재조회 (d) 안읽음 수의 단일 진실을 서버로 통일 |
| **Function UX Effect** | 앱이 닫혀 있어도 새 알림/읽음에 따라 아이콘 숫자가 정확히 갱신되고, 모두 읽으면 즉시 뱃지가 사라지며, 재진입 없이 한 번에 동기화된다 |
| **Core Value** | "보이는 숫자 = 실제 안읽음 수" — 언제나 신뢰할 수 있는 뱃지 |

## Context Anchor

| 항목 | 내용 |
|------|------|
| **WHY** | 뱃지 숫자가 실제와 어긋나 알림 시스템의 신뢰도가 깨짐. 사용자가 "읽을 게 있나?"를 아이콘으로 판단 못 함 |
| **WHO** | iOS(주) / Android 푸시 알림을 받는 모든 LinkFin 사용자 |
| **RISK** | (1) off-by-one: 푸시 발송 시점과 fcm_send_log insert 순서. (2) iOS는 payload에 badge 없으면 아이콘 미변경 — 닫힌 상태 동기화는 서버 badge에 전적으로 의존. (3) 멀티기기 시 동일 user 뱃지 공유 |
| **SUCCESS** | SC-01~07 (아래) 충족. 핵심: 아이콘 숫자 = 서버 countUnread, 모두읽음 즉시 0, 재진입 없이 동기화 |
| **SCOPE** | 서버 badge payload 주입 + 앱 뱃지/카운트 동기화 로직 수정 + 단일 진실(서버) 통일. 제외: 알림 그룹핑, Android 채널별 뱃지 세분화, 푸시 탭 딥링크(별도 feature notification-detail) |

## 현황 분석 (코드 기준)

### 백엔드 (LinkerMain)

| 위치 | 현재 동작 | 문제 |
|------|-----------|------|
| `FirebaseNotificationService.java:109,160` | `sendNotification(..., Integer badge)` + `createNotificationData`에 `aps.badge` 주입 로직 **존재함** | badge 파라미터로 호출하는 곳이 **0곳** → 항상 null |
| `GeminiService.java:220` 등 모든 발송 | `sendNotification(title, body, token, "FINANCE")` (4-arg) | **badge 미전달** → APNs payload에 badge 없음 → iOS 아이콘 영구 미갱신 |
| `fcmSendLogMapper.countUnread` | `user_id + success=1 + is_read=0 (+app_type)` | 정상. badge 계산에 재사용 가능 |
| `fcmSendLogMapper.markAllAsRead` | `user_id + is_read=0 (+app_type)`, `success=1` 필터 없음 | 경미한 불일치(읽음 처리 대상에 실패건 포함) — 정합성 위해 정렬 권장 |

### 앱 (linker_finance)

| 위치 | 현재 동작 | 문제 |
|------|-----------|------|
| `fcm_service.dart:209` `fetchUnreadCount` | 서버 조회 후 `unreadCount.value` + `_updateAppBadge` | 정상. 단, 호출 시점이 부족 |
| `fcm_service.dart:260` `markAllLogsAsRead` | `unreadCount.value=0`만 설정 | **`_updateAppBadge(0)` 미호출** → OS 아이콘 안 지워짐 (증상②) |
| `fcm_service.dart:100-103` `_openDetail` | `markLogAsRead(seq)` (await 안 함) 직후 `fetchUnreadCount()` | 읽음 PUT 커밋 전 조회 → stale 카운트 (경합) |
| `fcm_service.dart:251` `markLogAsRead` | PUT만, 뱃지/카운트 미반영 | 단건 읽음 후 즉시 반영 경로 약함 |
| (없음) AppLifecycle 옵저버 | resume 시 재조회 없음 | 백그라운드→포그라운드 복귀만으론 미갱신 |
| `fcm_service.dart:146,206 vs 228` | 인메모리 리스트 카운트와 서버 카운트가 같은 `unreadCount.value`를 번갈아 덮어씀 | 이중 진실 → 깜빡임/불일치 |

> 핵심: 아이콘 "46"은 **앱이 마지막 포그라운드에서 써넣은 값**. 푸시에 badge가 없어 닫힌 동안 안 바뀜. 그래서 앱을 열어 fetchUnreadCount가 돌아야 실제값으로 교정됨.

## 요구사항 (Requirements)

### 기능 요구사항 (FR)

- **FR-01 (서버)**: 모든 FINANCE 푸시 발송 시 APNs payload에 `badge = 발송 직후 해당 user의 countUnread` 를 포함한다. (Android는 무시되거나 별도 처리 — iOS 우선)
- **FR-02 (서버)**: badge 계산은 "이번 알림 포함" 기준이어야 한다 (off-by-one 방지). 발송 로그 insert와 카운트 조회 순서를 보정한다.
- **FR-03 (앱)**: `markAllLogsAsRead` 성공 시 `unreadCount.value=0` + `_updateAppBadge(0)`(아이콘 제거)를 즉시 수행한다.
- **FR-04 (앱)**: 읽음 처리(단건/전체)는 서버 PUT을 `await`한 뒤 `fetchUnreadCount`로 동기화한다 (경합 제거).
- **FR-05 (앱)**: 앱이 포그라운드로 복귀(resumed)할 때 `fetchUnreadCount`를 호출한다 (AppLifecycle 옵저버 추가).
- **FR-06 (앱)**: 안읽음 수의 단일 진실은 **서버 `fetchUnreadCount`** 로 통일한다. 인메모리 `notifications` 리스트는 표시용으로만 쓰고 `unreadCount.value`를 직접 덮어쓰지 않는다.

### 비기능 요구사항 (NFR)

- **NFR-01**: badge 계산 추가 쿼리는 발송당 1회(countUnread)로 제한 — 발송 성능 영향 최소화.
- **NFR-02**: 기존 푸시 전송/로그 동작과 하위 호환 (badge 없는 경로도 정상 동작).
- **NFR-03**: 시뮬레이터/뱃지 미지원 환경에서 예외 안전 (기존 try-catch 유지).

## 성공 기준 (Success Criteria)

| ID | 기준 | 검증 방법 |
|----|------|-----------|
| **SC-01** | 새 알림 도착 시 앱이 닫혀 있어도 아이콘 숫자가 서버 안읽음 수와 일치 | 실기기: 앱 종료 → 푸시 수신 → 아이콘 숫자 확인 |
| **SC-02** | 앱 진입 후 보이는 안읽음 수 = 아이콘 숫자 | 진입 전 아이콘 vs 진입 후 카운트 비교 |
| **SC-03** | 알림 모두 읽고 앱 나오면 **즉시** 아이콘 뱃지 사라짐 (재진입 불필요) | 모두읽음 → 홈 → 백그라운드 → 아이콘 확인 |
| **SC-04** | 단건 읽음 후 카운트/뱃지가 1 감소로 정확히 반영 | 상세 진입 → 뒤로 → 카운트 확인 |
| **SC-05** | 백그라운드→포그라운드 복귀 시 카운트 자동 갱신 | 타기기에서 읽음 처리 → 복귀 → 갱신 확인 |
| **SC-06** | off-by-one 없음 (badge가 실제 안읽음과 정확히 일치, ±0) | 알림 1건 수신 시 badge=정확한 누계 |
| **SC-07** | 인메모리/서버 카운트 충돌로 인한 깜빡임 없음 | 포그라운드 수신 시 숫자 1회만 변동 |

## 제약 / 가정 (Constraints & Assumptions)

- iOS 아이콘 뱃지는 payload `aps.badge` 없이는 닫힌 상태에서 변경 불가 → SC-01/03의 닫힌 상태 정확성은 **서버 badge 주입에 의존** (앱-only 불가).
- badge는 user 단위(countUnread)라 멀티기기 시 모든 기기 동일 — 의도된 동작으로 간주.
- app_type=`FINANCE` 스코프 유지. 타 앱 알림과 섞이지 않음.
- 푸시 탭 딥링크(`notification-detail`)와는 독립. 본 feature는 "숫자 동기화"에 한정.

## 범위 밖 (Out of Scope)

- 알림 그룹핑/요약 뱃지, Android 런처별 뱃지 세분화
- 알림 카테고리별 분리 카운트
- 푸시 data 페이로드 alert_ref 연결(별도 작업)

## 다음 단계

`/pdca design notification-badge-sync` — 3가지 설계안(서버 badge 주입 위치 + 앱 동기화 구조) 비교 후 선택.

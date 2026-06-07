# Analysis: 알림 상세 페이지 + 푸시 딥링크 (notification-detail)

> Feature: notification-detail
> Created: 2026-06-08
> Phase: Check (Gap Analysis)
> Match Rate: 98% (정적 분석, 서버/런타임 미실행)

---

## Context Anchor

| 항목 | 내용 |
|------|------|
| **WHY** | 푸시 탭해도 내용 도달 못 함 + 긴 내용 보텀시트에서 잘림 |
| **WHO** | 푸시 알림 받는 모든 LinkFin 사용자 |
| **RISK** | 푸시 `data`에 seq 포함 여부 미확인(V-01), 콜드스타트 타이밍(V-02) |
| **SUCCESS** | 푸시/목록 탭 → 상세 진입, 긴 내용 전체 스크롤, 읽음 동기화 |
| **SCOPE** | 상세 페이지 + 푸시 딥링크 4경로 + 보텀시트 제거 |

---

## 1. Match Rate

| 축 | 비율 | 가중 |
|----|:----:|:----:|
| Structural (파일/구조) | 100% | ×0.2 |
| Functional (로직 깊이) | 95% | ×0.4 |
| Contract (API) | 100% | ×0.4 |
| **Overall (정적)** | **98%** | — |

> 런타임 미실행(모바일 푸시 = 실기기 필요) → 정적 공식 적용: `S×0.2 + F×0.4 + C×0.4`

---

## 2. Structural Match (100%)

| 설계 항목 | 구현 | 상태 |
|-----------|------|:----:|
| models/notification_detail.dart | 존재 | ✅ |
| screens/notification_detail_screen.dart | 존재 | ✅ |
| notification_list_screen.dart 수정 | showModalBottomSheet 0건 → push | ✅ |
| fcm_service.dart 수정 | pending/openDetail/flush + 핸들러 3종 | ✅ |
| home_screen.dart 수정 | initState flush 호출 | ✅ |

`flutter analyze lib/` → **No issues found**.

---

## 3. Functional Depth (95%) — Success Criteria

| SC | 상태 | 근거 (file:line) |
|----|:----:|------------------|
| SC-01 상세 페이지 신설 | ✅ Met | notification_detail_screen.dart |
| SC-02 목록 탭→상세(보텀시트 제거) | ✅ Met | notification_list_screen.dart `_showDetail` (Navigator.push) |
| SC-03 긴 본문 전체 스크롤 | ✅ Met | SingleChildScrollView + SelectableText |
| SC-04 포그라운드 스낵바→상세 | ✅ Met | fcm_service.dart:178 |
| SC-05 백그라운드 탭→상세 | ✅ Met | fcm_service.dart:133 `_handleMessageOpenedApp` |
| SC-06 종료상태 탭→상세 | ✅ Met (코드) | fcm_service.dart:83 pending → home_screen.dart:34 flush |
| SC-07 읽음 처리+뱃지 동기화 | ✅ Met | fcm_service.dart `_openDetail` (seq != null) + 목록 `_markAsRead` |

> -5%: SC-04~06은 코드 경로는 완비됐으나 실기기 런타임 미검증.

---

## 4. API Contract (100%)

- 신규 엔드포인트 없음.
- 재사용: `fcmLogMy`(본문 보유), `fcmLogRead`(markLogAsRead), `fcmLogUnreadCount`.
- `NotificationDetail.fromLog`/`fromMessage` 두 출처 정규화 — 설계 §3.1 일치.

---

## 5. Decision Record 준수

| 결정 | 준수 |
|------|:----:|
| C안 — 경량 값 객체 정규화 | ✅ |
| Navigator.push (named route 미사용) | ✅ |
| pending 변수 + flush 콜드스타트 | ✅ |
| seq 있을 때만 읽음 처리 | ✅ |

설계 이탈 없음.

---

## 6. Gap / 잔여 항목

| ID | 항목 | 심각도 | 조치 |
|----|------|:------:|------|
| V-01 | 푸시 `message.data`에 seq 포함 여부 | Info | 실기기 푸시 수신 후 `dev.log('알림 탭 data: ...')` 확인. 없으면 푸시 탭 진입 시 읽음 미적용(본문 표시는 정상) — 서버에서 data에 seq 추가 검토 |
| V-02 | 콜드스타트 flush 동작 (스플래시→로그인→홈) | Info | 실기기에서 종료 상태 푸시 탭 테스트 |
| T-03~T-06 | 푸시 4경로 런타임 | Info | 시뮬레이터 FCM 토큰 미발급 → 실기기 필요 |

> Critical/Important(신뢰도 ≥80%) 이슈 **없음**.

---

## 7. 결론

정적 정합성 98%, 설계 이탈 없음, 컴파일 클린. 코드 측면은 완료 상태이며, 남은 것은 **실기기 푸시 런타임 검증(V-01/V-02)** 뿐. 이는 코드 결함이 아닌 환경 의존 검증 항목이므로 Report 단계 진행 가능.

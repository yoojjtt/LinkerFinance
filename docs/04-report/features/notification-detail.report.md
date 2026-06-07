# Report: 알림 상세 페이지 + 푸시 딥링크 (notification-detail)

> Feature: notification-detail
> Created: 2026-06-08
> Phase: Completed
> Match Rate: 98% (정적 분석)

---

## Executive Summary

| 관점 | 내용 |
|------|------|
| **Problem** | 푸시 탭해도 앱만 열리고 내용 미도달 + 목록 긴 알림이 보텀시트에서 잘림 |
| **Solution** | 전체 화면 알림 상세 페이지 신설, 푸시 탭·목록 탭 모두 연결, 보텀시트 제거 |
| **Function UX Effect** | 푸시 누르면 전체 내용 즉시 표시, 목록도 길이 무관 끝까지 읽기 |
| **Core Value** | 알림 내용을 끊김 없이 전부 확인 — 푸시→내용 도달을 한 번에 |

### 1.3 Value Delivered (실제 결과)

| 관점 | 결과 | 지표 |
|------|------|------|
| **Problem 해소** | 푸시 4경로(포그라운드/백그라운드/종료) 전부 상세 진입 경로 확보 | SC-04~06 코드 완비 |
| **Solution 구현** | 상세 페이지 신설 + 보텀시트 제거 | showModalBottomSheet 0건 |
| **UX 효과** | 긴 본문 전체 스크롤 + 텍스트 복사 가능 | SelectableText 적용 |
| **품질** | 정적 정합 98%, 컴파일 클린 | flutter analyze: No issues |

---

## 2. Key Decisions & Outcomes

| 결정 (출처) | 채택 | 준수 | 결과 |
|-------------|------|:----:|------|
| [Plan] C안 — 실용적 균형 | 두 출처 정규화 값 객체 | ✅ | 과설계 없이 목록/푸시 단일 처리 |
| [Design] `NotificationDetail` (fromLog/fromMessage) | 출처 무관 상세 화면 | ✅ | 화면이 데이터 출처를 모름 → 단순 |
| [Design] pending + flushPendingDetail | 콜드스타트 보존 | ✅ | 종료 상태 탭도 홈 진입 후 복원 |
| [Design] seq 있을 때만 읽음 처리 | 안전한 fallback | ✅ | data에 seq 없어도 본문 표시 정상 |

---

## 3. Success Criteria Final Status

| SC | 상태 | 근거 |
|----|:----:|------|
| SC-01 상세 페이지 신설 | ✅ Met | notification_detail_screen.dart |
| SC-02 목록 탭→상세(보텀시트 제거) | ✅ Met | notification_list_screen.dart `_showDetail` |
| SC-03 긴 본문 전체 스크롤 | ✅ Met | SingleChildScrollView + SelectableText |
| SC-04 포그라운드 스낵바→상세 | ✅ Met | fcm_service.dart:178 |
| SC-05 백그라운드 탭→상세 | ✅ Met | fcm_service.dart:133 |
| SC-06 종료상태 탭→상세 | ✅ Met (코드) | fcm_service.dart:83 + home_screen.dart:34 |
| SC-07 읽음 처리+뱃지 동기화 | ✅ Met | `_openDetail` + 목록 `_markAsRead` |

**Success Rate: 7/7 (100%)** — 단, SC-04~06은 실기기 런타임 검증 대기.

---

## 4. 구현 산출물

**신규**
- `lib/models/notification_detail.dart`
- `lib/screens/notification_detail_screen.dart`

**수정**
- `lib/screens/notification_list_screen.dart` — 보텀시트 → push
- `lib/services/fcm_service.dart` — pending/openDetail/flush + 핸들러 3종 + 스낵바
- `lib/screens/home_screen.dart` — initState flush

---

## 5. 잔여 / 후속 (실기기 검증)

| ID | 항목 | 비고 |
|----|------|------|
| V-01 | 푸시 `message.data`에 seq 포함 여부 | `dev.log('알림 탭 data')` 확인. 없으면 서버에서 data.seq 추가 검토 |
| V-02 | 콜드스타트 flush 동작 | 종료 상태 푸시 탭 실기기 테스트 |
| T-03~06 | 푸시 4경로 런타임 | 시뮬레이터 불가 → 실기기 필요 |

---

## 6. 학습 / 회고

- **데이터는 이미 완전했다**: 목록 "잘림"은 데이터 누락이 아니라 보텀시트 높이 제한이었음 → 코드 탐색이 잘못된 가정을 걸러냄.
- **두 출처 정규화 패턴**: 목록 Map / 푸시 RemoteMessage를 값 객체 팩토리로 합치니 화면이 단순해짐. 향후 알림 type별 분기 확장 시에도 이 지점만 손대면 됨.
- **모바일 푸시는 정적 검증 한계**: 시뮬레이터 FCM 미지원으로 런타임은 실기기 의존 — Do 단계에서 검증 로그를 미리 심어 둔 것이 유효.

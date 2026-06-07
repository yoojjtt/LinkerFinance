# Plan: 알림 상세 페이지 + 푸시 딥링크 (notification-detail)

> Feature: notification-detail
> Created: 2026-06-08
> Status: Draft
> Level: Dynamic

---

## Executive Summary

| 관점 | 내용 |
|------|------|
| **Problem** | ① 푸시 알림을 탭해도 앱만 열리고 내용이 안 보인다(이동 없음). ② 알림 목록 탭 시 보텀시트(최대 화면 90%)로 떠서 긴 내용이 다 안 보인다 |
| **Solution** | 별도 **알림 상세 페이지**(전체 화면, 스크롤)를 신설하고, 푸시 탭과 목록 탭 모두 이 페이지로 연결한다. 기존 보텀시트는 제거 |
| **Function UX Effect** | 푸시를 누르면 앱이 열리며 해당 알림의 전체 내용 페이지가 바로 보이고, 목록에서도 길이에 상관없이 전체 내용을 끝까지 읽을 수 있다 |
| **Core Value** | 알림 내용을 끊김 없이 전부 확인 — 푸시→내용 도달 경로를 한 번에 |

## Context Anchor

| 항목 | 내용 |
|------|------|
| **WHY** | 푸시 알림의 핵심 가치(내용 전달)가 끊겨 있음. 탭해도 내용에 도달 못 하고, 긴 내용은 보텀시트에서 잘려 보임 |
| **WHO** | 푸시 알림을 받는 모든 LinkFin 사용자 |
| **RISK** | 푸시 페이로드(`message.data`)에 식별자(seq) 포함 여부 미확인. 콜드 스타트(앱 종료 상태) 탭 시 navigatorKey/로그인 미준비 타이밍 |
| **SUCCESS** | 푸시 탭 시 상세 페이지 자동 진입, 목록 탭 시 상세 페이지 진입, 긴 내용 전체 스크롤 표시, 읽음 처리 유지 |
| **SCOPE** | 상세 페이지 신설 + 푸시 딥링크(포그라운드/백그라운드/종료) + 보텀시트 제거. 알림 종류별 화면 분기(종목/공시로 이동 등)는 제외 |

## 현황 분석 (코드 기준)

| 위치 | 현재 동작 | 문제 |
|------|-----------|------|
| `fcm_service.dart:92` `_handleMessageOpenedApp` | 알림을 로컬 목록에 추가 + 읽음 처리만 | **화면 이동 없음** |
| `fcm_service.dart:74` `getInitialMessage` | 로컬 목록 추가만 | 종료 상태 탭 시 이동 없음 |
| `fcm_service.dart:139` 스낵바 '보기' | `/notifications`(목록)로 이동 | 상세가 아닌 목록까지만 |
| `notification_list_screen.dart:315` `_showDetail` | `showModalBottomSheet`(최대 0.9) | 긴 내용 잘려 보임 |
| `fcmLogMy` 응답 | `seq/title/body/create_DT/is_read` 전부 포함 | **본문 데이터는 이미 완전함** → UI만 교체하면 됨 |

> 핵심: 목록의 긴 내용이 "안 보이는" 건 데이터 누락이 아니라 보텀시트 높이 제한 때문. 전체 페이지로 바꾸면 해결.

## API 매핑 (MVP)

| 기능 | Method | Endpoint | 비고 |
|------|--------|----------|------|
| 알림 목록(본문 포함) | GET | `/api/LB/fcm/log/my` | 이미 사용 중. `body` 전체 포함 |
| 단건 읽음 | PUT | `/api/LB/fcm/log/read?seq=` | 이미 사용 중 (`markLogAsRead`) |

> 단건 조회(by seq) 엔드포인트는 없음. 상세 표시는 (a) 목록 탭은 보유한 `log` 객체, (b) 푸시 탭은 `message.notification.body`(잘리지 않음) 또는 seq 보유 시 목록 API 재조회로 해결.

## 상세 페이지 데이터 소스 전략

| 진입 경로 | 데이터 출처 | 읽음 처리 |
|-----------|-------------|-----------|
| 목록 항목 탭 | 보유한 `log` Map (title/body/create_DT/seq) — 추가 조회 불필요 | seq로 `markLogAsRead` |
| 푸시 탭 (포그라운드 스낵바 '보기') | `RemoteMessage` (notification.title/body, data) | data에 seq 있으면 처리 |
| 푸시 탭 (백그라운드, `onMessageOpenedApp`) | `RemoteMessage` | data에 seq 있으면 처리 |
| 푸시 탭 (종료 상태, `getInitialMessage`) | `RemoteMessage` (앱 준비 후 지연 네비게이션) | data에 seq 있으면 처리 |

## 성공 기준

| # | 기준 |
|---|------|
| SC-01 | 알림 상세 페이지(전체 화면, 제목/시간/본문 스크롤)가 신설된다 |
| SC-02 | 목록 항목 탭 시 보텀시트 대신 상세 페이지로 이동한다 (보텀시트 제거) |
| SC-03 | 긴 본문도 잘리지 않고 끝까지 스크롤하여 읽을 수 있다 |
| SC-04 | 포그라운드 스낵바 '보기' 탭 시 상세 페이지로 이동한다 |
| SC-05 | 백그라운드(앱 실행 중 백그라운드) 푸시 탭 시 상세 페이지로 자동 진입한다 |
| SC-06 | 종료 상태에서 푸시 탭 시 앱 시작 후 상세 페이지로 진입한다 |
| SC-07 | 상세 진입 시 해당 알림이 읽음 처리되고 미읽음 카운트/뱃지에 반영된다 |

## 미해결/검증 필요 (Do 단계 확인)

| # | 항목 | 확인 방법 |
|---|------|-----------|
| V-01 | 서버 푸시 `message.data`에 seq 등 식별자 포함 여부 | 실제 푸시 수신 후 `dev.log('data: ...')` 확인 (포그라운드 핸들러에 이미 로깅 있음) |
| V-02 | 종료 상태 콜드 스타트 시 navigatorKey/로그인 준비 타이밍 | 스플래시/로그인 완료 후 pending 네비게이션 처리 필요 여부 |

## 범위 제외 (Out of Scope)

- 알림 종류(type)별 화면 분기 — 종목 상세/공시 등으로의 딥링크
- 알림 삭제/스와이프 액션
- 서버 단건 조회 API 신설

## 다음 단계

`/pdca design notification-detail` — 상세 페이지 위치, RemoteMessage→상세 데이터 정규화, 콜드스타트 pending 네비게이션 처리 방식을 3가지 설계안으로 비교

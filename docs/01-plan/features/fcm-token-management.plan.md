# FCM 토큰 관리 기능 Plan

> Feature: fcm-token-management
> Created: 2026-05-31
> Status: Draft
> Level: Dynamic

---

## Executive Summary

| 항목 | 내용 |
|------|------|
| Feature | FCM 토큰 등록/갱신/알림 ON/OFF |
| 생성일 | 2026-05-31 |
| 예상 기간 | 1일 |

### Value Delivered

| 관점 | 내용 |
|------|------|
| Problem | FCM 토큰이 서버에 등록되지 않아 서버에서 특정 사용자에게 푸시를 보낼 수 없음 |
| Solution | 로그인 시 자동 토큰 등록, 토큰 갱신 시 자동 재등록, 내정보에서 알림 ON/OFF 제공 |
| Function UX Effect | 사용자는 별도 조작 없이 로그인만으로 푸시 수신 가능, 원하면 내정보에서 끌 수 있음 |
| Core Value | 서버→클라이언트 실시간 알림 채널 확보, 사용자별 알림 제어권 부여 |

## Context Anchor

| Key | Value |
|-----|-------|
| WHY | 서버에서 사용자에게 재무/주식 알림을 보내려면 FCM 토큰이 서버에 등록되어야 함 |
| WHO | Linker Finance 앱 사용자 (관리자) |
| RISK | 시뮬레이터에서 FCM 토큰 못 가져옴 (실기기 필수), 토큰 만료/갱신 누락 |
| SUCCESS | 로그인 후 서버에 토큰 자동 등록됨, 토큰 갱신 시 재등록됨, 알림 ON/OFF 동작 |
| SCOPE | 토큰 등록/갱신/비활성화 + 알림 목록/읽음처리. worker_manager와 동일한 FCM 서비스 구조 |

---

## 1. 요구사항

### 1.1 핵심 기능

| ID | 기능 | 설명 | 우선순위 |
|----|------|------|----------|
| F-01 | 토큰 서버 등록 | 로그인 성공 시 FCM 토큰을 서버 `POST /api/LB/fcm/token/access`로 등록 | 필수 |
| F-02 | 토큰 자동 갱신 | `onTokenRefresh` 리스너로 토큰 변경 감지 시 서버에 재등록 | 필수 |
| F-03 | 알림 ON/OFF | 내정보 화면에서 푸시 알림 토글, OFF 시 `PUT /api/LB/fcm/token/deactivate` 호출 | 필수 |
| F-04 | 포그라운드 알림 | 앱 사용 중 수신된 FCM 메시지를 SnackBar로 표시 | 필수 |
| F-05 | 알림 목록 | 수신된 알림 히스토리 목록 화면 | 필수 |
| F-06 | 읽음 처리 | 알림 개별/전체 읽음 처리 + 미읽음 카운트 배지 | 필수 |

### 1.2 API 매핑

| 기능 | Server API | Method |
|------|-----------|--------|
| 토큰 등록/갱신 | `/api/LB/fcm/token/access` | POST |
| 내 토큰 조회 | `/api/LB/fcm/token/read` | GET |
| 토큰 비활성화 | `/api/LB/fcm/token/deactivate` | PUT |
| 내 알림 목록 | `/api/LB/fcm/log/my` | POST |
| 알림 읽음 처리 | `/api/LB/fcm/log/read` | PUT |
| 전체 읽음 처리 | `/api/LB/fcm/log/readAll` | PUT |
| 미읽음 카운트 | `/api/LB/fcm/log/unreadCount` | GET |

### 1.3 요청 파라미터 (token/access)

| 필드 | 값 | 비고 |
|------|-----|------|
| company_key | `currentUser.companyKey` | 로그인 유저에서 가져옴 |
| user_id | `currentUser.userId` | 로그인 유저에서 가져옴 |
| app_type | `"FINANCE"` | 고정값 (이 앱은 재무앱) |
| token | FCM 토큰 | `FirebaseMessaging.getToken()` |
| device_id | 디바이스 ID | `flutter_secure_storage`에 생성/저장 |
| device_os | `"ANDROID"` or `"iOS"` | `Platform.isIOS` 기준 |

---

## 2. 구현 범위

### 2.1 추가 패키지

| 패키지 | 용도 |
|--------|------|
| `firebase_core` | Firebase 초기화 |
| `firebase_messaging` | FCM 푸시 알림 |

### 2.2 신규/수정 파일

| 파일 | 변경 내용 |
|------|----------|
| `lib/firebase_options.dart` | 신규: Firebase 프로젝트 설정 (FlutterFire CLI로 생성) |
| `lib/main.dart` | 수정: Firebase 초기화, FCM 서비스 설정 |
| `lib/config/api_config.dart` | 수정: FCM 관련 API 엔드포인트 7개 추가 |
| `lib/models/notification_model.dart` | 신규: 알림 데이터 모델 |
| `lib/services/fcm_service.dart` | 신규: 토큰 등록/갱신/비활성화/알림 처리 로직 |
| `lib/services/api_service.dart` | 수정: GET, PUT 메서드 추가 |
| `lib/services/auth_service.dart` | 수정: 로그인 성공 후 토큰 등록 호출 |
| `lib/screens/my_info/my_info_screen.dart` | 수정: 알림 ON/OFF 토글 UI 추가 |
| `lib/screens/notification_list_screen.dart` | 신규: 알림 히스토리 목록 화면 |
| `android/app/google-services.json` | 신규: Firebase Android 설정 |
| `ios/Runner/GoogleService-Info.plist` | 신규: Firebase iOS 설정 |

### 2.3 구현 흐름

```
[로그인 성공]
  → AuthService.login() 성공
  → FcmService.registerToken() 호출
    → FCM 토큰 가져오기
    → POST /api/LB/fcm/token/access
    → 서버에 토큰 seq 저장 (비활성화용)

[토큰 갱신 발생]
  → onTokenRefresh 리스너 감지
  → 로그인 상태면 FcmService.registerToken() 재호출

[포그라운드 메시지 수신]
  → FirebaseMessaging.onMessage 리스너
  → SnackBar로 알림 표시
  → 미읽음 카운트 업데이트

[내정보 → 알림 OFF]
  → PUT /api/LB/fcm/token/deactivate?seq={저장된 seq}
  → 로컬에 OFF 상태 저장

[내정보 → 알림 ON]
  → FcmService.registerToken() 재호출 (새 토큰 등록)
  → 로컬에 ON 상태 저장

[알림 목록 화면]
  → POST /api/LB/fcm/log/my 로 목록 조회
  → 알림 터치 시 PUT /api/LB/fcm/log/read 로 읽음 처리
  → 전체 읽음 버튼 → PUT /api/LB/fcm/log/readAll
```

---

## 3. Firebase 프로젝트 세팅 절차

### 3.1 Firebase 프로젝트 생성
1. [Firebase Console](https://console.firebase.google.com/) 접속
2. "프로젝트 추가" → 프로젝트명: `linker-finance`
3. Google Analytics 설정 (선택)

### 3.2 앱 등록
1. **Android 앱 추가**
   - 패키지명: `com.linkerlab.linkerfinance`
   - `google-services.json` 다운로드 → `android/app/` 에 배치
2. **iOS 앱 추가**
   - Bundle ID: `com.linkerlab.linkerfinance`
   - `GoogleService-Info.plist` 다운로드 → `ios/Runner/` 에 배치

### 3.3 FlutterFire CLI (권장)
```bash
# FlutterFire CLI 설치
dart pub global activate flutterfire_cli

# Firebase 프로젝트 연결 + firebase_options.dart 자동 생성
flutterfire configure --project=linker-finance
```

### 3.4 Android 추가 설정
- `android/build.gradle` — Google Services 플러그인 추가
- `android/app/build.gradle` — `apply plugin: 'com.google.gms.google-services'`
- `minSdkVersion` 21 이상 확인

### 3.5 iOS 추가 설정
- Xcode > Capabilities > Push Notifications 활성화
- APNs 인증키를 Firebase Console에 등록

---

## 4. 성공 기준

| ID | 기준 | 검증 방법 |
|----|------|----------|
| SC-01 | 로그인 후 서버에 토큰이 등록됨 | 서버 DB 또는 token/read API로 확인 |
| SC-02 | 토큰 갱신 시 서버에 새 토큰으로 재등록됨 | 로그 확인 |
| SC-03 | 내정보에서 알림 OFF → 서버 토큰 비활성화됨 | deactivate API 호출 확인 |
| SC-04 | 내정보에서 알림 ON → 서버에 새 토큰 등록됨 | token/access API 호출 확인 |
| SC-05 | 토큰 등록 실패 시 앱이 크래시하지 않음 | 네트워크 끊김 상태 테스트 |
| SC-06 | 포그라운드에서 알림 수신 시 SnackBar 표시 | 실기기 테스트 |
| SC-07 | 알림 목록에서 수신 알림 확인 가능 | 수동 테스트 |
| SC-08 | 알림 읽음 처리 및 미읽음 카운트 정상 작동 | 수동 테스트 |

---

## 5. 리스크

| 리스크 | 영향 | 대응 |
|--------|------|------|
| 시뮬레이터에서 FCM 토큰 못 가져옴 | 개발/테스트 제한 | try-catch로 안전 처리, 실기기 테스트 |
| 토큰 등록 API 실패 | 푸시 수신 불가 | 실패 시 무시 (앱 동작에 영향 없도록), 다음 앱 실행 시 재시도 |
| 로그아웃 없이 앱 삭제 | 비활성 토큰 잔존 | 서버 cleanup API로 관리 (이 앱 범위 밖) |
| Firebase 프로젝트 미생성 | FCM 초기화 실패 | Firebase 세팅 완료 후 구현 시작 |

---

## 6. worker_manager 참고사항

이 Plan은 worker_manager 프로젝트의 `fcm-token-management` 기능을 기반으로 작성되었다.
- **동일**: FCM 서비스 구조(FcmService), API 엔드포인트, 토큰 등록/갱신/비활성화 로직
- **변경**: app_type `"MANAGER"` → `"FINANCE"`, Firebase 프로젝트 별도 생성
- **추가**: 알림 목록/읽음처리 기능 포함 (worker_manager에서 이미 구현된 기능)

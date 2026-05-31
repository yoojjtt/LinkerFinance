# Plan: 관리자 계정 관리 (admin-account)

> Feature: admin-account
> Created: 2026-05-31
> Status: Draft
> Level: Dynamic

---

## Executive Summary

| 항목 | 내용 |
|------|------|
| Feature | 관리자 계정 관리 (로그인~내정보) |
| 생성일 | 2026-05-31 |
| 예상 기간 | 2~3일 |

| 관점 | 내용 |
|------|------|
| **Problem** | 현재 기본 카운터 앱 템플릿 상태로 로그인, 인증, 계정 관리 기능이 전혀 없어 앱을 사용할 수 없다 |
| **Solution** | LinkerBiz 백엔드 API 7개를 연동하여 로그인→내정보 전체 사용자 흐름을 완성한다 (worker_manager와 동일 API) |
| **Function UX Effect** | 로그인 후 내정보 조회/수정이 가능하며, 아이디찾기/비밀번호 재설정으로 자체 계정 복구가 가능하다 |
| **Core Value** | 재무 관리 앱의 최소 진입 조건(인증 기반)을 확보하여 주식/재무 기능 구현의 토대를 만든다 |

---

## Context Anchor

| 항목 | 내용 |
|------|------|
| **WHY** | linker_finance는 주식/재무 관련 기능을 제공할 앱이며, 사용자 인증이 모든 기능의 전제 조건이다. worker_manager와 동일한 LinkerBiz 백엔드를 사용한다 |
| **WHO** | LinkerBiz 서비스를 사용하는 회사 관리자 (user_type 8~9) |
| **RISK** | 서버 API 스펙 변경 시 클라이언트 수정 필요, 자동로그인 시 자격증명 보안 관리 |
| **SUCCESS** | 로그인→내정보 조회/수정→로그아웃 전체 플로우가 동작, 아이디찾기/비밀번호 재설정 정상 작동 |
| **SCOPE** | API 7개 연동 (로그인, 로그아웃, 아이디찾기, 비밀번호재설정, 내정보, 비밀번호변경, 프로필변경). worker_manager의 admin-account 기능과 동일 |

---

## 1. 배경 및 목적

### 1.1 현재 상태
- Flutter 프로젝트 초기 단계 (Dart SDK ^3.9.2)
- 기본 카운터 앱 템플릿 상태 (main.dart만 존재)
- **스플래시, 로그인 화면, API 연동 로직 모두 없음** — 처음부터 구현 필요
- 상태관리, HTTP 클라이언트, 라우팅 구조 미설정
- worker_manager 프로젝트의 동일 기능을 참고하여 구현

### 1.2 목적
LinkerBiz 백엔드 관리자 계정 API 7개를 연동하여 로그인부터 내정보 관리까지 전체 사용자 흐름을 완성한다.
로고/앱이름만 linker_finance로 변경하고, 나머지 로그인/계정 로직은 worker_manager와 동일하게 구현한다.

---

## 2. 요구사항

### 2.1 기능 요구사항

#### FR-01: 로그인
- `POST /api/LB/user/userAccess`로 아이디/비밀번호 전송
- 성공 시 사용자 정보(`res[0]`) 저장 후 메인 화면으로 이동
- 실패 시 에러 메시지 표시 (300: 비밀번호 불일치, 400: 계정 없음)
- 자동로그인 체크 시 자격증명을 로컬에 저장하여 다음 실행 시 자동 로그인

#### FR-02: 로그아웃
- `POST /api/LB/user/userAccessOut`으로 로그아웃 처리
- 로컬 세션 및 자동로그인 정보 삭제
- 로그인 화면으로 이동

#### FR-03: 아이디 찾기
- 이름 + 핸드폰번호 입력 화면
- `POST /api/LB/account/findId` 호출
- 성공 시 마스킹된 아이디 표시 (예: `hon*****`)
- 실패 시 에러 표시 (400: 일치 계정 없음)

#### FR-04: 비밀번호 재설정
- 아이디 + 이름 + 핸드폰번호 입력 화면
- `POST /api/LB/account/resetPassword` 호출
- 성공 시 "임시 비밀번호가 SMS로 발송되었습니다" 안내
- 실패 시 에러 표시 (400~500 코드별 메시지)

#### FR-05: 내 정보 조회
- `POST /api/LB/account/myInfo`로 로그인 사용자 정보 조회
- 이름, 이메일, 연락처, 회사, 유형/레벨, 주소, 은행정보 등 표시
- 마이페이지 화면 구성

#### FR-06: 비밀번호 변경
- 현재 비밀번호 + 새 비밀번호 + 확인 입력
- `POST /api/LB/account/changePassword` 호출
- 새 비밀번호 최소 6자 클라이언트 검증
- 성공 시 안내 후 로그인 화면으로 이동 (재로그인 유도)

#### FR-07: 연락처·이메일 변경
- 핸드폰번호, 이메일 편집 가능한 UI
- `POST /api/LB/account/updateProfile` 호출
- 변경할 항목만 전송
- 성공 시 갱신된 정보로 화면 업데이트

### 2.2 비기능 요구사항

| 항목 | 기준 |
|------|------|
| 보안 | 자동로그인 자격증명은 `flutter_secure_storage`로 암호화 저장 |
| 성능 | API 응답 대기 시 로딩 인디케이터 표시 |
| UX | 에러 시 SnackBar로 사용자 안내, 네트워크 오류 핸들링 |
| 호환성 | iOS, Android 모바일 우선 (기존 설정 유지) |

---

## 3. 기술 스택

### 3.1 추가 패키지

| 패키지 | 용도 |
|--------|------|
| `http` | HTTP 클라이언트 (API 호출) |
| `flutter_secure_storage` | 자격증명(아이디/비밀번호) 암호화 저장 |

### 3.2 상태관리
- **StatefulWidget + setState** 기본 사용 (worker_manager와 동일)
- 로그인 사용자 정보는 싱글톤 패턴으로 앱 전역 공유
- 추후 규모 커지면 Provider/Riverpod 도입 고려

### 3.3 프로젝트 구조 (신규 파일)

```
lib/
├── main.dart                          # 수정: 라우팅, Firebase 초기화
├── config/
│   └── api_config.dart                # API Base URL, 엔드포인트 상수
├── models/
│   └── user_model.dart                # 사용자 데이터 모델
├── services/
│   ├── api_service.dart               # HTTP 클라이언트 래퍼
│   └── auth_service.dart              # 로그인/로그아웃/자동로그인 로직
├── screens/
│   ├── splash_screen.dart             # 신규: 스플래시 + 자동로그인 체크
│   ├── login_screen.dart              # 신규: 로그인 화면
│   ├── find_id_screen.dart            # 신규: 아이디 찾기
│   ├── reset_password_screen.dart     # 신규: 비밀번호 재설정
│   ├── home_screen.dart               # 신규: 로그인 후 메인 화면 (3탭)
│   └── my_info/
│       ├── my_info_screen.dart        # 신규: 내 정보 메인
│       └── change_password_screen.dart # 신규: 비밀번호 변경
└── widgets/
    └── loading_overlay.dart           # 신규: 로딩 인디케이터 오버레이
```

---

## 4. 사용자 흐름

```
[앱 시작]
  └── SplashScreen
        ├── 자동로그인 정보 있음 → API 로그인 시도
        │     ├── 성공 → HomeScreen
        │     └── 실패 → LoginScreen (저장 정보 삭제)
        └── 자동로그인 없음 → LoginScreen

[LoginScreen]
  ├── 로그인 버튼 → API 호출 → HomeScreen
  ├── 아이디 찾기 → FindIdScreen
  └── 비밀번호 재설정 → ResetPasswordScreen

[HomeScreen] (3탭: Home / Finance / MyInfo)
  └── 내 정보(MyInfo 탭) → MyInfoScreen
        ├── 정보 조회 (자동)
        ├── 연락처/이메일 변경
        ├── 비밀번호 변경 → ChangePasswordScreen
        └── 로그아웃 → LoginScreen
```

---

## 5. API 매핑

| 기능 | Method | Endpoint | 인증 |
|------|--------|----------|:----:|
| 로그인 | POST | `/api/LB/user/userAccess` | N |
| 로그아웃 | POST | `/api/LB/user/userAccessOut` | N |
| 아이디 찾기 | POST | `/api/LB/account/findId` | N |
| 비밀번호 재설정 | POST | `/api/LB/account/resetPassword` | N |
| 내 정보 조회 | POST | `/api/LB/account/myInfo` | Y |
| 비밀번호 변경 | POST | `/api/LB/account/changePassword` | Y |
| 연락처·이메일 변경 | POST | `/api/LB/account/updateProfile` | Y |

### 공통 응답 형식
```json
{
  "resultCode": "200",   // 200=성공, 300~=비즈니스에러, 400~=입력에러
  "res": { ... }
}
```

---

## 6. 구현 우선순위

| 순서 | 모듈 | 설명 | 의존성 |
|:----:|------|------|--------|
| 1 | config + models | API 설정, 사용자 모델 | 없음 |
| 2 | api_service | HTTP 클라이언트 기반 | config |
| 3 | auth_service | 로그인/로그아웃/자동로그인 | api_service |
| 4 | splash_screen | 스플래시 + 자동로그인 체크 | auth_service |
| 5 | login_screen | 로그인 UI + API 연동 | auth_service |
| 6 | find_id_screen | 아이디 찾기 화면 + API | api_service |
| 7 | reset_password_screen | 비밀번호 재설정 화면 + API | api_service |
| 8 | home_screen | 로그인 후 메인 화면 (3탭) | auth_service |
| 9 | my_info_screen | 내 정보 조회/수정 | api_service |
| 10 | change_password_screen | 비밀번호 변경 | api_service |

---

## 7. 리스크

| 리스크 | 영향 | 대응 |
|--------|------|------|
| 서버 API 스펙 변경 | API 호출 실패 | api_config.dart에 엔드포인트 중앙 관리, 모델 파싱 에러 핸들링 |
| 자동로그인 자격증명 유출 | 보안 사고 | flutter_secure_storage 사용 (키체인/키스토어) |
| 네트워크 불안정 | UX 저하 | 타임아웃 설정, 재시도 안내 |
| SMS 발송 실패 (비밀번호 재설정) | 서버측 이슈 | resultCode 500 처리, 사용자에게 재시도 안내 |

---

## 8. 성공 기준

| # | 기준 | 검증 방법 |
|---|------|-----------|
| SC-01 | 올바른 아이디/비밀번호로 로그인 성공 시 HomeScreen 진입 | 수동 테스트 |
| SC-02 | 잘못된 자격증명으로 로그인 시 에러 메시지 표시 | 수동 테스트 |
| SC-03 | 자동로그인 체크 후 앱 재시작 시 자동으로 HomeScreen 진입 | 수동 테스트 |
| SC-04 | 아이디 찾기에서 이름+핸드폰 입력 시 마스킹된 ID 표시 | 수동 테스트 |
| SC-05 | 비밀번호 재설정 요청 시 성공/실패 메시지 정상 표시 | 수동 테스트 |
| SC-06 | 내 정보 화면에서 사용자 정보 정상 표시 | 수동 테스트 |
| SC-07 | 비밀번호 변경 성공 후 재로그인 가능 | 수동 테스트 |
| SC-08 | 연락처/이메일 변경 후 갱신된 정보 표시 | 수동 테스트 |
| SC-09 | 로그아웃 시 로그인 화면으로 이동, 자동로그인 정보 삭제 | 수동 테스트 |

---

## 9. worker_manager 참고사항

이 Plan은 worker_manager 프로젝트의 `admin-account` 기능을 기반으로 작성되었다.
- **동일**: API 엔드포인트, 데이터 모델(UserModel), 서비스 로직(AuthService, ApiService), 화면 구성
- **변경**: 앱 이름(Linker Finance), 로고, HomeScreen 탭 구성(Work 탭 → Finance 탭)
- **제외**: 송장/결재 워크플로우(worker_manager의 work-menu-approval) — 별도 주식/재무 기능으로 대체 예정

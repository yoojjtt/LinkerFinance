# Analysis: 관리자 계정 관리 (admin-account)

> Feature: admin-account
> Analyzed: 2026-05-31
> Match Rate: 99%
> Design: docs/02-design/features/admin-account.design.md

---

## Context Anchor

| 항목 | 내용 |
|------|------|
| **WHY** | linker_finance는 주식/재무 관련 기능을 제공할 앱이며, 사용자 인증이 모든 기능의 전제 조건이다 |
| **WHO** | LinkerBiz 서비스를 사용하는 회사 관리자 (user_type 8~9) |
| **RISK** | 서버 API 스펙 변경 시 클라이언트 수정 필요, 자동로그인 시 자격증명 보안 관리 |
| **SUCCESS** | 로그인→내정보 조회/수정→로그아웃 전체 플로우가 동작, 아이디찾기/비밀번호 재설정 정상 작동 |
| **SCOPE** | API 7개 연동 (로그인, 로그아웃, 아이디찾기, 비밀번호재설정, 내정보, 비밀번호변경, 프로필변경) |

---

## 1. Overall Scores

| Category | Score | Status |
|----------|:-----:|:------:|
| Structural Match | 100% | PASS |
| Functional Depth | 98% | PASS |
| API Contract | 100% | PASS |
| **Overall (static)** | **99%** | **PASS** |

Formula: Overall = (Structural × 0.2) + (Functional × 0.4) + (Contract × 0.4)

---

## 2. Structural Match (100%)

| # | Design Path | Exists | Status |
|---|-------------|:------:|:------:|
| 1 | `lib/main.dart` | YES | PASS |
| 2 | `lib/config/api_config.dart` | YES | PASS |
| 3 | `lib/models/user_model.dart` | YES | PASS |
| 4 | `lib/services/api_service.dart` | YES | PASS |
| 5 | `lib/services/auth_service.dart` | YES | PASS |
| 6 | `lib/widgets/loading_overlay.dart` | YES | PASS |
| 7 | `lib/screens/splash_screen.dart` | YES | PASS |
| 8 | `lib/screens/login_screen.dart` | YES | PASS |
| 9 | `lib/screens/find_id_screen.dart` | YES | PASS |
| 10 | `lib/screens/reset_password_screen.dart` | YES | PASS |
| 11 | `lib/screens/home_screen.dart` | YES | PASS |
| 12 | `lib/screens/my_info/my_info_screen.dart` | YES | PASS |
| 13 | `lib/screens/my_info/change_password_screen.dart` | YES | PASS |

13/13 파일 존재 확인

---

## 3. API Contract (100%)

| # | Endpoint | Request Body | Response | Contract |
|---|----------|:------------:|:--------:|:--------:|
| 1 | `/api/LB/user/userAccess` | `{username, password}` | `res[0]` as Array | PASS |
| 2 | `/api/LB/user/userAccessOut` | `{username, password}` | fire-and-forget | PASS |
| 3 | `/api/LB/account/findId` | `{user_name, user_cell}` | `res.user_id` | PASS |
| 4 | `/api/LB/account/resetPassword` | `{user_id, user_name, user_cell}` | String message | PASS |
| 5 | `/api/LB/account/myInfo` | `{user_id}` | `res` as Object | PASS |
| 6 | `/api/LB/account/changePassword` | `{user_id, current_password, new_password}` | String message | PASS |
| 7 | `/api/LB/account/updateProfile` | `{user_id, user_cell?, user_email?}` | UserModel | PASS |

Error code 처리 전체 일치 (300/400/401/500 코드별 메시지 매핑 정확)

---

## 4. Plan Success Criteria

| # | 기준 | 상태 | 근거 |
|---|------|:----:|------|
| SC-01 | 올바른 자격증명으로 로그인 성공 시 HomeScreen 진입 | ✅ Met | `auth_service.dart:30` login → `login_screen.dart:285` pushReplacement |
| SC-02 | 잘못된 자격증명으로 로그인 시 에러 메시지 표시 | ✅ Met | `auth_service.dart:36` _loginErrorMessage → `login_screen.dart:290` SnackBar |
| SC-03 | 자동로그인 체크 후 앱 재시작 시 자동 HomeScreen 진입 | ✅ Met | `splash_screen.dart:81` _checkAutoLogin flow |
| SC-04 | 아이디 찾기에서 마스킹된 ID 표시 | ✅ Met | `find_id_screen.dart:53` `res['user_id']` 표시 |
| SC-05 | 비밀번호 재설정 성공/실패 메시지 정상 표시 | ✅ Met | `reset_password_screen.dart:57-63` 분기 처리 |
| SC-06 | 내 정보 화면에서 사용자 정보 정상 표시 | ✅ Met | `my_info_screen.dart:30` _loadMyInfo → 프로필/연락처/주소/은행 표시 |
| SC-07 | 비밀번호 변경 성공 후 재로그인 가능 | ✅ Met | `change_password_screen.dart:85` _showSuccessAndLogout |
| SC-08 | 연락처/이메일 변경 후 갱신된 정보 표시 | ✅ Met | `my_info_screen.dart:82` _editField → updateProfile API |
| SC-09 | 로그아웃 시 로그인 화면 이동, 자동로그인 삭제 | ✅ Met | `my_info_screen.dart:157` _onLogout → pushAndRemoveUntil |

**Success Rate: 9/9 (100%)**

---

## 5. Gaps Found

| # | Category | Location | Description | Severity |
|---|----------|----------|-------------|:--------:|
| 1 | Functional | `user_model.dart` | `toJson()` 메서드 미구현 (Design §3.1 코멘트에 언급) | Minor |
| 2 | Functional | `my_info_screen.dart` | 푸시 알림 ON/OFF 토글 미구현 (Design §6.6 와이어프레임) | Minor |
| 3 | Structural | `main.dart` | Firebase 초기화 주석 처리 | Minor |

모든 Gap은 `fcm-token-management` feature 범위로 의도적 연기. admin-account 범위 내 기능은 100% 완성.

---

## 6. Navigation Flow (100%)

| Flow | Design | Implementation | Match |
|------|--------|----------------|:-----:|
| Splash → HomeScreen (자동로그인 성공) | pushReplacement | pushReplacement | PASS |
| Splash → LoginScreen (실패/없음) | pushReplacement | pushReplacement | PASS |
| Login → HomeScreen | pushReplacement | pushReplacement | PASS |
| Login → FindIdScreen | push | push | PASS |
| Login → ResetPasswordScreen | push | push | PASS |
| MyInfo → ChangePasswordScreen | push | push | PASS |
| ChangePassword 성공 → LoginScreen | pushAndRemoveUntil | pushAndRemoveUntil | PASS |
| 로그아웃 → LoginScreen | pushAndRemoveUntil | pushAndRemoveUntil | PASS |

---

## 7. Design Token (100%)

| 토큰 | 설계값 | 구현값 | Match |
|------|--------|--------|:-----:|
| primaryColor | `#1B2E5C` | `Color(0xFF1B2E5C)` | PASS |
| accentColor | `#FFD700` | `Color(0xFFFFD700)` | PASS |
| backgroundColor | `#F5F5F7` | `Color(0xFFF5F5F7)` | PASS |
| inputFillColor | `#FAF8F0` | `Color(0xFFFAF8F0)` | PASS |
| borderRadius(card/btn/input) | 16/12/10 | 16/12/10 | PASS |

---

## 8. flutter analyze

```
Analyzing linker_finance...
No issues found! (ran in 1.3s)
```

import 'package:flutter/foundation.dart' show kReleaseMode;

// Design Ref: §5.1 — API Base URL + 엔드포인트 중앙 관리
class ApiConfig {
  static const String baseUrl = kReleaseMode
      ? 'https://main-api.linkerbiz.net'
      : 'http://localhost:20118';

  // 계정 관련
  static const String login = '/api/LB/user/userAccess';
  static const String logout = '/api/LB/user/userAccessOut';
  static const String findId = '/api/LB/account/findId';
  static const String resetPassword = '/api/LB/account/resetPassword';
  static const String myInfo = '/api/LB/account/myInfo';
  static const String changePassword = '/api/LB/account/changePassword';
  static const String updateProfile = '/api/LB/account/updateProfile';

  // FCM 토큰
  static const String fcmTokenAccess = '/api/LB/fcm/token/access';
  static const String fcmTokenRead = '/api/LB/fcm/token/read';
  static const String fcmTokenDeactivate = '/api/LB/fcm/token/deactivate';

  // FCM 발송 이력
  static const String fcmLogMy = '/api/LB/fcm/log/my';
  static const String fcmLogRead = '/api/LB/fcm/log/read';
  static const String fcmLogReadAll = '/api/LB/fcm/log/readAll';
  static const String fcmLogUnreadCount = '/api/LB/fcm/log/unreadCount';

  // 거시경제 대시보드
  static const String macroLatest = '/api/IV/quant/macro/latest';
  static const String macroCurrent = '/api/IV/quant/macro/current';
  static const String macroHistory = '/api/IV/quant/macro/history';
  static const String macroYieldSpread = '/api/IV/quant/macro/yield-spread';
  static const String macroFearGreed = '/api/IV/quant/macro/fear-greed';
  static const String macroCategories = '/api/IV/quant/macro/categories';

  // 관심종목
  static const String watchlistGroups = '/api/IV/quant/watchlist/groups';
  static const String watchlistStocks = '/api/IV/quant/watchlist/stocks';
  static const String watchlistReturns = '/api/IV/quant/watchlist/returns';

  // 종목 차트/검색
  static const String stockChart = '/api/IV/quant/screener/stock'; // /{code}?days=
  static const String stockSearch = '/api/IV/kiwoom/stock/search'; // ?keyword=

  // AI 모니터 알림 (전체 내용 = ai_commentary)
  static const String monitorAlerts =
      '/api/IV/monitor/alerts'; // /{id}?companyKey=&userId=

  // 시장일지
  static const String journal = '/api/IV/journal';

  // 심리 (투자 원칙 + 체크리스트)
  static const String psych = '/api/IV/psych';

  // 매매기법
  static const String strategy = '/api/IV/strategy';

  // 일정관리
  static const String events = '/api/IV/quant/events';
}

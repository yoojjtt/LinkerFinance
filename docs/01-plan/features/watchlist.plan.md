# Plan: 관심종목 (watchlist)

> Feature: watchlist
> Created: 2026-05-31
> Status: Draft
> Level: Dynamic

---

## Executive Summary

| 관점 | 내용 |
|------|------|
| **Problem** | Finance 탭이 placeholder 상태로 주식 관련 기능이 없다 |
| **Solution** | 관심종목 그룹 관리 + 종목 카드(현재가/등락률/기간수익률) + 그룹 평균수익률을 구현한다 |
| **Function UX Effect** | Finance 탭에서 관심종목을 그룹별로 조회하고, 기간별 수익률로 포트폴리오 성과를 한눈에 파악한다 |
| **Core Value** | 투자자의 관심종목 모니터링 — 모바일에서 빠르게 현황 확인 |

## Context Anchor

| 항목 | 내용 |
|------|------|
| **WHY** | Finance 탭 placeholder 교체. 거시경제(홈) 다음으로 가장 많이 사용할 화면 |
| **WHO** | 주식 투자 관리자 — 관심종목을 그룹별로 관리하는 사용자 |
| **RISK** | 종목 수가 많을 때 가격 조회 API 부하, 실시간 가격 갱신 빈도 |
| **SUCCESS** | 그룹 필터 동작, 종목 카드(현재가/등락률/수익률) 정상 표시, Pull-to-refresh |
| **SCOPE** | 그룹 조회 + 종목 조회(with_price) + 기간수익률 조회. CRUD/스코어/비교는 제외 |

## API 매핑 (MVP)

| 기능 | Method | Endpoint | Params |
|------|--------|----------|--------|
| 그룹 목록 | GET | `/api/IV/quant/watchlist/groups` | company_key, user_id |
| 종목 목록 | GET | `/api/IV/quant/watchlist/stocks` | company_key, user_id, group_id?, with_price=true |
| 기간수익률 | POST | `/api/IV/quant/watchlist/returns` | stock_codes[], period |

## 성공 기준

| # | 기준 |
|---|------|
| SC-01 | Finance 탭에서 관심종목 그룹 목록 표시 |
| SC-02 | 그룹 필터 선택 시 해당 그룹 종목만 표시 |
| SC-03 | 종목 카드에 이름/현재가/등락률 표시 |
| SC-04 | 기간 선택(1주/1개월/6개월/1년) 시 수익률 표시 |
| SC-05 | 그룹별 평균수익률 표시 |
| SC-06 | Pull-to-refresh 동작 |

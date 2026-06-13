# Chart UX Improvement Plan

## Executive Summary

| 관점 | 내용 |
|------|------|
| **Problem** | 차트 라이브러리 3개 혼용(fl_chart/interactive_chart/k_chart), 스크롤 미지원, 가격 포맷 가독성 저하 |
| **Solution** | Syncfusion Flutter Charts 1개로 통합, 수평 스크롤 + 미래 여백 + 현재가 마커 + Y축 콤마 포맷 |
| **UX Effect** | 미래에셋 수준의 차트 탐색 — 터치 스크롤/줌, 현재가 즉시 파악, 일관된 차트 경험 |
| **Core Value** | 라이브러리 통합으로 유지보수 단순화 + 투자 분석 필수 기능 완성 |

## Context Anchor

| Key | Value |
|-----|-------|
| **WHY** | 차트 가독성·탐색성 부족 + 라이브러리 파편화로 유지보수 부담 |
| **WHO** | 개인 투자자 (주식/거시경제 지표 분석) |
| **RISK** | Syncfusion Community License 적용 필요, 기존 차트 코드 전면 교체 |
| **SUCCESS** | 좌우 스크롤, 미래 여백, Y축 콤마 포맷, 현재가 마커, 라이브러리 1개 통합 |
| **SCOPE** | 거시경제 라인차트 + 종목상세 캔들차트 |

---

## 1. 요구사항

### 1.1 라이브러리 통합

| # | 항목 | 내용 |
|---|------|------|
| L1 | 도입 | `syncfusion_flutter_charts` 추가 |
| L2 | 제거 | `fl_chart`, `interactive_chart`, `k_chart` 제거 |
| L3 | 라이선스 | Community License 등록 (무료, 매출 $1M 이하) |

### 1.2 공통 차트 개선

| # | 요구사항 | 설명 |
|---|---------|------|
| R1 | 좌우 스크롤 | `ZoomPanBehavior(enablePanning: true)` |
| R2 | 미래 여백 | 차트 오른쪽 빈 영역 (~20%) |
| R3 | Y축 가격 포맷 | 콤마 구분자 + 소수점 (NumberFormat) |
| R4 | 현재가 마커 | Y축에 현재가 수평선 + 라벨 (plotBands) |
| R5 | 핀치 줌 | `enablePinching: true` |

### 1.3 거시경제 차트 (라인)

| # | 개선 |
|---|------|
| M1 | SfCartesianChart + LineSeries로 교체 |
| M2 | X축 날짜 라벨, Y축 가격 라벨 표시 |
| M3 | 높이 확대 (~250px) |

### 1.4 종목상세 차트 (캔들)

| # | 개선 |
|---|------|
| S1 | SfCartesianChart + CandleSeries로 교체 |
| S2 | 기술지표 내장 사용 (SMA, Bollinger Bands) |
| S3 | 현재가 수평선 + 라벨 |

---

## 2. 수정 대상 파일

| 파일 | 변경 |
|------|------|
| `pubspec.yaml` | syncfusion 추가, fl_chart/interactive_chart/k_chart 제거 |
| `lib/screens/macro/asset_history_chart.dart` | Syncfusion LineSeries로 전면 재작성 |
| `lib/screens/stock/stock_detail_screen.dart` | Syncfusion CandleSeries로 전면 재작성 |
| `lib/utils/macro_utils.dart` | Y축용 짧은 가격 포맷 함수 추가 |
| `lib/screens/stock/chart_overlay_painter.dart` | 삭제 (Syncfusion 내장 기능으로 대체) |
| `lib/utils/chart_indicators.dart` | 삭제 또는 축소 (내장 지표 사용) |

## 3. 성공 기준

| # | 기준 |
|---|------|
| SC1 | 두 차트 모두 좌우 드래그 스크롤 동작 |
| SC2 | 오른쪽 미래 여백 존재 |
| SC3 | Y축 가격 콤마 포맷 (예: 94,700) |
| SC4 | 현재가 수평선 + 라벨 표시 |
| SC5 | 라이브러리 1개(syncfusion)로 통합 완료 |
| SC6 | 기존 기술지표(MA/BB) 동작 유지 |

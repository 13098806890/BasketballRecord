# Korean Voice Rules Analysis

## ASR Locale
- `ko-KR`

## Shot Keywords

| Spoken Phrase | eventCode | Notes |
|---|---|---|
| `투` / `투포인트` / `2` | stat.two | |
| `쓰리` / `쓰리포인트` / `3` | stat.three | |
| `레이업` | stat.layup | |
| `미드` / `미드레인지` | stat.midRange | |
| `페인트` / `인사이드` | stat.paint | |
| `자유투` / `프리스로우` | stat.freeThrow | |
| `보너스` / `원 플러스` | stat.bonus | |

## Made / Missed States

| Spoken | Type |
|---|---|
| `성공` / `들어감` / `득점` | made |
| `실패` / `빗나감` / `블록` / `못 넣음` | missed |

## Stat Events

| Spoken Phrase | eventCode | Notes |
|---|---|---|
| `파울` | stat.foul | |
| `리바운드` / `공격 리바운드` / `수비 리바운드` | stat.rebound | |
| `어시스트` | stat.assist | |
| `블록` | stat.block | |
| `스틸` | stat.steal | |
| `턴오버` / `트레블링` / `더블드리블` | stat.turnover | "트레블링" = traveling |

## Commands

| Spoken Phrase | eventCode | Notes |
|---|---|---|
| `시작` / `첫 쿼터` / `다음 쿼터` | event.period | |
| `일시정지` / `타임아웃` | event.pause | |
| `재개` / `계속` | event.pause | |
| `종료` / `경기종료` | event.game_end | |

## Substitution Keywords

`교체` / `체인지` / `교체 투입`

Number formats supported via `extractNumber`:
- `#5` / `5번`
- `5` alone (standalone digit)

## Fuzzy Map
Korean — empty. No pinyin normalization needed.

## Conflicts to Watch
1. `미드` could match "mid" or "middle" — in Korean basketball context, "미드레인지" is the intended match; "미드" alone works as shorthand
2. `블록` as missed state vs `블록` as stat event — shot matching runs first; "블록" in shot context (블록 당함 = blocked shot) matches missed state; standalone "블록" matches stat.block via non-shot path
3. `체인지` is an English loanword (change) — specific to substitution context

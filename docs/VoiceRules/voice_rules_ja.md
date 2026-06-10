# Japanese Voice Rules Analysis

## ASR Locale
- `ja-JP`

## Shot Keywords (シュート種類)

Japanese basketball uses English loanwords (Katakana) for most shot types:

| Spoken Phrase | eventCode | Notes |
|---|---|---|
| `ツー` / `ツーポイント` / `2` / `２` | stat.two | "two" / "two point" |
| `スリー` / `スリーポイント` / `3` / `３` | stat.three | "three" / "three point" |
| `レイアップ` | stat.layup | layup |
| `ミドル` / `ミドルレンジ` | stat.midRange | mid / mid range |
| `ペイント` / `インサイド` | stat.paint | paint / inside |
| `ポストアップ` | stat.paint | post up |
| `フリースロー` / `フリー` | stat.freeThrow | free throw |
| `ボーナス` / `ワンワン` | stat.bonus | bonus / "one one" (and one) |

"ワンワン" (wan wan = one one) is a colloquial Japanese basketball term for "and one".

## Made / Missed States

| Spoken | Type | Notes |
|---|---|---|
| `入った` / `はいった` | made | "went in" — most natural |
| `決まった` / `きまった` | made | "decided/confirmed" |
| `成功` / `せいこう` | made | "success" |
| `得点` / `とくてん` | made | "scored" |
| `外した` / `はずした` | missed | "missed/off target" |
| `入らない` / `はいらない` | missed | "doesn't go in" |
| `ミス` | missed | miss |
| `失敗` / `しっぱい` | missed | failure |
| `ブロック` | missed | blocked (loanword) |

## Stat Events (統計イベント)

| Spoken Phrase | eventCode | Notes |
|---|---|---|
| `ファウル` / `ファール` | stat.foul | foul |
| `リバウンド` | stat.rebound | rebound |
| `オフェンスリバウンド` | stat.rebound | offensive rebound |
| `ディフェンスリバウンド` | stat.rebound | defensive rebound |
| `アシスト` | stat.assist | assist |
| `ブロック` / `ショットブロック` | stat.block | block / shot block |
| `スティール` | stat.steal | steal |
| `ターンオーバー` | stat.turnover | turnover |
| `トラベリング` | stat.turnover | traveling |
| `バイオレーション` | stat.turnover | violation |
| `ダブルドリブル` | stat.turnover | double dribble |

Note: `ブロック` appears in both missed states (blocked shot) and stat events (block). Shot path runs first; "ブロックされた" or "ブロック" after a shot keyword matches missed state, while standalone "ブロック" matches stat.block via non-shot path.

## Commands (コマンド)

| Spoken Phrase | eventCode | Notes |
|---|---|---|
| `開始` / `スタート` | event.period | start |
| `第1クオーター` / `第1Q` | event.period | first quarter |
| `次のクオーター` / `次` | event.period | next quarter |
| `タイムアウト` | event.pause | timeout |
| `一時停止` | event.pause | pause |
| `休憩` | event.pause | break |
| `再開` / `リスタート` | event.pause | resume / restart |
| `続ける` | event.pause | continue |
| `終了` / `試合終了` | event.game_end | end / game end |

## Substitution Keywords (交代)

`交代` / `選手交代` / `チェンジ` / `入れ替え` / `代え` / `リプレース`

Number format: `5番` is supported via extractNumber.

## Fuzzy Map
Japanese — empty. No pinyin normalization needed.

## Conflicts to Watch
1. `ブロック` — shot keyword suffix vs stat event. Shot matching runs first; "ブロック" after a made/missed state check passes through to stat.block.
2. Short Katakana words like `ツー` (2) vs `ツーポイント` (two point) — `findKeyword("ツー")` matches "ツー" in "ツーポイント" → OK since they map to same eventPrefix.

## Recommendations
1. Add `ツーポイント`, `スリーポイント` as shot keyword variants
2. Add `ワンワン` for bonus/and-one
3. Add `入らない` as missed state (natural negative form)
4. Add more stat event variants (offensive/defensive rebound, traveling, violation, double dribble)
5. Keep game_end commands (no confusion issue in Japanese)
6. Add `第1Q`, `次のクオーター` for period commands
7. Add `選手交代` to substitution keywords
8. Keep fuzzyMap empty

# English Voice Rules Analysis

## ASR Locale
- `en-US` — primary; `en-GB`/`en-AU` would share nearly identical rules

## Shot Keywords

| Spoken Phrase | eventCode | Notes |
|---|---|---|
| `two` / `two pointer` / `2` / `2 pointer` / `2pt` | stat.two | "two" also matches "two points" naturally |
| `three` / `three pointer` / `3` / `3 pointer` / `3pt` / `trey` / `triple` | stat.three | |
| `layup` / `finger roll` | stat.layup | |
| `mid` / `mid range` / `jumper` / `jump shot` / `pull up` | stat.midRange | |
| `paint` / `inside` / `post up` / `hook` / `baby hook` | stat.paint | |
| `free throw` / `foul shot` / `freebie` / `charity` | stat.freeThrow | |
| `bonus` / `and one` / `and1` | stat.bonus | |

"downtown" and "from deep" are too vague (could be confused with other keywords) — skip.

## Made / Missed States

| Spoken | Type |
|---|---|
| `made` / `good` / `in` / `score` / `scores` / `swish` | made |
| `missed` / `miss` / `no` / `not` / `out` / `short` / `blocked` / `airball` / `brick` | missed |

"got it" is ambiguous between made and rebound — skip.
"rim" and "front rim" are specific miss descriptions but ASR reliability is low — skip.

## Stat Events

| Spoken Phrase | eventCode | Notes |
|---|---|---|
| `foul` / `reach` / `push` / `hold` / `hack` | stat.foul | |
| `rebound` / `board` / `glass` / `offensive board` / `defensive board` | stat.rebound | Single eventCode for all rebound types |
| `assist` / `dime` / `helper` | stat.assist | |
| `block` / `rejection` / `swat` | stat.block | |
| `steal` / `pick` / `takeaway` / `strip` | stat.steal | |
| `turnover` / `travel` / `walk` / `violation` / `carry` / `palming` / `double dribble` | stat.turnover | |

"offensive foul" and "charge" map to foul but might not be reliably recognized by ASR.

## Commands

| Spoken Phrase | eventCode | Notes |
|---|---|---|
| `start` / `begin` / `tip off` / `jump ball` / `first quarter` / `second half` | event.period | "next quarter" is useful for manual period advance |
| `next quarter` / `next period` | event.period | |
| `timeout` / `pause` / `stop` / `halt` / `freeze` / `hold` | event.pause | |
| `resume` / `continue` / `unpause` / `play` / `go` | event.pause | |
| `end` / `finish` / `game over` / `final` | event.game_end | |

## Substitution Keywords

`sub` / `substitution` / `replace` / `swap` / `change` / `switch` / `in for`

Number formats supported via `extractNumber`:
- `#5` / `number 5` / `no.5` / `no 5`
- `5` alone (standalone digit)

## Fuzzy Map
English — empty. No pinyin normalization needed.

## Conflicts to Watch
1. `two` vs `timeout` — `findKeyword("two")` does NOT match "timeout" (character sequence differs)
2. `block` as shot keyword vs `block` as stat event — shot matching runs first; "blocked shot" goes through shot missed state ("blocked" is in missedStates), "block" alone matches stat.block via non-shot path
3. `in` as made state vs `in` as preposition — "in" in "layup in" or "sub in" could cause false made state match. Mitigation: `in` is a short word, player name matching on left text provides context.
4. `mid` could match "mid-range" — `findKeyword("mid")` finds "mid" in "mid range" ✅

## Recommendations for VoiceRules_en.swift Updates

1. Add "two pointer", "three pointer", "2 pointer", "3 pointer" as additional shot keywords
2. Add "trey" for three
3. Add "jumper", "jump shot", "pull up" for mid-range
4. Add "and one" for bonus
5. Add more missed states: "brick", "short"
6. Keep game_end commands (no confusion issue in English)
7. Add "jump ball", "next quarter" for period
8. Add "switch" to substitution keywords
9. Add "walk", "carry", "palming", "double dribble" to turnover stat events
10. Keep fuzzyMap empty

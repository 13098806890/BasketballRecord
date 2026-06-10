# Russian Voice Rules Analysis

## ASR Locale
- `ru-RU`

## Shot Keywords

| Spoken Phrase | eventCode | Notes |
|---|---|---|
| `два` / `2` | stat.two | |
| `три` / `3` | stat.three | |
| `лей-ап` | stat.layup | |
| `средний` | stat.midRange | Short for "средний бросок" (mid-range shot) |
| `краска` / `изнутри` | stat.paint | "краска" = paint area, "изнутри" = inside |
| `штрафной` / `штрафной бросок` | stat.freeThrow | |
| `бонус` | stat.bonus | |

"дальний" (long-range) is too vague — three-pointer should use "три" explicitly.

## Made / Missed States

| Spoken | Type |
|---|---|
| `забил` / `попал` / `есть` / `очко` | made |
| `промах` / `мимо` / `заблокировали` / `не попал` | missed |

## Stat Events

| Spoken Phrase | eventCode | Notes |
|---|---|---|
| `фол` | stat.foul | |
| `подбор` / `подбор в нападении` / `подбор в защите` | stat.rebound | |
| `передача` / `ассист` | stat.assist | |
| `блок` / `блок-шот` | stat.block | |
| `перехват` | stat.steal | |
| `потеря` / `пробежка` / `нарушение` | stat.turnover | "пробежка" = traveling, "нарушение" = violation |

## Commands

| Spoken Phrase | eventCode | Notes |
|---|---|---|
| `начало` / `старт` / `первая четверть` | event.period | |
| `пауза` / `тайм-аут` | event.pause | |
| `продолжить` | event.pause | |
| `конец` / `конец игры` | event.game_end | |

## Substitution Keywords

`замена` / `меняем` / `заменить`

Number formats supported via `extractNumber`:
- `#5` / `номер 5`
- `5` alone (standalone digit)

## Fuzzy Map
Russian — empty. No pinyin normalization needed.

## Conflicts to Watch
1. `блок` and `блок-шот` — keyword matching is exact, "блок" does not match "блок-шот" and vice versa (added both)
2. `конец` alone vs `конец игры` — exact match first, then partial match; both resolve to game_end which is correct
3. `нарушение` is very generic — could match various violations but all map to turnover
